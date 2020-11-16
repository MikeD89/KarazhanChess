-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Frame Creation Utilites
-------------------------------------------------------------------------------

FrameUtils = {}
FrameUtils.framePool = {}

-- Get a frame, either from the pool, or fresh
function FrameUtils:getFrameFromPool()
	-- Try to get a frame from the pool
	local f = tremove(FrameUtils.framePool)
	
	if not f then
		-- If it doesn't exist, make a new one
        return CreateFrame("FRAME", nil, KC.frame)
	else
		-- This space reserved for cleaning up frames (if needed)
    end
    return f
end

-- Remove a frame and place it back in the pool
function FrameUtils:returnFrameToPool(frame)
    frame:Hide()
    tinsert(FrameUtils.framePool, frame)
end

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
function FrameUtils:CreateIcon(w, h, textureName, layer, name)	
	-- create this as a frame
	frame = FrameUtils:getFrameFromPool()
	frame:SetWidth(w)
	frame:SetHeight(h)
    frame:EnableMouse(true)
	
	-- And with a texture
	frame.texture = frame:CreateTexture(name, layer)
    frame.texture:SetTexture(textureName)
    frame.texture:SetAllPoints()

	return frame
end

-- Function used to create a movable icon with a callback and sub coords
function FrameUtils:CreateBoardLabel(square, frame, row)
	offset = 2

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 	
	label:SetAlpha(KC.boardAlpha)
	
	if (row) then
		label:SetText(square.rowLabel)
		label:SetPoint("TOPLEFT", square.frame, "TOPLEFT", offset, -offset)	
	else
		label:SetText(square.colLabel)
		label:SetPoint("BOTTOMRIGHT", square.frame, "BOTTOMRIGHT", -offset, offset)
	end

	return label
end