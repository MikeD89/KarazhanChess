-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Gameplay Logic
-------------------------------------------------------------------------------

Game = {}
Game.__index = Game;
Game.NewGameConfirmDiag = "GAME_NEW_GAME_CONFIRM_DIAGLOG"
Game.ClearBoardConfirmDiag = "GAME_CLEAR_BOARD_CONFIRM_DIAGLOG"

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