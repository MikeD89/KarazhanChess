-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Utilities
-------------------------------------------------------------------------------

-- Function to convert a date to a visual date to display.
-- Based on DBM Function.
function showRealDate(curseDate)
	curseDate = tostring(curseDate)
	local year, month, day, hour, minute, second = curseDate:sub(1, 4), curseDate:sub(5, 6), curseDate:sub(7, 8), curseDate:sub(9, 10), curseDate:sub(11, 12), curseDate:sub(13, 14)
	if year and month and day and hour and minute and second then
		return year.."/"..month.."/"..day.." "..hour..":"..minute..":"..second
	end
end

-- Function to to check for nil on strings
function isNull(e)
	return e == nil or e == ''
end

-- Util funtion to return the path
function dir(path)
	return "Interface\\AddOns\\KarazhanChess\\"..path
end