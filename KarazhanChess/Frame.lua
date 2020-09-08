-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Primary Frame
-------------------------------------------------------------------------------

function KC:createChessFrame()
	-- Create the frame
	local frame = CreateFrame("FRAME", KC.name, UIParent)
	tinsert(UISpecialFrames, frame:GetName())
	
	-- Format the Frame
	frame:SetBackdrop({
	  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	  tile = true,
	  tileSize = 32,
	  edgeSize = 32,
	  insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetMinResize(KC.minWidth, KC.minHeight)
	frame:SetFrameStrata("DIALOG")
	frame.window = "default"
  
	local xOffset = (KC.defaultWidth - GetScreenWidth()) / 2
	local yOffset = (KC.defaultHeight - GetScreenHeight()) / 2
  
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOffset, yOffset)
	frame:Hide()

	local width = KC.defaultWidth
	local height = KC.defaultHeight
  	width = max(width, KC.minWidth)
  	height = max(height, KC.minHeight)
	  
	frame:SetWidth(width)
  	frame:SetHeight(height)

  	local close = FrameUtils:CreateDecoration(frame)
  	close:SetPoint("TOPRIGHT", -30, 12)

	local closebutton = CreateFrame("BUTTON", nil, close, "UIPanelCloseButton")
	closebutton:SetPoint("CENTER", close, "CENTER", 1, -1)
	closebutton:SetScript("OnClick", function() KC:HideWindow() end)

	local title = CreateFrame("Frame", nil, frame)

	local titleText = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")

	titleText:SetText(KC.formattedName)

	local titleBG = FrameUtils:CreateDecorationWide(frame, max(120, titleText:GetWidth()))
	titleBG:SetPoint("TOP", 0, 24)
	titleText:SetPoint("TOP", titleBG, "TOP", 0, -14)
    
    local function commitWindowChanges() 
        -- do nothing
    end
    
    FrameUtils:CreateFrameSizer(frame, commitWindowChanges, "BOTTOMLEFT")
    FrameUtils:CreateFrameSizer(frame, commitWindowChanges, "BOTTOMRIGHT")

	return frame
end