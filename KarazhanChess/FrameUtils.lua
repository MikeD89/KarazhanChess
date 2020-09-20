-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Frame Creation Utilites
-------------------------------------------------------------------------------

FrameUtils = {}

-- Function used to keep a frame from leaving the screen
function FrameUtils:KeepFrameInBounds(frame, bounds)
	local xOffset = frame:GetRight() - GetScreenWidth()
	local yOffset = frame:GetTop() - GetScreenHeight()

	if bounds:GetRight() > GetScreenWidth() then
		xOffset = xOffset + (GetScreenWidth() - bounds:GetRight())
	elseif bounds:GetLeft() < 0 then
		xOffset = xOffset + (0 - bounds:GetLeft())
	end

	if bounds:GetTop() > GetScreenHeight() then
		yOffset = yOffset + (GetScreenHeight() - bounds:GetTop())
	elseif bounds:GetBottom() < 0 then
		yOffset = yOffset + (0 - bounds:GetBottom())
	end

	frame:ClearAllPoints()
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOffset, yOffset)
end

-- Function used to create an icon 
function FrameUtils:CreateIcon(parent, w, h, texture, layer)
	return FrameUtils:CreateIcon(parent, w, h, texture, layer, nil)
end

-- Function used to create an icon with a sub-coordinate
function FrameUtils:CreateIcon(parent, w, h, texture, layer, coords)	
	-- create the frame
	local iconFrame = CreateFrame("FRAME", nil, parent)
	iconFrame:SetWidth(w)
	iconFrame:SetHeight(h)

	-- Use a default position for debug purposes
	iconFrame:SetPoint("CENTER", parent, "CENTER")
	
	-- create an icon to look good
	local icon = iconFrame:CreateTexture(nil, textureType)
	icon:SetTexture(texture)
	icon:SetAllPoints()

	-- If this is a part texture use that
	if (coords ~= nil) then
		frame:GetTexture():SetTexCoord(unpack(coords)); -- cut out the region with our class icon according to coords
	end

	return iconFrame
end

-- Function used to modify an icon to make it moveable with no callback
function FrameUtils:MakeIconMoveable(icon, callback)
	FrameUtils:MakeIconMoveable(icon, nil)
end

-- Function used to modify an icon to make it moveable
function FrameUtils:MakeIconMoveable(icon, callback)
	-- create the frame
	icon:EnableMouse(true)

	-- Make it move!
	icon:SetScript("OnMouseDown", function() 
		icon:SetMovable(true)
		icon:StartMoving()  
	end) 

	-- and make it stop
	icon:SetScript("OnMouseUp", function()
		icon:StopMovingOrSizing()
		icon:SetMovable(false)
		if (callback ~= nil) then
			callback()
		end
	end)
end