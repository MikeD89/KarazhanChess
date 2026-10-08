-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Frame Creation Utilites
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC

local FrameUtils = {}
ns.FrameUtils = FrameUtils
FrameUtils.framePool = {}

-- Get a frame, either from the pool, or fresh
function FrameUtils:getFrameFromPool()
	-- Try to get a frame from the pool
	local f = tremove(FrameUtils.framePool)
	
	if not f then
		-- If it doesn't exist, make a new one
        return CreateFrame("FRAME", nil, KC.boardFrame, "BackdropTemplate")
	else
		-- This space reserved for cleaning up frames (if needed)
    end
    return f
end

-- Remove a frame and place it back in the pool
function FrameUtils:returnFrameToPool(frame)
	frame:Hide()
	frame:ClearAllPoints()
	frame.texture:SetTexture(nil)
	frame:SetScript("OnMouseDown", nil)
	frame:SetScript("OnMouseUp", nil)
	frame:SetScript("OnUpdate", nil)
	frame:SetScript("OnHide", nil)
    tinsert(FrameUtils.framePool, frame)
end

-- Stops a texture snapping to the screen's pixel grid. Snapping (the client default)
-- nudges edges to whole pixels, which makes scaled artwork look jagged at window
-- sizes that don't land on whole pixels. Unsnapped, it scales smoothly at any size.
function FrameUtils:DisablePixelSnapping(texture)
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
end

-- Function used to create an icon
function FrameUtils:CreateIcon(w, h, textureName, layer)
	-- create this as a frame
	local frame = FrameUtils:getFrameFromPool()
	frame:SetWidth(w)
	frame:SetHeight(h)
    frame:EnableMouse(true)

	-- And with a texture. Pooled frames already have one, so reuse it.
	if not frame.texture then
		frame.texture = frame:CreateTexture(nil, layer)
		frame.texture:SetAllPoints()
		FrameUtils:DisablePixelSnapping(frame.texture)
	end
	frame.texture:SetDrawLayer(layer)
    frame.texture:SetTexture(textureName)

	return frame
end

-- Function used to create a movable icon with a callback and sub coords
function FrameUtils:CreateBoardLabel(square, frame, row)
	local offset = 2

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