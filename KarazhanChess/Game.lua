-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Gameplay Logic
-------------------------------------------------------------------------------

-- Game variables
KC.selectedPiece = nil

-- Piece Selection
function KC:SelectPiece(piece)
    if(KC.selectedPiece ~= nil) then
        KC:DeselectPiece()
    end

    -- This is definately a selection, so render it and update the board
    KC.selectedPiece = piece
    KC.selectedPiece:SetSelected()
    KC:ShowValidMoves()	
end

function KC:DeselectPiece()
    if(KC.selectedPiece == nil) then
        return
    end

    -- Handle cleaning up the board
    KC.selectedPiece:SetDeselected()
    KC.selectedPiece = nil
    KC:clearLegalMoves()
end

-- Move calculation
function KC:ShowValidMoves()
    -- Calculate valid moves
    validMoves = {"a1", "b2", "c3", "d4", "e5", "f6", "g7", "h8" }

    -- Display them all
    for i,move in ipairs(validMoves) do
        KC:GetBoardPosition(move):ShowAsLegalMove()
    end
end

-- Board selection
function KC:BoardSquareSelected(square)
    -- KC:P(square.IsLegalMove())
    -- Check this is legit.
    -- if (board:IsLegalMove() == false) then
    --     return 
    -- end

    -- TODO - Captures and stuff

    -- Update the piece 
    -- KC.selectedPiece:
end