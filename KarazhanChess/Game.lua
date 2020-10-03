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
    KC:ShowValidMoves
	
end

function KC:ShowValidMoves(piece)

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