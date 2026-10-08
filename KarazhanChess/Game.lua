-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Gameplay Logic
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Piece = ns.FrameUtils, ns.Piece
local removeFromTableByIndex = ns.removeFromTableByIndex

local Game = {}
ns.Game = Game
Game.__index = Game;
Game.NewGameConfirmDiag = "KARAZHANCHESS_NEW_GAME_CONFIRM"
Game.ClearBoardConfirmDiag = "KARAZHANCHESS_CLEAR_BOARD_CONFIRM"

-- Constructor
function Game:new()
    -- Metatable
    local self = {};
    setmetatable(self, Game);

    -- Locals
    local size = KC.boardSectionSize

    -- Variables
    self.gameState = 0
    self.pieces = {}
    self.selectedPiece = nil

    -- Init
    self:CreateStaticModals()

    -- Done!
    return self;
end

function Game:CreateStaticModals()
    -- New Game
    StaticPopupDialogs[Game.NewGameConfirmDiag] = {
        text = "Starting a new game of Karazhan Chess will reset the board.\n\nAre you sure you wish to start a New Game?",
        button1 = OKAY,
        button2 = CANCEL,
        OnAccept = function()
            self:StartNewGame()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
      }

      -- Clear Board
      StaticPopupDialogs[Game.ClearBoardConfirmDiag] = {
        text = "Are you sure you wish to clear the board?",
        button1 = OKAY,
        button2 = CANCEL,
        OnAccept = function()
            self:ClearBoard()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
      }
end

-- Update Textures
function Game:UpdateTextures()
    for i=1,table.getn(self.pieces),1 do
		self.pieces[i]:UpdateTexture()
	end
end

-- Register a piece so it can recieve a texture update
function Game:CreatePiece(type, isWhite, startingLocation)
    local piece = Piece:new(type, isWhite)
    table.insert(self.pieces, piece)

    if(startingLocation ~= nil) then
       -- Assume we want to show it, and stick it int he right locaton
       piece:ApplyPosition(startingLocation)
       piece:ShowPiece() 
    end
end

function Game:RemovePiece(piece)
    -- Clean the reverse lookup
    local square = piece.currentSquare
    if(square ~= nil) then
        square.currentPiece = nil
    end

    FrameUtils:returnFrameToPool(piece.frame)
    removeFromTableByIndex(self.pieces, piece.id)
end

-- Starting a new game with a confirmation dialog
function Game:StartNewGameWithConfirm() 
    if(table.getn(self.pieces) ~= 0) then
        -- If there is a game started, get confirmation
        StaticPopup_Show(Game.NewGameConfirmDiag)
    else
        self:StartNewGame()
    end    
end

-- Force starting a new game
function Game:StartNewGame()
    local order = 'rnbqkbnr'
    local cols = 'abcdefgh'
    local pawnType = 'p'

    -- Reset state
    self:ClearBoard()

	for i=1,KC.boardDim,1 do
		local pieceType = strsub(order, i, i)
		local c = strsub(cols, i, i)
		
        self:CreatePiece(pieceType, true,  c.."1")
        self:CreatePiece(pieceType, false,  c.."8")

		self:CreatePiece(pawnType, true,  c.."2")
		self:CreatePiece(pawnType, false,  c.."7")
	end
end

-- Clear board with a confirmation popup
function Game:ClearBoardWithConfirm() 
    if(table.getn(self.pieces) == 0) then
        -- Nothing to do
        return
    else
        StaticPopup_Show(Game.ClearBoardConfirmDiag)
    end
end

-- Remove all pieces
function Game:ClearBoard()
    -- Remove everything
    local count = table.getn(self.pieces)
    for i=1,count,1 do
        self:RemovePiece(self.pieces[1])
    end

    -- Hide any UI hints
    self:DeselectPiece()
    KC:HidePromotionPicker()
end

-- Game Logic
function Game:EndGameVictory() 
end

-- Game Logic
function Game:EndGameDefeat() 
end

-- Select a piece
function Game:SelectPiece(piece) 
    if(self.selectedPiece ~= nil) then
        if(piece.currentSquare:IsLegalCapture()) then
            -- Caputure & Deselect
            self:HandleCapture(piece)
            self:DeselectPiece()
            return 
        else
            -- Just picking a different piece
            self:DeselectPiece()
        end
    end

    -- This is definately a selection, so render it and update the board
    self.selectedPiece = piece
    self.selectedPiece:SetSelected()
    self:ShowValidMoves()
end

-- Deselect a piece
function Game:DeselectPiece()
    KC:clearLegalMovesAndCaptures()

    if(self.selectedPiece == nil) then
        return
    end

    -- Handle cleaning up the board
    self.selectedPiece:SetDeselected()
    self.selectedPiece = nil
end

-- Board selection
-- Moves the selected piece to square if that's a legal move. Returns whether it moved.
-- animated is false when the piece was dropped there by dragging (it's already in place).
function Game:HandleBoardSquareClicked(square, animated)
    -- Nothign to do if no piece selected
    if(self.selectedPiece == nil) then
        return false
    end

    -- Is this a legit move?
    if (square:IsLegalMove() or square:IsLegalCapture()) then
        local piece = self.selectedPiece
        local fromSquare = piece.currentSquare

        -- Capturing: take the enemy piece off the board before moving in
        if (square:IsLegalCapture() and square.currentPiece ~= nil) then
            self:RemovePiece(square.currentPiece)
        end

        piece:MovePiece(square, animated ~= false)
        piece.hasMoved = true

        -- A king moving two files is castling, so bring the rook across too
        if (piece.name == "k" and math.abs(square.colIndex - fromSquare.colIndex) == 2) then
            self:CompleteCastle(square)
        end

        -- A pawn reaching the last rank promotes; the player picks what to
        if (piece.name == "p" and square.rowIndex == piece:GetPromotionRow()) then
            KC:ShowPromotionPicker(piece, square, function(name) piece:PromoteTo(name) end)
        end

        self:DeselectPiece()
        return true
    end
    return false
end

-- Moves the rook to the other side of a king that has just castled onto kingSquare
function Game:CompleteCastle(kingSquare)
    local castle = Piece:GetCastleByKingCol(kingSquare.colIndex)
    local row = kingSquare.rowIndex
    local rook = KC.board[castle.rookCol][row].currentPiece

    rook:MovePiece(KC.board[castle.rookToCol][row], true)
    rook.hasMoved = true
end

-- Captures piece with the selected piece (used when the enemy piece itself is clicked)
function Game:HandleCapture(piece)
    -- What space are we capturing onto
    local square = piece.currentSquare
    if(square == nil) then
        KC:Print("Warning: Attempted to Capture Piece that isn't on a Square.")
        return
    end

    -- Moving onto a legal capture square removes the piece there
    self:HandleBoardSquareClicked(square)
end

-- Move display
function Game:ShowValidMoves()
    -- Calculate valid moves
    local validMoves, validCaptures = self:CalculateValidMoves()

    -- Display them all
    for i,move in ipairs(validMoves) do
        KC:GetBoardPosition(move):ShowAsLegalMove()
    end
    for i,capture in ipairs(validCaptures) do
        KC:GetBoardPosition(capture):ShowAsLegalCapture()
    end
end

-- Move calcultion: returns the selected piece's moves and captures
function Game:CalculateValidMoves()
    if (self.selectedPiece == nil) then
        return {}, {}
    end
    return self.selectedPiece:CalculateMoves()
end