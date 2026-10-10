-- Karazhan Chess - plays the computer levels against each other: every engine
-- move must be legal (checked with Rules), and the stronger level should score
-- more. Uses the level settings from Computer.lua.
-- Run: node lua.js tests/selfplay.lua <levelA> <levelB> [games] [timeScale] [verbose]
--   e.g. node lua.js tests/selfplay.lua RaidFinder Normal 10
-- Colours alternate. timeScale multiplies the think time limits (default 3, as
-- fengari is much slower than WoW's Lua); depth-limited levels play as in game.
local ns = {}
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", ns)
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Engine.lua"))("KarazhanChess", ns)
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Computer.lua"))("KarazhanChess", ns)
local Rules, Engine, Computer = ns.Rules, ns.Engine, ns.Computer

local keyA, keyB = arg[1] or "RaidFinder", arg[2] or "Normal"
local games = tonumber(arg[3]) or 4
local timeScale = tonumber(arg[4]) or 3
local verbose = arg[5] == "verbose" -- print every move with its score, depth and nodes
local levelA, levelB = Computer:GetLevel(keyA), Computer:GetLevel(keyB)
assert(levelA.key == keyA and levelB.key == keyB, "unknown level")
math.randomseed(os.time())

local function repetitionKey(pos)
    return (Rules.ToFEN(pos):match("^(%S+ %S+ %S+ %S+)"))
end

local function insufficient(pos)
    local minors = 0
    for sq = 1, 64 do
        local kind = pos.board[sq] and Rules.Type[pos.board[sq]]
        if kind == "n" or kind == "b" then
            minors = minors + 1
        elseif kind and kind ~= "k" then
            return false
        end
    end
    return minors <= 1
end

-- Plays one game; returns 1 (white wins), 0 (black wins) or 0.5, and how it ended
local function play(white, black)
    local pos = Rules.FromFEN(Rules.StartFEN)
    local history = { pos = {}, keys = {} }
    local counts = {}
    Engine.Clear()
    for ply = 1, 400 do
        local status = Rules.GetStatus(Rules.Copy(pos))
        if status == "checkmate" then return (pos.turn == "w") and 0 or 1, "checkmate", ply end
        if status == "stalemate" then return 0.5, "stalemate", ply end
        if insufficient(pos) then return 0.5, "material", ply end
        if pos.halfmove >= 100 then return 0.5, "fifty", ply end
        local key = repetitionKey(pos)
        counts[key] = (counts[key] or 0) + 1
        if counts[key] >= 3 then return 0.5, "repetition", ply end

        local seen = {}
        for _, earlier in ipairs(history.pos) do seen[Engine.Hash(earlier)] = true end
        history.pos[#history.pos + 1] = Rules.Copy(pos)

        Computer.level = (pos.turn == "w") and white or black
        local opts = Computer:GetSearchOptions(pos)
        if opts.time then opts.time = opts.time * timeScale end
        opts.history = seen
        local result = Engine.Search(Rules.Copy(pos), opts)
        local move = result and Rules.FindMove(pos, result.move)
        if not move then
            error("illegal or no move " .. tostring(result and result.move) .. " in " .. Rules.ToFEN(pos))
        end
        if verbose then
            print(string.format("  %3d %s %-11s %-6s score %6d depth %2d nodes %7d %.1fs", ply, pos.turn, Computer.level.key,
                result.move, result.score, result.depth, result.nodes, result.time / 1000))
        end
        Rules.MakeMove(pos, move)
    end
    return 0.5, "move limit", 400
end

local scoreA = 0
local start = os.clock()
for g = 1, games do
    local aWhite = g % 2 == 1
    local result, how, plies = play(aWhite and levelA or levelB, aWhite and levelB or levelA)
    local forA = aWhite and result or (1 - result)
    scoreA = scoreA + forA
    print(string.format("game %d: %s (%s) %s, %d plies, %s %.1f - %.1f %s", g, aWhite and keyA or keyB, "white",
        how, plies, keyA, scoreA, g - scoreA, keyB))
end
print(string.format("%s %.1f - %.1f %s (%.0fs)", keyA, scoreA, games - scoreA, keyB, os.clock() - start))
