-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Chess Engine: the computer opponent's search (pure Lua 5.1, no WoW API)
-------------------------------------------------------------------------------

-- Separate from Rules for speed: Rules builds a table per move, which is fine
-- for a click but far too slow to search with. The engine keeps one position of
-- its own and allocates nothing while searching:
--   a 10x12 mailbox board (a1 = 21, h1 = 28, a8 = 91, h8 = 98; the border is OFF),
--   pieces as numbers (1-6 = pawn, knight, bishop, rook, queen, king; white
--   positive, black negative), side 1 (white) or -1 (black),
--   moves as numbers: from + to * 128 + promotion * 16384 + flag * 131072.
--
-- Search: iterative deepening negamax with alpha-beta (principal variation
-- search), a transposition table, null move pruning, late move reductions,
-- check extensions, killer and history move ordering, and a quiescence search
-- over captures. Evaluation is PeSTO's tapered piece-square tables (material
-- and placement for the middlegame and endgame, blended by the material left).
--
-- The search can run in slices: opts.yield is called whenever opts.slice ms
-- have passed (in WoW, coroutine.yield, so a long think spreads over frames).
--
-- Outside WoW (tests) the file is run with no namespace, so it makes its own
-- and returns Engine.
local _, ns = ...
ns = ns or {}

local Engine = {}
ns.Engine = Engine

local floor = math.floor

-- Constants -------------------------------------------------------------------

local EMPTY, OFF = 0, 7
local PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = 1, 2, 3, 4, 5, 6
local FLAG_DOUBLE, FLAG_EP, FLAG_CASTLE = 1, 2, 3
local TO, PROMO, FLAG = 128, 16384, 131072 -- move field multipliers

local INF = 100000
local MATE = 30000
local MAX_PLY = 96
Engine.Mate = MATE

local LETTER_PIECE = { P = 1, N = 2, B = 3, R = 4, Q = 5, K = 6, p = -1, n = -2, b = -3, r = -4, q = -5, k = -6 }
local PROMO_LETTER = { [KNIGHT] = "n", [BISHOP] = "b", [ROOK] = "r", [QUEEN] = "q" }

-- Mailbox index of each rules engine square (1-64), and square names
local MAILBOX, NAME = {}, {}
local SQUARES = {} -- the 64 mailbox indexes, a1 first
for sq = 1, 64 do
    local col, row = (sq - 1) % 8 + 1, floor((sq - 1) / 8) + 1
    local m = 10 + row * 10 + col
    MAILBOX[sq], SQUARES[sq] = m, m
    NAME[m] = string.sub("abcdefgh", col, col) .. row
end

local KNIGHT_DIRS = { 21, 19, 12, 8, -8, -12, -19, -21 }
local KING_DIRS = { 11, 10, 9, 1, -1, -9, -10, -11 }
local DIAG_DIRS = { 11, 9, -9, -11 }
local ORTHO_DIRS = { 10, 1, -1, -10 }
local SLIDER_DIRS = { [BISHOP] = DIAG_DIRS, [ROOK] = ORTHO_DIRS, [QUEEN] = KING_DIRS }

-- Castling rights are bits: 1 = K, 2 = Q, 4 = k, 8 = q. A move from or to one of
-- these squares clears the rights in its mask. CLEARED[rights * 16 + mask].
local CASTLE_MASK = { [21] = 2, [25] = 3, [28] = 1, [91] = 8, [95] = 12, [98] = 4 }
local CLEARED = {}
for rights = 0, 15 do
    for mask = 0, 15 do
        local result, bit = 0, 1
        for _ = 1, 4 do
            if floor(rights / bit) % 2 == 1 and floor(mask / bit) % 2 == 0 then
                result = result + bit
            end
            bit = bit * 2
        end
        CLEARED[rights * 16 + mask] = result
    end
end

-- Zobrist-style hashing, with addition instead of XOR (Lua 5.1 has no bit
-- operators): each key is below 2^40, so a position's sum stays exact in a double.
-- A fixed seed keeps the keys the same in WoW and in the offline tests.
local seed = 20261010
local function rand31()
    seed = (seed * 16807) % 2147483647
    return seed
end
local function rand40()
    return rand31() * 512 + rand31() % 512
end

local ZPIECE = {}
for piece = -KING, KING do
    if piece ~= 0 then
        local keys = {}
        for _, m in ipairs(SQUARES) do keys[m] = rand40() end
        ZPIECE[piece] = keys
    end
end
local ZSIDE = rand40()
local ZCASTLE = {}
for rights = 0, 15 do ZCASTLE[rights] = rand40() end
local ZEP = { [0] = 0 }
for _, m in ipairs(SQUARES) do ZEP[m] = rand40() end

-- Evaluation tables -----------------------------------------------------------

-- PeSTO piece values and piece-square tables by Ronald Friederich (Rofchade),
-- as published on the Chess Programming Wiki. Each table runs from a8 to h1, as
-- seen by white.
local MG_VALUE = { 82, 337, 365, 477, 1025, 0 }
local EG_VALUE = { 94, 281, 297, 512, 936, 0 }
local PHASE_INC = { 0, 1, 1, 2, 4, 0 } -- 24 with all pieces on; 0 in a pawn ending

local MG_TABLE = {
    { -- pawn
          0,   0,   0,   0,   0,   0,   0,   0,
         98, 134,  61,  95,  68, 126,  34, -11,
         -6,   7,  26,  31,  65,  56,  25, -20,
        -14,  13,   6,  21,  23,  12,  17, -23,
        -27,  -2,  -5,  12,  17,   6,  10, -25,
        -26,  -4,  -4, -10,   3,   3,  33, -12,
        -35,  -1, -20, -23, -15,  24,  38, -22,
          0,   0,   0,   0,   0,   0,   0,   0,
    },
    { -- knight
        -167, -89, -34, -49,  61, -97, -15, -107,
         -73, -41,  72,  36,  23,  62,   7,  -17,
         -47,  60,  37,  65,  84, 129,  73,   44,
          -9,  17,  19,  53,  37,  69,  18,   22,
         -13,   4,  16,  13,  28,  19,  21,   -8,
         -23,  -9,  12,  10,  19,  17,  25,  -16,
         -29, -53, -12,  -3,  -1,  18, -14,  -19,
        -105, -21, -58, -33, -17, -28, -19,  -23,
    },
    { -- bishop
        -29,   4, -82, -37, -25, -42,   7,  -8,
        -26,  16, -18, -13,  30,  59,  18, -47,
        -16,  37,  43,  40,  35,  50,  37,  -2,
         -4,   5,  19,  50,  37,  37,   7,  -2,
         -6,  13,  13,  26,  34,  12,  10,   4,
          0,  15,  15,  15,  14,  27,  18,  10,
          4,  15,  16,   0,   7,  21,  33,   1,
        -33,  -3, -14, -21, -13, -12, -39, -21,
    },
    { -- rook
         32,  42,  32,  51,  63,   9,  31,  43,
         27,  32,  58,  62,  80,  67,  26,  44,
         -5,  19,  26,  36,  17,  45,  61,  16,
        -24, -11,   7,  26,  24,  35,  -8, -20,
        -36, -26, -12,  -1,   9,  -7,   6, -23,
        -45, -25, -16, -17,   3,   0,  -5, -33,
        -44, -16, -20,  -9,  -1,  11,  -6, -71,
        -19, -13,   1,  17,  16,   7, -37, -26,
    },
    { -- queen
        -28,   0,  29,  12,  59,  44,  43,  45,
        -24, -39,  -5,   1, -16,  57,  28,  54,
        -13, -17,   7,   8,  29,  56,  47,  57,
        -27, -27, -16, -16,  -1,  17,  -2,   1,
         -9, -26,  -9, -10,  -2,  -4,   3,  -3,
        -14,   2, -11,  -2,  -5,   2,  14,   5,
        -35,  -8,  11,   2,   8,  15,  -3,   1,
         -1, -18,  -9,  10, -15, -25, -31, -50,
    },
    { -- king
        -65,  23,  16, -15, -56, -34,   2,  13,
         29,  -1, -20,  -7,  -8,  -4, -38, -29,
         -9,  24,   2, -16, -20,   6,  22, -22,
        -17, -20, -12, -27, -30, -25, -14, -36,
        -49,  -1, -27, -39, -46, -44, -33, -51,
        -14, -14, -22, -46, -44, -30, -15, -27,
          1,   7,  -8, -64, -43, -16,   9,   8,
        -15,  36,  12, -54,   8, -28,  24,  14,
    },
}

local EG_TABLE = {
    { -- pawn
          0,   0,   0,   0,   0,   0,   0,   0,
        178, 173, 158, 134, 147, 132, 165, 187,
         94, 100,  85,  67,  56,  53,  82,  84,
         32,  24,  13,   5,  -2,   4,  17,  17,
         13,   9,  -3,  -7,  -7,  -8,   3,  -1,
          4,   7,  -6,   1,   0,  -5,  -1,  -8,
         13,   8,   8,  10,  13,   0,   2,  -7,
          0,   0,   0,   0,   0,   0,   0,   0,
    },
    { -- knight
        -58, -38, -13, -28, -31, -27, -63, -99,
        -25,  -8, -25,  -2,  -9, -25, -24, -52,
        -24, -20,  10,   9,  -1,  -9, -19, -41,
        -17,   3,  22,  22,  22,  11,   8, -18,
        -18,  -6,  16,  25,  16,  17,   4, -18,
        -23,  -3,  -1,  15,  10,  -3, -20, -22,
        -42, -20, -10,  -5,  -2, -20, -23, -44,
        -29, -51, -23, -15, -22, -18, -50, -64,
    },
    { -- bishop
        -14, -21, -11,  -8,  -7,  -9, -17, -24,
         -8,  -4,   7, -12,  -3, -13,  -4, -14,
          2,  -8,   0,  -1,  -2,   6,   0,   4,
         -3,   9,  12,   9,  14,  10,   3,   2,
         -6,   3,  13,  19,   7,  10,  -3,  -9,
        -12,  -3,   8,  10,  13,   3,  -7, -15,
        -14, -18,  -7,  -1,   4,  -9, -15, -27,
        -23,  -9, -23,  -5,  -9, -16,  -5, -17,
    },
    { -- rook
         13,  10,  18,  15,  12,  12,   8,   5,
         11,  13,  13,  11,  -3,   3,   8,   3,
          7,   7,   7,   5,   4,  -3,  -5,  -3,
          4,   3,  13,   1,   2,   1,  -1,   2,
          3,   5,   8,   4,  -5,  -6,  -8, -11,
         -4,   0,  -5,  -1,  -7, -12,  -8, -16,
         -6,  -6,   0,   2,  -9,  -9, -11,  -3,
         -9,   2,   3,  -1,  -5, -13,   4, -20,
    },
    { -- queen
         -9,  22,  22,  27,  27,  19,  10,  20,
        -17,  20,  32,  41,  58,  25,  30,   0,
        -20,   6,   9,  49,  47,  35,  19,   9,
          3,  22,  24,  45,  57,  40,  57,  36,
        -18,  28,  19,  47,  31,  34,  39,  23,
        -16, -27,  15,   6,   9,  17,  10,   5,
        -22, -23, -30, -16, -16, -23, -36, -32,
        -33, -28, -22, -43,  -5, -32, -20, -41,
    },
    { -- king
        -74, -35, -18, -18, -11,  15,   4, -17,
        -12,  17,  14,  17,  17,  38,  23,  11,
         10,  17,  23,  15,  20,  45,  44,  13,
         -8,  22,  24,  27,  26,  33,  26,   3,
        -18,  -4,  21,  24,  27,  23,   9, -11,
        -19,  -3,  11,  21,  23,  16,   7,  -9,
        -27, -11,   4,  13,  14,   4,  -5, -17,
        -53, -34, -21, -11, -28, -14, -24, -43,
    },
}

-- PST_MG[piece][mailbox]: value plus placement, from white's point of view
-- (black pieces count negative), so the evaluation is a running sum
local PST_MG, PST_EG, PHASE = {}, {}, {}
for kind = PAWN, KING do
    local wmg, weg, bmg, beg = {}, {}, {}, {}
    for sq = 1, 64 do
        local col, row = (sq - 1) % 8 + 1, floor((sq - 1) / 8) + 1
        local m = MAILBOX[sq]
        local white = (8 - row) * 8 + col -- tables start at a8
        local black = (row - 1) * 8 + col -- mirrored for black
        wmg[m] = MG_VALUE[kind] + MG_TABLE[kind][white]
        weg[m] = EG_VALUE[kind] + EG_TABLE[kind][white]
        bmg[m] = -(MG_VALUE[kind] + MG_TABLE[kind][black])
        beg[m] = -(EG_VALUE[kind] + EG_TABLE[kind][black])
    end
    PST_MG[kind], PST_EG[kind], PST_MG[-kind], PST_EG[-kind] = wmg, weg, bmg, beg
    PHASE[kind], PHASE[-kind] = PHASE_INC[kind], PHASE_INC[kind]
end

-- Move ordering values (most valuable victim, least valuable attacker)
local ORDER_VALUE = { 100, 320, 330, 500, 900, 2000 }

-- Position --------------------------------------------------------------------

local board = {}
for i = 0, 119 do board[i] = OFF end
local side = 1        -- 1 white, -1 black to move
local ep = 0          -- en passant target square, 0 for none
local castle = 0      -- castling right bits
local halfmove = 0
local kingSq = { [1] = 0, [-1] = 0 }
local hash = 0
local mg, eg, phase = 0, 0, 0 -- running evaluation sums (white's view) and game phase

-- Undo stack, one entry per move made from the root
local sp = 0
local stackCap, stackCastle, stackEp, stackHalf, stackHash, stackMg, stackEg, stackPhase = {}, {}, {}, {}, {}, {}, {}, {}

local function put(piece, m)
    board[m] = piece
    hash = hash + ZPIECE[piece][m]
    mg = mg + PST_MG[piece][m]
    eg = eg + PST_EG[piece][m]
    phase = phase + PHASE[piece]
end

local function remove(m)
    local piece = board[m]
    board[m] = EMPTY
    hash = hash - ZPIECE[piece][m]
    mg = mg - PST_MG[piece][m]
    eg = eg - PST_EG[piece][m]
    phase = phase - PHASE[piece]
end

-- Sets the engine's position from a rules engine position (see Rules.lua).
-- Returns the position's hash.
function Engine.SetPosition(pos)
    hash, mg, eg, phase = 0, 0, 0, 0
    kingSq[1], kingSq[-1] = 0, 0
    for sq = 1, 64 do
        local m = MAILBOX[sq]
        board[m] = EMPTY
        local letter = pos.board[sq]
        if letter then
            local piece = LETTER_PIECE[letter]
            put(piece, m)
            if piece == KING then
                kingSq[1] = m
            elseif piece == -KING then
                kingSq[-1] = m
            end
        end
    end
    side = (pos.turn == "b") and -1 or 1
    local c = pos.castling
    castle = (c.K and 1 or 0) + (c.Q and 2 or 0) + (c.k and 4 or 0) + (c.q and 8 or 0)
    ep = pos.ep and MAILBOX[pos.ep] or 0
    halfmove = pos.halfmove or 0
    hash = hash + ZCASTLE[castle] + ZEP[ep] + ((side == -1) and ZSIDE or 0)
    sp = 0
    return hash
end

-- The hash of a rules engine position (for repetitions in the game so far)
function Engine.Hash(pos)
    return Engine.SetPosition(pos)
end

-- Attacks ---------------------------------------------------------------------

-- Is mailbox square sq attacked by side "by" (1 or -1)?
local function isAttacked(sq, by)
    -- A white pawn attacks up-left and up-right, so look the other way from sq
    if board[sq - 9 * by] == by or board[sq - 11 * by] == by then
        return true
    end
    local piece = KNIGHT * by
    for i = 1, 8 do
        if board[sq + KNIGHT_DIRS[i]] == piece then return true end
    end
    piece = KING * by
    for i = 1, 8 do
        if board[sq + KING_DIRS[i]] == piece then return true end
    end
    local queen = QUEEN * by
    piece = BISHOP * by
    for i = 1, 4 do
        local d = DIAG_DIRS[i]
        local t = sq + d
        local p = board[t]
        while p == EMPTY do
            t = t + d
            p = board[t]
        end
        if p == piece or p == queen then return true end
    end
    piece = ROOK * by
    for i = 1, 4 do
        local d = ORTHO_DIRS[i]
        local t = sq + d
        local p = board[t]
        while p == EMPTY do
            t = t + d
            p = board[t]
        end
        if p == piece or p == queen then return true end
    end
    return false
end

-- Move generation -------------------------------------------------------------

-- Fills list with pseudo-legal moves for the side to move (only captures and
-- queen promotions if capturesOnly) and returns how many
local function generate(list, capturesOnly)
    local n = 0
    local s = side
    local fwd = 10 * s

    for i = 1, 64 do
        local from = SQUARES[i]
        local v = board[from] * s
        if v > 0 and v < OFF then
            if v == PAWN then
                local promoting = (s == 1 and from >= 81) or (s == -1 and from <= 38)
                local to = from + fwd
                if board[to] == EMPTY then
                    if promoting then
                        n = n + 1; list[n] = from + to * TO + QUEEN * PROMO
                        if not capturesOnly then
                            n = n + 1; list[n] = from + to * TO + ROOK * PROMO
                            n = n + 1; list[n] = from + to * TO + BISHOP * PROMO
                            n = n + 1; list[n] = from + to * TO + KNIGHT * PROMO
                        end
                    elseif not capturesOnly then
                        n = n + 1; list[n] = from + to * TO
                        if (s == 1 and from <= 38) or (s == -1 and from >= 81) then
                            local two = to + fwd
                            if board[two] == EMPTY then
                                n = n + 1; list[n] = from + two * TO + FLAG_DOUBLE * FLAG
                            end
                        end
                    end
                end
                for dc = -1, 1, 2 do
                    to = from + fwd + dc
                    local w = board[to] * s
                    if w < 0 and w > -OFF then
                        if promoting then
                            n = n + 1; list[n] = from + to * TO + QUEEN * PROMO
                            if not capturesOnly then
                                n = n + 1; list[n] = from + to * TO + ROOK * PROMO
                                n = n + 1; list[n] = from + to * TO + BISHOP * PROMO
                                n = n + 1; list[n] = from + to * TO + KNIGHT * PROMO
                            end
                        else
                            n = n + 1; list[n] = from + to * TO
                        end
                    elseif to == ep then
                        n = n + 1; list[n] = from + to * TO + FLAG_EP * FLAG
                    end
                end

            elseif v == KNIGHT or v == KING then
                local dirs = (v == KNIGHT) and KNIGHT_DIRS or KING_DIRS
                for j = 1, 8 do
                    local to = from + dirs[j]
                    local p = board[to]
                    if p == EMPTY then
                        if not capturesOnly then
                            n = n + 1; list[n] = from + to * TO
                        end
                    else
                        local w = p * s
                        if w < 0 and w > -OFF then
                            n = n + 1; list[n] = from + to * TO
                        end
                    end
                end

            else
                local dirs = SLIDER_DIRS[v]
                for j = 1, #dirs do
                    local d = dirs[j]
                    local to = from + d
                    local p = board[to]
                    while p == EMPTY do
                        if not capturesOnly then
                            n = n + 1; list[n] = from + to * TO
                        end
                        to = to + d
                        p = board[to]
                    end
                    local w = p * s
                    if w < 0 and w > -OFF then
                        n = n + 1; list[n] = from + to * TO
                    end
                end
            end
        end
    end

    -- Castling: the right, king and rook in place, the squares between empty,
    -- and the king not attacked on its start, crossing or landing square
    if not capturesOnly and castle > 0 then
        local base = (s == 1) and 0 or 70 -- e1 = 25, e8 = 95
        local kingBit, queenBit = (s == 1) and 1 or 4, (s == 1) and 2 or 8
        local e = 25 + base
        if board[e] == KING * s then
            if floor(castle / kingBit) % 2 == 1 and board[e + 3] == ROOK * s
                and board[e + 1] == EMPTY and board[e + 2] == EMPTY
                and not isAttacked(e, -s) and not isAttacked(e + 1, -s) and not isAttacked(e + 2, -s) then
                n = n + 1; list[n] = e + (e + 2) * TO + FLAG_CASTLE * FLAG
            end
            if floor(castle / queenBit) % 2 == 1 and board[e - 4] == ROOK * s
                and board[e - 1] == EMPTY and board[e - 2] == EMPTY and board[e - 3] == EMPTY
                and not isAttacked(e, -s) and not isAttacked(e - 1, -s) and not isAttacked(e - 2, -s) then
                n = n + 1; list[n] = e + (e - 2) * TO + FLAG_CASTLE * FLAG
            end
        end
    end
    return n
end

-- Making moves ----------------------------------------------------------------

local function makeMove(m)
    local from = m % TO
    local to = floor(m / TO) % TO
    local promo = floor(m / PROMO) % 8
    local flag = floor(m / FLAG)

    sp = sp + 1
    stackCastle[sp], stackEp[sp], stackHalf[sp], stackHash[sp] = castle, ep, halfmove, hash
    stackMg[sp], stackEg[sp], stackPhase[sp] = mg, eg, phase

    local s = side
    local piece = board[from]
    local capSq = (flag == FLAG_EP) and (to - 10 * s) or to
    local captured = board[capSq]
    stackCap[sp] = captured
    if captured ~= EMPTY then
        remove(capSq)
    end
    remove(from)
    put((promo > 0) and promo * s or piece, to)

    if flag == FLAG_CASTLE then
        if to > from then
            remove(to + 1)
            put(ROOK * s, to - 1)
        else
            remove(to - 2)
            put(ROOK * s, to + 1)
        end
    end
    if piece == KING * s then
        kingSq[s] = to
    end

    if castle > 0 then
        local rights = castle
        local mask = CASTLE_MASK[from]
        if mask then rights = CLEARED[rights * 16 + mask] end
        mask = CASTLE_MASK[to]
        if mask then rights = CLEARED[rights * 16 + mask] end
        if rights ~= castle then
            hash = hash - ZCASTLE[castle] + ZCASTLE[rights]
            castle = rights
        end
    end

    hash = hash - ZEP[ep]
    ep = (flag == FLAG_DOUBLE) and (from + 10 * s) or 0
    hash = hash + ZEP[ep]

    if piece == s or captured ~= EMPTY then
        halfmove = 0
    else
        halfmove = halfmove + 1
    end

    side = -s
    if s == 1 then hash = hash + ZSIDE else hash = hash - ZSIDE end
end

local function unmakeMove(m)
    local from = m % TO
    local to = floor(m / TO) % TO
    local promo = floor(m / PROMO) % 8
    local flag = floor(m / FLAG)

    local s = -side
    side = s
    local piece = (promo > 0) and s or board[to]
    board[from] = piece
    board[to] = EMPTY
    local captured = stackCap[sp]
    if captured ~= EMPTY then
        board[(flag == FLAG_EP) and (to - 10 * s) or to] = captured
    end
    if flag == FLAG_CASTLE then
        if to > from then
            board[to + 1], board[to - 1] = ROOK * s, EMPTY
        else
            board[to - 2], board[to + 1] = ROOK * s, EMPTY
        end
    end
    if piece == KING * s then
        kingSq[s] = from
    end

    castle, ep, halfmove, hash = stackCastle[sp], stackEp[sp], stackHalf[sp], stackHash[sp]
    mg, eg, phase = stackMg[sp], stackEg[sp], stackPhase[sp]
    sp = sp - 1
end

-- Passes the move (null move pruning)
local function makeNull()
    sp = sp + 1
    stackEp[sp], stackHalf[sp], stackHash[sp] = ep, halfmove, hash
    hash = hash - ZEP[ep]
    ep = 0
    halfmove = 0 -- also stops the repetition scan going back past the null move
    if side == 1 then hash = hash + ZSIDE else hash = hash - ZSIDE end
    side = -side
end

local function unmakeNull()
    side = -side
    ep, halfmove, hash = stackEp[sp], stackHalf[sp], stackHash[sp]
    sp = sp - 1
end

-- Move lists, one per ply, reused
local moveLists, scoreLists = {}, {}
for ply = 0, MAX_PLY + 1 do
    moveLists[ply], scoreLists[ply] = {}, {}
end

function Engine.MoveToUCI(m)
    local promo = floor(m / PROMO) % 8
    return NAME[m % TO] .. NAME[floor(m / TO) % TO] .. (PROMO_LETTER[promo] or "")
end

-- Counts leaf nodes depth plies deep (checks the move generator against Rules)
local function perft(depth, ply)
    local list = moveLists[ply]
    local n = generate(list, false)
    local nodes = 0
    for i = 1, n do
        local m = list[i]
        makeMove(m)
        if not isAttacked(kingSq[-side], side) then
            nodes = nodes + ((depth == 1) and 1 or perft(depth - 1, ply + 1))
        end
        unmakeMove(m)
    end
    return nodes
end

function Engine.Perft(pos, depth)
    Engine.SetPosition(pos)
    if depth == 0 then return 1 end
    return perft(depth, 0)
end

-- Evaluation ------------------------------------------------------------------

-- From the side to move's point of view, in centipawns
local function evaluate()
    local p = (phase > 24) and 24 or phase
    return floor((mg * p + eg * (24 - p)) / 24) * side
end

-- Whether side s has anything besides pawns and the king (null move is unsafe
-- in pawn endings, where zugzwang is common)
local function hasPieces(s)
    for i = 1, 64 do
        local v = board[SQUARES[i]] * s
        if v > PAWN and v < KING then
            return true
        end
    end
    return false
end

-- Search ----------------------------------------------------------------------

-- Transposition table: hash -> one packed number,
-- ((move * 64 + depth) * 4 + bound) * 65536 + score + 32768
local BOUND_EXACT, BOUND_LOWER, BOUND_UPPER = 0, 1, 2
local TT_LIMIT = 100000 -- entries (about 4 MB); the table starts again when full
local tt, ttCount = {}, 0

local killers1, killers2 = {}, {}
local history = {} -- quiet move scores by (piece + 6) * 128 + to

local nodes = 0
local stopped = false
local canStop = false     -- the first iteration always finishes
local gameHashes = {}     -- positions earlier in the game (repetitions)
local rootBest, rootScore = 0, 0
local rootFirst = 0       -- the previous iteration's best move, searched first at the root
local clock, startTime, timeLimit, nodeLimit
local yieldFn, sliceStart, sliceLimit

local function checkTime()
    local now = clock()
    if canStop and ((timeLimit and now - startTime >= timeLimit) or (nodeLimit and nodes >= nodeLimit)) then
        stopped = true
    end
    if yieldFn and now - sliceStart >= sliceLimit then
        yieldFn()
        sliceStart = clock()
    end
end

local function isRepetition()
    if gameHashes[hash] then
        return true
    end
    local k = sp - 1
    local limit = sp - halfmove
    while k > limit and k >= 1 do
        if stackHash[k] == hash then
            return true
        end
        k = k - 2
    end
    return false
end

-- Ordering score for a capture or promotion (0 for a quiet move)
local function captureScore(m)
    local to = floor(m / TO) % TO
    local victim = board[to]
    local promo = floor(m / PROMO) % 8
    local score = 0
    if victim ~= EMPTY then
        local attacker = board[m % TO]
        score = ORDER_VALUE[(victim < 0) and -victim or victim] * 10 - ((attacker < 0) and -attacker or attacker)
    elseif floor(m / FLAG) == FLAG_EP then
        score = ORDER_VALUE[PAWN] * 10 - PAWN
    end
    if promo > 0 then
        score = score + ORDER_VALUE[promo] * 10
    end
    return score
end

-- Moves the best scored move left in list (from i on) to i
local function pickMove(list, scores, i, n)
    local best, bestScore = i, scores[i]
    for j = i + 1, n do
        if scores[j] > bestScore then
            best, bestScore = j, scores[j]
        end
    end
    if best ~= i then
        list[i], list[best] = list[best], list[i]
        scores[i], scores[best] = scores[best], scores[i]
    end
end

local function quiesce(alpha, beta, ply)
    nodes = nodes + 1
    if nodes % 256 == 0 then checkTime() end
    if stopped then return 0 end

    local stand = evaluate()
    if stand >= beta or ply >= MAX_PLY then
        return stand
    end
    if stand > alpha then
        alpha = stand
    end

    local list, scores = moveLists[ply], scoreLists[ply]
    local n = generate(list, true)
    for i = 1, n do
        scores[i] = captureScore(list[i])
    end

    local best = stand
    for i = 1, n do
        pickMove(list, scores, i, n)
        local m = list[i]
        -- Delta pruning: skip captures that can't lift the score near alpha
        local victim = board[floor(m / TO) % TO]
        local gain = (victim == EMPTY) and 100 or ORDER_VALUE[(victim < 0) and -victim or victim]
        if floor(m / PROMO) % 8 > 0 or stand + gain + 200 > alpha then
            makeMove(m)
            if isAttacked(kingSq[-side], side) then
                unmakeMove(m)
            else
                local score = -quiesce(-beta, -alpha, ply + 1)
                unmakeMove(m)
                if stopped then return 0 end
                if score > best then
                    best = score
                    if score > alpha then
                        if score >= beta then
                            return score
                        end
                        alpha = score
                    end
                end
            end
        end
    end
    return best
end

local function search(depth, alpha, beta, ply, allowNull)
    if ply > 0 and (halfmove >= 100 or isRepetition()) then
        return 0
    end

    local inCheck = isAttacked(kingSq[side], -side)
    if inCheck then
        depth = depth + 1
    end
    if depth <= 0 then
        return quiesce(alpha, beta, ply)
    end
    if ply >= MAX_PLY then
        return evaluate()
    end

    nodes = nodes + 1
    if nodes % 256 == 0 then checkTime() end
    if stopped then return 0 end

    -- Transposition table: a move to try first, maybe a score
    local ttMove = 0
    local entry = tt[hash]
    if entry then
        local score = entry % 65536 - 32768
        local rest = floor(entry / 65536)
        local bound = rest % 4
        rest = floor(rest / 4)
        ttMove = floor(rest / 64)
        if ply > 0 and rest % 64 >= depth then
            if score > MATE - MAX_PLY then
                score = score - ply
            elseif score < -MATE + MAX_PLY then
                score = score + ply
            end
            if bound == BOUND_EXACT or (bound == BOUND_LOWER and score >= beta) or (bound == BOUND_UPPER and score <= alpha) then
                return score
            end
        end
    end

    -- Null move: if passing still beats beta, a real move surely does
    if allowNull and not inCheck and depth >= 3 and ply > 0 and beta < MATE - MAX_PLY
        and evaluate() >= beta and hasPieces(side) then
        makeNull()
        local score = -search(depth - 3, -beta, -beta + 1, ply + 1, false)
        unmakeNull()
        if stopped then return 0 end
        if score >= beta then
            return beta
        end
    end

    local list, scores = moveLists[ply], scoreLists[ply]
    local n = generate(list, false)
    local k1, k2 = killers1[ply], killers2[ply]
    for i = 1, n do
        local m = list[i]
        if ply == 0 and m == rootFirst then
            -- Not left to the TT, which may have been emptied: an unfinished
            -- iteration's result relies on this move being searched first
            scores[i] = 4000000
        elseif m == ttMove then
            scores[i] = 3000000
        else
            local c = captureScore(m)
            if c > 0 then
                scores[i] = 2000000 + c
            elseif m == k1 then
                scores[i] = 1900000
            elseif m == k2 then
                scores[i] = 1800000
            else
                scores[i] = history[(board[m % TO] + 6) * 128 + floor(m / TO) % TO] or 0
            end
        end
    end

    local best, bestMove, legal = -INF, 0, 0
    local origAlpha = alpha
    for i = 1, n do
        pickMove(list, scores, i, n)
        local m = list[i]
        local to = floor(m / TO) % TO
        local quiet = board[to] == EMPTY and floor(m / PROMO) % 8 == 0 and floor(m / FLAG) ~= FLAG_EP
        local piece = board[m % TO]

        makeMove(m)
        if isAttacked(kingSq[-side], side) then
            unmakeMove(m)
        else
            legal = legal + 1
            local score
            if legal == 1 then
                score = -search(depth - 1, -beta, -alpha, ply + 1, true)
            else
                -- Late quiet moves are searched less deep first: not at the root or
                -- on the main line (beta - alpha > 1), and not checks
                local reduction = 0
                if quiet and ply > 0 and beta - alpha == 1 and depth >= 3 and legal > 3 and not inCheck
                    and not isAttacked(kingSq[side], -side) then
                    reduction = (legal > 8 and depth >= 5) and 2 or 1
                end
                score = -search(depth - 1 - reduction, -alpha - 1, -alpha, ply + 1, true)
                if score > alpha and reduction > 0 then
                    score = -search(depth - 1, -alpha - 1, -alpha, ply + 1, true)
                end
                if score > alpha and score < beta then
                    score = -search(depth - 1, -beta, -alpha, ply + 1, true)
                end
            end
            unmakeMove(m)
            if stopped then return 0 end

            if score > best then
                best, bestMove = score, m
                if ply == 0 then
                    rootBest, rootScore = m, score
                end
                if score > alpha then
                    alpha = score
                    if score >= beta then
                        if quiet then
                            if m ~= k1 then
                                killers2[ply], killers1[ply] = k1, m
                            end
                            local key = (piece + 6) * 128 + to
                            history[key] = (history[key] or 0) + depth * depth
                        end
                        break
                    end
                end
            end
        end
    end

    if legal == 0 then
        return inCheck and (-MATE + ply) or 0
    end

    if ttCount >= TT_LIMIT then
        tt, ttCount = {}, 0
    end
    if tt[hash] == nil then
        ttCount = ttCount + 1
    end
    local bound = (best >= beta) and BOUND_LOWER or ((best > origAlpha) and BOUND_EXACT or BOUND_UPPER)
    local stored = best
    if stored > MATE - MAX_PLY then
        stored = stored + ply
    elseif stored < -MATE + MAX_PLY then
        stored = stored - ply
    end
    tt[hash] = ((bestMove * 64 + ((depth > 63) and 63 or depth)) * 4 + bound) * 65536 + stored + 32768
    return best
end

-- Legal moves at the current position, as a new list
local function legalMoves()
    local list = {}
    local n = generate(moveLists[0], false)
    for i = 1, n do
        local m = moveLists[0][i]
        makeMove(m)
        if not isAttacked(kingSq[-side], side) then
            list[#list + 1] = m
        end
        unmakeMove(m)
    end
    return list
end

local function defaultClock()
    return os.clock() * 1000
end

-- Searches pos (a rules engine position) for the side to move. opts:
--   depth       deepest iteration (default 64)
--   time        stop after this many ms (the first iteration always finishes)
--   nodes       stop after this many nodes
--   noise       centipawns: score every root move fully and add up to +-noise
--               of random error before choosing (weaker play, and variety)
--   randomMove  chance (0-1) of playing a random legal move instead
--   history     set of Engine.Hash values of earlier positions (repetitions)
--   clock       function returning ms (default os.clock)
--   yield, slice  call yield() after every slice ms of searching
--   random      function(n) returning 1..n (default math.random)
-- Returns { move = uci, score, depth, nodes, time } or nil if there is no legal
-- move. score is in centipawns for the side to move; mates are near +-Engine.Mate.
function Engine.Search(pos, opts)
    opts = opts or {}
    Engine.SetPosition(pos)
    if kingSq[1] == 0 or kingSq[-1] == 0 then
        return nil
    end

    clock = opts.clock or defaultClock
    timeLimit, nodeLimit = opts.time, opts.nodes
    yieldFn, sliceLimit = opts.yield, opts.slice or 10
    startTime = clock()
    sliceStart = startTime
    gameHashes = opts.history or {}
    local random = opts.random or math.random
    local maxDepth = opts.depth or 64
    nodes, stopped, canStop = 0, false, false

    -- History scores fade between searches; killers are per position
    for key, value in pairs(history) do
        history[key] = floor(value / 8)
    end
    for ply = 0, MAX_PLY do
        killers1[ply], killers2[ply] = nil, nil
    end

    local moves = legalMoves()
    local function result(m, score, depth)
        return { move = Engine.MoveToUCI(m), score = score, depth = depth, nodes = nodes, time = clock() - startTime }
    end
    if #moves == 0 then
        return nil
    elseif #moves == 1 then
        return result(moves[1], 0, 0)
    elseif opts.randomMove and random(1000) <= opts.randomMove * 1000 then
        return result(moves[random(#moves)], 0, 0)
    end

    local noise = opts.noise or 0
    if noise > 0 then
        -- Score every root move with a full window, deepening while there's time,
        -- then pick the best after adding the noise
        local scores = {}
        local depthDone = 0
        for depth = 1, maxDepth do
            local current = {}
            for i, m in ipairs(moves) do
                makeMove(m)
                current[i] = -search(depth - 1, -INF, INF, 1, true)
                unmakeMove(m)
                if stopped then break end
            end
            if stopped then break end
            scores, depthDone = current, depth
            canStop = true
            if timeLimit and clock() - startTime > timeLimit / 2 then break end
        end
        local bestIndex, bestValue = 1, -INF
        for i = 1, #moves do
            local value = scores[i] + random(2 * noise + 1) - noise - 1
            if value > bestValue then
                bestIndex, bestValue = i, value
            end
        end
        return result(moves[bestIndex], scores[bestIndex], depthDone)
    end

    local bestMove, bestScore, depthDone = moves[1], 0, 0
    for depth = 1, maxDepth do
        rootBest = 0
        rootFirst = (depth > 1) and bestMove or 0
        local score = search(depth, -INF, INF, 0, false)
        if stopped then
            -- The previous best is searched first, so anything found in the
            -- unfinished iteration beat it
            if rootBest ~= 0 then
                bestMove, bestScore = rootBest, rootScore
            end
            break
        end
        bestMove, bestScore, depthDone = rootBest, score, depth
        canStop = true
        -- A forced mate won't change; and the next iteration would take longer than what's left
        if score > MATE - MAX_PLY or score < -MATE + MAX_PLY then break end
        if timeLimit and clock() - startTime > timeLimit / 2 then break end
    end
    return result(bestMove, bestScore, depthDone)
end

-- Forgets the transposition table (a new game)
function Engine.Clear()
    tt, ttCount = {}, 0
    history = {}
end

return Engine
