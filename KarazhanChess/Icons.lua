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
Icons.Board.LightSquare = "\\ls.tga"
Icons.Board.DarkSquare = "\\ds.tga"

function Icons.Board:GetBoardIcon(light) 
    icon = ternary(light == true, Icons.Board.LightSquare, Icons.Board.DarkSquare)
    selectedTheme = Icons.Board.Themes[KC:getBoardTheme()]
    return Icons.Board.Folder..selectedTheme..icon
end

-- 

Icons.Piece = {}
Icons.Piece.Folder = dir("Textures\\Piece\\")
Icons.Piece.Themes = { "Default", "P Test1", "P Test2" }
Icons.Piece.WhiteKing = "\\wk.tga"
Icons.Piece.WhiteQueen = "\\wq.tga"
Icons.Piece.WhiteBishop = "\\wb.tga"
Icons.Piece.WhiteKnight = "\\wn.tga"
Icons.Piece.WhitePawn = "\\wp.tga"
Icons.Piece.BlackKing = "\\bk.tga"
Icons.Piece.BlackQueen = "\\bq.tga"
Icons.Piece.BlackBishop = "\\bb.tga"
Icons.Piece.BlackKnight = "\\bn.tga"
Icons.Piece.BlackPawn = "\\bp.tga"

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