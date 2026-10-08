-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Primary Frame
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Square = ns.FrameUtils, ns.Square
local ord = ns.ord

function KC:createChessFrame(frame)
	-- Variables
	local inset = 8
	local mouseOverAlpha = 1.0
	local mouseAwayAlpha = 0.3
	
	-- Format the frame
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
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
	
	-- Set the fixed size and restore the saved position (or centre it)
	frame:SetSize(KC.fixedWidth, KC.fixedHeight)
	frame:SetClampedToScreen(true)
	KC:RestoreWindowPosition()
	
	-- Hide it by default
	frame:Hide()

	-- The board, pieces, markers and labels live in their own container that ignores
	-- the window opacity. WoW applies alpha to each texture separately rather than to
	-- the window as a whole, so a translucent piece would show the square through it.
	KC.boardFrame = CreateFrame("FRAME", nil, frame)
	KC.boardFrame:SetAllPoints(frame)
	KC.boardFrame:SetIgnoreParentAlpha(true)

	-- Hover highlight for legal destinations. Polled because the cursor is usually
	-- over a piece (dragged, or the capture target), which hides OnEnter from squares.
	KC.boardFrame:SetScript("OnUpdate", function() KC:UpdateHoverSquare() end)

	-- Make it fade out when the mouse is away. Polled every frame because the
	-- board's child frames swallow OnEnter/OnLeave, so the parent never sees the mouse leave.
	-- The fade dims everything; the window opacity setting only applies to the window itself.
	local fadeInTime = 0.2
	local fadeOutTime = 1.0
	local fade = mouseOverAlpha
	frame:SetScript('OnUpdate', function(f, elapsed)
		local target = mouseOverAlpha
		local duration = fadeInTime
		if self.db.global.fadeoutWindow and not f:IsMouseOver() then
			target = mouseAwayAlpha
			duration = fadeOutTime
		end

		if fade ~= target then
			local step = (mouseOverAlpha - mouseAwayAlpha) * elapsed / duration
			if fade < target then
				fade = math.min(fade + step, target)
			else
				fade = math.max(fade - step, target)
			end
		end

		f:SetAlpha(fade * KC:getWindowOpacity())
		KC.boardFrame:SetAlpha(fade)
	end)

	-- Add the titles
	local titleText = frame:CreateFontString(nil, "ARTWORK") 	
	titleText:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
    titleText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	titleText:SetText(KC.name)
	titleText:SetPoint("TOP", frame, "TOP", 0, -18)

	-- Add the title drag bar
	local title = CreateFrame("FRAME", nil, frame)
	title:SetWidth(frame:GetWidth())
	title:SetHeight(titleText:GetHeight())
	title:SetPoint("CENTER", titleText, "CENTER")

	-- Make it move the window
	title:SetScript("OnMouseDown", function() frame:StartMoving()  end) 
	title:SetScript("OnMouseUp", function()
	  frame:StopMovingOrSizing() -- SetClampedToScreen keeps it on screen
	  KC:SaveWindowPosition()
	end)

	-- Close Button
	local closebutton = CreateFrame("BUTTON", nil, title, "UIPanelCloseButton")
	closebutton:SetSize(30, 30)
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset+2, -inset+2)
	closebutton:SetScript("OnClick", function() KC:HideWindow() end)

	-- Flip Board button, in the opposite corner to the close button
	local flipButton = CreateFrame("BUTTON", nil, title)
	flipButton:SetSize(20, 20)
	flipButton:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + 6, -inset - 6)
	flipButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
	flipButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	flipButton:SetScript("OnClick", function() KC:FlipBoard() end)
	flipButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText("Flip board")
		GameTooltip:Show()
	end)
	flipButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Button consts
	local buttonWidth = 70
	local buttonHeight = 20
	local buttonMargin = 10

	local function createButton(text, width, onClick)
		local button = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(width or buttonWidth, buttonHeight)
		button:SetText(text)
		button:SetNormalFontObject("GameFontNormalSmall")
		button:SetScript("OnClick", onClick)
		return button
	end

	-- Play mode buttons, right to left
	local newGameButton = createButton("New Game", nil, function() KC.game:StartNewGameWithConfirm() end)
	newGameButton:SetPoint("BOTTOMRIGHT", -KC.frameMargin, 17)

	local clearBoardButton = createButton("Clear Board", nil, function() KC.game:ClearBoardWithConfirm() end)
	clearBoardButton:SetPoint("RIGHT", newGameButton, "LEFT", -buttonMargin, 0)

	local optionsButton = createButton("Options", nil, function() KC:OpenConfig() end)
	optionsButton:SetPoint("RIGHT", clearBoardButton, "LEFT", -buttonMargin, 0)

	KC.playButtons = { newGameButton, clearBoardButton, optionsButton }

	-- Puzzle mode buttons, in the same places
	local nextButton = createButton("Next Puzzle", nil, function() ns.Puzzles:Next() end)
	nextButton:SetPoint("BOTTOMRIGHT", -KC.frameMargin, 17)

	KC.solutionButton = createButton("Solution", nil, function() ns.Puzzles:ShowSolution() end)
	KC.solutionButton:SetPoint("RIGHT", nextButton, "LEFT", -buttonMargin, 0)

	-- Tier selector: shows the chosen tier and opens a menu of them
	KC.tierButton = createButton("", buttonWidth + 10, function(button) KC:OpenTierMenu(button) end)
	KC.tierButton:SetPoint("RIGHT", KC.solutionButton, "LEFT", -buttonMargin, 0)

	KC.puzzleButtons = { nextButton, KC.solutionButton, KC.tierButton }

	-- Move history buttons (both modes), bottom left: back one move / forward one move
	local function createHistoryButton(text, tooltip, delta)
		local button = createButton(text, 30, function() KC.game:StepHistory(delta) end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tooltip)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return button
	end
	KC.prevMoveButton = createHistoryButton("<", "Previous move", -1)
	KC.prevMoveButton:SetPoint("BOTTOMLEFT", KC.frameMargin, 17)
	KC.nextMoveButton = createHistoryButton(">", "Next move", 1)
	KC.nextMoveButton:SetPoint("LEFT", KC.prevMoveButton, "RIGHT", 4, 0)
	KC:UpdateHistoryButtons()
	for _, button in ipairs(KC.puzzleButtons) do
		button:Hide()
	end

	-- Mode tabs (Play / Puzzles), hanging below the window like Blizzard's panel tabs
	KC:createModeTabs(frame)

	-- Resize grip in the bottom-right corner
	KC:createResizeGrip(frame)

	-- Add the board
	KC:createChessBoard(frame)

	-- Info bar under the board: a headline, a detail line and a small footer,
	-- set with KC:SetStatus (game results in free play, puzzle feedback in puzzles)
	local boardBottom = Square.yOffset + KC.boardHeight
	KC.infoStatus = frame:CreateFontString(nil, "OVERLAY")
	KC.infoStatus:SetFont("Fonts\\MORPHEUS.TTF", 20, "OUTLINE")
	KC.infoStatus:SetPoint("TOP", frame, "TOP", 0, -(boardBottom + 6))

	KC.infoDetail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	KC.infoDetail:SetPoint("TOP", KC.infoStatus, "BOTTOM", 0, -3)
	KC.infoDetail:SetWidth(KC.boardWidth)
	KC.infoDetail:SetWordWrap(false)

	KC.infoFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	KC.infoFooter:SetPoint("TOP", KC.infoDetail, "BOTTOM", 0, -3)
	KC.infoFooter:SetWidth(KC.boardWidth)

	KC:SetStatus(nil)
end

-- Colours for the info bar headline, as r, g, b
ns.Colours = {
	Normal = { NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b },
	Good = { 0.38, 0.85, 0.32 },     -- Lichess "good move" green
	Bad = { 0.88, 0.28, 0.25 },      -- Lichess "mistake" red
	Neutral = { 0.85, 0.85, 0.85 },
}

-- Sets the info bar under the board. status nil clears it.
function KC:SetStatus(status, colour, detail, footer)
	if not KC.infoStatus then
		return
	end
	colour = colour or ns.Colours.Normal
	KC.infoStatus:SetText(status or "")
	KC.infoStatus:SetTextColor(colour[1], colour[2], colour[3])
	KC.infoDetail:SetText(detail or "")
	KC.infoFooter:SetText(footer or "")
end

-- Modes
-- Two tabs below the window switch between free play and puzzles
function KC:createModeTabs(frame)
	KC.modeTabs = {}
	local names = { "Play", "Puzzles" }
	for i, name in ipairs(names) do
		local tab = CreateFrame("BUTTON", nil, frame, "PanelTabButtonTemplate")
		tab:SetID(i)
		tab:SetText(name)
		PanelTemplates_TabResize(tab, 0)
		if (i == 1) then
			tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 7)
		else
			tab:SetPoint("LEFT", KC.modeTabs[i - 1], "RIGHT", -16, 0)
		end
		tab:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			KC:SetMode((i == 1) and "play" or "puzzle")
		end)
		KC.modeTabs[i] = tab
	end
	frame.Tabs = KC.modeTabs
	PanelTemplates_SetNumTabs(frame, #KC.modeTabs)
	PanelTemplates_SetTab(frame, 1)
	KC.mode = "play"
end

-- Switches between "play" (free play) and "puzzle"
function KC:SetMode(mode)
	if (mode == KC.mode) then
		return
	end

	if (mode == "puzzle") then
		if not ns.Puzzles:Enter() then
			return -- The info bar says why
		end
	else
		ns.Puzzles:Leave()
	end

	KC.mode = mode
	PanelTemplates_SetTab(KC.frame, (mode == "play") and 1 or 2)
	for _, button in ipairs(KC.playButtons) do
		button:SetShown(mode == "play")
	end
	for _, button in ipairs(KC.puzzleButtons) do
		button:SetShown(mode == "puzzle")
	end
	KC:UpdatePuzzleButtons()
end

-- < and > are enabled when there is an earlier / later position to show
function KC:UpdateHistoryButtons()
	if not KC.prevMoveButton then
		return
	end
	local game = KC.game
	KC.prevMoveButton:SetEnabled(game.historyIndex > 1)
	KC.nextMoveButton:SetEnabled(game.historyIndex < #game.history)
end

-- Tier name on the tier button; Solution only while a puzzle is unsolved
function KC:UpdatePuzzleButtons()
	if not KC.tierButton then
		return
	end
	local Puzzles = ns.Puzzles
	KC.tierButton:SetText(Puzzles:GetTier().name)
	KC.solutionButton:SetEnabled(Puzzles.active and Puzzles.puzzle ~= nil and not Puzzles.done)
end

-- The tier menu: one entry per tier with its rating range
function KC:OpenTierMenu(owner)
	local Puzzles = ns.Puzzles
	if (MenuUtil and MenuUtil.CreateContextMenu) then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle("Puzzle difficulty")
			for _, tier in ipairs(Puzzles.Tiers) do
				root:CreateRadio(tier.name.." |cff9d9d9d("..tier.range..")|r",
					function() return Puzzles:GetTier().key == tier.key end,
					function()
						Puzzles:SetTier(tier.key)
						KC:UpdatePuzzleButtons()
					end)
			end
		end)
		return
	end

	-- No menu API: step to the next tier
	local current = Puzzles:GetTier().key
	for i, tier in ipairs(Puzzles.Tiers) do
		if (tier.key == current) then
			Puzzles:SetTier(Puzzles.Tiers[i % #Puzzles.Tiers + 1].key)
			break
		end
	end
	KC:UpdatePuzzleButtons()
end

-- Stores the window's anchor so it reopens in the same place next session
function KC:SaveWindowPosition()
	local point, _, relativePoint, x, y = KC.frame:GetPoint(1)
	KC.db.global.windowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- Puts the window at its saved size and position, or the centre of the screen if there isn't one.
-- The scale is applied first, as anchor offsets are measured in the window's own scale.
function KC:RestoreWindowPosition()
	local pos = KC.db.global.windowPosition
	KC.frame:SetScale(KC.db.global.windowScale)
	KC.frame:ClearAllPoints()
	if pos and pos.point then
		KC.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	else
		KC.frame:SetPoint("CENTER", UIParent, "CENTER")
	end
end

-- Adds a grip to the bottom-right corner that resizes the window by scaling it.
-- Everything in the window is laid out at a fixed size, so scaling keeps it all in proportion.
function KC:createResizeGrip(frame)
	local grip = CreateFrame("BUTTON", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

	grip:SetScript("OnMouseDown", function(g)
		-- Measure from where the top-left corner is when the drag starts
		local left, top = KC:GetWindowTopLeft()
		local parentScale = UIParent:GetEffectiveScale()

		g:SetScript("OnUpdate", function()
			local cursorX, cursorY = GetCursorPosition()
			local scaleX = (cursorX - left) / (KC.fixedWidth * parentScale)
			local scaleY = (top - cursorY) / (KC.fixedHeight * parentScale)
			KC:SetWindowScale((scaleX + scaleY) / 2, left, top)
		end)
	end)

	grip:SetScript("OnMouseUp", function(g)
		g:SetScript("OnUpdate", nil)
		KC:SaveWindowPosition()

		-- Update the size slider if the options panel is open
		KC.ACR:NotifyChange(KC.name)
	end)
end

-- The window's top-left corner in screen pixels, or nil if it hasn't been laid out yet
function KC:GetWindowTopLeft()
	local left, top = KC.frame:GetLeft(), KC.frame:GetTop()
	if not left or not top then
		return nil
	end
	local effective = KC.frame:GetEffectiveScale()
	return left * effective, top * effective
end

-- Scales the window (clamped to the allowed range) and saves the scale. The top-left
-- corner stays at (left, top) in screen pixels, defaulting to where it is now.
-- The caller is responsible for saving the new position with SaveWindowPosition.
function KC:SetWindowScale(scale, left, top)
	if not left then
		left, top = KC:GetWindowTopLeft()
	end
	scale = math.max(KC.minWindowScale, math.min(KC.maxWindowScale, scale))

	KC.frame:SetScale(scale)
	KC.db.global.windowScale = scale

	-- Without a known position (never laid out) just keep the current anchor
	if not left then
		return
	end

	local effective = KC.frame:GetEffectiveScale()
	KC.frame:ClearAllPoints()
	KC.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / effective, top / effective)
end

-- Add the visual and logical board into the frame
function KC:createChessBoard(frame)
	-- Flipped at the start of each column, so a1 starts dark ("light on the right")
	local lightSquare = true

	KC.board = {}

	for i=1,KC.boardDim,1 do
		KC.board[i] = {}
		lightSquare = not lightSquare

		for j=1,KC.boardDim,1 do
			KC.board[i][j] = Square:new(frame, KC.boardSectionSize, i, j, lightSquare)
			lightSquare = not lightSquare
		end
	end

	-- Show the labels on the board's edges (if enabled)
	KC:applyBoardLabelVisibility()

	-- Apply the opacity setting to the whole window
	KC:applyWindowOpacity()
end

-- Board orientation
-- Where a square is drawn, as a column and row counted from the displayed
-- bottom-left corner. Unflipped, that's a1 and the square's own indices.
function KC:GetDisplayPosition(col, row)
	if KC.boardFlipped then
		return KC.boardDim + 1 - col, KC.boardDim + 1 - row
	end
	return col, row
end

-- The square drawn at a displayed column and row (the mapping is its own inverse)
function KC:GetSquareAtDisplay(col, row)
	local c, r = KC:GetDisplayPosition(col, row)
	return KC.board[c][r]
end

-- Turns the board so black (flipped) or white is at the bottom
function KC:SetBoardFlipped(flipped)
	if (KC.boardFlipped == flipped) then
		return
	end
	KC.boardFlipped = flipped

	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			KC.board[i][j]:UpdatePosition()
		end
	end
	KC:applyBoardLabelVisibility()
	KC:AnchorPromotionPicker()
end

function KC:FlipBoard()
	KC:SetBoardFlipped(not KC.boardFlipped)
end

-- Applies the user selected opacity to the whole window. The fade (OnUpdate in
-- createChessFrame) scales from this value, so it only needs setting directly here.
function KC:applyWindowOpacity()
	KC.frame:SetAlpha(KC:getWindowOpacity())
end

-- Applies a user selected texture to all the board squares
function KC:applyBoardTextures()
	-- Apply Chess Board Textures
	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			KC.board[i][j]:UpdateTexture()
		end
	end
end

-- Applies a user selected texture to all the pieces on the board
function KC:applyPieceTextures()
	-- Apply Chess Piece Textures
	KC.game:UpdateTextures()
end

-- Toggles the board labels on and off
function KC:applyBoardLabelVisibility()
	local state = KC:getBoardLabelsVisible()

	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			KC.board[i][j]:UpdateLabels(state)
		end
	end
end

-- Clears all legal moves
function KC:clearLegalMovesAndCaptures()
	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			KC.board[i][j].legalMove:Hide()
			KC.board[i][j].legalCapture:Hide()
		end
	end
end

-- Gets the square under the mouse cursor, or nil if it's not over the board
function KC:GetSquareUnderCursor()
	for i=1,KC.boardDim,1 do
		for j=1,KC.boardDim,1 do
			if KC.board[i][j].frame:IsMouseOver() then
				return KC.board[i][j]
			end
		end
	end
end

-- Highlights the legal move / capture square under the cursor while a piece is selected
function KC:UpdateHoverSquare()
	local square = nil
	if KC.game.selectedPiece and KC.boardFrame:IsMouseOver() then
		local candidate = KC:GetSquareUnderCursor()
		if candidate and (candidate:IsLegalMove() or candidate:IsLegalCapture()) then
			square = candidate
		end
	end

	if square ~= KC.hoverSquare then
		if KC.hoverSquare then
			KC.hoverSquare:SetHovered(false)
		end
		if square then
			square:SetHovered(true)
		end
		KC.hoverSquare = square
	end
end

-- Gets a specific board position
function KC:GetBoardPosition(position)
	local col = strsub(position, 1, 1)
	local row = strsub(position, 2, 2)
	return KC.board[ord(col)][tonumber(row)]
end
