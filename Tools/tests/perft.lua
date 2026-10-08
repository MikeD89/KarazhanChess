-- Karazhan Chess - move generator check: perft node counts against known values
-- Run: node lua.js tests/perft.lua [quick]
local Rules = assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", {})
local quick = arg[1] == "quick"

-- Expected counts from https://www.chessprogramming.org/Perft_Results
local cases = {
    { "start", Rules.StartFEN, { 20, 400, 8902, 197281 } },
    { "kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", { 48, 2039, 97862 } },
    { "position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", { 14, 191, 2812, 43238 } },
    { "position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", { 6, 264, 9467 } },
    { "position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", { 44, 1486, 62379 } },
}

local failed = 0
for _, case in ipairs(cases) do
    local name, fen, expected = case[1], case[2], case[3]
    local pos = assert(Rules.FromFEN(fen))
    assert(Rules.ToFEN(pos) == fen, "FEN round trip failed for " .. name .. ": " .. Rules.ToFEN(pos))
    for depth, want in ipairs(expected) do
        if quick and want > 10000 then break end
        local start = os.clock()
        local got = Rules.Perft(pos, depth)
        local ok = got == want
        if not ok then failed = failed + 1 end
        print(string.format("%-11s depth %d: %7d %s (%.1fs)", name, depth, got, ok and "ok" or ("FAIL, expected " .. want), os.clock() - start))
    end
end

-- Checkmate / stalemate detection
local function status(fen)
    return (Rules.GetStatus(assert(Rules.FromFEN(fen))))
end
local checks = {
    { "fool's mate", "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3", "checkmate" },
    { "stalemate", "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1", "stalemate" },
    { "start", Rules.StartFEN, nil },
}
for _, c in ipairs(checks) do
    local got = status(c[2])
    local ok = got == c[3]
    if not ok then failed = failed + 1 end
    print(string.format("%-11s status: %s %s", c[1], tostring(got), ok and "ok" or "FAIL"))
end

if failed > 0 then
    error(failed .. " check(s) failed")
end
print("all passed")
