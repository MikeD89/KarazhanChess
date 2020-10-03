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
    self.selected = false

    -- Pieces have to exist inside a frame
    -- TODO - We CANNOT remove frames. Therefore we should move these frames to be "piece holders" for the board
    --        And get this class to "load" pieces into the board, NOT create the frames on the fly
	self.frame = CreateFrame("FRAME", nil, KC.frame)
	self.frame:SetWidth(KC.boardSectionSize)
	self.frame:SetHeight(KC.boardSectionSize)
    self.frame:EnableMouse(true)
	
    -- And with a texture
	self.texture = self.frame:CreateTexture(nil, "OVERLAY", nil, Piece.SubLayer)
    self.texture:SetTexture(self.icon)
    self.texture:SetAllPoints()
    self.texture:SetBlendMode("BLEND")

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
	self.texture:SetTexture(self.icon)
end

-- Position 
function Piece:ApplyPosition(position) 
    if (position ~= nil) then
        local col = strsub(position, 1, 1)
        local row = strsub(position, 2, 2)
        self.frame:SetPoint("CENTER", KC.board[ord(col)][tonumber(row)], "CENTER")
    else
        self.texture:Hide()
        KC:Print("Invalid Position for Piece: "..position)
    end
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