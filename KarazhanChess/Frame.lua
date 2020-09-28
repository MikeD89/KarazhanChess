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
	frame:SetFrameStrata("HIGH")
	
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
	local titleText = frame:CreateFontString(nil, "ARTWORK") 	
	titleText:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
    titleText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	titleText:SetText(KC.name)
	titleText:SetPoint("TOP", frame, "TOP", 0, -18)

	local authorText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall") 
	authorText:SetText("By MeloN <"..format("|cffff5c33%s|r","Convicted")..">")
	authorText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", KC.frameMargin, 14)	

	local versionText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall") 
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
		KC:P("TODO - New Game Button")
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

	-- Add the placeholder text for victory.
	KC.statusText = frame:CreateFontString(nil, "OVERLAY") 	
	KC.statusText:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
	KC.statusText:SetTextColor(0, 1, 0)
	KC.statusText:SetText("Victory, or Death!")
	KC.statusText:SetPoint("CENTER", frame, "CENTER", 0, 20)	
	KC.statusText:Hide()
end

-- Add the visual and logical board into the frame
function KC:createChessBoard(frame)
	local yOffet = 50
	local colLabels = 'abcdefgh'
	local lightSquare = false
	local size = KC.boardSectionSize
	local firstRow = true
	local newColumn = true

	-- Globals
	KC.board = {}
	KC.boardLabels = {}
	
	-- Columns
	for i=1,KC.boardDim,1 do
		-- New row
		local h = strsub(colLabels, i, i)
		KC.board[i] = {}  
		lightSquare = not lightSquare
		newColumn = true

		-- Rows
		for j=1,KC.boardDim,1 do
			-- Pick the color
			icon = Icons.Board:GetBoardIcon(lightSquare)

			-- Create the board square
			square = FrameUtils:CreateIcon(frame, size, size, icon, "ARTWORK")
			square:SetAlpha(KC.boardAlpha)
			square.colLabel = h
			square.colIndex = i
			square.rowLabel = ""..j
			square.rowIndex = j
			square.fullLabel = square.colLabel..square.rowLabel
			square.lightSquare = lightSquare

			-- Position and Save
			local xpos = KC.frameMargin + ((square.colIndex - 1) * KC.boardSectionSize)
			local ypos = yOffet + KC.boardHeight - (square.rowIndex * KC.boardSectionSize)
			square:SetPoint("TOPLEFT", frame, "TOPLEFT", xpos, -ypos)

			-- Give it a Legal Move indicator
			square.legalMove = FrameUtils:CreateIcon(frame, size/3, size/3, Icons.LegalMove, "ARTWORK")
			square.legalMove:SetPoint("CENTER", square, "CENTER")
			square.legalMove:Hide()

			-- Make the move indicator be toggleable
			square.ShowAsLegalMove = function(self) 
				square.legalMove:Show()
			end
			square.ClearLegalMove = function(self) 
				square.legalMove:Hide()
			end

			-- Create the neccersary labels
			if (firstRow) then
				local label = FrameUtils:CreateBoardLabel(square, frame, true)
				table.insert(KC.boardLabels, label)
			end
			if (newColumn) then
				local label = FrameUtils:CreateBoardLabel(square, frame, false)
				table.insert(KC.boardLabels, label)
			end

			-- Save it and flip the colour
			KC.board[i][j] = square
			lightSquare = not lightSquare

			-- This is no longer a new column 
			newColumn = false
		end	
		
		-- After the first row we don't need labels any more
		firstRow = false			
	end

	-- We've added labels (probably) - We might need to hide them
	KC:applyBoardLabelVisibility()
end

-- Applies a user selected texture to all the board squares
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

-- Applies a user selected texture to all the pieces on the board
function KC:applyPieceTextures()
	-- Apply Chess Piece Textures
	for i=1,table.getn(KC.pieces),1 do
		KC.pieces[i]:UpdateTexture()
	end
end

-- Toggles the board labels on and off
function KC:applyBoardLabelVisibility()
	local state = KC:getBoardLabelsVisible()

	for i=1,table.getn(KC.boardLabels),1 do
		if(state) then
			KC.boardLabels[i]:Show()
		else
			KC.boardLabels[i]:Hide()
		end
	end
end

-- Clears all legal moves
function KC:clearLegalMoves()
	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			KC.board[i][j].legalMove:Hide()
		end
	end
end
