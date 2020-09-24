-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Icon Constants
-------------------------------------------------------------------------------

Icons = {}

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
Icons.Piece.Themes = { "Default" }
Icons.Piece.WhiteKing = "\\wk.blp"
Icons.Piece.WhiteQueen = "\\wq.blp"
Icons.Piece.WhiteBishop = "\\wb.blp"
Icons.Piece.WhiteKnight = "\\wn.blp"
Icons.Piece.WhitePawn = "\\wp.blp"
Icons.Piece.BlackKing = "\\bk.blp"
Icons.Piece.BlackQueen = "\\bq.blp"
Icons.Piece.BlackBishop = "\\bb.blp"
Icons.Piece.BlackKnight = "\\bn.blp"
Icons.Piece.BlackPawn = "\\bp.blp"

function Icons.Piece:GetPieceIcon(piece) 
    selectedTheme = Icons.Piece.Themes[KC:getPieceTheme()]
    return Icons.Piece.Folder..selectedTheme..piece
end

-- 

Icons.Piece.Lookup = {
    ['wk'] = {"K", Icons.Piece.WhiteKing},
    ['wq'] = {"Q", Icons.Piece.WhiteQueen},
    ['wb'] = {"B", Icons.Piece.WhiteBishop},
    ['wn'] = {"N", Icons.Piece.WhiteKnight},
    ['wp'] = {"P", Icons.Piece.WhitePawn},
    ['bk'] = {"k", Icons.Piece.BlackKing},
    ['bq'] = {"q", Icons.Piece.BlackQueen},
    ['bb'] = {"b", Icons.Piece.BlackBishop},
    ['bn'] = {"n", Icons.Piece.BlackKnight},
    ['bp'] = {"p", Icons.Piece.BlackPawn},
}