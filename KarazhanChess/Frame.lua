-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Primary Frame
-------------------------------------------------------------------------------

function KC:createChessFrame(frame)
	-- Variables
	local inset = 8
	local mouseOverAlpha = 1.0
	local mouseAwayAlpha = 0.3
	
	-- Format the frame
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
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	
	-- Set the default position and fixed size
	frame:SetSize(KC.fixedWidth, KC.fixedHeight)
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
	local titleText = frame:CreateFontString(nil, "OVERLAY") 	
	titleText:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
    titleText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	titleText:SetText(KC.name)
	titleText:SetPoint("TOP", frame, "TOP", 0, -18)

	local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 
	authorText:SetText("By MeloN <"..format("|cffff5c33%s|r","Convicted")..">")
	authorText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", KC.frameMargin, 14)	

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

	-- Button consts
	buttonWidth = 70
	buttonHeight = 20
	buttonMargin = 10

	-- New Game Button
	local newGameButton = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate");
	newGameButton:SetPoint("BOTTOMRIGHT", -KC.frameMargin, 17);
	newGameButton:SetSize(buttonWidth, buttonHeight);
	newGameButton:SetText("New Game");
	newGameButton:SetNormalFontObject("GameFontNormalSmall");
	newGameButton:SetScript("OnClick", function(self, arg)
		KC:Print("TODO - New Game Button")
	end)

	-- Options Button
	local optionsButton = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate");
	optionsButton:SetPoint("RIGHT", newGameButton, "LEFT", -buttonMargin, 0);
	optionsButton:SetSize(buttonWidth, buttonHeight);
	optionsButton:SetText("Options");
	optionsButton:SetNormalFontObject("GameFontNormalSmall");
	optionsButton:SetScript("OnClick", function(self, arg)
		KC:OpenConfig()
	end)

	-- Add the board
	KC:createChessBoard(frame)
end

-- Add the visual and logical board into the frame
function KC:createChessBoard(frame)
	local yOffet = 50
	local horiLabels = "abcdefgh"
	local lightSquare = false
	local size = KC.boardSectionSize
	
	for i=1,KC.boardDim,1 do
		-- New row
		local h = horiLabels[i]
		KC.board[i] = {}  
		lightSquare = not lightSquare

		for j=1,KC.boardDim,1 do
			-- Pick the color
			icon = Icons.Board:GetBoardIcon(lightSquare)

			-- Create the board
			board = FrameUtils:CreateIcon(frame, size, size, icon, "OVERLAY")
			board:SetAlpha(0.8)
			board.horiLabel = h
			board.horiIndex = i
			board.vertLabel = ""..j
			board.vertIndex = j
			board.lightSquare = lightSquare

			-- Position and Save
			local xpos = KC.frameMargin + ((board.horiIndex - 1) * KC.boardSectionSize)
			local ypos = yOffet + ((board.vertIndex - 1) * KC.boardSectionSize)
			board:SetPoint("TOPLEFT", frame, "TOPLEFT", xpos, -ypos)

			-- Save it and flip the colour
			KC.board[i][j] = board
			lightSquare = not lightSquare
		end				
	end
end


function KC:applyBoardTextures()
	-- Apply Chess Board Textures
	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			square = KC.board[i][j]
			icon = Icons.Board:GetBoardIcon(square.lightSquare)
			square:SetTexture(icon)
		end
	end
end

function KC:applyPieceTextures()
	-- Apply Chess Piece Textures
	-- local moveable = FrameUtils:CreateMoveableIcon(frame, 40, 40, dir("Textures\\pieces\\default\\wk"), "OVERLAY", function(icon) print(icon:GetPoint()) end)
	-- moveable:SetPoint("CENTER", frame, "CENTER", 80, 0)
end