-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Piece Handling
-------------------------------------------------------------------------------

Piece = {}
Piece.__index = Piece;
Piece.SubLayer = 4

-- (1: Abbreviation) (2: Point Value)
Piece.Data = {
    ["king"] = {"k", 0},
    ["queen"] = {"q", 9},
    ["rook"] = {"r", 5},
    ["knight"] = {"n", 3},
    ["bishop"] = {"b", 3},
    ["pawn"] = {"p", 1},
};


-- Constructor
function Piece:new(name, isWhite, position)
    -- Metatable
    local self = {};
    local data = Piece.Data[name];
    setmetatable(self, Piece);

    -- Variables
    self.name = data[1];
    self.points = data[2];
    self.isWhite = isWhite;
    self.prefix = self.isWhite and "w" or "b";
    self.key = self.prefix..self.name;
    self.icon = Icons.Piece:GetPieceIcon(self.key)
    self.selected = false

    -- Pieces have to exist inside a frame
    -- TODO - We CANNOT remove frames. Therefore we should move these frames to be "piece holders" for the board
    --        And get this class to "load" pieces into the board, NOT create the frames on the fly
    self.frame = FrameUtils:CreateIcon(KC.boardSectionSize, KC.boardSectionSize, self.icon, "OVERLAY", self.key)
    self.frame:SetFrameLevel(Piece.SubLayer)

    -- TODO: Dragging and Dropping. 
    -- self.frame:SetScript("OnMouseDown", self.HandleMouseDown)
    self.frame:SetScript("OnMouseUp", function() self:HandleMouseUp() end)    
    
    -- Position initialisation
    self:ApplyPosition(position)

    -- Done!
    return self;
end

function Piece:__tostring()
    return "Piece - "..self:getLookupKey()
end

-- Interface
function Piece:UpdateTexture(position) 
    self.icon = Icons.Piece:GetPieceIcon(self.key)
	self.frame.texture:SetTexture(self.icon)
end

-- Position 
function Piece:ApplyPosition(position) 
    if (position ~= nil) then
        -- Get the board and put ourselves there
        local board = KC:GetBoardPosition(position)
        self:MovePiece(board)
    else
        self.frame:Hide()
        KC:Print("Invalid Position for Piece: "..position)
    end
end

function Piece:MovePiece(board) 
    -- Put our piece in the center of the board
    self.frame:SetPoint("CENTER", board, "CENTER")

    -- Store our piece inside the board for reverse lookup
    if(board.piece ~= nil) then
        KC:Print("Overwriting Piece Stored Inside Board Position: "..position)
    end
    board.piece = self
end

-- Selection
function Piece:HandleMouseUp()
    if MouseIsOver(self.frame) then
        if(self.selected) then
            KC:DeselectPiece()
        else
            KC:SelectPiece(self)
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