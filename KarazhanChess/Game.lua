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
        -- TODO - Check for captures
        -- TODO - check for matching colours
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
    KC:clearLegalMovesAndCaptures()
end

-- Move calculation
function KC:ShowValidMoves()
    -- Calculate valid moves
    validMoves = {"a1", "a2", "c3", "c4", "e5", "e6", "g7", "g8" }
    validCaptures = {"b2", "b3", "d4", "d5", "f6", "f7", "h8", "h1" }

    -- Display them all
    for i,move in ipairs(validMoves) do
        KC:GetBoardPosition(move):ShowAsLegalMove()
    end
    for i,capture in ipairs(validCaptures) do
        KC:GetBoardPosition(capture):ShowAsLegalCapture()
    end
end

-- Board selection
function KC:HandleBoardSquareClicked(square)
    -- Nothign to do if no piece selected
    if(KC.selectedPiece == nil) then
        return
    end

    -- Is this a legit move?
    if (square:IsLegalMove() == false) then
        return 
    end

    -- TODO - Captures and stuff

    -- Update the piece visually
    KC.selectedPiece:MovePiece(square)
    KC:DeselectPiece()
end