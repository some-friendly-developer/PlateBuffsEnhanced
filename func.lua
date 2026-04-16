-- globals
local _G = _G
local tostring = tostring
local getn = table.getn
local math_floor = math.floor
local string_sub = string.sub
local string_len = string.len
local GetUnitName = GetUnitName


-- Isolate the environment
local folder, core = ...

local L = core.L or LibStub("AceLocale-3.0"):GetLocale(folder, true)
--~ setfenv(1, core)
-- local

--~ local whiteText			= "|cffffffff%s|r"
local strDebugFrom		= "|cffffff00[%s]|r" --Yellow function name. help pinpoint where the debug msg is from.
local strWhiteBar		= "|cffffff00 || |r" -- a white bar to seperate the debug info.

local colouredName		= "|cff7f7f7f{|r|cffff0000PB|r|cff7f7f7f}|r "
function core.echo(...)
	local tbl  = {...}
	local msg = tostring(tbl[1])
	for i=2,getn(tbl) do 
		msg = msg..strWhiteBar..tostring(tbl[i])
	end
	
	local cf = _G["ChatFrame1"]
	if cf then
		cf:AddMessage(colouredName..msg,.7,.7,.7)
	end
end

core.DEBUG = false
--[===[@debug@
core.DEBUG = true
--@end-debug@]===]

-----------------------------
function core.Debug(from, ...)	--
-- simple print function.	--
------------------------------
	if core.DEBUG == false then
		return 
	end
	local tbl  = {...}
	local msg = tostring(tbl[1])
	for i=2,getn(tbl) do 
		msg = msg..strWhiteBar..tostring(tbl[i])
	end
	core.echo(strDebugFrom:format(from).." "..tostring(msg))
end


------------------------------------------------------------------
function core:Round(num, zeros)										--
-- zeroes is the number of decimal places. eg 1=*.*, 3=*.***	--
------------------------------------------------------------------
	return math_floor( num * 10 ^ (zeros or 0) + 0.5 ) / 10 ^ (zeros or 0)
end


function core:RedToGreen(current, max)
	local percentage = (current/max)*100;
	local red,green = 0,0;
	if percentage >= 50 then
		--green to yellow
		green		= 1;
		red			= ((100 - percentage) / 100) * 2;
	else
		--yellow to red
		red	= 1;
		green		= ((100 - (100 - percentage)) / 100) * 2;
	end
	return red, green, 0
end



local chunks = {
	year	= 60 * 60 * 24 * 365,
	month	= 60 * 60 * 24 * 30,
--~ 	week	= 60 * 60 * 24 * 7,
	day		= 60 * 60 * 24,
	hour	= 60 * 60,
	minute	= 60,
}

--------------------------------------------------------------
function core:SecondsToString(seconds, maxLenth)			--
-- Returns the number of hours in a readable string format.	--
-- maxLenth 1="1h", 2="1h, 33m", 3="1h, 33m, 21s", ect		--
-- OPTIMIZATION: Fast-path for the common case (sub-hour     --
-- cooldowns). Only falls back to the full decomposition for  --
-- values >= 1 hour, which is rare in combat scenarios.       --
--------------------------------------------------------------
	if seconds == 0 then return "0" end
	local maxLenth = maxLenth or 2

	-- Fast-path: the vast majority of aura cooldowns are sub-hour.
	if seconds < chunks.hour then
		local sMinute = math_floor(seconds / chunks.minute)
		local sSecond = seconds % chunks.minute
		if sMinute > 0 then
			if maxLenth >= 2 and sSecond > 0 then
				return sMinute.."m "..sSecond
			end
			return sMinute.."m"
		end
		return tostring(sSecond)
	end

	-- Slow-path: hours, days, months, years (rare for nameplate auras).
	local msg = ""
	local rem = seconds
	local sYear  = math_floor(rem / chunks.year);   rem = rem % chunks.year
	local sMonth = math_floor(rem / chunks.month);  rem = rem % chunks.month
	local sDay   = math_floor(rem / chunks.day);    rem = rem % chunks.day
	local sHour  = math_floor(rem / chunks.hour);   rem = rem % chunks.hour
	local sMinute = math_floor(rem / chunks.minute); rem = rem % chunks.minute

	local sLenth = 0
	if sYear  > 0 and sLenth < maxLenth then sLenth = sLenth+1; msg = sYear.."y " end
	if sMonth > 0 and sLenth < maxLenth then sLenth = sLenth+1; msg = msg..sMonth.."mo " end
	if sDay   > 0 and sLenth < maxLenth then sLenth = sLenth+1; msg = msg..sDay.."d " end
	if sHour  > 0 and sLenth < maxLenth then sLenth = sLenth+1; msg = msg..sHour.."h " end
	if sMinute > 0 and sLenth < maxLenth then sLenth = sLenth+1; msg = msg..sMinute.."m " end
	if rem    > 0 and sLenth < maxLenth then msg = msg..rem.." " end

	return string_sub(msg, 1, string_len(msg) - 1)
end

------------------------------------------------------------------
function core:GetFullName(unitID)								--
-- Returns a unit's name with server if server isn't our own.	--
-- This name matches the one shown in combatlog.				--
------------------------------------------------------------------	
	local name = GetUnitName(unitID, true)
	name = name:gsub(" - ","") --1 dash is still in there. This makes the name match combatlog and scoreboard names.
	return name
end

function core:RemoveServerName(name)
	if name ~= nil then
		local loc = name:find("-")
		if loc then
			name = name:sub(0, loc - 1)
		end
	end
	return name
end