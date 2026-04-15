local folder, core = ...

--Globals
local _G = _G
local pairs = pairs
local table_insert	= table.insert
local table_sort	= table.sort
local table_getn	= table.getn
local Debug = core.Debug
local tonumber = tonumber
local GetSpellInfo = GetSpellInfo
local select = select
local LSM_opts = LibStub and LibStub("LibSharedMedia-3.0", true)


core.tooltip = core.tooltip or CreateFrame("GameTooltip", folder.."Tooltip", UIParent, "GameTooltipTemplate")
local tooltip = core.tooltip
tooltip:Show()
tooltip:SetOwner(UIParent, "ANCHOR_NONE")


-- Isolate the environment
--~ setfenv(1, core)
-- local
local spellIDs = {}

local defaultSettings = core.defaultSettings
local L = core.L or LibStub("AceLocale-3.0"):GetLocale(folder, true)

local P = {}
local prev_OnEnable = core.OnEnable;
function core:OnEnable()
	prev_OnEnable(self);

--~ 	self:Debug("OnEnable", "options", self.db.profile)
	P = self.db.profile
	
	
	self:BuildSpellUI()
end

local minIconSize = 16
local maxIconSize = 80
local minTextSize = 6
local maxTextSize = 20

--1=all, 2=mine, 3=none
defaultSettings.profile.defaultBuffShow			= 3
defaultSettings.profile.defaultDebuffShow			= 1  -- Change to 1 temporarily to show all debuffs

--~ defaultSettings.profile.showAura				= false
defaultSettings.profile.watchUnitIDAuras = true

defaultSettings.profile.abovePlayers		= true
defaultSettings.profile.aboveNPC		= true
defaultSettings.profile.aboveFriendly		= true
defaultSettings.profile.aboveNeutral		= true
defaultSettings.profile.aboveHostile		= true

defaultSettings.profile.barAnchorPoint		= "BOTTOM"
defaultSettings.profile.plateAnchorPoint		= "TOP"
defaultSettings.profile.barOffsetX		= 0
defaultSettings.profile.barOffsetY		= 8 --bit north incase user's running Threat plates.
defaultSettings.profile.iconsPerBar		= 6
defaultSettings.profile.barGrowth		= 1
defaultSettings.profile.numBars		= 2
defaultSettings.profile.iconSize		= 24
defaultSettings.profile.biggerSelfSpells		= true
defaultSettings.profile.showCooldown		= true
defaultSettings.profile.shrinkBar		= true
defaultSettings.profile.showBarBackground		= false
defaultSettings.profile.frameLevel		= 0

defaultSettings.profile.cooldownSize		= 10
defaultSettings.profile.stackSize		= 10
defaultSettings.profile.showCooldownTexture		= true
defaultSettings.profile.showDebuffBorder		= true


defaultSettings.profile.blinkTimeleft		= 0.2 --20%
defaultSettings.profile.auraPollInterval	= 0.25
defaultSettings.profile.showTotems = false
defaultSettings.profile.npcCombatWithOnly = true
defaultSettings.profile.playerCombatWithOnly = false
defaultSettings.profile.cooldownFont           = ""  -- empty = default WoW font (Friz Quadrata)
defaultSettings.profile.cooldownTextPosition   = 3   -- 1=Center, 2=Inner Bottom, 3=Under Icon
defaultSettings.profile.colorCooldownText      = 1  -- 1=Legacy, 2=Static, 3=Threshold
defaultSettings.profile.cooldownTextAlpha      = 1.0



core.CoreOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,

	
	args = {
		enable = {
			type = "toggle",	order	= 1,
			name	= L["Enable"],
			desc	= L["Enables / Disables the addon"],
			set = function(info,val) 
				if val == true then
					core:Enable()
				else
					core:Disable()
				end
			end,
			get = function(info) return core:IsEnabled() end
		},
		defaultBuffShow = {
			type = "select", order = 11,
			name = L["Show Buffs"],
			desc = L["Show buffs above nameplate."],

			values = function()
				return {
					L["All"], 
					L["Mine Only"],
					L["None"],
				}
			end,
		},	
		defaultDebuffShow = {
			type = "select", order = 12,
			name = L["Show Debuffs"],
			desc = L["Show debuffs above nameplate."],

			values = function()
				return {
					L["All"], 
					L["Mine Only"],
					L["None"],
				}
			end,
		},
		
		--[===[@debug@
		watchUnitIDAuras = {
			type = "toggle", order	= 90,
			name = "Watch unitID auras",
			desc = "Option to help me test out combatlog tracking.",

		},
		--@end-debug@]===]
		
	},
}



core.WhoOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,
	
	args = {
		typeHeader = {
			name	= L["Type"],
			order	= 10,
			type = "header",
		},

		abovePlayers = {
			name = L["Players"],
			desc = L["Add buffs above players"],
			type = "toggle",
			order	= 11,
		},
	
		aboveNPC = {
			name = L["NPC"],
			desc = L["Add buffs above NPCs"],
			type = "toggle",
			order	= 12,
		},
	
		reactionHeader = {
			name	= L["Reaction"],
			order	= 15,
			type = "header",
		},

		aboveFriendly = {
			name = L["Friendly"],
			desc = L["Add buffs above friendly plates"],
			type = "toggle",
			order	= 16,
		},

		aboveNeutral = {
			name = L["Neutral"],
			desc = L["Add buffs above neutral plates"],
			type = "toggle",
			order	= 17,
		},
		
		aboveHostile = {
			name = L["Hostile"],
			desc = L["Add buffs above hostile plates"],
			type = "toggle",
			order	= 18,
		},

		otherHeader = {
			name	= L["Other"],
			order	= 20,
			type = "header",
		},

		showTotems = {
			name = L["Show Totems"],
			desc = L["Show spell icons on totems"],
			type = "toggle",
			order	= 21,
		},
		
		
		npcCombatWithOnly = {
			name = L["NPC combat only"],
			desc = L["Only show spells above nameplates that are in combat."],
			type = "toggle",
			order	= 22,
			set = function(info,val) 
				P.npcCombatWithOnly = val
				core:Disable()
				core:Enable()
			end,
		},
		
		playerCombatWithOnly = {
			name = L["Player combat only"],
			desc = L["Only show spells above nameplates that are in combat."],
			type = "toggle",
			order	= 23,
			set = function(info,val) 
				P.playerCombatWithOnly = val
				core:Disable()
				core:Enable()
			end,
		},
		
		
		
	},
}

core.BarOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,
	
	args = {
		barAnchorPoint = {
			name = L["Row Anchor Point"],
			order = 1,
			desc = L["Point of the buff frame that gets anchored to the nameplate.\ndefault = Bottom"],
			type = "select",
			
			values = function()
				return {
					["TOP"]=L["Top"], 
					["BOTTOM"]=L["Bottom"], 
--~ 					["LEFT"]=L["Left"], --NOTE! Using these values may break bar anchors to other bars.
--~ 					["RIGHT"]=L["Right"], 
--~ 					["CENTER"]=L["Center"], 
					["TOPLEFT"]=L["Top Left"], 
					["BOTTOMLEFT"]=L["Bottom Left"], 
					["TOPRIGHT"]=L["Top Right"], 
					["BOTTOMRIGHT"]=L["Bottom Right"], 
				}
			end,
			set = function(info,val) 
				P.barAnchorPoint = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barAnchorPoint end
		},

		plateAnchorPoint = {
			name = L["Plate Anchor Point"],
			order = 2,
			desc = L["Point of the nameplate our buff frame gets anchored to.\ndefault = Top"],
			type = "select",
			
			values = function()
				return {
					["TOP"]=L["Top"], 
					["BOTTOM"]=L["Bottom"], 
--~ 					["LEFT"]=L["Left"],   --NOTE! Using these values may break bar anchors to other bars.
--~ 					["RIGHT"]=L["Right"], 
--~ 					["CENTER"]=L["Center"], 
					["TOPLEFT"]=L["Top Left"], 
					["BOTTOMLEFT"]=L["Bottom Left"], 
					["TOPRIGHT"]=L["Top Right"], 
					["BOTTOMRIGHT"]=L["Bottom Right"], 
				}
			end,
			set = function(info,val) 
				P.plateAnchorPoint = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.plateAnchorPoint end
		},
		
		barOffsetX = {
			name = L["Row X Offset"],
			desc = L["Left to right offset."],
			type = "range",
			order	= 5,
			min		= -100,
			max		= 100,
			step	= 1,
			set = function(info,val) 
				P.barOffsetX = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barOffsetX end
		},

		
		barOffsetY = {
			name = L["Row Y Offset"],
			desc = L["Up to down offset."],
			type = "range",
			order	= 6,
			min		= -100,
			max		= 100,
			step	= 1,
			set = function(info,val) 
				P.barOffsetY = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barOffsetY end
		},
		
		iconsPerBar = {
			name = L["Icons per bar"],
			desc = L["Number of icons to display per bar."],
			type = "range",
			order	= 7,
			min		= 1,
			max		= 16,
			step	= 1,
			set = function(info,val) 
				P.iconsPerBar = val
				core:ResetAllPlateIcons()
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
			end,
--~ 			get = function(info) return P.iconsPerBar end
		},
		
		barGrowth = {
			type = "select",	order = 8,
			name = L["Row Growth"],
			desc = L["Which way do the bars grow, up or down."],

			values = function()
				return {
					L["Up"],
					L["Down"],
				}
			end,
			set = function(info,val) 
				P.barGrowth = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barGrowth end
		},
		
		numBars = {
			name = L["Max bars"],
			desc = L["Max number of bars to show."],
			type = "range",
			order	= 9,
			min		= 1,
			max		= 4,
			step	= 1,
			set = function(info,val) 
				P.numBars = val
				core:ResetAllPlateIcons()
		--~ 		core:UpdateBarsSize()
				core:UpdateBarsBackground()
				core:ShowAllKnownSpells()
			end,
--~ 			get = function(info) return P.numBars end
		},
		
		
		
		
		
		biggerSelfSpells = {
			name = L["Larger self spells"],
			desc = L["Make your spells 20% bigger then other's."],
			type = "toggle",
			order	= 11,
		},
		
		

		

		shrinkBar = {
			name = L["Shrink Bar"],
			desc = L["Shrink the bar horizontally when spells frames are hidden."],
			type = "toggle",
			order	= 20,
			set = function(info,val) 
				P.shrinkBar = val
				core:UpdateAllPlateBarSizes()
			end,
		},
		
		--[[
		frameLevel = {
			name = "Frame Level",
			desc = "xxx",
			type = "range",
			
			order	= 21,
			min		= 0,
			max		= 20,
			step	= 1,
			
			set = function(info,val) 
				P.frameLevel = val
				core:UpdateAllFrameLevel()
			end,
		},]]
		
		
		
		showBarBackground = {
			name = L["Show bar background"],
			desc = L["Show the area where spell icons will be. This is to help you configure the bars."],
			type = "toggle",
			order	= 99,
			set = function(info,val) 
				P.showBarBackground = val
				core:UpdateBarsBackground()
			end,
			get = function(info) 
				return P.showBarBackground 
			end,
		},

		iconTestMode = {
			name = L["Test Mode"],
			desc = L["For each spell on someone, multiply it by the number of icons per bar.\nThis option won't be saved at logout."],
			type = "toggle",
			order	= 100,
		},
		
	},
}

--~ defaultSettings.profile.spellOpts = {}

-- END OF BAR

local tmpNewName = ""
core.SpellOptionsTable = {
	name = core.titleFull,
	type = "group",
	

	
	args = {
--~ 				whatThisDo = {
--~ 					type = "description",	order = 5,
--~ 					name = "Specific spell options.",
--~ 				},

		
		
		
		inputName = {
			type = "input",	order	= 2,
			name = L["Spell name"],
			desc = L["Input a spell name. (case sensitive)\nOr spellID"],
			set = function(info,val) 
				local num = tonumber(val)
				if num then
					local spellName = GetSpellInfo(num)
--~ 					Debug("num 1", num, spellName)
					if spellName then
						tmpNewName = spellName
						return
					end
				end
--~ 				Debug(val, type(val))
				tmpNewName = val
			end,
			get = function(info) return tmpNewName end
		},

		addName = {
			type = "execute",	order	= 3,
			name	= L["Add spell"],
			desc	= L["Add spell to list."],
			func = function(info) 
				if tmpNewName ~= "" then
					core:AddNewSpell(tmpNewName)
					tmpNewName = ""
				end
			end
		},

		spellList = {
			type = "group",	order	= 5,
			name	= L["Specific Spells"],
			
			args={}, --done later
		},
		
--~ 		defaultSpellOpt = {
--~ 			type = "group",	order	= 6,
--~ 			name	= "Default",

--~ 		},



		
		
		
	},
}

core.DefaultSpellOptionsTable = {
	name = core.titleFull,
	type = "group",
	
	get = function(info)
		local key = info[#info]
		return P[key]
	end,
	set = function(info, v)
		local key = info[#info] -- backup_enabled, etc...
		P[key] = v
	end,
	
	args = {
		spellDesc = {
			type = "description",
			name = L["Spells not in the Specific Spells list will use these options."],
			order = 1,
		},

		iconSize = {
			name = L["Icon Size"],
			desc = L["Size of the icons."],
			type = "range",
			order	= 10,
			min		= minIconSize,
			max		= maxIconSize,
			step	= 4,
			set = function(info,val) 
				P.iconSize = val
				core:ResetIconSizes()
		--~ 		core:UpdateBarsSize()
			end,
		},
	
		cooldownGroup = {
			type = "group",
			name = L["Cooldown Text"],
			order = 11,
			inline = true,
			args = {
				showCooldown = {
					name = L["Show cooldown"],
					desc = L["Show cooldown text below the spell icon. (Independent from cooldown overlay)"],
					type = "toggle",
					order = 1,
					set = function(info, val)
						P.showCooldown = val
						core:ResetIconSizes()
						core:ShowAllKnownSpells()
					end,
				},

				cooldownSize = {
					name = L["Cooldown Text Size"],
					desc = L["Text size"],
					type = "range",
					order = 2,
					min   = minTextSize,
					max   = maxTextSize,
					step  = 1,
					set = function(info, val)
						P.cooldownSize = val
						core:ResetCooldownSize()
						core:ResetAllPlateIcons()
						core:ResetIconSizes()
						core:ShowAllKnownSpells()
					end,
				},

				showCooldownTexture = {
					name = L["Show cooldown overlay"],
					desc = L["Show a clock overlay over spell textures showing the time remaining."].."\n"..L["This overlay tends to disappear when the frame's moving."],
					type = "toggle",
					order = 3,
				},

				colorCooldownText = {
					name = L["Cooldown Text Color"],
					desc = L["How to color the cooldown countdown text."],
					type = "select",
					order = 4,
					values = {
						[1] = L["Legacy (green to red)"],
						[2] = L["Static (white)"],
						[3] = L["Threshold (white / yellow / red)"],
					},
				},

				cooldownTextAlpha = {
					name = L["Cooldown Text Alpha"],
					desc = L["Opacity of the cooldown countdown text."],
					type = "range",
					order = 5,
					min  = 0,
					max  = 1,
					step = 0.05,
					isPercent = true,
				},

				cooldownFont = {
					name = L["Cooldown Font"],
					desc = L["Font face for cooldown/duration text. Requires LibSharedMedia-3.0, or leave blank for the default WoW font."],
					type = "select",
					order = 4,
					dialogControl = LSM_opts and "LSM30_Font" or nil,
					values = function()
						if LSM_opts then
							local list = LSM_opts:List("font")
							local t = { [""] = L["Default"] }
							for _, name in ipairs(list) do
								t[name] = name
							end
							return t
						end
						return {
							[""]                    = L["Default"],
							["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
							["Fonts\\ARIALN.TTF"]   = "Arial Narrow",
							["Fonts\\skurri.ttf"]   = "Skurri",
							["Fonts\\morpheus.ttf"] = "Morpheus",
						}
					end,
					set = function(info, val)
						P.cooldownFont = val
						core:ResetCooldownFont()
					end,
					get = function(info) return P.cooldownFont or "" end,
				},

				cooldownTextPosition = {
					name = L["Cooldown Text Position"],
					desc = L["Where to anchor the cooldown/duration text relative to the icon."],
					type = "select",
					order = 5,
					values = function()
						return {
							L["Icon Center"],
							L["Icon Inner Bottom"],
							L["Under Icon"],
						}
					end,
					set = function(info, val)
						P.cooldownTextPosition = val
						core:ResetCooldownPosition()
					end,
					get = function(info) return P.cooldownTextPosition or 3 end,
				},
			},
		},

		stackSize = {
			name = L["Stack Text Size"],
			desc = L["Text size"],
			type = "range",
			order = 12,
			min   = minTextSize,
			max   = maxTextSize,
			step  = 1,
			set = function(info, val)
				P.stackSize = val
				core:ResetStackSizes()
			end,
		},

		blinkTimeleft = {
			name = L["Blink Timeleft"],
			desc = L["Blink spell if below x% timeleft, (only if it's below 60 seconds)"],
			type = "range",
			order = 13,
			min   = 0,
			max   = 1,
			step  = 0.05,
			isPercent = true,
		},

		auraPollInterval = {
			name = L["Aura Poll Interval"],
			desc = L["How often (in seconds) to check for aura changes on nameplates. Lower = more responsive but higher CPU cost."],
			type = "range",
			order = 14,
			min   = 0.1,
			max   = 2.0,
			step  = 0.1,
		},

		showDebuffBorder = {
			name = L["Show debuff border"],
			desc = L["Show a colored border around debuff icons based on magic school."],
			type = "toggle",
			order = 15,
		},

	}
}


function core:BuildSpellUI()
	--P.addSpellDescriptions

	local SpellOptionsTable = core.SpellOptionsTable
	SpellOptionsTable.args.spellList.args = {} --reset

	local list = {}
	for name, data in pairs(P.spellOpts) do 
		if not P.ignoreDefaultSpell[name] then
			table_insert(list, name)
		end
	end
	
	table_sort(list, function(a,b) 
		if(a and b) then 
--~ 			if P.spellOpts[a].iconSize and P.spellOpts[b].iconSize and P.spellOpts[a].iconSize ~= P.spellOpts[b].iconSize then
--~ 				return P.spellOpts[a].iconSize > P.spellOpts[b].iconSize
--~ 			else
				return a < b
--~ 			end
		end 
	end)
	
	
	local testDone = false
	local spellName, data
	local spellDesc, spellTexture
	local iconSize
	local nameColour
	for i=1, table_getn(list) do 
		spellName = list[i]
		data = P.spellOpts[spellName]
		iconSize = data.iconSize or P.iconSize
		
		if data.show == 1 then
			nameColour = "|cff00ff00%s|r" --green
		elseif data.show == 3 then 
			nameColour = "|cffff0000%s|r" --red
		else
			nameColour = "|cffffff00%s|r"--yellow
		end
		
		
		spellDesc = "??"
		spellTexture = "Interface\\Icons\\"..core.unknownIcon
		local _n, _r, _t = GetSpellInfo(spellName)
		if _t then
			spellTexture = _t
		end
		if spellIDs[spellName] then
			tooltip:SetHyperlink("spell:"..spellIDs[spellName])
			local lines = tooltip:NumLines()
			if lines > 0 then
				spellDesc = _G[folder.."TooltipTextLeft"..lines] and _G[folder.."TooltipTextLeft"..lines]:GetText() or "??"
			end
		end
		
		
		
		--add spell to table.
		SpellOptionsTable.args.spellList.args[spellName] = {
			type	= "group",
			name	= nameColour:format(spellName.." ("..iconSize..")"),
			desc	= spellDesc, --L["Spell name"],
			order = i,
			args={}
		}
		
		--UI elements
		SpellOptionsTable.args.spellList.args[spellName].args.showOpt = {
			type = "select",	order = 2,
			name = L["Show"],
			desc = L["Always show spell, only show your spell, never show spell"],

			values = {
				L["Always"],
				L["Mine only"],
				L["Never"],
			},
			set = function(info,val) 
				P.spellOpts[info[2]].show = val
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].show or 1 end
		}
		
		
		SpellOptionsTable.args.spellList.args[spellName].args.iconSize = {
			name = L["Icon Size"],
			desc = L["Size of the icons."],
			type = "range",
			order	= 3,
			min		= minIconSize,
			max		= maxIconSize,
			step	= 4,
			set = function(info,val) 
				P.spellOpts[info[2]].iconSize = val
				
				core:ResetIconSizes()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].iconSize or P.iconSize end
		}
		
		SpellOptionsTable.args.spellList.args[spellName].args.cooldownSize = {
			name = L["Cooldown Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 4,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.spellOpts[info[2]].cooldownSize = val
				
				core:ResetCooldownSize()
				core:ResetAllPlateIcons()
				core:ResetIconSizes()--Adjust the frame height with the new Cooldown Text Size
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].cooldownSize or P.cooldownSize end
		}
		
		SpellOptionsTable.args.spellList.args[spellName].args.stackSize = {
			name = L["Stack Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 14,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.spellOpts[info[2]].stackSize = val
				core:ResetStackSizes()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].stackSize or P.stackSize end
		}

		local previewSize = data.iconSize or P.iconSize
		SpellOptionsTable.args.spellList.args[spellName].args.previewGroup = {
			type = "group",
			name = L["Preview"],
			order = 50,
			inline = true,
			args = {
				previewIcon = {
					type = "description",
					name = spellName .. " (" .. previewSize .. "px)",
					order = 1,
					image = spellTexture,
					imageWidth = previewSize,
					imageHeight = previewSize,
					width = "full",
				},
			},
		}

		--last
		
		SpellOptionsTable.args.spellList.args[spellName].args.removeSpell = {
			type = "execute",	order	= 91,
			name	= L["Remove Spell"],
			desc	= L["Remove spell from list"],
			func = function(info) 
				core:RemoveSpell(info[2])
			end
		}
		
	end
	
	
end
