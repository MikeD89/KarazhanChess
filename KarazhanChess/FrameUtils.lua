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
	-- Create the icon from the parent
	local icon = parent:CreateTexture(nil, textureType)
	icon:SetTexture(texture)
	icon:SetWidth(w)
	icon:SetHeight(h)
	icon:SetPoint("CENTER", parent, "CENTER")

	-- If this is a part texture use that
	if (coords ~= nil) then
		icon:GetTexture():SetTexCoord(unpack(coords));
	end

	return icon
end

-- Function used to create a movable icon with no call back and no sub coords
function FrameUtils:CreateMoveableIcon(parent, w, h, texture, layer)
	return FrameUtils:CreateMoveableIcon(parent, w, h, texture, layer, nil)
end

-- Function used to create a movable icon with a callback 
function FrameUtils:CreateMoveableIcon(parent, w, h, texture, layer, callback)
	return FrameUtils:CreateMoveableIcon(parent, w, h, texture, layer, callback, nil)
end

-- Function used to create a movable icon with a callback and sub coords
function FrameUtils:CreateMoveableIcon(parent, w, h, texture, layer, callback, coords)
	-- create the frame
	local iconFrame = CreateFrame("FRAME", nil, parent)
	iconFrame:SetWidth(w)
	iconFrame:SetHeight(h)
	iconFrame:EnableMouse(true)
	iconFrame:SetPoint("CENTER", parent, "CENTER")
	
	-- Create the texture to go in the icon
	local icon = iconFrame:CreateTexture(nil, textureType)
	icon:SetTexture(texture)
	icon:SetAllPoints()

	-- If this is a part texture use that
	if (coords ~= nil) then
		icon:GetTexture():SetTexCoord(unpack(coords));
	end

	-- Make it move!
	iconFrame:SetScript("OnMouseDown", function() 
		iconFrame:SetMovable(true)
		iconFrame:StartMoving()  
	end) 

	-- and make it stop
	iconFrame:SetScript("OnMouseUp", function()
		iconFrame:StopMovingOrSizing()
		iconFrame:SetMovable(false)
		if (callback ~= nil) then
			callback(iconFrame)
		end
	end)

	return iconFrame
end