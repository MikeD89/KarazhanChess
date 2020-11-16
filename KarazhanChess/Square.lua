-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Board Square Handling
-------------------------------------------------------------------------------

Square = {}
Square.__index = Square;
Square.colLabels = 'abcdefgh'
Square.yOffset = 50

-- Constructor
function Square:new(frame, size, colIndex, rowIndex, lightSquare)
    -- Metatable
    local self = {};
    setmetatable(self, Square);

    -- Locals
    local size = KC.boardSectionSize

    -- Variables
    self.boardIcon = Icons.Board:GetBoardIcon(lightSquare)
    self.colLabel = strsub(Square.colLabels, colIndex, colIndex)
    self.name = self.colLabel..colIndex
    self.colIndex = colIndex
    self.rowLabel = ""..rowIndex
    self.rowIndex = rowIndex
    self.lightSquare = lightSquare
    self.piece = nil

    -- Create the icon
    self.frame = FrameUtils:CreateIcon(size, size, self.boardIcon, "ARTWORK", name)
    self.frame:SetAlpha(KC.boardAlpha)

    -- Position
    local xpos = KC.frameMargin + ((self.colIndex - 1) * size)
    local ypos = Square.yOffset + KC.boardHeight - (self.rowIndex * size)
    self.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", xpos, -ypos)

    -- Give it a Legal Move indicator
    self.legalMove = FrameUtils:CreateIcon(size/3, size/3, Icons.LegalMove, "ARTWORK", self.name.."_lmi")
    self.legalMove:SetPoint("CENTER", self.frame, "CENTER")
    self.legalMove:Hide()

    -- Give it a Legal Capture indicator
    self.legalCapture = FrameUtils:CreateIcon(size, size, Icons.LegalCapture, "ARTWORK", self.name.."_lci")
    self.legalCapture:SetPoint("CENTER", self.frame, "CENTER")
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