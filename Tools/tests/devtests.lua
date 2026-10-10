-- Karazhan Chess - checks the in-game test cases in KarazhanChess/Dev/Tests.lua:
-- unique IDs, required fields, every FEN parses and every setup move is legal
-- Run: node lua.js tests/devtests.lua
local Rules = assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", {})
local ns = { KC = { isDevBuild = true } }
local Tests = assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Dev/Tests.lua"))("KarazhanChess", ns)

local failed = 0
local function fail(test, message)
    failed = failed + 1
    print((test.id or "?") .. ": " .. message)
end

local loadFields = { fen = true, newGame = true, clear = true, moves = true, flipped = true, mode = true, computer = true }
local levels = { RaidFinder = true, Normal = true, Heroic = true, Mythic = true, CuttingEdge = true }
local seen = {}
for _, test in ipairs(Tests) do
    if type(test.id) ~= "string" then fail(test, "missing id") end
    if seen[test.id] then fail(test, "duplicate id") end
    seen[test.id] = true
    for _, field in ipairs({ "section", "name", "check" }) do
        if type(test[field]) ~= "string" or test[field] == "" then fail(test, "missing " .. field) end
    end
    if test.steps ~= nil and type(test.steps) ~= "table" then fail(test, "steps is not a list") end

    local load = test.load
    if load then
        for key in pairs(load) do
            if not loadFields[key] then fail(test, "unknown load field " .. key) end
        end
        if load.mode and load.mode ~= "play" and load.mode ~= "puzzle" then fail(test, "bad mode " .. tostring(load.mode)) end
        if load.computer then
            if not levels[load.computer.level] then fail(test, "bad computer level " .. tostring(load.computer.level)) end
            local colour = load.computer.colour
            if colour ~= nil and colour ~= "w" and colour ~= "b" then fail(test, "bad computer colour " .. tostring(colour)) end
            if not (load.fen or load.newGame) then fail(test, "computer needs fen or newGame") end
            if load.moves or load.flipped or load.clear then fail(test, "computer can't be combined with moves, flipped or clear") end
        end

        local pos, err
        if load.fen then
            pos, err = Rules.FromFEN(load.fen)
            if not pos then fail(test, "bad FEN: " .. err) end
        elseif load.newGame then
            pos = Rules.FromFEN(Rules.StartFEN)
        elseif load.clear then
            pos = Rules.FromFEN("8/8/8/8/8/8/8/8 w - - 0 1")
        end

        if load.moves then
            if not pos then
                fail(test, "moves without a board setup")
            else
                -- No turns in free play: each move is made by whichever side owns the piece
                for _, uci in ipairs(load.moves) do
                    local letter = pos.board[Rules.SquareIndex(uci:sub(1, 2)) or 0]
                    pos.turn = letter and Rules.Colour[letter] or pos.turn
                    local move = Rules.FindMove(pos, uci)
                    if not move then
                        fail(test, "setup move " .. uci .. " isn't legal")
                        break
                    end
                    Rules.MakeMove(pos, move)
                end
            end
        end
    end
end

print(#Tests .. " tests checked")
if failed > 0 then error(failed .. " problems") end
print("all passed")
