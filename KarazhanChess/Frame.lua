-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Primary Frame
-------------------------------------------------------------------------------

function KC:createChessFrame()
	-- Variables
	local inset = 8
	
	-- Create and Format the Frame
	local frame = CreateFrame("FRAME", KC.name, UIParent)

	frame:SetBackdrop({
	  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	  tile = true,
	  tileSize = 32,
	  edgeSize = 32,
	  insets = { left = inset, right = inset, top = inset, bottom = inset }
	})
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetFrameStrata("HIGH")
	frame.window = "default"
	
	-- Set the default position and fixed size
	frame:SetWidth(KC.fixedWidth)
	frame:SetHeight(KC.fixedHeight)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	
	-- Hide it by default
	frame:Hide()

	-- Add the title	
	local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline") 
	titleText:SetText(KC.formattedName)
	titleText:SetPoint("TOP", frame, "TOP", 0, -14)

	-- Add the title drag bar
	local title = CreateFrame("FRAME", nil, frame)
	title:SetWidth(titleText:GetWidth())
	title:SetHeight(titleText:GetHeight())
	title:SetPoint("CENTER", titleText, "CENTER")

	-- Make it move the window
	title:SetScript("OnMouseDown", function() frame:StartMoving()  end) 
	title:SetScript("OnMouseUp", function()
	  frame:StopMovingOrSizing()
	  FrameUtils:KeepFrameInBounds(frame, titleText)
	end)

	-- Close Button
	local closebutton = CreateFrame("BUTTON", nil, frame, "UIPanelCloseButton")
	closebutton:SetSize(30, 30)
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset+2, -inset+2)
	closebutton:SetScript("OnClick", function() KC:HideWindow() end)

	-- Annnd... Done!
	return frame
end
