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

-- Indicator colours as r, g, b, a. Lichess (chessground) colours, with the alpha
-- raised from Lichess's (0.5 / 0.3 / 0.3) as those read too faint in game.
Square.MoveColour = { 20/255, 85/255, 30/255, 0.75 }  -- move-dest dot
Square.CaptureColour = { 20/255, 85/255, 0, 0.6 }     -- capture corners
Square.HoverColour = { 20/255, 85/255, 30/255, 0.5 }  -- destination under the cursor

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
    FrameUtils:DisablePixelSnapping(self.selectedHighlight)
    self.selectedHighlight:SetColorTexture(20/255, 85/255, 30/255, 0.5)
    self.selectedHighlight:Hide()

    -- Hover highlight (Lichess style): tints a destination square under the cursor,
    -- replacing its dot / capture corners. Driven by KC:UpdateHoverSquare.
    self.hoverHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 2)
    self.hoverHighlight:SetAllPoints()
    FrameUtils:DisablePixelSnapping(self.hoverHighlight)
    self.hoverHighlight:SetColorTexture(unpack(Square.HoverColour))
    self.hoverHighlight:Hide()

    -- Legal move indicator: a dot in the centre of the square (white texture, tinted)
    self.legalMove = FrameUtils:CreateIcon(size, size, Icons.LegalMove, "ARTWORK")
    self.legalMove:SetPoint("CENTER", self.frame, "CENTER")
    self.legalMove:SetFrameLevel(KC.boardFrame:GetFrameLevel() + Square.MarkerLevel)
    self.legalMove:EnableMouse(false) -- Let clicks through to the square
    self.legalMove.texture:SetVertexColor(unpack(Square.MoveColour))
    self.legalMove:Hide()

    -- Legal capture indicator: corners tinted around the target piece (white texture, tinted)
    self.legalCapture = FrameUtils:CreateIcon(size, size, Icons.LegalCapture, "ARTWORK")
    self.legalCapture:SetPoint("CENTER", self.frame, "CENTER")
    self.legalCapture:SetFrameLevel(KC.boardFrame:GetFrameLevel() + Square.MarkerLevel)
    self.legalCapture:EnableMouse(false)
    self.legalCapture.texture:SetVertexColor(unpack(Square.CaptureColour))
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

-- Hover highlight. The markers are faded out rather than hidden, as their
-- visibility is what marks the square as a legal move / capture.
function Square:SetHovered(hovered)
    self.hoverHighlight:SetShown(hovered)
    local markerAlpha = hovered and 0 or 1
    self.legalMove:SetAlpha(markerAlpha)
    self.legalCapture:SetAlpha(markerAlpha)
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