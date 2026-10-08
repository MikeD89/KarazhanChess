-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Icon Constants
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local dir, ternary = ns.dir, ns.ternary

local Icons = {}
ns.Icons = Icons
Icons.MiniMap = dir("Textures\\minimap")
Icons.LegalMove = dir("Textures\\legalmove")
Icons.LegalCapture = dir("Textures\\legalcapture")
Icons.Check = dir("Textures\\check")

--

-- Themes are saved by name, which is also the texture folder name. The Themes
-- list only sets the order shown in the options dropdown.
-- LegacyThemes is the list from before themes were saved by name, used to
-- convert old index-based settings (see KC:migrateThemeSettings).

-- Builds the { [name] = name } table AceConfig needs for a select's values
local function themeValues(themes)
    local values = {}
    for _, name in ipairs(themes) do
        values[name] = name
    end
    return values
end

Icons.Board = {}
Icons.Board.Folder = dir("Textures\\Board\\")
Icons.Board.Themes = { "Default", "Horde", "Alliance", "Brown", "Blue", "Green", "Purple", "Khaki" }
Icons.Board.ThemeValues = themeValues(Icons.Board.Themes)
Icons.Board.LegacyThemes = { "Default", "Bubblegum" }
Icons.Board.LightSquare = "\\ls.blp"
Icons.Board.DarkSquare = "\\ds.blp"

function Icons.Board:GetBoardIcon(light)
    local icon = ternary(light == true, Icons.Board.LightSquare, Icons.Board.DarkSquare)
    return Icons.Board.Folder..KC:getBoardTheme()..icon
end

--

Icons.Piece = {}
Icons.Piece.Folder = dir("Textures\\Piece\\")
Icons.Piece.Themes = { "Default", "Merida", "Chessnut", "Fantasy", "Celtic", "Spatial", "RhosGFX", "Papercut" }
Icons.Piece.ThemeValues = themeValues(Icons.Piece.Themes)
Icons.Piece.LegacyThemes = { "Default", "Tournament" }

function Icons.Piece:GetPieceIcon(piece)
    return Icons.Piece.Folder..KC:getPieceTheme().."\\"..piece..".blp"
end

-- 
