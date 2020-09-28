-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Piece Handling
-------------------------------------------------------------------------------

Piece = {}
Piece.__index = Piece;

Piece.data = {
    ["king"] = {"k", 0},
    ["queen"] = {"q", 9},
    ["rook"] = {"r", 5},
    ["knight"] = {"n", 3},
    ["bishop"] = {"b", 3},
    ["pawn"] = {"p", 1},
};

-- Constructor
function Piece:new(data, isWhite)
    -- Metatable
    local self = {};
    setmetatable(self, Piece);

    -- Variables
    self.data = data;
    self.name = data[1];
    self.points = data[2];
    self.isWhite = isWhite;
    self.prefix = (self.isWhite) ? "w" : "b";
    self.key = self.prefix..self.name;
    return self;
end

-- To String
function Piece:__tostring()
    return "Piece - "..self:getLookupKey()
end

-- Update Functions
function Piece:UpdateTexture() 
    icon = Icons.Board:GetPieceIcon(self.TextureLookup[self.key])
    -- texture:SetTexture(icon)
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