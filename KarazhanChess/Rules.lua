-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Chess Rules Engine (pure Lua 5.1, no WoW API, so it also runs offline)
-------------------------------------------------------------------------------

-- Works on a position snapshot, not on the board frames:
--   pos.board[sq]  piece letter ("PNBRQK" white, "pnbrqk" black) or nil
--   pos.turn       "w" or "b"
--   pos.castling   { K = bool, Q = bool, k = bool, q = bool }
--   pos.ep         en passant target square (the square passed over) or nil
--   pos.halfmove, pos.fullmove
-- Squares are 1-64: sq = (row - 1) * 8 + col, so a1 = 1, h1 = 8, a8 = 57, h8 = 64.
--
-- A move is a table: { from, to, piece, captured, capSq, promotion, flag,
-- rookFrom, rookTo }. flag is nil, "double" (two-square pawn push), "ep" (en
-- passant capture) or "castle". promotion is the new piece's letter.
--
-- Outside WoW (tests and the puzzle builder) the file is run with no namespace,
-- so it makes its own and returns Rules.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.Rules = Rules

Rules.StartFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local floor = math.floor
local sub, upper, lower, byte = string.sub, string.upper, string.lower, string.byte

-- Lookups ---------------------------------------------------------------------

local FILES = "abcdefgh"

local COLOUR, TYPE = {}, {}
for _, p in ipairs({ "P", "N", "B", "R", "Q", "K" }) do
    COLOUR[p], TYPE[p] = "w", lower(p)
    COLOUR[lower(p)], TYPE[lower(p)] = "b", lower(p)
end
Rules.Colour, Rules.Type = COLOUR, TYPE

local OTHER = { w = "b", b = "w" }

local COL, ROW = {}, {}
for sq = 1, 64 do
    COL[sq] = (sq - 1) % 8 + 1
    ROW[sq] = floor((sq - 1) / 8) + 1
end

local function index(col, row)
    if col < 1 or col > 8 or row < 1 or row > 8 then
        return nil
    end
    return (row - 1) * 8 + col
end
Rules.Index = index

function Rules.Col(sq) return COL[sq] end
function Rules.Row(sq) return ROW[sq] end

-- "e4" <-> 29
function Rules.SquareName(sq)
    return sub(FILES, COL[sq], COL[sq]) .. ROW[sq]
end

function Rules.SquareIndex(name)
    if type(name) ~= "string" or #name ~= 2 then
        return nil
    end
    local col = byte(name, 1) - 96
    local row = byte(name, 2) - 48
    return index(col, row)
end

-- Precomputed targets: knight and king jumps, and the rays sliders travel along
local ORTHOGONAL = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local DIAGONAL = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local KNIGHT = { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }

local KNIGHT_TARGETS, KING_TARGETS, ORTHO_RAYS, DIAG_RAYS = {}, {}, {}, {}
for sq = 1, 64 do
    local c, r = COL[sq], ROW[sq]

    local function jumps(offsets)
        local list = {}
        for _, o in ipairs(offsets) do
            local t = index(c + o[1], r + o[2])
            if t then list[#list + 1] = t end
        end
        return list
    end

    local function rays(dirs)
        local list = {}
        for _, d in ipairs(dirs) do
            local ray = {}
            local cc, rr = c + d[1], r + d[2]
            while index(cc, rr) do
                ray[#ray + 1] = index(cc, rr)
                cc, rr = cc + d[1], rr + d[2]
            end
            list[#list + 1] = ray
        end
        return list
    end

    KNIGHT_TARGETS[sq] = jumps(KNIGHT)
    KING_TARGETS[sq] = jumps({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } })
    ORTHO_RAYS[sq] = rays(ORTHOGONAL)
    DIAG_RAYS[sq] = rays(DIAGONAL)
end

-- Castling: king from e1/e8 to g or c, the rook jumps to the square passed over.
-- "empty" must be free; the king must not be attacked on "safe" (its start,
-- the square it crosses and where it lands).
local CASTLES = {
    { right = "K", colour = "w", kingFrom = 5,  kingTo = 7,  rookFrom = 8,  rookTo = 6,  empty = { 6, 7 },      safe = { 5, 6, 7 } },
    { right = "Q", colour = "w", kingFrom = 5,  kingTo = 3,  rookFrom = 1,  rookTo = 4,  empty = { 2, 3, 4 },   safe = { 5, 4, 3 } },
    { right = "k", colour = "b", kingFrom = 61, kingTo = 63, rookFrom = 64, rookTo = 62, empty = { 62, 63 },    safe = { 61, 62, 63 } },
    { right = "q", colour = "b", kingFrom = 61, kingTo = 59, rookFrom = 57, rookTo = 60, empty = { 58, 59, 60 }, safe = { 61, 60, 59 } },
}
Rules.Castles = CASTLES

-- Moving from or to one of these squares loses the castling right
local CASTLE_RIGHT_SQUARES = { [1] = { "Q" }, [8] = { "K" }, [5] = { "K", "Q" }, [57] = { "q" }, [64] = { "k" }, [61] = { "k", "q" } }

-- Positions -------------------------------------------------------------------

function Rules.NewPosition()
    return {
        board = {},
        turn = "w",
        castling = { K = false, Q = false, k = false, q = false },
        ep = nil,
        halfmove = 0,
        fullmove = 1,
    }
end

function Rules.Copy(pos)
    local copy = Rules.NewPosition()
    for sq = 1, 64 do copy.board[sq] = pos.board[sq] end
    for k, v in pairs(pos.castling) do copy.castling[k] = v end
    copy.turn, copy.ep, copy.halfmove, copy.fullmove = pos.turn, pos.ep, pos.halfmove, pos.fullmove
    return copy
end

-- Parses a FEN string. Returns the position, or nil and an error message.
function Rules.FromFEN(fen)
    if type(fen) ~= "string" then
        return nil, "FEN is not a string"
    end
    local placement, turn, castling, ep, halfmove, fullmove =
        fen:match("^%s*(%S+)%s+([wb])%s+(%S+)%s+(%S+)%s*(%d*)%s*(%d*)%s*$")
    if not placement then
        return nil, "malformed FEN"
    end

    local pos = Rules.NewPosition()
    local row, col = 8, 1
    for i = 1, #placement do
        local ch = sub(placement, i, i)
        if ch == "/" then
            if col ~= 9 then return nil, "bad rank length" end
            row, col = row - 1, 1
        elseif ch:match("%d") then
            col = col + tonumber(ch)
        elseif COLOUR[ch] then
            local sq = index(col, row)
            if not sq then return nil, "piece off the board" end
            pos.board[sq] = ch
            col = col + 1
        else
            return nil, "bad piece letter " .. ch
        end
        if col > 9 then return nil, "rank too long" end
    end
    if row ~= 1 or col ~= 9 then
        return nil, "wrong number of squares"
    end

    pos.turn = turn
    if castling ~= "-" then
        for i = 1, #castling do
            local ch = sub(castling, i, i)
            if pos.castling[ch] == nil then return nil, "bad castling field" end
            pos.castling[ch] = true
        end
    end
    if ep ~= "-" then
        pos.ep = Rules.SquareIndex(ep)
        if not pos.ep then return nil, "bad en passant square" end
    end
    pos.halfmove = tonumber(halfmove) or 0
    pos.fullmove = tonumber(fullmove) or 1
    return pos
end

function Rules.ToFEN(pos)
    local ranks = {}
    for row = 8, 1, -1 do
        local rank, empty = "", 0
        for col = 1, 8 do
            local p = pos.board[index(col, row)]
            if p then
                if empty > 0 then rank = rank .. empty end
                rank, empty = rank .. p, 0
            else
                empty = empty + 1
            end
        end
        if empty > 0 then rank = rank .. empty end
        ranks[#ranks + 1] = rank
    end

    local castling = ""
    for _, k in ipairs({ "K", "Q", "k", "q" }) do
        if pos.castling[k] then castling = castling .. k end
    end
    if castling == "" then castling = "-" end

    return table.concat(ranks, "/") .. " " .. pos.turn .. " " .. castling .. " "
        .. (pos.ep and Rules.SquareName(pos.ep) or "-") .. " " .. pos.halfmove .. " " .. pos.fullmove
end

function Rules.FindKing(pos, colour)
    local king = colour == "w" and "K" or "k"
    for sq = 1, 64 do
        if pos.board[sq] == king then return sq end
    end
end

-- Attacks ---------------------------------------------------------------------

-- Is sq attacked by any piece of colour "by"?
function Rules.IsAttacked(pos, sq, by)
    local board = pos.board
    local white = by == "w"
    local c, r = COL[sq], ROW[sq]

    -- Pawns attack diagonally forward, so look diagonally backward from sq
    local pawn = white and "P" or "p"
    local pr = white and r - 1 or r + 1
    local t = index(c - 1, pr)
    if t and board[t] == pawn then return true end
    t = index(c + 1, pr)
    if t and board[t] == pawn then return true end

    local knight = white and "N" or "n"
    for _, t in ipairs(KNIGHT_TARGETS[sq]) do
        if board[t] == knight then return true end
    end

    local king = white and "K" or "k"
    for _, t in ipairs(KING_TARGETS[sq]) do
        if board[t] == king then return true end
    end

    local rook, bishop, queen = white and "R" or "r", white and "B" or "b", white and "Q" or "q"
    for _, ray in ipairs(ORTHO_RAYS[sq]) do
        for _, t in ipairs(ray) do
            local p = board[t]
            if p then
                if p == rook or p == queen then return true end
                break
            end
        end
    end
    for _, ray in ipairs(DIAG_RAYS[sq]) do
        for _, t in ipairs(ray) do
            local p = board[t]
            if p then
                if p == bishop or p == queen then return true end
                break
            end
        end
    end
    return false
end

-- Is colour's king attacked? (False if it has no king, e.g. on a cleared board.)
function Rules.InCheck(pos, colour)
    local king = Rules.FindKing(pos, colour)
    return king ~= nil and Rules.IsAttacked(pos, king, OTHER[colour])
end

-- Move generation -------------------------------------------------------------

local PROMOTIONS = { "q", "r", "b", "n" }

-- Pseudo-legal moves for colour (default: side to move). Kings are never
-- captured: in a legal game that can't happen, and on a free-play board without
-- turns it keeps the old "kings aren't capturable" behaviour.
function Rules.GeneratePseudoMoves(pos, colour)
    colour = colour or pos.turn
    local board = pos.board
    local white = colour == "w"
    local moves = {}

    local function add(from, to, piece, flag)
        local target = board[to]
        moves[#moves + 1] = { from = from, to = to, piece = piece, captured = target, capSq = target and to or nil, flag = flag }
    end

    -- Empty, or an enemy that isn't the king
    local function canLand(t)
        local target = board[t]
        return target == nil or (COLOUR[target] ~= colour and TYPE[target] ~= "k")
    end

    for sq = 1, 64 do
        local piece = board[sq]
        if piece and COLOUR[piece] == colour then
            local kind = TYPE[piece]

            if kind == "p" then
                local dir = white and 1 or -1
                local c, r = COL[sq], ROW[sq]
                local startRow, promoRow = white and 2 or 7, white and 8 or 1

                local function addPawn(to, captured, capSq, flag)
                    if ROW[to] == promoRow then
                        for _, p in ipairs(PROMOTIONS) do
                            moves[#moves + 1] = { from = sq, to = to, piece = piece, captured = captured, capSq = capSq,
                                promotion = white and upper(p) or p }
                        end
                    else
                        moves[#moves + 1] = { from = sq, to = to, piece = piece, captured = captured, capSq = capSq, flag = flag }
                    end
                end

                local one = index(c, r + dir)
                if one and board[one] == nil then
                    addPawn(one)
                    local two = index(c, r + dir * 2)
                    if r == startRow and two and board[two] == nil then
                        addPawn(two, nil, nil, "double")
                    end
                end

                for dc = -1, 1, 2 do
                    local t = index(c + dc, r + dir)
                    if t then
                        local target = board[t]
                        if target and COLOUR[target] ~= colour and TYPE[target] ~= "k" then
                            addPawn(t, target, t)
                        elseif target == nil and t == pos.ep then
                            -- En passant: the captured pawn sits behind the target square
                            local capSq = t - dir * 8
                            local victim = board[capSq]
                            if victim and TYPE[victim] == "p" and COLOUR[victim] ~= colour then
                                addPawn(t, victim, capSq, "ep")
                            end
                        end
                    end
                end

            elseif kind == "n" or kind == "k" then
                for _, t in ipairs(kind == "n" and KNIGHT_TARGETS[sq] or KING_TARGETS[sq]) do
                    if canLand(t) then add(sq, t, piece) end
                end

            else
                local raySets = {}
                if kind == "r" or kind == "q" then raySets[#raySets + 1] = ORTHO_RAYS[sq] end
                if kind == "b" or kind == "q" then raySets[#raySets + 1] = DIAG_RAYS[sq] end
                for _, rays in ipairs(raySets) do
                    for _, ray in ipairs(rays) do
                        for _, t in ipairs(ray) do
                            if canLand(t) then add(sq, t, piece) end
                            if board[t] then break end
                        end
                    end
                end
            end
        end
    end

    -- Castling: the right, the king and rook in place, the squares between empty,
    -- and the king not in check on its start, crossing or landing square
    local enemy = OTHER[colour]
    for _, castle in ipairs(CASTLES) do
        if castle.colour == colour and pos.castling[castle.right]
            and board[castle.kingFrom] == (white and "K" or "k")
            and board[castle.rookFrom] == (white and "R" or "r") then
            local ok = true
            for _, t in ipairs(castle.empty) do
                if board[t] then ok = false break end
            end
            if ok then
                for _, t in ipairs(castle.safe) do
                    if Rules.IsAttacked(pos, t, enemy) then ok = false break end
                end
            end
            if ok then
                moves[#moves + 1] = { from = castle.kingFrom, to = castle.kingTo, piece = board[castle.kingFrom],
                    flag = "castle", rookFrom = castle.rookFrom, rookTo = castle.rookTo }
            end
        end
    end

    return moves
end

-- Plays move on pos (in place) and returns what UnmakeMove needs to take it back
function Rules.MakeMove(pos, move)
    local board = pos.board
    local undo = {
        captured = move.captured, capSq = move.capSq,
        ep = pos.ep, turn = pos.turn, halfmove = pos.halfmove, fullmove = pos.fullmove,
        K = pos.castling.K, Q = pos.castling.Q, k = pos.castling.k, q = pos.castling.q,
    }
    local colour = COLOUR[move.piece]

    if move.capSq then board[move.capSq] = nil end
    board[move.from] = nil
    board[move.to] = move.promotion or move.piece
    if move.flag == "castle" then
        board[move.rookTo] = board[move.rookFrom]
        board[move.rookFrom] = nil
    end

    for _, sq in ipairs({ move.from, move.to }) do
        local rights = CASTLE_RIGHT_SQUARES[sq]
        if rights then
            for _, right in ipairs(rights) do pos.castling[right] = false end
        end
    end

    pos.ep = move.flag == "double" and (colour == "w" and move.from + 8 or move.from - 8) or nil
    pos.halfmove = (TYPE[move.piece] == "p" or move.captured) and 0 or pos.halfmove + 1
    if colour == "b" then pos.fullmove = pos.fullmove + 1 end
    pos.turn = OTHER[colour]
    return undo
end

function Rules.UnmakeMove(pos, move, undo)
    local board = pos.board
    if move.flag == "castle" then
        board[move.rookFrom] = board[move.rookTo]
        board[move.rookTo] = nil
    end
    board[move.to] = nil
    board[move.from] = move.piece
    if undo.capSq then board[undo.capSq] = undo.captured end

    pos.ep, pos.turn, pos.halfmove, pos.fullmove = undo.ep, undo.turn, undo.halfmove, undo.fullmove
    pos.castling.K, pos.castling.Q, pos.castling.k, pos.castling.q = undo.K, undo.Q, undo.k, undo.q
end

-- Legal moves for colour (default: side to move): pseudo-legal moves that don't
-- leave that side's own king in check. from limits it to one square's moves.
function Rules.GenerateLegalMoves(pos, colour, from)
    colour = colour or pos.turn
    local legal = {}
    for _, move in ipairs(Rules.GeneratePseudoMoves(pos, colour)) do
        if from == nil or move.from == from then
            local undo = Rules.MakeMove(pos, move)
            if not Rules.InCheck(pos, colour) then
                legal[#legal + 1] = move
            end
            Rules.UnmakeMove(pos, move, undo)
        end
    end
    return legal
end

-- Game state for the side to move: "checkmate", "stalemate" or nil, and whether
-- that side is in check
function Rules.GetStatus(pos)
    local inCheck = Rules.InCheck(pos, pos.turn)
    if #Rules.GenerateLegalMoves(pos) == 0 then
        return inCheck and "checkmate" or "stalemate", inCheck
    end
    return nil, inCheck
end

-- UCI -------------------------------------------------------------------------

function Rules.MoveToUCI(move)
    return Rules.SquareName(move.from) .. Rules.SquareName(move.to) .. (move.promotion and lower(move.promotion) or "")
end

-- The legal move (for the side to move) matching a UCI string like "e7e8q", or nil
function Rules.FindMove(pos, uci)
    for _, move in ipairs(Rules.GenerateLegalMoves(pos)) do
        if Rules.MoveToUCI(move) == uci then
            return move
        end
    end
end

-- Testing ---------------------------------------------------------------------

-- Counts leaf nodes depth plies deep (the standard move generator check)
function Rules.Perft(pos, depth)
    if depth == 0 then return 1 end
    local moves = Rules.GenerateLegalMoves(pos)
    if depth == 1 then return #moves end
    local nodes = 0
    for _, move in ipairs(moves) do
        local undo = Rules.MakeMove(pos, move)
        nodes = nodes + Rules.Perft(pos, depth - 1)
        Rules.UnmakeMove(pos, move, undo)
    end
    return nodes
end

return Rules
