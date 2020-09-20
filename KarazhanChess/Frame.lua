-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Primary Frame
-------------------------------------------------------------------------------

function KC:createChessFrame()
	-- Variables
	local inset = 8
	local mouseOverAlpha = 1.0
	local mouseAwayAlpha = 0.3
	
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
	
	-- Set the default position and fixed size
	frame:SetWidth(KC.fixedWidth)
	frame:SetHeight(KC.fixedHeight)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	
	-- Hide it by default
	frame:Hide()

	-- Make it fade out when the mouse is away
	local function setFadeState() 
		if (self.db.global.fadeoutWindow) then
			if MouseIsOver(frame) then
				UIFrameFadeIn(frame, 1.0, frame:GetAlpha(), mouseOverAlpha)
			else
				UIFrameFadeOut(frame, 0.20, frame:GetAlpha(), mouseAwayAlpha)
			end
		end
	end

	frame:SetScript('OnEnter', setFadeState)
	frame:SetScript('OnLeave', setFadeState)

	-- Add the titles
	local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") 
	titleText:SetText(KC.name)
	titleText:SetPoint("TOP", frame, "TOP", 0, -14)

	local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 
	authorText:SetText("By MeloN <"..format("|cffff5c33%s|r","Convicted")..">")
	authorText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)	

	local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 
	versionText:SetText("Version: "..KC.formattedVersion)
	versionText:SetPoint("BOTTOMLEFT", authorText, "TOPLEFT", 0, 2)	

	-- Add the title drag bar
	local title = CreateFrame("FRAME", nil, frame)
	title:SetWidth(frame:GetWidth())
	title:SetHeight(titleText:GetHeight())
	title:SetPoint("CENTER", titleText, "CENTER")

	-- Make it move the window
	title:SetScript("OnMouseDown", function() frame:StartMoving()  end) 
	title:SetScript("OnMouseUp", function()
	  frame:StopMovingOrSizing()
	  FrameUtils:KeepFrameInBounds(frame, titleText)
	end)

	-- Close Button
	local closebutton = CreateFrame("BUTTON", nil, title, "UIPanelCloseButton")
	closebutton:SetSize(30, 30)
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset+2, -inset+2)
	closebutton:SetScript("OnClick", function() KC:HideWindow() end)

	-- Add the board
	KC:createChessBoard(frame)

	-- Annnd... Done!
	return frame
end

-- Add the visual and logical board into the frame
function KC:createChessBoard(frame)
	local moveable = FrameUtils:CreateMoveableIcon(frame, 40, 40, dir("Textures\\pieces\\default\\wk"), "OVERLAY", function(icon) print(icon:GetPoint()) end)
	moveable:SetPoint("CENTER", frame, "CENTER", 80, 0)
	FrameUtils:CreateIcon(frame, 40, 40, dir("Textures\\pieces\\default\\wk"), "OVERLAY")
end

function KC:applyBoardTextures()
	-- Apply Chess Board Textures
end

function KC:applyPieceTextures()
	-- Apply Chess Piece Textures
end