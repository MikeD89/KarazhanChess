-- Karazhan Chess - checks the generated puzzle data addon: loads its files the way
-- WoW would (through a stub LibStub), then for every tier checks the count,
-- unique IDs, record lookup by index and by ID, and that every record decodes
-- to a position where the whole solution is legal.
-- Run: node lua.js tests/puzzles.lua [sample]   (sample: check every Nth record, default 1)
local step = tonumber(arg[1]) or 1

local ns = {}
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", ns)
assert(loadfile(ADDON_ROOT .. "/KarazhanChess/PuzzleCodec.lua"))("KarazhanChess", ns)
local Rules, Codec = ns.Rules, ns.PuzzleCodec

-- What the data addon calls
local tiers, themes = {}, nil
local KC = {}
function KC:RegisterPuzzles(key, data) tiers[key] = data end
function KC:RegisterPuzzleThemes(list) themes = list end
LibStub = function() return { GetAddon = function() return KC end } end

-- Load the files listed in the .toc, in order
local dir = ADDON_ROOT .. "/KarazhanChess_Puzzles/"
local toc = readfile(dir .. "KarazhanChess_Puzzles.toc")
for file in toc:gmatch("\n([%w_]+%.lua)") do
    local start = os.clock()
    assert(loadfile(dir .. file))()
    print(string.format("loaded %-16s %.2fs", file, os.clock() - start))
end
assert(themes and #themes > 0, "no themes registered")

local failed, seen = 0, {}
local function fail(msg)
    failed = failed + 1
    if failed <= 10 then print("FAIL " .. msg) end
end

for _, key in ipairs({ "RaidFinder", "Normal", "Heroic", "Mythic", "CuttingEdge" }) do
    local tier = assert(tiers[key], "missing tier " .. key)
    local records = 0
    for _, chunk in ipairs(tier.chunks) do
        for _ in chunk:gmatch("%S+") do records = records + 1 end
    end
    if records ~= tier.count then fail(key .. " count " .. tier.count .. " but " .. records .. " records") end

    local start, checked = os.clock(), 0
    for i = 1, tier.count, step do
        local record = Codec.GetRecord(tier, i)
        local id = Codec.GetId(record)
        if seen[id] then fail("duplicate id " .. id) end
        seen[id] = true
        if Codec.FindRecord(tier, id) ~= record then fail("FindRecord " .. id) end

        local puzzle = Codec.Decode(record, themes)
        local pos = Rules.Copy(puzzle.position)
        for n, uci in ipairs(puzzle.moves) do
            local move = Rules.FindMove(pos, uci)
            if not move then fail(id .. " move " .. n .. " " .. uci .. " illegal") break end
            Rules.MakeMove(pos, move)
        end
        checked = checked + 1
    end
    print(string.format("%-12s %6d puzzles, %d checked, %.1fs", key, tier.count, checked, os.clock() - start))
end

if failed > 0 then error(failed .. " check(s) failed") end
print("all passed")
