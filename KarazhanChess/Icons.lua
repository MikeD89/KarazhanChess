-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Icon Constants
-------------------------------------------------------------------------------

Icons = {}
Icons.MiniMap = dir("Textures\\minimap")
Icons.LegalMove = dir("Textures\\legalmove")
Icons.LegalCapture = dir("Textures\\legalcapture")

--

Icons.Board = {}
Icons.Board.Folder = dir("Textures\\Board\\")
Icons.Board.Themes = { "Default", "Bubblegum" }
Icons.Board.LightSquare = "\\ls.blp"
Icons.Board.DarkSquare = "\\ds.blp"

function Icons.Board:GetBoardIcon(light) 
    icon = ternary(light == true, Icons.Board.LightSquare, Icons.Board.DarkSquare)
    selectedTheme = Icons.Board.Themes[KC:getBoardTheme()]
    return Icons.Board.Folder..selectedTheme..icon
end

-- 

Icons.Piece = {}
Icons.Piece.Folder = dir("Textures\\Piece\\")
Icons.Piece.Themes = { "Default", "Tournament" }

function Icons.Piece:GetPieceIcon(piece) 
    selectedTheme = Icons.Piece.Themes[KC:getPieceTheme()]
    return Icons.Piece.Folder..selectedTheme.."\\"..piece..".blp"
end

-- 
