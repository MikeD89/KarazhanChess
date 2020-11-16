-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Gameplay Logic
-------------------------------------------------------------------------------

Game = {}
Game.__index = Game;

-- Constructor
function Game:new()
    -- Metatable
    local self = {};
    setmetatable(self, Game);

    -- Locals
    local size = KC.boardSectionSize

    -- Variables
    self.gameState = 0
    self.selectedPiece = nil

    -- Done!
    return self;
end

-- Game Logic
function Game:StartNewGame() 
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
    if(self.selectedPiece == nil) then
        return
    end

    -- Handle cleaning up the board
    self.selectedPiece:SetDeselected()
    self.selectedPiece = nil
    KC:clearLegalMovesAndCaptures()
end

-- Board selection
function Game:HandleBoardSquareClicked(square)
    -- Nothign to do if no piece selected
    if(self.selectedPiece == nil) then
        return
    end

    -- Is this a legit move?
    if (square:IsLegalMove() or square:IsLegalCapture()) then
        self.selectedPiece:MovePiece(square, true)
        self:DeselectPiece()
    end
end

function Game:HandleCapture(piece)
    -- TODO - King Check -> Victory

    -- What space are we capturing onto 
    local square = piece.currentSquare

    -- Remove the peice from the board
    piece:HidePiece()
    piece:ClearSquareAssignment()

    -- Move the current piece into the space
    self:HandleBoardSquareClicked(square)

    -- Visually deselect it
    self:DeselectPiece()
end

-- Move display
function Game:ShowValidMoves()
    -- Calculate valid moves
    validMoves = self:CalculateValidMoves()
    validCaptures = self:CalculateValidCaptures()

    -- Display them all
    for i,move in ipairs(validMoves) do
        KC:GetBoardPosition(move):ShowAsLegalMove()
    end
    for i,capture in ipairs(validCaptures) do
        KC:GetBoardPosition(capture):ShowAsLegalCapture()
    end
end

-- Move calcultion
function Game:CalculateValidMoves()
    return {"a1", "a2", "c3", "c4", "e5", "e6", "g7", "g8" }
end

function Game:CalculateValidCaptures()
    return {"b2", "b3", "d4", "d5", "f6", "f7", "h8", "h1", "e8" }
end



-- -- Register a piece so it can recieve a texture update
-- function KC:RegisterPiece(piece)
-- 	table.insert(KC.pieces, piece)
-- end

-- function KC:UnregisterPiece(piece)
-- 	removeFromTableByIndex(KC.pieces, piece.id)
-- end

-- -- Preload the Pieces
-- function KC:PreloadPieces()
-- 	local order = 'rnbqkbnr'
-- 	local cols = 'abcdefgh'

-- 	for i=1,KC.boardDim,1 do
-- 		local p = strsub(order, i, i)
-- 		local c = strsub(cols, i, i)
		
-- 		table.insert(KC.pieces, Piece:new(p, true, c.."1"))
-- 		table.insert(KC.pieces, Piece:new(p, false, c.."8"))

-- 		table.insert(KC.pieces, Piece:new("p", true, c.."2"))
-- 		table.insert(KC.pieces, Piece:new("p", false, c.."7"))
-- 	end
-- end
