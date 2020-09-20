-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Frame Creation Utilites - Based on WeakAuras2
-------------------------------------------------------------------------------

FrameUtils = {}

function FrameUtils:CreateDecoration(frame)
	local deco = CreateFrame("Frame", nil, frame)
	deco:SetSize(17, 40)
  
	local bg1 = deco:CreateTexture(nil, "BACKGROUND")
	bg1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	bg1:SetTexCoord(0.31, 0.67, 0, 0.63)
	bg1:SetAllPoints(deco)
  
	local bg2 = deco:CreateTexture(nil, "BACKGROUND")
	bg2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	bg2:SetTexCoord(0.235, 0.275, 0, 0.63)
	bg2:SetPoint("RIGHT", bg1, "LEFT")
	bg2:SetSize(10, 40)
  
	local bg3 = deco:CreateTexture(nil, "BACKGROUND")
	bg3:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	bg3:SetTexCoord(0.72, 0.76, 0, 0.63)
	bg3:SetPoint("LEFT", bg1, "RIGHT")
	bg3:SetSize(10, 40)
  
	return deco
end
  
function FrameUtils:CreateDecorationWide(frame, width)
	local deco1 = frame:CreateTexture(nil, "OVERLAY")
	deco1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	deco1:SetTexCoord(0.31, 0.67, 0, 0.63)
	deco1:SetSize(width, 40)
  
	local deco2 = frame:CreateTexture(nil, "OVERLAY")
	deco2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	deco2:SetTexCoord(0.21, 0.31, 0, 0.63)
	deco2:SetPoint("RIGHT", deco1, "LEFT")
	deco2:SetSize(30, 40)
  
	local deco3 = frame:CreateTexture(nil, "OVERLAY")
	deco3:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	deco3:SetTexCoord(0.67, 0.77, 0, 0.63)
	deco3:SetPoint("LEFT", deco1, "RIGHT")
	deco3:SetSize(30, 40)
  
	return deco1
end
  
function FrameUtils:CreateFrameSizer(frame, callback, position)
	callback = callback or (function() end)
  
	local left, right, top, bottom, xOffset1, yOffset1, xOffset2, yOffset2
	if position == "BOTTOMLEFT" then
	  left, right, top, bottom = 1, 0, 0, 1
	  xOffset1, yOffset1 = 6, 6
	  xOffset2, yOffset2 = 0, 0
	elseif position == "BOTTOMRIGHT" then
	  left, right, top, bottom = 0, 1, 0, 1
	  xOffset1, yOffset1 = 0, 6
	  xOffset2, yOffset2 = -6, 0
	elseif position == "TOPLEFT" then
	  left, right, top, bottom = 1, 0, 1, 0
	  xOffset1, yOffset1 = 6, 0
	  xOffset2, yOffset2 = 0, -6
	elseif position == "TOPRIGHT" then
	  left, right, top, bottom = 0, 1, 1, 0
	  xOffset1, yOffset1 = 0, 0
	  xOffset2, yOffset2 = -6, -6
	end
  
	local handle = CreateFrame("BUTTON", nil, frame)
	handle:SetPoint(position, frame)
	handle:SetSize(25, 25)
	handle:EnableMouse()
  
	handle:SetScript("OnMouseDown", function()
	  frame:StartSizing(position)
	end)
  
	handle:SetScript("OnMouseUp", function()
	  frame:StopMovingOrSizing()
	  callback()
	end)
  
	local normal = handle:CreateTexture(nil, "OVERLAY")
	normal:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	normal:SetTexCoord(left, right, top, bottom)
	normal:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
	normal:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
	handle:SetNormalTexture(normal)
  
	local pushed = handle:CreateTexture(nil, "OVERLAY")
	pushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	pushed:SetTexCoord(left, right, top, bottom)
	pushed:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
	pushed:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
	handle:SetPushedTexture(pushed)
  
	local highlight = handle:CreateTexture(nil, "OVERLAY")
	highlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	highlight:SetTexCoord(left, right, top, bottom)
	highlight:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
	highlight:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
	handle:SetHighlightTexture(highlight)
  
	return handle
end

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
