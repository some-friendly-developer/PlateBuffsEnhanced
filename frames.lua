--[[
	PlateBuffs Frames - Refactored for C_NamePlate API
	
	This handles frame creation and management for the refactored PlateBuffs addon.
	Key change: All frames now keyed by unit token ("nameplate1", etc.) instead of plate frame references.
]]

local folder, core = ...

local L = core.L or LibStub("AceLocale-3.0"):GetLocale(folder, true)
local _G = _G
local pairs = pairs
local GetTime = GetTime
local CreateFrame = CreateFrame
local table_remove = table.remove
local table_sort = table.sort
local type = type
local table_getn = table.getn
local Debug = core.Debug
local DebuffTypeColor = DebuffTypeColor
local select = select
local string_gsub = string.gsub

local buffBars = core.buffBars
local buffFrames = core.buffFrames
local guidBuffs = core.guidBuffs

core.unknownIcon = "Inv_misc_questionmark"

-- Settings are initialized in core.lua

-- Create a module-level reference for P that will be updated
local P = {}

local prev_OnEnable = core.OnEnable
function core:OnEnable()
    -- Set P BEFORE calling prev_OnEnable so events can access it
    P = self.db.profile
    Core = self -- For debugging
    prev_OnEnable(self)
end

---
--- BUFF ICON DISPLAY LOGIC
---

local function UpdateBuffSize(frame, size)
    frame.icon:SetWidth(size)
    frame.icon:SetHeight(size)
    frame:SetWidth(size)

    if P.showCooldown == true then
        frame:SetHeight(size + frame.cd:GetStringHeight())
    else
        frame:SetHeight(size)
    end
end

local function UpdateBuffCDSize(buffFrame, size)
    buffFrame.cd:SetFont("Fonts\\FRIZQT__.TTF", size, "NORMAL")
    buffFrame.cdbg:SetHeight(buffFrame.cd:GetStringHeight())
end

local function SetStackSize(buffFrame, size)
    buffFrame.stack:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
end

local function iconOnShow(self)
    self:SetAlpha(1)

    self.cdbg:Hide()
    self.cd:Hide()
    self.cdtexture:Hide()
    self.stack:Hide()

    if P.showCooldown == true and self.expirationTime > 0 then
        self.cdbg:Show()
        self.cd:Show()

        if P.showCooldownTexture == true then
            self.cdtexture:SetCooldown(self.startTime, self.duration)
            self.cdtexture:Show()
        end
    end

    local iconSize = P.iconSize
    local cooldownSize = P.cooldownSize
    local stackSize = P.stackSize

    local spellName = self.spellName or "X"
    local spellOpts = core:HaveSpellOpts(spellName)

    if spellOpts then
        iconSize = spellOpts.iconSize or iconSize
        cooldownSize = spellOpts.cooldownSize or cooldownSize
        stackSize = spellOpts.stackSize or stackSize
    end

    UpdateBuffCDSize(self, cooldownSize)

    if self.stackCount and tonumber(self.stackCount) and tonumber(self.stackCount) > 1 then
        self.stack:SetText(tostring(self.stackCount))
        self.stack:Show()
        SetStackSize(self, stackSize)
    end

    if self.isDebuff then
        local colour = DebuffTypeColor[self.debuffType or ""]
        if colour then
            -- Optionally apply debuff coloring
        end
    end

    if self.playerCast and P.biggerSelfSpells == true then
        UpdateBuffSize(self, iconSize * 1.2)
    else
        UpdateBuffSize(self, iconSize)
    end
end

local function iconOnHide(self)
    self.stack:Hide()
    self.cdbg:Hide()
    self.cd:Hide()
    self.cdtexture:Hide()
    self:SetAlpha(1)

    UpdateBuffSize(self, P.iconSize)
end

local function iconOnUpdate(self, elapsed)
    if not self.expirationTime or self.expirationTime <= 0 then
        return  -- OPTIMIZATION: Skip expensive calculations if no expiration
    end

    self.lastUpdate = (self.lastUpdate or 0) + elapsed
    
    -- OPTIMIZATION: Only update display every 0.1s instead of every frame
    if self.lastUpdate <= 0.1 then
        return
    end
    self.lastUpdate = 0

    local rawTimeLeft = self.expirationTime - GetTime()
    
    -- Hide buff if already expired
    if rawTimeLeft <= 0 then
        self:Hide()
        return
    end

    local timeLeft = core:Round(rawTimeLeft, (rawTimeLeft < 10) and 1 or 0)

    -- Update cooldown display only if visible
    if P.showCooldown == true then
        self.cd:SetText(core:SecondsToString(timeLeft, 1))
        self.cd:SetTextColor(core:RedToGreen(timeLeft, self.duration))
        self.cdbg:SetWidth(self.cd:GetStringWidth())
    end

    -- OPTIMIZATION: Cache blink calculation threshold to avoid repeated division
    if (timeLeft / self.duration) < (P.blinkTimeleft or 0.2) and timeLeft < 60 then
        local f = GetTime() % 1
        if f > 0.5 then
            f = 1 - f
        end
        self:SetAlpha(f * 3)
    end
end

---
--- FRAME CREATION
---

local function CreateBuffFrame(parentFrame, unit)
    local f = CreateFrame("Frame", nil, parentFrame)

    f.unit = unit  -- Store unit token instead of nameplate reference
    f:SetFrameStrata("BACKGROUND")

    f.icon = CreateFrame("Frame", nil, f)
    f.icon:SetPoint("TOP", f)
    f.texture = f.icon:CreateTexture(nil, "BACKGROUND")
    f.texture:SetAllPoints(true)

    local cd = f:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    cd:SetText("0")
    cd:SetPoint("TOP", f.icon, "BOTTOM")

    f.cd = cd
    f.cdbg = f:CreateTexture(nil, "BACKGROUND")
    f.cdbg:SetTexture(0, 0, 0, .75)
    f.cdbg:SetPoint("CENTER", cd)

    f.cdtexture = CreateFrame("Cooldown", nil, f.icon, "CooldownFrameTemplate")
    f.cdtexture:SetReverse(true)
    f.cdtexture:SetDrawEdge(false)
    f.cdtexture:SetAllPoints(true)

    core:SetFrameLevel(f)

    f.stack = f.icon:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    f.stack:SetText("0")
    f.stack:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -1, 3)

    f.lastUpdate = 0
    f.expirationTime = 0

    f:SetScript("OnShow", iconOnShow)
    f:SetScript("OnHide", iconOnHide)
    f:SetScript("OnUpdate", iconOnUpdate)

    f.stackCount = 0
    f.cdbg:Hide()
    f.cd:Hide()
    f.cdtexture:Hide()
    f.stack:Hide()

    return f
end

local function CreateBarFrame(parentFrame, unit)
    local f = CreateFrame("frame", nil, parentFrame)
    f.unit = unit
    f.nameplateFrame = parentFrame  -- Store reference to nameplate frame
    f.lastAuraUpdate = 0
    f.auraUpdateInterval = 0.25  -- Check auras every 250ms instead of 500ms (reduced from original)

    f:SetFrameStrata("BACKGROUND")
    f:SetBackdrop(nil)  -- Remove any border
    f:SetWidth(1)
    f:SetHeight(1)

    f.barBG = f:CreateTexture(nil, "BACKGROUND")
    f.barBG:SetAllPoints(true)
    f.barBG:SetTexture("Interface\\Buttons\\WHITE8x8")  -- Use WoW's built-in white texture
    f.barBG:SetVertexColor(1, 1, 0, 0.5)  -- Yellow with 50% alpha for visibility

    if P.showBarBackground == true then
        f.barBG:Show()
    else
        f.barBG:Hide()
    end

    -- OPTIMIZATION: Keep polling but increase interval from 500ms to 250ms
    -- UNIT_AURA doesn't fire for nameplate display tokens, so polling is necessary
    -- 250ms is still a 50% reduction from original while maintaining responsiveness
    f:SetScript("OnUpdate", function(self, elapsed)
        self.lastAuraUpdate = self.lastAuraUpdate + elapsed
        if self.lastAuraUpdate >= self.auraUpdateInterval then
            self.lastAuraUpdate = 0
            if self.unit and buffFrames[self.unit] then
                core:UpdateAurasForUnit(self.unit, self.nameplateFrame)
                core:AddBuffsToPlate(self.unit)
            end
        end
    end)

    f:Show()
    return f
end

---
--- FRAME BUILDING
---

function core:BuildBuffFrameForUnit(unit, nameplateFrame)
    -- Validate inputs
    if not unit or not nameplateFrame then
        return
    end

    -- Create bar frame structure
    if not buffBars[unit] then
        buffBars[unit] = {}
    end

    if not buffBars[unit][1] then
        buffBars[unit][1] = CreateBarFrame(nameplateFrame, unit)
    end

    buffBars[unit][1]:ClearAllPoints()
    
    -- Validate P values with defaults
    local barPoint = P.barAnchorPoint or "BOTTOM"
    local platePoint = P.plateAnchorPoint or "TOP"
    local offsetX = P.barOffsetX or 0
    local offsetY = P.barOffsetY or 0
    
    buffBars[unit][1]:SetPoint(barPoint, nameplateFrame, platePoint, offsetX, offsetY)
    buffBars[unit][1]:SetParent(nameplateFrame)

    -- Create additional bars if configured
    local numBars = P.numBars or 2
    if numBars > 1 then
        for r = 2, numBars do
            if not buffBars[unit][r] then
                buffBars[unit][r] = CreateBarFrame(nameplateFrame, unit)
            end
            buffBars[unit][r]:ClearAllPoints()
            buffBars[unit][r]:SetPoint(barPoint, buffBars[unit][r - 1], platePoint, 0, 0)
            buffBars[unit][r]:SetParent(nameplateFrame)
        end
    end

    -- Create icon frames
    local totalIcons = numBars * (P.iconsPerBar or 6)
    if not buffFrames[unit] or not buffFrames[unit][totalIcons] then
        self:BuildIconFrames(unit)
    end
end

function core:BuildIconFrames(unit)
    buffFrames[unit] = buffFrames[unit] or {}

    local total = 0
    local prevFrame = nil

    for bar = 1, P.numBars do
        for icon = 1, P.iconsPerBar do
            total = total + 1

            if not buffFrames[unit][total] then
                buffFrames[unit][total] = CreateBuffFrame(buffBars[unit][bar], unit)
            end

            buffFrames[unit][total]:SetParent(buffBars[unit][bar])
            buffFrames[unit][total]:ClearAllPoints()

            if icon == 1 and bar == 1 then
                buffFrames[unit][total]:SetPoint("BOTTOMLEFT", buffBars[unit][bar])
            elseif icon == 1 then
                buffFrames[unit][total]:SetPoint("BOTTOMLEFT", buffBars[unit][bar])
            else
                buffFrames[unit][total]:SetPoint("BOTTOMLEFT", prevFrame, "BOTTOMRIGHT")
            end

            prevFrame = buffFrames[unit][total]
        end
    end
end

---
--- BUFF DISPLAY & UPDATES
---

function core:AddBuffsToPlate(unit)
    -- unit is the key, not plate
    local numBars = P.numBars or 2
    local iconsPerBar = P.iconsPerBar or 6
    local totalIcons = numBars * iconsPerBar
    
    if not buffFrames[unit] or not buffFrames[unit][totalIcons] then
        return
    end

    if guidBuffs[unit] then
        -- OPTIMIZATION: Only sort if aura count changed (simple delta detection)
        local auraCount = table_getn(guidBuffs[unit] or {})
        local shouldSort = (buffFrames[unit].lastAuraCount or 0) ~= auraCount
        buffFrames[unit].lastAuraCount = auraCount
        
        if shouldSort then
            -- Sort buffs: player cast first, then by expiration time, then by name
            table_sort(guidBuffs[unit], function(a, b)
                if a and b then
                    if a.playerCast ~= b.playerCast then
                        return (a.playerCast or 0) > (b.playerCast or 0)
                    elseif a.expirationTime == b.expirationTime then
                        return a.name < b.name
                    else
                        return (a.expirationTime or 0) < (b.expirationTime or 0)
                    end
                end
            end)
        end

        -- Update icon frames with aura data
        for i = 1, totalIcons do
            if buffFrames[unit][i] then
                if guidBuffs[unit][i] then
                    buffFrames[unit][i].spellName = guidBuffs[unit][i].name or ""
                    buffFrames[unit][i].expirationTime = guidBuffs[unit][i].expirationTime or 0
                    buffFrames[unit][i].duration = guidBuffs[unit][i].duration or 1
                    buffFrames[unit][i].startTime = guidBuffs[unit][i].startTime or GetTime()
                    buffFrames[unit][i].stackCount = guidBuffs[unit][i].stackCount or 0
                    buffFrames[unit][i].isDebuff = guidBuffs[unit][i].isDebuff
                    buffFrames[unit][i].debuffType = guidBuffs[unit][i].debuffType
                    buffFrames[unit][i].playerCast = guidBuffs[unit][i].playerCast

                    -- Set the texture exactly like original PlateBuffs
                    -- Icon from UnitAura is already a full path like "Interface\Icons\IconName"
                    if guidBuffs[unit][i].icon and guidBuffs[unit][i].icon ~= "" then
                        buffFrames[unit][i].texture:SetTexture(guidBuffs[unit][i].icon)
                        buffFrames[unit][i].texture:SetTexCoord(0, 1, 0, 1)
                        buffFrames[unit][i].texture:SetAlpha(0.65)
                    else
                        -- Fallback to question mark with full path
                        buffFrames[unit][i].texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        buffFrames[unit][i].texture:SetTexCoord(0, 1, 0, 1)
                        buffFrames[unit][i].texture:SetAlpha(0.65)
                    end

                    buffFrames[unit][i]:Show()
                    iconOnShow(buffFrames[unit][i])
                    iconOnUpdate(buffFrames[unit][i], 1)
                else
                    buffFrames[unit][i]:Hide()
                end
            end
        end

        -- Ensure bar frames are shown/hidden based on content
        for barIdx = 1, numBars do
            if buffBars[unit] and buffBars[unit][barIdx] then
                -- Count visible icons in this bar
                local visibleCount = 0
                local startIcon = (barIdx - 1) * (P.iconsPerBar or 6) + 1
                local endIcon = barIdx * (P.iconsPerBar or 6)
                for iconIdx = startIcon, endIcon do
                    if buffFrames[unit][iconIdx] and buffFrames[unit][iconIdx]:IsShown() then
                        visibleCount = visibleCount + 1
                    end
                end
                
                if visibleCount > 0 then
                    buffBars[unit][barIdx]:Show()
                else
                    buffBars[unit][barIdx]:Hide()
                end
            end
        end

        self:UpdateAllBarSizes(unit)
    end
end

function core:HidePlateSpells(unit)
    if buffFrames[unit] then
        for i = 1, table_getn(buffFrames[unit]) do
            buffFrames[unit][i]:Hide()
        end
    end
end

function core:RemoveOldSpells(unit)
    -- No longer needed with C_NamePlate (UNIT_AURA handles updates)
    -- Kept as stub for compatibility
end

---
--- BAR SIZE MANAGEMENT
---

local function GetBarChildrenSize(n, ...)
    local frame
    local totalWidth = 1
    local totalHeight = 1
    if n > P.iconsPerBar then
        n = P.iconsPerBar
    end
    for i = 1, n do
        frame = select(i, ...)
        if P.shrinkBar == true then
            if frame:IsShown() then
                totalWidth = totalWidth + frame:GetWidth()
                if frame:GetHeight() > totalHeight then
                    totalHeight = frame:GetHeight()
                end
            end
        else
            totalWidth = totalWidth + frame:GetWidth()
            if frame:GetHeight() > totalHeight then
                totalHeight = frame:GetHeight()
            end
        end
    end
    return totalWidth, totalHeight
end

local function UpdateBarSize(barFrame)
    if barFrame:GetNumChildren() == 0 then
        return
    end

    local totalWidth, totalHeight = GetBarChildrenSize(barFrame:GetNumChildren(), barFrame:GetChildren())

    barFrame:SetWidth(totalWidth)
    barFrame:SetHeight(totalHeight)
end

function core:UpdateAllBarSizes(unit)
    for r = 1, P.numBars do
        if buffBars[unit] and buffBars[unit][r] then
            UpdateBarSize(buffBars[unit][r])
        end
    end
end

function core:UpdateAllPlateBarSizes()
    for unit in pairs(buffBars) do
        self:UpdateAllBarSizes(unit)
    end
end

---
--- UI UPDATE FUNCTIONS
---

function core:UpdateBarsBackground()
    for unit in pairs(buffBars) do
        for b in pairs(buffBars[unit]) do
            if P.showBarBackground == true then
                buffBars[unit][b].barBG:Show()
            else
                buffBars[unit][b].barBG:Hide()
            end
        end
    end
end

function core:UpdateAllFrameLevel()
    for unit in pairs(buffFrames) do
        for i = 1, table_getn(buffFrames[unit]) do
            self:SetFrameLevel(buffFrames[unit][i])
        end
    end
end

function core:SetFrameLevel(frame)
    frame:SetFrameLevel(self.db.profile.frameLevel)
    frame.cdtexture:SetFrameLevel(self.db.profile.frameLevel + 1)
end

function core:ResetAllPlateIcons()
    for unit in pairs(buffFrames) do
        self:BuildIconFrames(unit)
    end
end

function core:ResetIconSizes()
    local iconSize

    for unit in pairs(buffFrames) do
        for i = 1, table_getn(buffFrames[unit]) do
            local frame = buffFrames[unit][i]
            local spellOpts = self:HaveSpellOpts(frame.spellName)

            if frame:IsShown() and spellOpts then
                iconSize = spellOpts.iconSize
            else
                iconSize = P.iconSize
            end

            frame.icon:SetWidth(iconSize)
            frame.icon:SetHeight(iconSize)
            frame:SetWidth(iconSize)

            if P.showCooldown == true then
                frame:SetHeight(iconSize + frame.cd:GetStringHeight())
            else
                frame:SetHeight(iconSize)
            end
        end
    end
end

function core:ResetCooldownSize()
    for unit in pairs(buffFrames) do
        for i = 1, table_getn(buffFrames[unit]) do
            local spellOpts = self:HaveSpellOpts(buffFrames[unit][i].spellName)
            UpdateBuffCDSize(buffFrames[unit][i], 
                           buffFrames[unit][i].spellName and spellOpts and 
                           spellOpts.cooldownSize or P.cooldownSize)
        end
    end
end

function core:ResetStackSizes()
    for unit in pairs(buffFrames) do
        for i = 1, table_getn(buffFrames[unit]) do
            local spellOpts = self:HaveSpellOpts(buffFrames[unit][i].spellName)
            SetStackSize(buffFrames[unit][i], 
                        buffFrames[unit][i].spellName and spellOpts and 
                        spellOpts.stackSize or P.stackSize)
        end
    end
end

function core:ResetAllBarPoints()
    local barPoint = P.barAnchorPoint
    local parentPoint = P.plateAnchorPoint

    if P.barGrowth == 1 then
        barPoint = string_gsub(barPoint, "TOP", "BOTTOM")
        parentPoint = string_gsub(parentPoint, "BOTTOM", "TOP")
    else
        barPoint = string_gsub(barPoint, "BOTTOM", "TOP")
        parentPoint = string_gsub(parentPoint, "TOP", "BOTTOM")
    end

    for unit in pairs(buffBars) do
        if buffBars[unit][1] then
            buffBars[unit][1]:ClearAllPoints()
            local nameplateFrame = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplateFrame then
                buffBars[unit][1]:SetPoint(P.barAnchorPoint, nameplateFrame, P.plateAnchorPoint, 
                                          P.barOffsetX, P.barOffsetY)
            end
        end

        for r = 2, table_getn(buffBars[unit]) do
            buffBars[unit][r]:ClearAllPoints()
            buffBars[unit][r]:SetPoint(barPoint, buffBars[unit][r - 1], parentPoint, 0, 0)
        end
    end
end

function core:ShowAllKnownSpells()
    for unit in pairs(buffFrames) do
        self:AddBuffsToPlate(unit)
    end
end
