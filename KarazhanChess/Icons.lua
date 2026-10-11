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
Icons.Piece.Themes = { "Default", "Karazhan", "Merida", "Chessnut", "Fantasy", "Celtic", "Spatial", "RhosGFX", "Papercut" }
Icons.Piece.ThemeValues = themeValues(Icons.Piece.Themes)
Icons.Piece.LegacyThemes = { "Default", "Tournament" }

function Icons.Piece:GetPieceIcon(piece)
    return Icons.Piece.Folder..KC:getPieceTheme().."\\"..piece..".blp"
end

-- Model themes draw each piece as a creature model from the game itself instead
-- of a texture, so they have no texture folder. Karazhan uses the pieces of
-- Medivh's chess event: the Alliance plays white and the Horde black. Per piece:
-- display = creature display ID (the NPC in brackets), distance = camera distance
-- scale (above 1 shows the model smaller, so pawns stand shorter than the king).
Icons.Piece.Models = {
    Karazhan = {
        wk = { display = 16293, distance = 1.0 },  -- King Llane
        wq = { display = 16280, distance = 1.05 }, -- Human Conjurer
        wb = { display = 16278, distance = 1.1 },  -- Human Cleric
        wn = { display = 19783, distance = 1.1 },  -- Human Charger
        wr = { display = 5564,  distance = 1.1 },  -- Conjured Water Elemental
        wp = { display = 16276, distance = 1.3 },  -- Human Footman
        bk = { display = 16270, distance = 1.0 },  -- Warchief Blackhand
        bq = { display = 16263, distance = 1.05 }, -- Orc Warlock
        bb = { display = 16267, distance = 1.1 },  -- Orc Necrolyte
        bn = { display = 2352,  distance = 1.1 },  -- Orc Wolf
        br = { display = 16269, distance = 1.1 },  -- Summoned Daemon
        bp = { display = 16264, distance = 1.3 },  -- Orc Grunt
    },
}

-- Models face the viewer, turned a little so the two sides face each other
-- (radians, white turned one way and black the other)
Icons.Piece.ModelFacing = 0.4

-- The animation models play: 0 is the idle stand
local standAnimation = 0

function Icons.Piece:IsModelTheme()
    return Icons.Piece.Models[KC:getPieceTheme()] ~= nil
end

-- Points the model at its piece. Runs again once the model has loaded, since
-- loading resets the camera and animation.
local function setupModel(model)
    local spec = model.spec
    if not spec then
        return
    end
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(spec.distance or 1)
    model:SetPosition(0, 0, 0)
    model:SetFacing(model.isWhite and -Icons.Piece.ModelFacing or Icons.Piece.ModelFacing)
    local animated = KC:getPieceAnimation()
    if animated or not model.FreezeAnimation then
        model:SetAnimation(standAnimation)
        if model.SetPaused then
            model:SetPaused(not animated)
        end
    else
        -- The first frame of the stand: a still pose that is the same every time
        model:SetPaused(false)
        model:FreezeAnimation(standAnimation, 0, 0)
    end
end

-- Draws piece key (like "wk") on holder: on texture for texture themes, or on a
-- model filling holder (created the first time) for model themes. Used by the
-- pieces and the promotion picker.
function Icons.Piece:ApplyArt(holder, texture, key)
    local models = Icons.Piece.Models[KC:getPieceTheme()]
    if not models then
        if holder.pieceModel then
            holder.pieceModel:Hide()
        end
        texture:SetTexture(Icons.Piece:GetPieceIcon(key))
        return
    end

    texture:SetTexture(nil)
    local model = holder.pieceModel
    if not model then
        -- Mouse stays off, so clicks reach the piece or button underneath
        model = CreateFrame("PlayerModel", nil, holder)
        model:SetAllPoints()
        model:SetScript("OnModelLoaded", setupModel)
        holder.pieceModel = model
    end

    local spec = models[key]
    model.isWhite = string.sub(key, 1, 1) == "w"
    if model.spec ~= spec then
        model.spec = spec
        model:SetDisplayInfo(spec.display)
    end
    setupModel(model)
    model:Show()
end

-- Hides a model ApplyArt put on holder (for frames going back to the pool)
function Icons.Piece:ClearArt(holder)
    local model = holder.pieceModel
    if model then
        model:Hide()
        model:ClearModel()
        model.spec = nil
    end
end

-- 
