-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Pawn Promotion Picker
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Icons = ns.FrameUtils, ns.Icons

-- Lichess style: the board is dimmed and the choices form a column on the
-- promotion file, starting at the promotion square and running towards the centre.
-- The dimmed overlay takes the mouse, so nothing else on the board can be used
-- until a piece is chosen.
local promotionOptions = { "q", "r", "b", "n" }

-- Frame levels above KC.boardFrame: over squares, markers and pieces (incl. dragged)
local overlayLevel = 10
local optionLevel = 11

local function createPicker()
	local overlay = CreateFrame("FRAME", nil, KC.boardFrame)
	overlay:SetFrameLevel(KC.boardFrame:GetFrameLevel() + overlayLevel)
	overlay:EnableMouse(true) -- Swallow clicks so the board can't be used meanwhile
	overlay:Hide()

	-- Clicking the dimmed board (anywhere but a choice) cancels, as on Lichess
	overlay:SetScript("OnMouseUp", function()
		local onCancelled = overlay.onCancelled
		KC:HidePromotionPicker()
		if onCancelled then
			onCancelled()
		end
	end)

	local dim = overlay:CreateTexture(nil, "BACKGROUND")
	dim:SetAllPoints()
	dim:SetColorTexture(0, 0, 0, 0.5)

	overlay.options = {}
	for i = 1, #promotionOptions do
		local option = CreateFrame("BUTTON", nil, overlay)
		option:SetSize(KC.boardSectionSize, KC.boardSectionSize)
		option:SetFrameLevel(KC.boardFrame:GetFrameLevel() + optionLevel)

		-- Light tile behind the piece, brightening on hover
		local tile = option:CreateTexture(nil, "BACKGROUND")
		tile:SetAllPoints()
		tile:SetColorTexture(0.85, 0.85, 0.85, 0.95)

		local hover = option:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(0.95, 0.55, 0.15, 0.6)

		option.icon = option:CreateTexture(nil, "ARTWORK")
		option.icon:SetAllPoints()
		FrameUtils:DisablePixelSnapping(option.icon)

		overlay.options[i] = option
	end

	return overlay
end

-- Shows the picker for a pawn that has just reached the last rank on square.
-- onChosen(pieceName) is called with the chosen piece ("q", "r", "b" or "n");
-- onCancelled() is called if the player clicks off the picker instead.
-- Hiding the picker any other way (KC:HidePromotionPicker) calls neither.
function KC:ShowPromotionPicker(pawn, square, onChosen, onCancelled)
	KC.promotionPicker = KC.promotionPicker or createPicker()
	local picker = KC.promotionPicker
	picker.onCancelled = onCancelled
	KC:AnchorPromotionPicker()

	-- Run from the promotion square towards the centre of the board. The options
	-- are anchored to squares, so they follow the board if it is flipped.
	local direction = pawn.isWhite and -1 or 1
	for i, option in ipairs(picker.options) do
		local name = promotionOptions[i]
		local row = square.rowIndex + (i - 1) * direction

		option:ClearAllPoints()
		option:SetPoint("CENTER", KC.board[square.colIndex][row].frame, "CENTER")
		option.icon:SetTexture(Icons.Piece:GetPieceIcon(pawn.prefix..name))
		option:SetScript("OnClick", function()
			KC:HidePromotionPicker()
			onChosen(name)
		end)
	end

	picker:Show()
end

-- Fits the dimmed overlay to the displayed corners of the board, which swap when
-- it is flipped
function KC:AnchorPromotionPicker()
	local picker = KC.promotionPicker
	if not picker then
		return
	end
	picker:ClearAllPoints()
	picker:SetPoint("TOPLEFT", KC:GetSquareAtDisplay(1, KC.boardDim).frame, "TOPLEFT")
	picker:SetPoint("BOTTOMRIGHT", KC:GetSquareAtDisplay(KC.boardDim, 1).frame, "BOTTOMRIGHT")
end

function KC:HidePromotionPicker()
	if KC.promotionPicker then
		KC.promotionPicker.onCancelled = nil
		KC.promotionPicker:Hide()
	end
end

function KC:IsPromotionPickerShown()
	return KC.promotionPicker ~= nil and KC.promotionPicker:IsShown()
end
