-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Piece Handling
-------------------------------------------------------------------------------

Piece = {}
Piece.__index = Piece;
Piece.SubLayer = 4

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

    -- Pieces have to exist inside a frame
	self.frame = CreateFrame("FRAME", nil, KC.frame)
	self.frame:SetWidth(KC.boardSectionSize)
	self.frame:SetHeight(KC.boardSectionSize)
    self.frame:EnableMouse(true)
	
    -- And with a texture
	self.texture = self.frame:CreateTexture(nil, "OVERLAY", nil, Piece.SubLayer)
    self.texture:SetTexture(self.icon)
    self.texture:SetAllPoints()
    self.texture:SetBlendMode("BLEND")

	-- Make it move!
	self.frame:SetScript("OnMouseDown", function() 
		self.frame:SetMovable(true)
		self.frame:StartMoving()  
	end) 

	-- and make it stop
	self.frame:SetScript("OnMouseUp", function()
		self.frame:StopMovingOrSizing()
		self.frame:SetMovable(false)
	end)    

    -- Position initialisation
    if (position ~= nil) then
        self:ApplyPosition(position)
    else
        self.texture:Hide()
    end

    -- Done!
    return self;
end

function Piece:__tostring()
    return "Piece - "..self:getLookupKey()
end

-- Interface
function Piece:UpdateTexture(position) 
    self.icon = Icons.Piece:GetPieceIcon(self.key)
	self.texture:SetTexture(self.icon)
end

-- Position 
function Piece:ApplyPosition(position) 
    -- TODO validation
    if (position ~= nil) then
        local col = strsub(position, 1, 1)
        local row = strsub(position, 2, 2)
        self.frame:SetPoint("CENTER", KC.board[ord(col)][tonumber(row)], "CENTER")
    else
        self.texture:Hide()
    end
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