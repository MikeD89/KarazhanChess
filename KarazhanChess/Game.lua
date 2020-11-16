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
    self.pieces = {}
    self.selectedPiece = nil

    -- Init
    self:CreateStaticModals()

    -- Done!
    return self;
end

-- Update Textures
function Game:UpdateTextures()
    for i=1,table.getn(self.pieces),1 do
		self.pieces[i]:UpdateTexture()
	end
end

-- Register a piece so it can recieve a texture update
function Game:CreatePiece(type, isWhite, startingLocation)
    piece = Piece:new(type, isWhite)
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

-- Game Logic
function Game:StartNewGame() 
    if(table.getn(self.pieces) ~= 0) then
        -- TODO - confirmation
    end    

    local order = 'rnbqkbnr'
    local cols = 'abcdefgh'
    local pawnType = 'p'

    -- Reset state
    self:RemoveAllPieces()

	for i=1,KC.boardDim,1 do
		local pieceType = strsub(order, i, i)
		local c = strsub(cols, i, i)
		
        self:CreatePiece(pieceType, true,  c.."1")
        self:CreatePiece(pieceType, false,  c.."8")

		self:CreatePiece(pawnType, true,  c.."2")
		self:CreatePiece(pawnType, false,  c.."7")
	end
end

-- Game Logic
function Game:EndGameVictory() 
end

-- Game Logic
function Game:EndGameDefeat() 
end

-- Clear board with a confirmation popup
function Game:ClearBoardWithConfirm() 
    if(table.getn(self.pieces) == 0) then
        -- Nothing to do
        return
    end

    -- Do the work
    self:RemoveAllPieces()
end

-- Remove all pieces
function Game:RemoveAllPieces()
    local count = table.getn(self.pieces)
    for i=1,count,1 do
        self:RemovePiece(self.pieces[1])
    end
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
    -- What space are we capturing onto
    local square = piece.currentSquare
    if(square == nil) then
        KC:Print("Warning: Attempted to Capture Piece that isn't on a Square.")
        return
    end

    -- Remove the piece
    self:RemovePiece(piece)

    -- Move the new piece into position
    self:HandleBoardSquareClicked(square)
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

function Game:CreateStaticModals()
    StaticPopupDialogs["EXAMPLE_HELLOWORLD"] = {
        text = "Do you want to greet the world today?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            GreetTheWorld()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
      }
end