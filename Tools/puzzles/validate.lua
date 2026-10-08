-- Karazhan Chess - puzzle validation, run inside fengari by build.js.
-- Loads the addon's own Rules and PuzzleCodec, so a puzzle that passes here is
-- decoded and played exactly as it will be in game.
local ns = {}
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", ns)
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/PuzzleCodec.lua"))("KarazhanChess", ns)
local Rules, Codec = ns.Rules, ns.PuzzleCodec

THEME_NAMES = {}

-- themes: space separated theme list, in code order (index 0 first)
function setThemes(themes)
    THEME_NAMES = {}
    for name in string.gmatch(themes, "%S+") do
        THEME_NAMES[#THEME_NAMES + 1] = name
    end
end

local function firstFields(fen)
    return fen:match("^(%S+ %S+ %S+ %S+)")
end

-- Checks an encoded record against the source row: it must decode to the same
-- FEN (board, turn, castling, en passant), moves and themes, every move must be
-- legal in turn, and a mate puzzle must end in checkmate.
-- Returns "ok" or the reason it failed.
function validate(record, fen, moves, themes)
    local ok, result = pcall(function()
        local puzzle = Codec.Decode(record, THEME_NAMES)
        if firstFields(puzzle.fen) ~= firstFields(fen) then
            return "fen mismatch: " .. puzzle.fen .. " vs " .. fen
        end
        if table.concat(puzzle.moves, " ") ~= moves then
            return "moves mismatch: " .. table.concat(puzzle.moves, " ") .. " vs " .. moves
        end
        if table.concat(puzzle.themes, " ") ~= themes then
            return "themes mismatch: " .. table.concat(puzzle.themes, " ") .. " vs " .. themes
        end

        local pos = Rules.FromFEN(puzzle.fen)
        if not pos then
            return "bad fen"
        end
        for i, uci in ipairs(puzzle.moves) do
            local move = Rules.FindMove(pos, uci)
            if not move then
                return "illegal move " .. i .. ": " .. uci
            end
            Rules.MakeMove(pos, move)
        end

        local isMate = (" " .. themes .. " "):find(" mate ", 1, true) ~= nil
        if isMate and Rules.GetStatus(pos) ~= "checkmate" then
            return "mate theme but no checkmate"
        end
        return "ok"
    end)
    if not ok then
        return "error: " .. tostring(result)
    end
    return result
end
