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
-- scale (1 fits the whole model to the square; above 1 shows it smaller, so pawns
-- stand shorter than the king).
-- WoW Forever's client data only has the original game's creatures, so most of
-- the event's pieces (added in The Burning Crusade) don't exist there and it gets
-- stand-ins of the same kind. Only the water elemental and the wolf are shared.
local isForever = select(4, GetBuildInfo()) < 20000

Icons.Piece.Models = {
    Karazhan = isForever and {
        wk = { display = 5566,  distance = 0.8 },  -- Highlord Bolvar Fordragon
        wq = { display = 2968,  distance = 0.85 }, -- Archmage Malin
        wb = { display = 5072,  distance = 0.85 }, -- Archbishop Benedictus
        wn = { display = 2410,  distance = 0.85 }, -- White Stallion
        wr = { display = 5564,  distance = 0.85 }, -- Conjured Water Elemental
        wp = { display = 5446,  distance = 0.95 }, -- Stormwind City Guard
        bk = { display = 9778,  distance = 0.8 },  -- Warchief Rend Blackhand
        bq = { display = 1326,  distance = 0.85 }, -- Zevrost (Orgrimmar warlock)
        bb = { display = 6039,  distance = 0.85 }, -- Blackrock Shadowcaster
        bn = { display = 2352,  distance = 0.85 }, -- Orc Wolf
        br = { display = 1912,  distance = 0.85 }, -- Doomguard
        bp = { display = 4260,  distance = 0.95 }, -- Orgrimmar Grunt
    } or {
        wk = { display = 16293, distance = 0.8 },  -- King Llane
        wq = { display = 16280, distance = 0.85 }, -- Human Conjurer
        wb = { display = 16278, distance = 0.85 }, -- Human Cleric
        wn = { display = 19783, distance = 0.85 }, -- Human Charger
        wr = { display = 5564,  distance = 0.85 }, -- Conjured Water Elemental
        wp = { display = 16276, distance = 0.95 }, -- Human Footman
        bk = { display = 16270, distance = 0.8 },  -- Warchief Blackhand
        bq = { display = 16263, distance = 0.85 }, -- Orc Warlock
        bb = { display = 16267, distance = 0.85 }, -- Orc Necrolyte
        bn = { display = 2352,  distance = 0.85 }, -- Orc Wolf
        br = { display = 16269, distance = 0.85 }, -- Summoned Daemon
        bp = { display = 16264, distance = 0.95 }, -- Orc Grunt
    },
}

-- Models face the viewer, turned a little so the two sides face each other
-- (radians, white turned one way and black the other)
Icons.Piece.ModelFacing = 0.4

-- The animation models play: 0 is the idle stand
local standAnimation = 0

-- Points the model at its piece. Runs again once the model has loaded, since
-- loading resets the camera and animation, and whenever the model is shown or
-- resized: the camera is fitted to the model when it loads, and a model that
-- loaded while hidden (pieces start hidden) or before it had its size can end up
-- zoomed differently. RefreshCamera fits it afresh before our distance applies.
local function setupModel(model)
    local spec = model.spec
    if not spec then
        return
    end
    if model.RefreshCamera then
        model:RefreshCamera()
    end
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(spec.distance or 1)
    model:SetPosition(0, 0, 0)
    model:SetFacing(model.isWhite and -Icons.Piece.ModelFacing or Icons.Piece.ModelFacing)
    model:SetAnimation(standAnimation)
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
        model:SetScript("OnShow", setupModel)
        model:SetScript("OnSizeChanged", setupModel)
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

-- Hides a model ApplyArt put on holder (for frames going back to the pool). The
-- model stays set, so reusing the frame for the same piece needs no reload.
function Icons.Piece:ClearArt(holder)
    if holder.pieceModel then
        holder.pieceModel:Hide()
    end
end

-- Preloading
-- The client loads a model's files the first time it is drawn, which takes a
-- moment, and pieces are made while the window is still closed. So the models of
-- the chosen theme are loaded at login (and when the theme is picked) on a 1x1
-- frame that is shown until they have all loaded. The frames are kept, so the
-- files stay loaded and the board shows its pieces straight away. Only a model
-- theme does this; switching to a texture theme lets the models go.
local preloadTimeout = 10 -- seconds before the preload frame hides regardless
local preloadFrame

local function hidePreloadWhenDone()
    for _, model in pairs(preloadFrame.models) do
        if not model.loaded then
            return
        end
    end
    preloadFrame:Hide()
end

function Icons.Piece:PreloadModels()
    local models = Icons.Piece.Models[KC:getPieceTheme()]
    if not models then
        if preloadFrame then
            preloadFrame:Hide()
            for _, model in pairs(preloadFrame.models) do
                model:ClearModel()
                model.display = nil
            end
        end
        return
    end
    if not preloadFrame then
        preloadFrame = CreateFrame("Frame", nil, UIParent)
        preloadFrame:SetFrameStrata("BACKGROUND")
        preloadFrame:SetSize(1, 1)
        preloadFrame:SetPoint("BOTTOMLEFT")
        preloadFrame.models = {}
    end

    for key, spec in pairs(models) do
        local model = preloadFrame.models[key]
        if not model then
            model = CreateFrame("PlayerModel", nil, preloadFrame)
            model:SetAllPoints()
            model:SetScript("OnModelLoaded", function(self)
                self.loaded = true
                hidePreloadWhenDone()
            end)
            preloadFrame.models[key] = model
        end
        if model.display ~= spec.display then
            model.display = spec.display
            model.loaded = false
            model:SetDisplayInfo(spec.display)
        end
    end

    preloadFrame:Show()
    hidePreloadWhenDone()
    C_Timer.After(preloadTimeout, function() preloadFrame:Hide() end)
end

-- 
