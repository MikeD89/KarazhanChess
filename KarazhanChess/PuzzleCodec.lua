-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Puzzle Data Decoding (pure Lua 5.1, no WoW API, so it also runs offline)
-------------------------------------------------------------------------------

-- Puzzles ship in the KarazhanChess_Puzzles load-on-demand addon, written by
-- Tools/puzzles/build.js. Each tier is registered as
--   { name, count, chunkSize, chunks = { "rec rec rec ...", ... } }
-- where records are separated by single spaces, chunkSize per chunk (the last
-- may hold fewer). A record is the 5-character Lichess puzzle ID followed by a
-- bit stream in base64 (A-Z a-z 0-9 + /, 6 bits per character, most
-- significant bit first). Fields, in order:
--   rating      12 bits
--   turn         1 bit   0 = white to move, 1 = black (the opponent, who moves first)
--   castling     4 bits  K Q k q
--   en passant   1 bit present, then 3 bits file (the rank follows from turn)
--   occupancy   64 bits  one per square, a1 to h8 (Rules square order)
--   pieces       4 bits  per occupied square, index into "PNBRQKpnbrqk"
--   move count   6 bits, then per move: from 6 bits, to 6 bits (square - 1),
--                promotion 1 bit, then 2 bits into "qrbn" if set
--   theme count  4 bits, then 7 bits per theme (index into the themes list, from 0)
-- Zero bits pad the stream to whole characters.
-- The encoder in Tools/puzzles/build.js must match this exactly.
local _, ns = ...
ns = ns or {}

local Codec = {}
ns.PuzzleCodec = Codec

Codec.IdLength = 5
Codec.Separator = " "

local floor = math.floor
local byte, sub, find = string.byte, string.sub, string.find

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, #ALPHABET do
    VALUE[byte(ALPHABET, i)] = i - 1
end
local POW = { [0] = 1, 2, 4, 8, 16, 32 }

local PIECES = "PNBRQKpnbrqk"
local PROMOTIONS = "qrbn"

-- Returns read(n): the next n bits of text from character start, as a number
local function bitReader(text, start)
    local pos, digit, bitsLeft = start, 0, 0
    return function(n)
        local value = 0
        for _ = 1, n do
            if bitsLeft == 0 then
                digit = VALUE[byte(text, pos) or 65] or 0
                pos = pos + 1
                bitsLeft = 6
            end
            bitsLeft = bitsLeft - 1
            value = value * 2 + floor(digit / POW[bitsLeft]) % 2
        end
        return value
    end
end

-- Decodes one record. themeNames is the data addon's theme list.
-- Returns { id, rating, fen, position, moves = { uci, ... }, themes = { name, ... } }.
-- position is a rules engine position (see Rules.lua) for the FEN.
function Codec.Decode(record, themeNames)
    local Rules = ns.Rules
    local read = bitReader(record, Codec.IdLength + 1)
    local puzzle = { id = sub(record, 1, Codec.IdLength), moves = {}, themes = {} }

    puzzle.rating = read(12)

    local pos = Rules.NewPosition()
    pos.turn = (read(1) == 1) and "b" or "w"
    pos.castling.K = read(1) == 1
    pos.castling.Q = read(1) == 1
    pos.castling.k = read(1) == 1
    pos.castling.q = read(1) == 1
    if read(1) == 1 then
        local file = read(3) + 1
        pos.ep = Rules.Index(file, pos.turn == "w" and 6 or 3)
    end

    local occupied = {}
    for sq = 1, 64 do
        occupied[sq] = read(1) == 1
    end
    for sq = 1, 64 do
        if occupied[sq] then
            local code = read(4) + 1
            pos.board[sq] = sub(PIECES, code, code)
        end
    end
    puzzle.position = pos
    puzzle.fen = Rules.ToFEN(pos)

    for i = 1, read(6) do
        local from, to = read(6) + 1, read(6) + 1
        local uci = Rules.SquareName(from) .. Rules.SquareName(to)
        if read(1) == 1 then
            local p = read(2) + 1
            uci = uci .. sub(PROMOTIONS, p, p)
        end
        puzzle.moves[i] = uci
    end

    for i = 1, read(4) do
        local name = themeNames and themeNames[read(7) + 1]
        if name then
            table.insert(puzzle.themes, name)
        end
    end

    return puzzle
end

-- Chunk navigation ------------------------------------------------------------

-- The index-th record (1-based) of a registered tier, or nil
function Codec.GetRecord(tier, index)
    if index < 1 or index > tier.count then
        return nil
    end
    local chunk = tier.chunks[floor((index - 1) / tier.chunkSize) + 1]
    local skip = (index - 1) % tier.chunkSize
    local start = 1
    for _ = 1, skip do
        start = find(chunk, Codec.Separator, start, true) + 1
    end
    local stop = find(chunk, Codec.Separator, start, true)
    return sub(chunk, start, (stop or 0) - 1)
end

-- The record with this puzzle ID in a registered tier, or nil
function Codec.FindRecord(tier, id)
    for _, chunk in ipairs(tier.chunks) do
        local start
        if sub(chunk, 1, Codec.IdLength) == id then
            start = 1
        else
            start = find(chunk, Codec.Separator .. id, 1, true)
            start = start and start + 1
        end
        if start then
            local stop = find(chunk, Codec.Separator, start, true)
            return sub(chunk, start, (stop or 0) - 1)
        end
    end
end

-- The puzzle ID of a record without decoding the rest
function Codec.GetId(record)
    return sub(record, 1, Codec.IdLength)
end

return Codec
