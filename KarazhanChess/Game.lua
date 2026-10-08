-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Gameplay Logic
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Rules, Piece = ns.FrameUtils, ns.Rules, ns.Piece
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
    self.epSquare = nil      -- En passant target (rules engine square) after a double pawn push
    self.checkSquares = {}   -- Squares showing the check glow

    -- Who may move: nil = either colour (free play), "w" / "b" = that colour only,
    -- false = nobody (e.g. while a puzzle plays the opponent's reply)
    self.allowedColour = nil

    -- Called as onPlayerMove(move, uci, undo) once a player's move is complete
    -- (after the promotion choice). uci includes the chosen promotion piece.
    self.onPlayerMove = nil

    -- Whether checkmate / stalemate is announced in the info bar (free play)
    self.announceResults = true

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
    return piece
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
    self:SetLastMove(nil, nil)
    self:ClearCheck()
    if self.announceResults then
        KC:SetStatus(nil)
    end
    self.epSquare = nil
    KC:HidePromotionPicker()
end

-- Highlights the from and to squares of the last move (Lichess style); nil clears it
function Game:SetLastMove(fromSquare, toSquare)
    if self.lastMoveFrom then self.lastMoveFrom:SetLastMove(false) end
    if self.lastMoveTo then self.lastMoveTo:SetLastMove(false) end

    self.lastMoveFrom, self.lastMoveTo = fromSquare, toSquare

    if fromSquare then fromSquare:SetLastMove(true) end
    if toSquare then toSquare:SetLastMove(true) end
end

-- Game Logic
function Game:EndGameVictory() 
end

-- Game Logic
function Game:EndGameDefeat() 
end

-- Whether the player may pick up piece (see allowedColour)
function Game:CanMove(piece)
    if (self.allowedColour == nil) then
        return true
    end
    return self.allowedColour == (piece.isWhite and "w" or "b")
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

    -- Only pieces of the side allowed to move can be picked up
    if not self:CanMove(piece) then
        return
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
    -- Nothing to do if no piece selected
    if(self.selectedPiece == nil) then
        return false
    end

    -- Is this a legit move?
    if not (square:IsLegalMove() or square:IsLegalCapture()) then
        return false
    end

    local piece = self.selectedPiece
    local move = self:FindLegalMove(piece, square)
    if (move == nil) then
        return false
    end

    local undo = self:ApplyMove(piece, move, animated ~= false)
    local opponent = piece.isWhite and "b" or "w"

    local uci = Rules.SquareName(move.from)..Rules.SquareName(move.to)

    -- A pawn reaching the last rank promotes; the player picks what to, or
    -- cancels (clicking off the picker), which takes the move back
    if (move.promotion) then
        KC:ShowPromotionPicker(piece, square,
            function(name)
                piece:PromoteTo(name)
                undo.promoted = true
                self:UpdateCheckState(opponent)
                self:NotifyPlayerMove(move, uci..name, undo)
            end,
            function()
                self:UndoMove(undo)
                self:UpdateCheckState(opponent)
            end)
    else
        self:UpdateCheckState(opponent)
        self:NotifyPlayerMove(move, uci, undo)
    end

    self:DeselectPiece()
    return true
end

function Game:NotifyPlayerMove(move, uci, undo)
    if self.onPlayerMove then
        self.onPlayerMove(move, uci, undo)
    end
end

-- Plays a rules engine move on the board frames: removes any captured piece (en
-- passant takes the pawn beside, not one on the destination), moves the piece,
-- brings the rook across when castling, and records the en passant square and
-- last move. Promotion and the check state are left to the caller. Returns what
-- Game:UndoMove needs to take the move back.
function Game:ApplyMove(piece, move, animated)
    local fromSquare = piece.currentSquare
    local toSquare = self:GetSquare(move.to)
    local undo = {
        move = move,
        piece = piece,
        fromSquare = fromSquare,
        toSquare = toSquare,
        hadMoved = piece.hasMoved,
        lastMoveFrom = self.lastMoveFrom,
        lastMoveTo = self.lastMoveTo,
        epSquare = self.epSquare,
    }

    if (move.capSq) then
        local target = self:GetPieceAt(move.capSq)
        undo.captured = { name = target.name, isWhite = target.isWhite, hasMoved = target.hasMoved, square = target.currentSquare }
        self:RemovePiece(target)
    end

    piece:MovePiece(toSquare, animated)
    piece.hasMoved = true
    self:SetLastMove(fromSquare, toSquare)

    if (move.flag == "castle") then
        self:CompleteCastle(move)
    end

    -- A double pawn push can be taken en passant on the next move only
    self.epSquare = (move.flag == "double") and (move.from + (piece.isWhite and 8 or -8)) or nil

    return undo
end

-- Plays a move given in UCI notation ("e2e4", "e1g1" to castle, "e7e8q" to
-- promote), animated, for whichever side owns the piece on the from square.
-- Used by puzzles for the opponent's replies. Returns the rules engine move, or
-- nil if it isn't legal here.
function Game:ExecuteMove(uci)
    local from = Rules.SquareIndex(string.sub(uci or "", 1, 2))
    local piece = from and self:GetPieceAt(from)
    if (piece == nil) then
        return nil
    end

    local colour = piece.isWhite and "w" or "b"
    local found
    for _, move in ipairs(Rules.GenerateLegalMoves(self:GetPosition(colour), colour, from)) do
        if (Rules.MoveToUCI(move) == uci) then
            found = move
            break
        end
    end
    if (found == nil) then
        return nil
    end

    self:DeselectPiece()
    KC:HidePromotionPicker()
    local undo = self:ApplyMove(piece, found, true)
    if (found.promotion) then
        piece:PromoteTo(string.lower(found.promotion))
        undo.promoted = true
    end
    self:UpdateCheckState(piece.isWhite and "b" or "w")
    return found, undo
end

-- Sets the board up from a FEN string. Castling rights become hasMoved flags:
-- every piece counts as moved except a king and rook that may still castle.
-- Returns the side to move ("w" or "b"), or nil and an error message.
function Game:LoadFEN(fen)
    local pos, err = Rules.FromFEN(fen)
    if (pos == nil) then
        return nil, err
    end
    return self:LoadPosition(pos)
end

-- Sets the board up from a rules engine position (see LoadFEN). Returns the side to move.
function Game:LoadPosition(pos)
    self:ClearBoard()
    for sq = 1, 64 do
        local letter = pos.board[sq]
        if letter then
            local piece = self:CreatePiece(string.lower(letter), Rules.Colour[letter] == "w", Rules.SquareName(sq))
            piece.hasMoved = true
        end
    end

    for _, castle in ipairs(Rules.Castles) do
        if pos.castling[castle.right] then
            local king, rook = self:GetPieceAt(castle.kingFrom), self:GetPieceAt(castle.rookFrom)
            if (king and rook) then
                king.hasMoved = false
                rook.hasMoved = false
            end
        end
    end

    self.epSquare = pos.ep
    self:UpdateCheckState(pos.turn)
    return pos.turn
end

-- The rules engine's legal move taking piece to square, or nil. A promotion
-- matches the first of its four moves; the picker decides the piece.
function Game:FindLegalMove(piece, square)
    local colour = piece.isWhite and "w" or "b"
    local from = Rules.Index(piece.currentSquare.colIndex, piece.currentSquare.rowIndex)
    local to = Rules.Index(square.colIndex, square.rowIndex)
    for _, move in ipairs(Rules.GenerateLegalMoves(self:GetPosition(colour), colour, from)) do
        if (move.to == to) then
            return move
        end
    end
end

-- Takes back a move recorded by Game:ApplyMove: the piece returns to its square
-- (as a pawn again if it promoted), a castling rook goes back to its corner, any
-- captured piece is put back, and the previous last move and en passant square
-- are restored. Used when a promotion is cancelled and for a wrong puzzle move.
-- The caller updates the check state.
function Game:UndoMove(undo)
    self:DeselectPiece()
    if undo.promoted then
        undo.piece:SetType("p")
    end
    undo.piece:MovePiece(undo.fromSquare, true)
    undo.piece.hasMoved = undo.hadMoved

    -- A legal castle means the rook hadn't moved before
    if (undo.move and undo.move.flag == "castle") then
        local rook = self:GetPieceAt(undo.move.rookTo)
        rook:MovePiece(self:GetSquare(undo.move.rookFrom), true)
        rook.hasMoved = false
    end

    if undo.captured then
        local restored = self:CreatePiece(undo.captured.name, undo.captured.isWhite, undo.captured.square.name)
        restored.hasMoved = undo.captured.hasMoved
    end

    self:SetLastMove(undo.lastMoveFrom, undo.lastMoveTo)
    self.epSquare = undo.epSquare
end

-- Moves the rook of a castling move to the other side of the king
function Game:CompleteCastle(move)
    local rook = self:GetPieceAt(move.rookFrom)
    rook:MovePiece(self:GetSquare(move.rookTo), true)
    rook.hasMoved = true
end

-- Rules engine squares (1-64) to board squares and the pieces on them
function Game:GetSquare(sq)
    return KC.board[Rules.Col(sq)][Rules.Row(sq)]
end

function Game:GetPieceAt(sq)
    return self:GetSquare(sq).currentPiece
end

-- A rules engine snapshot of the board, with turn as the side to move ("w" by
-- default). Castling is allowed on a side whose king and rook are on their
-- start squares and have never moved.
function Game:GetPosition(turn)
    local pos = Rules.NewPosition()
    for _, piece in ipairs(self.pieces) do
        local square = piece.currentSquare
        if square then
            pos.board[Rules.Index(square.colIndex, square.rowIndex)] = piece:GetLetter()
        end
    end

    for _, castle in ipairs(Rules.Castles) do
        local king, rook = self:GetPieceAt(castle.kingFrom), self:GetPieceAt(castle.rookFrom)
        pos.castling[castle.right] = (king ~= nil and not king.hasMoved and rook ~= nil and not rook.hasMoved)
    end

    pos.ep = self.epSquare
    pos.turn = turn or "w"
    return pos
end

-- Check
-- Shows the check glow on any king in check, and announces checkmate or stalemate
-- for colour (the side to move next). Returns the status ("checkmate",
-- "stalemate" or nil) and whether colour is in check.
function Game:UpdateCheckState(colour)
    self:ClearCheck()

    local pos = self:GetPosition(colour)
    for _, side in ipairs({ "w", "b" }) do
        if Rules.InCheck(pos, side) then
            local square = self:GetSquare(Rules.FindKing(pos, side))
            square:SetCheck(true)
            table.insert(self.checkSquares, square)
        end
    end

    local status, inCheck = Rules.GetStatus(pos)
    if self.announceResults then
        local mover = (colour == "w") and "Black" or "White"
        if (status == "checkmate") then
            KC:SetStatus("Checkmate", ns.Colours.Good, mover.." is victorious")
        elseif (status == "stalemate") then
            KC:SetStatus("Stalemate", ns.Colours.Neutral, "The game is a draw")
        else
            KC:SetStatus(nil)
        end
    end
    return status, inCheck
end

function Game:ClearCheck()
    for _, square in ipairs(self.checkSquares) do
        square:SetCheck(false)
    end
    self.checkSquares = {}
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