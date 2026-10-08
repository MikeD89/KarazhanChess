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
	  frame:StopMovingOrSizing() -- SetClampedToScreen keeps it on screen
	  KC:SaveWindowPosition()
	end)

	-- Close Button
	local closebutton = CreateFrame("BUTTON", nil, title, "UIPanelCloseButton")
	closebutton:SetSize(30, 30)
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset+2, -inset+2)
	closebutton:SetScript("OnClick", function() KC:HideWindow() end)

	-- Button consts
	local buttonWidth = 70
	local buttonHeight = 20
	local buttonMargin = 10

	-- New Game Button
	local newGameButton = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate");
	newGameButton:SetPoint("BOTTOMRIGHT", -KC.frameMargin, 17);
	newGameButton:SetSize(buttonWidth, buttonHeight);
	newGameButton:SetText("New Game");
	newGameButton:SetNormalFontObject("GameFontNormalSmall");
	newGameButton:SetScript("OnClick", function(self, arg) KC.game:StartNewGameWithConfirm() end)

	-- Clear Board Button
	local clearBoardButton = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate");
	clearBoardButton:SetPoint("RIGHT", newGameButton, "LEFT", -buttonMargin, 0);
	clearBoardButton:SetSize(buttonWidth, buttonHeight);
	clearBoardButton:SetText("Clear Board");
	clearBoardButton:SetNormalFontObject("GameFontNormalSmall");
	clearBoardButton:SetScript("OnClick", function(self, arg) KC.game:ClearBoardWithConfirm() end)

	-- Options Button
	local optionsButton = CreateFrame("BUTTON", nil, frame, "UIPanelButtonTemplate");
	optionsButton:SetPoint("RIGHT", clearBoardButton, "LEFT", -buttonMargin, 0);
	optionsButton:SetSize(buttonWidth, buttonHeight);
	optionsButton:SetText("Options");
	optionsButton:SetNormalFontObject("GameFontNormalSmall");
	optionsButton:SetScript("OnClick", function(self, arg)
		KC:OpenConfig()
	end)

	-- Resize grip in the bottom-right corner
	KC:createResizeGrip(frame)

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
	local firstRow = true
	local newColumn = true

	-- Globals
	KC.board = {}
	KC.boardLabels = {}
	
	-- Columns
	for i=1,KC.boardDim,1 do
		-- New row
		KC.board[i] = {}  
		lightSquare = not lightSquare
		newColumn = true

		-- Rows
		for j=1,KC.boardDim,1 do	
			-- Create a piece and flip the colour
			KC.board[i][j] = Square:new(frame, KC.boardSectionSize, i, j, lightSquare)
			lightSquare = not lightSquare

			-- Create the neccersary labels
			if (firstRow) then
				local label = FrameUtils:CreateBoardLabel(KC.board[i][j], KC.board[i][j].frame, true)
				table.insert(KC.boardLabels, label)
			end
			if (newColumn) then
				local label = FrameUtils:CreateBoardLabel(KC.board[i][j], KC.board[i][j].frame, false)
				table.insert(KC.boardLabels, label)
			end

			-- This is no longer a new column 
			newColumn = false
		end	
		
		-- After the first row we don't need labels any more
		firstRow = false			
	end

	-- We've added labels (probably) - We might need to hide them
	KC:applyBoardLabelVisibility()

	-- Apply the opacity setting to the whole window
	KC:applyWindowOpacity()
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

	for i=1,table.getn(KC.boardLabels),1 do
		if(state) then
			KC.boardLabels[i]:Show()
		else
			KC.boardLabels[i]:Hide()
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

-- Gets a specific board position
function KC:GetBoardPosition(position)
	local col = strsub(position, 1, 1)
	local row = strsub(position, 2, 2)
	return KC.board[ord(col)][tonumber(row)]
end
