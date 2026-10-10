-- Karazhan Chess - chess engine checks: perft counts (the engine has its own move
-- generator, so it must agree with Rules), finding known best moves, repetition
-- handling, and a speed benchmark.
-- Run: node lua.js tests/engine.lua [quick]
-- (fengari is much slower than WoW's Lua, so the speeds here are a lower bound)
local ns = {}
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", ns)
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Engine.lua"))("KarazhanChess", ns)
local Rules, Engine = ns.Rules, ns.Engine
local quick = arg[1] == "quick"

local failed = 0
local function check(ok, msg)
    if not ok then failed = failed + 1 end
    print((ok and "ok   " or "FAIL ") .. msg)
end

local function position(fen)
    return assert(Rules.FromFEN(fen))
end

-- Perft: same cases as tests/perft.lua
local cases = {
    { "start", Rules.StartFEN, { 20, 400, 8902, 197281 } },
    { "kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", { 48, 2039, 97862, 4085603 } },
    { "position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", { 14, 191, 2812, 43238, 674624 } },
    { "position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", { 6, 264, 9467, 422333 } },
    { "position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", { 44, 1486, 62379, 2103487 } },
}
for _, case in ipairs(cases) do
    local name, fen, expected = case[1], case[2], case[3]
    for depth, want in ipairs(expected) do
        if want > (quick and 10000 or 700000) then break end
        local start = os.clock()
        local got = Engine.Perft(position(fen), depth)
        check(got == want, string.format("perft %-10s depth %d: %d%s (%.1fs, %.0f nodes/s)", name, depth, got,
            got == want and "" or (", expected " .. want), os.clock() - start, got / math.max(os.clock() - start, 0.001)))
    end
end

-- Best moves
local tactics = {
    { "back rank mate", "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1", "d1d8" },
    { "scholar's mate", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "h5f7" },
    { "knight fork", "q3k3/8/8/1N6/8/8/8/4K3 w - - 0 1", "b5c7" },
    { "mate in 2", "kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1", "a1a6" },
    { "take the queen", "4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1", "d2d5" },
    { "promote", "8/4P3/8/8/8/k7/8/4K3 w - - 0 1", "e7e8q" },
}
for _, t in ipairs(tactics) do
    local result = Engine.Search(position(t[2]), { depth = 5, time = 20000 })
    local ok = result ~= nil and (t[3] == nil or result.move == t[3])
    check(ok, string.format("%-15s %s (depth %d, score %d, %d nodes, %.1fs)", t[1], result and result.move or "none",
        result and result.depth or 0, result and result.score or 0, result and result.nodes or 0, (result and result.time or 0) / 1000))
end

-- Checkmate and stalemate: nothing to play
check(Engine.Search(position("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")) == nil, "no move when mated")
check(Engine.Search(position("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")) == nil, "no move when stalemated")

-- Mate score
local mate = Engine.Search(position("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1"), { depth = 3 })
check(mate.score > Engine.Mate - 10, "mate in 1 scores as mate (" .. mate.score .. ")")

-- Repetition: up a queen, white must not walk into a position seen before;
-- down a queen (black to move), taking a repetition draw is fine. Here, with the
-- position after Kh1-g1 already seen, white avoids it.
do
    local pos = position("7k/8/8/8/8/8/8/Q6K w - - 0 1")
    local seen = {}
    local after = Rules.Copy(pos)
    Rules.MakeMove(after, Rules.FindMove(after, "h1g1"))
    seen[Engine.Hash(after)] = true
    local result = Engine.Search(pos, { depth = 4, history = seen })
    check(result.move ~= "h1g1", "avoids a repetition when winning (" .. result.move .. ")")
end

-- Noise and random moves still give legal moves
do
    local pos = position(Rules.StartFEN)
    for _, opts in ipairs({ { depth = 2, noise = 100 }, { depth = 1, randomMove = 1 } }) do
        local result = Engine.Search(pos, opts)
        check(result and Rules.FindMove(Rules.Copy(pos), result.move) ~= nil, "legal move with noise/random (" .. result.move .. ")")
    end
end

-- Yielding in slices: the search runs in a coroutine and yields
do
    local yields = 0
    local co = coroutine.create(function()
        return Engine.Search(position(Rules.StartFEN), { depth = 4, slice = 5, yield = coroutine.yield })
    end)
    local ok, result = coroutine.resume(co)
    while coroutine.status(co) ~= "dead" do
        yields = yields + 1
        ok, result = coroutine.resume(co)
    end
    check(ok and result and result.move ~= nil, "search in a coroutine (" .. yields .. " yields, " .. tostring(result and result.move) .. ")")
end

-- Speed: a fixed-depth search of a middlegame position
do
    Engine.Clear()
    local fen = "r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP1B1PPP/R2QKB1R w KQ - 0 8"
    for _, depth in ipairs(quick and { 3 } or { 3, 4, 5 }) do
        local result = Engine.Search(position(fen), { depth = depth })
        print(string.format("bench depth %d: %s score %d, %d nodes, %.1fs, %.0f nodes/s", depth, result.move, result.score,
            result.nodes, result.time / 1000, result.nodes / math.max(result.time / 1000, 0.001)))
    end
end

if failed > 0 then
    error(failed .. " check(s) failed")
end
print("all passed")
