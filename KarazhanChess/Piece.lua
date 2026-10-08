-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Piece Handling
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Icons, Square = ns.FrameUtils, ns.Icons, ns.Square

local Piece = {}
ns.Piece = Piece
Piece.__index = Piece;
Piece.SubLayer = 4

-- Pieces sit SubLayer levels above the board container, so above squares and markers
function Piece:GetBaseLevel()
    return KC.boardFrame:GetFrameLevel() + Piece.SubLayer
end
Piece.IndexCounter = 1

-- (1: Abbreviation) (2: Point Value)
Piece.Data = {
    ["k"] = {"k", 0},
    ["q"] = {"q", 9},
    ["r"] = {"r", 5},
    ["n"] = {"n", 3},
    ["b"] = {"b", 3},
    ["p"] = {"p", 1},
};

-- Movement offsets as {column, row}. Slides repeat a direction to the board edge,
-- steps move once. Pawns are handled separately as they depend on colour.
local orthogonal = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
local diagonal = { {1, 1}, {1, -1}, {-1, 1}, {-1, -1} }
local allDirections = { {1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1} }
local knightJumps = { {1, 2}, {2, 1}, {2, -1}, {1, -2}, {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2} }

Piece.Movement = {
    ["k"] = { steps = allDirections },
    ["q"] = { slides = allDirections },
    ["r"] = { slides = orthogonal },
    ["b"] = { slides = diagonal },
    ["n"] = { steps = knightJumps },
};

-- Castling, by column. The king starts on column 5 (e) and moves two squares
-- towards the rook, which jumps to the square the king passed over.
Piece.KingStartCol = 5
Piece.Castles = {
    { rookCol = 8, kingToCol = 7, rookToCol = 6, between = { 6, 7 } },    -- Kingside (O-O)
    { rookCol = 1, kingToCol = 3, rookToCol = 4, between = { 2, 3, 4 } }, -- Queenside (O-O-O)
};

function Piece:GetCastleByKingCol(kingToCol)
    for _, castle in ipairs(Piece.Castles) do
        if (castle.kingToCol == kingToCol) then
            return castle
        end
    end
end

-- Constructor
function Piece:new(name, isWhite)
    -- Metatable
    local self = {};
    local data = Piece.Data[name];
    setmetatable(self, Piece);

    -- Index 
    self.id = Piece.IndexCounter
    Piece.IndexCounter = self.id + 1

    -- Variables
    self.name = data[1];
    self.points = data[2];
    self.isWhite = isWhite;
    self.prefix = self.isWhite and "w" or "b";
    self.key = self.prefix..self.name;
    self.icon = Icons.Piece:GetPieceIcon(self.key)
    self.selected = false
    self.currentSquare = nil
    self.hasMoved = false

    -- Pieces have to exist inside a frame
    self.frame = FrameUtils:CreateIcon(KC.boardSectionSize, KC.boardSectionSize, self.icon, "OVERLAY")
    self.frame:SetFrameLevel(Piece:GetBaseLevel())

    -- Handle click 
    self.frame:SetScript("OnMouseUp", function() self:HandleMouseUp() end)    

    -- Hide by default
    self.frame:Hide()
    
    -- Done!
    return self;
end

-- Show/Hide
function Piece:ShowPiece()
    self.frame:Show() 
end 
function Piece:HidePiece()
    self.frame:Hide()
end 

-- String method
function Piece:__tostring()
    local position = self.currentSquare and self.currentSquare.name or "off board"
    return "Piece - "..self.key.." ("..position..")"
end

-- Interface
function Piece:UpdateTexture(position) 
    self.icon = Icons.Piece:GetPieceIcon(self.key)
	self.frame.texture:SetTexture(self.icon)
end

-- Moves
-- Returns the empty squares this piece can move to, as positions like "e4".
-- Any piece in the way blocks a slide or a pawn push. Occupied squares are never
-- moves; taking a piece belongs to captures, which aren't calculated yet.
function Piece:CalculateMoves()
    local moves = {}
    local square = self.currentSquare
    if (square == nil) then
        return moves
    end

    local col = square.colIndex
    local row = square.rowIndex

    local function onBoard(c, r)
        return c >= 1 and c <= KC.boardDim and r >= 1 and r <= KC.boardDim
    end

    local function isFree(c, r)
        return onBoard(c, r) and KC.board[c][r].currentPiece == nil
    end

    local function addMove(c, r)
        table.insert(moves, strsub(Square.colLabels, c, c)..r)
    end

    if (self.name == "p") then
        -- Pawns move forward one, or two from their starting rank, if nothing is in the way
        local direction = self.isWhite and 1 or -1
        local startRow = self.isWhite and 2 or (KC.boardDim - 1)

        if isFree(col, row + direction) then
            addMove(col, row + direction)
            if (row == startRow and isFree(col, row + (direction * 2))) then
                addMove(col, row + (direction * 2))
            end
        end
        return moves
    end

    local movement = Piece.Movement[self.name]

    for _, step in ipairs(movement.steps or {}) do
        local c, r = col + step[1], row + step[2]
        if isFree(c, r) then
            addMove(c, r)
        end
    end

    -- Slides stop at the first piece in the way
    for _, slide in ipairs(movement.slides or {}) do
        local c, r = col + slide[1], row + slide[2]
        while isFree(c, r) do
            addMove(c, r)
            c, r = c + slide[1], r + slide[2]
        end
    end

    if (self.name == "k") then
        for _, castle in ipairs(Piece.Castles) do
            if self:CanCastle(castle) then
                addMove(castle.kingToCol, row)
            end
        end
    end

    return moves
end

-- Castling needs an unmoved king on its start square, an unmoved rook of the
-- same colour in the corner, and empty squares between them.
-- TODO - The king may not castle out of, through, or into check
function Piece:CanCastle(castle)
    local square = self.currentSquare
    local homeRow = self.isWhite and 1 or KC.boardDim

    if (self.hasMoved or square.colIndex ~= Piece.KingStartCol or square.rowIndex ~= homeRow) then
        return false
    end

    local rook = KC.board[castle.rookCol][homeRow].currentPiece
    if (rook == nil or rook.name ~= "r" or rook.isWhite ~= self.isWhite or rook.hasMoved) then
        return false
    end

    for _, col in ipairs(castle.between) do
        if (KC.board[col][homeRow].currentPiece ~= nil) then
            return false
        end
    end

    return true
end

-- Position
function Piece:ApplyPosition(position)
    if (position ~= nil) then
        -- Get the board and put ourselves there
        local board = KC:GetBoardPosition(position)
        self:MovePiece(board, false)
    else
        self.frame:Hide()
        KC:Print("Invalid Position for Piece: "..self.key)
    end
end

-- Move a piece, with or without an animation
function Piece:MovePiece(square, animated) 
    -- Put our piece in the center of the square
    if(animated and self.currentSquare ~= nil) then
        local _, _, _, currentX, currentY = self.currentSquare.frame:GetPoint()
        local _, _, _, destX, destY = square.frame:GetPoint()
        local f = self.frame

        -- Move it to the top
        f:SetFrameLevel(Piece:GetBaseLevel() + 2)
    
        -- Animate the piece. The animation group lives on the frame and is reused,
        -- including when the frame is pooled and handed to another piece.
        local ag = f.moveAnimation
        if not ag then
            ag = f:CreateAnimationGroup()
            ag.translation = ag:CreateAnimation("Translation")
            ag.translation:SetDuration(0.1)
            f.moveAnimation = ag
        end

        -- If a previous move is still animating, stopping it runs its OnStop,
        -- which snaps the piece to that move's destination first
        if ag:IsPlaying() then
            ag:Stop()
        end
        ag.translation:SetOffset(destX - currentX, destY - currentY)

        -- When finished (or interrupted), fix it to the destination and reset the level
        local function finish()
            f:SetPoint("CENTER", square.frame, "CENTER")
            f:SetFrameLevel(Piece:GetBaseLevel())
        end
        ag:SetScript("OnFinished", finish)
        ag:SetScript("OnStop", finish)

        -- GO!
        ag:Play()
    else
        self.frame:SetPoint("CENTER", square.frame, "CENTER")
    end

    -- The square we are moving away from - clear its piece assignment
    if(self.currentSquare ~= nil) then
        self.currentSquare.currentPiece = nil
    end

    -- Store our piece inside the square for reverse lookup
    if(square.currentPiece ~= nil) then
        KC:Print("Warning: Piece Already Stored Inside Square Position: "..square.name)
    end
    square.currentPiece = self
    self.currentSquare = square

    -- TODO - Handle Pawn Promotion
end

-- Selection
function Piece:HandleMouseUp()
    if self.frame:IsMouseOver() then
        if(self.selected) then
            KC.game:DeselectPiece()
        else
            KC.game:SelectPiece(self)
        end 
    end
end

function Piece:SetSelected()
    self.frame:SetBackdrop({ bgFile = [[Interface/Buttons/WHITE8X8]] })
    self.frame:SetBackdropColor(0.16, 0.47, 0.04, 0.5)
    self.selected = true
end

function Piece:SetDeselected()
    self.frame:SetBackdrop(nil)        
    self.selected = false
end

---------------------------------------------------------
-- This needs to move to an algorithm class at some point
Piece.SunfishLookup = {
    ['wk'] = "K", 
    ['wq'] = "Q", 
    ['wb'] = "B", 
    ['wn'] = "N", 
    ['wp'] = "P", 
    ['bk'] = "k", 
    ['bq'] = "q", 
    ['bb'] = "b", 
    ['bn'] = "n", 
    ['bp'] = "p", 
}