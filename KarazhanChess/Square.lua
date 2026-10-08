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
-- From/to of the last move: the gold of the window's title and labels (WoW's
-- NORMAL_FONT_COLOR) at Lichess's last-move alpha
Square.LastMoveColour = { NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.41 }

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
    self.parent = frame
    self.size = size
    self:UpdatePosition()

    -- Rank and file labels. Every square has both; only those on the displayed
    -- left and bottom edges are shown (see Square:UpdateLabels), so they follow a flip.
    self.rankLabel = FrameUtils:CreateBoardLabel(self, self.frame, true)
    self.fileLabel = FrameUtils:CreateBoardLabel(self, self.frame, false)

    -- Square tints, drawn above the square texture (sublevel 0) and below the labels
    -- and markers, in this order: last move, selected, hover.

    -- Last move highlight (Lichess style): tints the from and to squares of the last move
    self.lastMoveHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 1)
    self.lastMoveHighlight:SetAllPoints()
    FrameUtils:DisablePixelSnapping(self.lastMoveHighlight)
    self.lastMoveHighlight:SetColorTexture(unpack(Square.LastMoveColour))
    self.lastMoveHighlight:Hide()

    -- Selection highlight (Lichess style): tints the square of the selected piece
    self.selectedHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 2)
    self.selectedHighlight:SetAllPoints()
    FrameUtils:DisablePixelSnapping(self.selectedHighlight)
    self.selectedHighlight:SetColorTexture(20/255, 85/255, 30/255, 0.5)
    self.selectedHighlight:Hide()

    -- Hover highlight (Lichess style): tints a destination square under the cursor,
    -- replacing its dot / capture corners. Driven by KC:UpdateHoverSquare.
    self.hoverHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 3)
    self.hoverHighlight:SetAllPoints()
    FrameUtils:DisablePixelSnapping(self.hoverHighlight)
    self.hoverHighlight:SetColorTexture(unpack(Square.HoverColour))
    self.hoverHighlight:Hide()

    -- Check highlight (Lichess style): a red glow under a king in check
    self.checkHighlight = self.frame:CreateTexture(nil, "ARTWORK", nil, 4)
    self.checkHighlight:SetAllPoints()
    FrameUtils:DisablePixelSnapping(self.checkHighlight)
    self.checkHighlight:SetTexture(Icons.Check)
    self.checkHighlight:Hide()

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

-- Places the square on the board, mirrored when the board is flipped (black at the bottom).
-- Pieces, markers and labels are anchored to the square, so they move with it.
function Square:UpdatePosition()
    local col, row = KC:GetDisplayPosition(self.colIndex, self.rowIndex)
    local xpos = KC.frameMargin + ((col - 1) * self.size)
    local ypos = Square.yOffset + KC.boardHeight - (row * self.size)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", xpos, -ypos)
end

-- Shows the rank label on the displayed left edge and the file label on the bottom edge
function Square:UpdateLabels(visible)
    local col, row = KC:GetDisplayPosition(self.colIndex, self.rowIndex)
    self.rankLabel:SetShown(visible and col == 1)
    self.fileLabel:SetShown(visible and row == 1)
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

-- Last move highlight
function Square:SetLastMove(shown)
    self.lastMoveHighlight:SetShown(shown)
end

-- Check highlight
function Square:SetCheck(shown)
    self.checkHighlight:SetShown(shown)
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