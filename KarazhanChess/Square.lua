-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Board Square Handling
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local FrameUtils, Icons = ns.FrameUtils, ns.Icons

local Square = {}
ns.Square = Square
Square.__index = Square;
Square.colLabels = 'abcdefgh'
Square.yOffset = 50

-- Frame levels above KC.boardFrame: squares, then move markers, then pieces (Piece.SubLayer)
Square.SquareLevel = 1
Square.MarkerLevel = 2

-- Constructor
function Square:new(frame, size, colIndex, rowIndex, lightSquare)
    -- Metatable
    local self = {};
    setmetatable(self, Square);

    -- Variables
    self.boardIcon = Icons.Board:GetBoardIcon(lightSquare)
    self.colLabel = strsub(Square.colLabels, colIndex, colIndex)
    self.name = self.colLabel..rowIndex
    self.colIndex = colIndex
    self.rowLabel = ""..rowIndex
    self.rowIndex = rowIndex
    self.lightSquare = lightSquare
    self.currentPiece = nil

    -- Create the icon
    self.frame = FrameUtils:CreateIcon(size, size, self.boardIcon, "ARTWORK")
    self.frame:SetFrameLevel(KC.boardFrame:GetFrameLevel() + Square.SquareLevel)

    -- Position
    local xpos = KC.frameMargin + ((self.colIndex - 1) * size)
    local ypos = Square.yOffset + KC.boardHeight - (self.rowIndex * size)
    self.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", xpos, -ypos)

    -- Selection highlight (Lichess style): tints the square of the selected piece.
    -- Drawn just above the square texture, below the labels and markers.
    self.selectedHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 1)
    self.selectedHighlight:SetAllPoints()
    self.selectedHighlight:SetColorTexture(20/255, 85/255, 30/255, 0.5)
    self.selectedHighlight:Hide()

    -- Give it a Legal Move indicator
    self.legalMove = FrameUtils:CreateIcon(size/3, size/3, Icons.LegalMove, "ARTWORK")
    self.legalMove:SetPoint("CENTER", self.frame, "CENTER")
    self.legalMove:SetFrameLevel(KC.boardFrame:GetFrameLevel() + Square.MarkerLevel)
    self.legalMove:EnableMouse(false) -- Let clicks through to the square
    self.legalMove:Hide()

    -- Give it a Legal Capture indicator
    self.legalCapture = FrameUtils:CreateIcon(size, size, Icons.LegalCapture, "ARTWORK")
    self.legalCapture:SetPoint("CENTER", self.frame, "CENTER")
    self.legalCapture:SetFrameLevel(KC.boardFrame:GetFrameLevel() + Square.MarkerLevel)
    self.legalCapture:EnableMouse(false)
    self.legalCapture:Hide()

    -- Callbacks
    self.frame:SetScript("OnMouseUp", function() KC.game:HandleBoardSquareClicked(self) end)   
    
    -- Done!
    return self;
end

-- Texture update
function Square:UpdateTexture() 
    local texture = Icons.Board:GetBoardIcon(self.lightSquare)
    self.frame.texture:SetTexture(texture)
end

-- Selection highlight
function Square:ShowSelected()
    self.selectedHighlight:Show()
end

function Square:ClearSelected()
    self.selectedHighlight:Hide()
end

-- Legal Move
function Square:IsLegalMove()
    return self.legalMove:IsShown()
end

function Square:ShowAsLegalMove() 
    self.legalMove:Show()
end

function Square:ClearLegalMove() 
    self.legalMove:Hide()
end

-- Legal Capture
function Square:IsLegalCapture() 
    return self.legalCapture:IsShown()
end

function Square:ShowAsLegalCapture() 
    self.legalCapture:Show()
end

function Square:ClearLegalCapture() 
    self.legalCapture:Hide()
end