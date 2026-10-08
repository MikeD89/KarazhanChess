-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Piece Handling
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Icons, Rules = ns.FrameUtils, ns.Icons, ns.Rules

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
    self.frame:SetScript("OnMouseDown", function(_, button) self:HandleMouseDown(button) end)
    self.frame:SetScript("OnMouseUp", function(_, button) self:HandleMouseUp(button) end)
    self.frame:SetScript("OnHide", function() self:CancelDrag() end)

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
-- Returns two lists of positions like "e4": the squares this piece can legally
-- move to, and the squares holding enemy pieces it can capture. The rules engine
-- works out legality (pins, check, castling through check, en passant) from a
-- snapshot of the board. An en passant capture lands on an empty square, so it
-- shows as a move dot, as on Lichess. Kings are never capturable.
function Piece:CalculateMoves()
    local moves, captures = {}, {}
    if (self.currentSquare == nil) then
        return moves, captures
    end

    local colour = self.isWhite and "w" or "b"
    local pos = KC.game:GetPosition(colour)
    local from = Rules.Index(self.currentSquare.colIndex, self.currentSquare.rowIndex)

    -- Promotions give four moves to the same square, so only list each square once
    local seen = {}
    for _, move in ipairs(Rules.GenerateLegalMoves(pos, colour, from)) do
        local name = Rules.SquareName(move.to)
        if not seen[name] then
            seen[name] = true
            if (move.captured and move.flag ~= "ep") then
                table.insert(captures, name)
            else
                table.insert(moves, name)
            end
        end
    end

    return moves, captures
end

-- This piece as a rules engine letter: upper case for white ("N"), lower for black
function Piece:GetLetter()
    return self.isWhite and string.upper(self.name) or self.name
end

-- Promotion
-- The rank a pawn of this colour promotes on
function Piece:GetPromotionRow()
    return self.isWhite and KC.boardDim or 1
end

-- Turns this piece (a pawn) into another type in place, keeping its square,
-- frame and place in the game's piece list
function Piece:PromoteTo(name)
    local data = Piece.Data[name]
    self.name = data[1]
    self.points = data[2]
    self.key = self.prefix..self.name
    self.hasMoved = true
    self:UpdateTexture()
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
-- Mouse handling: pressing a piece selects it (showing its moves). Moving the mouse
-- more than DragThreshold pixels while held turns the press into a drag; releasing
-- without dragging is a click, which deselects a piece that was already selected.
Piece.DragThreshold = 4

function Piece:HandleMouseDown(button)
    if (button ~= "LeftButton") then
        return
    end

    self.wasSelected = self.selected
    if not self.selected then
        KC.game:SelectPiece(self)

        -- Selecting can capture this piece instead (another piece was selected)
        if (KC.game.selectedPiece ~= self) then
            return
        end
    end

    -- Watch for the mouse moving far enough to start a drag
    local startX, startY = GetCursorPosition()
    self.pressed = true
    self.dragging = false
    self.frame:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        if not self.dragging then
            if math.abs(x - startX) + math.abs(y - startY) < Piece.DragThreshold then
                return
            end
            self.dragging = true
            self.frame:SetFrameLevel(Piece:GetBaseLevel() + 2)
        end

        -- Follow the cursor (cursor position is in screen pixels)
        local scale = self.frame:GetEffectiveScale()
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)
end

function Piece:HandleMouseUp(button)
    if (button ~= "LeftButton" or not self.pressed) then
        return
    end
    self.pressed = false
    self.frame:SetScript("OnUpdate", nil)

    if self.dragging then
        self.dragging = false
        self.frame:SetFrameLevel(Piece:GetBaseLevel())

        -- Drop onto the square under the cursor if it's a legal move, otherwise snap back
        local square = KC:GetSquareUnderCursor()
        if not (square and KC.game:HandleBoardSquareClicked(square, false)) then
            self:SnapBack()
        end
    elseif self.wasSelected and self.frame:IsMouseOver() then
        -- A plain click on the already-selected piece deselects it
        KC.game:DeselectPiece()
    end
end

-- Stops any press or drag in progress and puts the piece back on its square,
-- e.g. when the window is closed mid-drag and the mouse-up never arrives
function Piece:CancelDrag()
    self.frame:SetScript("OnUpdate", nil)
    if self.dragging and self.currentSquare then
        self.frame:SetFrameLevel(Piece:GetBaseLevel())
        self:SnapBack()
    end
    self.pressed = false
    self.dragging = false
end

-- Returns a dragged piece to its square
function Piece:SnapBack()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", self.currentSquare.frame, "CENTER")
end

-- Selection is shown by highlighting the piece's square (Lichess style), so the
-- highlight stays on the origin square while the piece is dragged. The square is
-- remembered because the piece has already moved by the time it's deselected.
function Piece:SetSelected()
    self.highlightedSquare = self.currentSquare
    if self.highlightedSquare then
        self.highlightedSquare:ShowSelected()
    end
    self.selected = true
end

function Piece:SetDeselected()
    if self.highlightedSquare then
        self.highlightedSquare:ClearSelected()
        self.highlightedSquare = nil
    end
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