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
    ["k"] = {"k", 0},
    ["q"] = {"q", 9},
    ["r"] = {"r", 5},
    ["n"] = {"n", 3},
    ["b"] = {"b", 3},
    ["p"] = {"p", 1},
};


-- Constructor
function Piece:new(name, isWhite, startingPosition)
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
    self.currentSquare = nil
    self.startingPosition = startingPosition

    -- Pieces have to exist inside a frame
    self.frame = FrameUtils:CreateIcon(KC.boardSectionSize, KC.boardSectionSize, self.icon, "OVERLAY", self.key)
    self.frame:SetFrameLevel(Piece.SubLayer)

    -- Give it a starting position
    self:ApplyPosition(self.startingPosition)

    -- Handle click 
    self.frame:SetScript("OnMouseUp", function() self:HandleMouseUp() end)    

    -- Hide by defauly
    -- self.frame:Hide()
    
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

-- Reset position
function Piece:ResetPosition()
    self.ApplyPosition(self.startingPosition)
end 

-- String method
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

function Piece:MovePiece(square) 
    -- Put our piece in the center of the square
    self.frame:SetPoint("CENTER", square, "CENTER")

    -- The square we are moving away from - clear its piece assignment
    if(self.currentSquare ~= nil) then
        self.currentSquare.piece = nil
    end

    -- Store our piece inside the square for reverse lookup
    if(square.piece ~= nil) then
        KC:Print("Overwriting Piece Stored Inside Square Position: "..square.fullLabel)
    end
    square.piece = self
    self.currentSquare = square
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