--[[
	PlateBuffs Core - Refactored for C_NamePlate API
	
	This is the refactored core.lua adapted to use Awesome WotLK's C_NamePlate system
	instead of the legacy LibNameplate library.
]]

local folder, core = ...

-- Global lookups (optimized for performance)
local _G = _G
local pairs = pairs
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local GetTime = GetTime
local table_sort = table.sort
local LibStub = LibStub
local table_insert = table.insert
local table_remove = table.remove
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitAura = UnitAura
local UnitAffectingCombat = UnitAffectingCombat
local UnitReaction = UnitReaction
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local GetSpellInfo = GetSpellInfo
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local select = select
local type = type
local Debug = core.Debug

-- OPTIMIZATION: Cache player GUID at load time
local playerGUID = UnitGUID("player")

-- Addon metadata
core.title = "Plate Buffs |cff1784d1Enhanced|r"
core.version = GetAddOnMetadata(folder, "X-Curse-Packaged-Version") or ""
core.titleFull = core.title .. " " .. core.version
core.addonDir = "Interface\\AddOns\\" .. folder .. "\\"

-- Default spell lists
local totemList = {
    2484, 8143, 8177, 8512, 6495, 8170, 3738, 2062, 2894, 58734, 58582, 58753,
    58739, 58656, 58745, 58757, 58774, 58749, 58704, 58643, 57722,
}

local defaultSpells1 = {
    118, 51514, 710, 6358, 6770, 605, 33786, 5782, 5484, 6789, 45438, 642, 8122,
    339, 23335, 23333, 34976, 2094, 33206, 29166, 47585, 19386,
}

local defaultSpells2 = {
    15487, 10060, 2825, 5246, 31224, 498, 47476, 31884, 37587, 12472, 49039, 48792,
    5277, 53563, 22812, 67867, 1499, 2637, 64044, 19503, 34490, 10278, 10326, 44572,
    20066, 46968, 46924, 16689, 2983, 2335, 6624, 3448, 11464, 17634, 53905, 54221, 1850,
}

-- Add class-specific default spells
local myClass = select(2, UnitClass("player"))
if myClass == "DRUID" or myClass == "ROGUE" then
    table.insert(defaultSpells2, 132)   -- Detect Invisibility
    table.insert(defaultSpells2, 16882) -- Detect Greater Invisibility
    table.insert(defaultSpells2, 6512)  -- Detect Lesser Invisibility
end

-- Database and profile references
core.db = {}
local db, P

-- Data structures (changed from plate frame keys to unit token keys)
core.guidBuffs = {}   -- guidBuffs[unit] = { aura data }
core.buffBars = {}    -- buffBars[unit] = { bar frames }
core.buffFrames = {}  -- buffFrames[unit] = { icon frames }

local buffBars = core.buffBars
local guidBuffs = core.guidBuffs
local buffFrames = core.buffFrames

-- Single shared ticker: UNIT_AURA does not fire for nameplate unit tokens in WotLK 3.3.5,
-- so we poll UnitAura on a 250ms interval instead of one OnUpdate per bar frame.
local AURA_POLL_INTERVAL = 0.25
local tickFrame = CreateFrame("Frame")
tickFrame.elapsed = 0
tickFrame:Hide()

-- Settings
core.defaultSettings = {
    profile = {
        spellOpts = {},
        ignoreDefaultSpell = {},
        skin_SkinID = "Blizzard",
        skin_Gloss = false,
        skin_Backdrop = false,
        skin_Colors = {},
    },
}

-- UI references
local coreOpts, spellUI, dspellUI, profileUI, whoUI, barUI

-- Totem name mapping
local totems = {}
local name, texture
for i = 1, #totemList do
    name, _, texture = GetSpellInfo(totemList[i])
    if name then
        totems[name] = texture
    end
end

-- Initialize default spells in settings
local defaultSettings = core.defaultSettings
for i = 1, #defaultSpells1 do
    name = GetSpellInfo(defaultSpells1[i])
    if name then
        defaultSettings.profile.spellOpts[name] = {
            iconSize = 80,
            cooldownSize = 18,
            show = 1,
            stackSize = 18,
        }
    end
end

for i = 1, #defaultSpells2 do
    name = GetSpellInfo(defaultSpells2[i])
    if name then
        defaultSettings.profile.spellOpts[name] = {
            iconSize = 40,
            cooldownSize = 14,
            show = 1,
            stackSize = 14,
        }
    end
end

-- Ace setup
LibStub("AceAddon-3.0"):NewAddon(core, folder, "AceConsole-3.0", "AceEvent-3.0")
core.L = LibStub("AceLocale-3.0"):GetLocale(folder, true)
local L = core.L

function core:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PBE_DB", core.defaultSettings, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileDeleted", "OnProfileChanged")
    self:RegisterChatCommand("pb", "MySlashProcessorFunc")

    local config = LibStub("AceConfig-3.0")
    local dialog = LibStub("AceConfigDialog-3.0")
    
    config:RegisterOptionsTable(self.title, self.CoreOptionsTable)
    coreOpts = dialog:AddToBlizOptions(self.title, self.titleFull)

    config:RegisterOptionsTable(self.title .. "Who", self.WhoOptionsTable)
    whoUI = dialog:AddToBlizOptions(self.title .. "Who", L["Who"], self.titleFull)

    config:RegisterOptionsTable(self.title .. "Spells", self.SpellOptionsTable)
    spellUI = dialog:AddToBlizOptions(self.title .. "Spells", L["Specific Spells"], self.titleFull)

    config:RegisterOptionsTable(self.title .. "dSpells", self.DefaultSpellOptionsTable)
    dspellUI = dialog:AddToBlizOptions(self.title .. "dSpells", L["Default Spells"], self.titleFull)

    config:RegisterOptionsTable(self.title .. "Rows", self.BarOptionsTable)
    barUI = dialog:AddToBlizOptions(self.title .. "Rows", L["Rows"], self.titleFull)

    config:RegisterOptionsTable(self.title .. "Profile", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
    profileUI = dialog:AddToBlizOptions(self.title .. "Profile", L["Profiles"], self.titleFull)
end

function core:OnEnable()
    db = self.db
    P = db.profile

    -- Register C_NamePlate events
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_AURA")

    -- Re-show any hidden bars
    for unit in pairs(buffBars) do
        for i = 1, #(buffBars[unit] or {}) do
            buffBars[unit][i]:Show()
        end
    end

    -- Scan for any existing nameplates that might have been created before addon loaded
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates(false)
        if plates then
            for _, plate in ipairs(plates) do
                if plate.nameplateUnitToken then
                    self:NAME_PLATE_UNIT_ADDED(nil, plate.nameplateUnitToken)
                end
            end
        end
    end

    -- Start the shared aura poll ticker
    tickFrame.elapsed = 0
    tickFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < (P.auraPollInterval or AURA_POLL_INTERVAL) then return end
        self.elapsed = 0
        for unit in pairs(guidBuffs) do
            core:UpdateAurasForUnit(unit)
            core:AddBuffsToPlate(unit)
            core:UpdateAllBarSizes(unit)
        end
    end)
    tickFrame:Show()
end

function core:OnDisable()
    -- Stop the shared aura poll ticker
    tickFrame:Hide()
    tickFrame:SetScript("OnUpdate", nil)

    -- Release all active nameplate frames back to the pools
    local units = {}
    for unit in pairs(guidBuffs) do
        units[#units + 1] = unit
    end
    for _, unit in ipairs(units) do
        self:HidePlateSpells(unit)
        self:ReleaseBuffBars(unit)
        guidBuffs[unit] = nil
    end
end

function core:OnProfileChanged()
    self:Disable()
    self:Enable()
end

function core:MySlashProcessorFunc(input)
    if input == "debug" then
        -- Debug: Show aura data info
        -- Count plates correctly (table_getn doesn't work with string keys)
        local plateCount = 0
        for unit in pairs(buffFrames or {}) do
            plateCount = plateCount + 1
        end
        
        self:Print("Debug: addon is loaded and tracking nameplates.")
        
    elseif input == "test" then
        -- Manual test: try to find and process plates
        self:Print("Test: scanning for nameplates...")
        if C_NamePlate and C_NamePlate.GetNamePlates then
            local plates = C_NamePlate.GetNamePlates(false)
            if plates then
                print("  Found " .. #plates .. " plates")
                for idx, plate in ipairs(plates) do
                    if plate.nameplateUnitToken then
                        local unit = plate.nameplateUnitToken
                        print("    Plate " .. idx .. ": " .. unit)
                        
                        -- Try to query auras with different unit references
                        print("      Testing UnitAura queries:")
                        
                        -- Try with nameplate token
                        local name1, _ = UnitAura(unit, 1, "HARMFUL")
                        print("        UnitAura('" .. unit .. "'): " .. (name1 or "nil"))
                        
                        -- Try other queries with nameplate token
                        print("        UnitExists('" .. unit .. "'): " .. tostring(UnitExists(unit)))
                        local unitName = UnitName(unit)
                        print("        UnitName('" .. unit .. "'): " .. (unitName or "nil"))
                        
                        -- Try with target
                        if UnitExists("target") then
                            local name2, _ = UnitAura("target", 1, "HARMFUL")
                            print("        UnitAura('target'): " .. (name2 or "nil"))
                            print("        Target name: " .. UnitName("target"))
                        end
                        
                        -- Dump frame properties
                        print("      Frame properties:")
                        if plate.UnitFrame then
                            print("        plate.UnitFrame exists")
                        end
                        if plate.unit then
                            print("        plate.unit: " .. tostring(plate.unit))
                        end
                        if plate.guid then
                            print("        plate.guid: " .. tostring(plate.guid))
                        end
                        if plate.nameplateUnitToken then
                            print("        plate.nameplateUnitToken: " .. tostring(plate.nameplateUnitToken))
                        end
                        
                        -- Try all properties
                        print("      All frame properties:")
                        for key, val in pairs(plate) do
                            if type(val) ~= "table" and type(val) ~= "userdata" then
                                print("        " .. key .. ": " .. tostring(val))
                            end
                        end
                    end
                end
            else
                print("  GetNamePlates returned nil")
            end
        else
            print("  C_NamePlate not available")
        end
    else
        InterfaceOptionsFrame_OpenToCategory(spellUI)
        InterfaceOptionsFrame_OpenToCategory(coreOpts)
    end
end

---
--- MAIN EVENT HANDLERS
---

function core:NAME_PLATE_UNIT_ADDED(event, unit)
    -- unit is like "nameplate1", "nameplate2", etc.
    if not unit then
        return
    end

    -- Get the frame for this unit
    local frame = C_NamePlate.GetNamePlateForUnit(unit)
    if not frame then
        return
    end

    -- Store the actual unit token on the frame for later use
    -- The "unit" parameter (nameplate1, nameplate2) is the display unit token
    frame.displayUnit = unit

    -- Initialize data storage for this unit
    guidBuffs[unit] = {}
    buffFrames[unit] = {}

    -- Build frame container anchored to the nameplate
    self:BuildBuffFrameForUnit(unit, frame)

    -- Populate initial aura data using the actual display unit
    self:UpdateAurasForUnit(unit, frame)
    self:AddBuffsToPlate(unit)
    
    -- Debug log
    if not self.plateCount then self.plateCount = 0 end
    self.plateCount = self.plateCount + 1
end

function core:NAME_PLATE_UNIT_REMOVED(event, unit)
    Debug("NAME_PLATE_UNIT_REMOVED", unit)
    self:HidePlateSpells(unit)   -- returns icon frames to pool
    self:ReleaseBuffBars(unit)   -- returns bar frames to pool
    guidBuffs[unit] = nil
end

function core:UNIT_AURA(event, ...)
    local unit = ...

    -- Only process nameplate units
    if not unit or not unit:match("^nameplate%d+$") then
        return
    end

    -- Check if we're tracking this nameplate
    if not buffFrames[unit] then
        return
    end

    -- Update aura data and refresh display
    self:UpdateAurasForUnit(unit)
    self:AddBuffsToPlate(unit)
end

---
--- FILTERING FUNCTIONS
---

function core:ShouldShowNameplateAuras(unit)
    -- Get unit information
    if not UnitExists(unit) then
        return false
    end

    local unitName = UnitName(unit)

    -- Check totem filter
    if P.showTotems == false and self:IsTotem(unitName) then
        return false
    end

    -- Check TYPE filters (Players vs NPCs)
    local isPlayer = UnitIsPlayer(unit)
    
    if isPlayer then
        if P.abovePlayers ~= true then
            return false
        end
    else
        if P.aboveNPC ~= true then
            return false
        end
    end

    -- Check REACTION filters (Friendly, Neutral, Hostile)
    local reaction = UnitReaction("player", unit)
    
    if reaction then
        if reaction >= 5 then
            -- Friendly
            if P.aboveFriendly ~= true then
                return false
            end
        elseif reaction == 4 then
            -- Neutral
            if P.aboveNeutral ~= true then
                return false
            end
        elseif reaction <= 3 then
            -- Hostile
            if P.aboveHostile ~= true then
                return false
            end
        end
    end

    -- Check COMBAT filters
    if isPlayer then
        if P.playerCombatWithOnly == true and not UnitAffectingCombat(unit) then
            return false
        end
    else
        if P.npcCombatWithOnly == true and not UnitAffectingCombat(unit) then
            return false
        end
    end

    return true
end

function core:IsTotem(unitName)
    return totems[unitName] ~= nil
end

function core:HaveSpellOpts(spellName)
    if not P or not spellName then
        return false
    end
    if P.ignoreDefaultSpell and P.ignoreDefaultSpell[spellName] then
        return false
    end
    if P.spellOpts and P.spellOpts[spellName] then
        return P.spellOpts[spellName]
    end
    return false
end

---
--- AURA COLLECTION & FILTERING
---

function core:UpdateAurasForUnit(unit, frame)
    -- Clear existing aura data for this unit
    guidBuffs[unit] = {}

    -- Dynamic filter: if this unit currently shouldn't show auras (e.g. not in combat
    -- yet when npcCombatWithOnly=true), leave guidBuffs empty so AddBuffsToPlate hides
    -- all icons. The tick will re-evaluate every poll cycle automatically.
    if not self:ShouldShowNameplateAuras(unit) then
        return
    end

    local debuffCount = 0

    -- The "unit" parameter is for the nameplate (e.g., "nameplate1")
    -- Try to query auras directly with the nameplate token first
    local queryUnit = unit
    
    local i = 1

    -- Collect HELPFUL auras (buffs)
    while true do
        local name, rank, icon, count, dispelType, duration, expirationTime, unitCaster,
              isStealable, shouldConsolidate, spellId = UnitAura(queryUnit, i, "HELPFUL")

        if not name then
            break
        end
        


        if self:ShouldShowAura(name, unitCaster, "BUFF") then
            -- Ensure all values are proper types
            duration = tonumber(duration) or 0
            expirationTime = tonumber(expirationTime) or 0
            count = tonumber(count) or 0
            icon = tostring(icon) or ""
            
            table_insert(guidBuffs[unit], {
                name = name,
                icon = icon,
                spellId = spellId,
                expirationTime = expirationTime,
                duration = duration,
                startTime = expirationTime - duration,
                stackCount = count,
                playerCast = (unitCaster == "player") and 1 or nil,
                caster = unitCaster,
                isDebuff = false,
                debuffType = nil,
            })
        end
        i = i + 1
    end

    -- Collect HARMFUL auras (debuffs)
    i = 1
    while true do
        local name, rank, icon, count, dispelType, duration, expirationTime, unitCaster,
              isStealable, shouldConsolidate, spellId = UnitAura(queryUnit, i, "HARMFUL")

        if not name then
            break
        end
        


        debuffCount = debuffCount + 1
        
        local shouldShow = self:ShouldShowAura(name, unitCaster, "DEBUFF", dispelType)
        
        if shouldShow then
            -- Ensure all values are proper types
            duration = tonumber(duration) or 0
            expirationTime = tonumber(expirationTime) or 0
            count = tonumber(count) or 0
            icon = tostring(icon) or ""
            
            table_insert(guidBuffs[unit], {
                name = name,
                icon = icon,
                spellId = spellId,
                expirationTime = expirationTime,
                duration = duration,
                startTime = expirationTime - duration,
                stackCount = count,
                playerCast = (unitCaster == "player") and 1 or nil,
                caster = unitCaster,
                isDebuff = true,
                debuffType = dispelType or "none",
            })
        end
        i = i + 1
    end
    
end

function core:IsCasterPlayer(caster)
    -- OPTIMIZATION: Use cached playerGUID instead of calling UnitGUID repeatedly
    if not caster then
        return false
    end
    
    if caster == "player" then
        return true
    end
    
    -- Direct GUID comparison (most common case)
    if playerGUID and caster == playerGUID then
        return true
    end
    
    return false
end

function core:ShouldShowAura(name, caster, auraType, debuffType)
    local spellOpts = self:HaveSpellOpts(name)

    -- Apply spell-specific settings
    if spellOpts and spellOpts.show then
        if spellOpts.show == 1 then
            return true  -- Always show
        elseif spellOpts.show == 2 then
            return self:IsCasterPlayer(caster)  -- Only show player's casts
        else
            return false  -- Don't show
        end
    end

    -- Apply default settings
    if auraType == "BUFF" then
        if P.defaultBuffShow == 1 then
            return true
        elseif P.defaultBuffShow == 2 then
            return self:IsCasterPlayer(caster)
        else
            return false
        end
    else
        -- DEBUFF
        if P.defaultDebuffShow == 1 then
            return true
        elseif P.defaultDebuffShow == 2 then
            return self:IsCasterPlayer(caster)
        else
            return false
        end
    end
end

---
--- SPELL MANAGEMENT FUNCTIONS
---

function core:AddNewSpell(spellName)
    -- Validate spell name is not empty
    if not spellName or spellName == "" then
        self:Print("Spell name cannot be empty")
        return
    end
    
    local P = self.db.profile
    if not P.spellOpts then
        P.spellOpts = {}
    end
    
    -- Add the new spell with default settings
    P.spellOpts[spellName] = {
        iconSize = P.iconSize or 24,
        cooldownSize = P.cooldownSize or 14,
        show = 1,
        stackSize = P.stackSize or 14,
    }
    
    self:Print("Added spell: " .. spellName)
    
    -- Refresh the UI to show the new spell
    self:BuildSpellUI()
end

function core:RemoveSpell(spellName)
    if not spellName then
        return
    end
    
    local P = self.db.profile
    if P.spellOpts and P.spellOpts[spellName] then
        P.spellOpts[spellName] = nil
        self:Print("Removed spell: " .. spellName)
        
        -- Refresh the UI
        self:BuildSpellUI()
    end
end

-- Option tables are defined in options.lua
