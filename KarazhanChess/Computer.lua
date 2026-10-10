-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Games against the computer: difficulty levels, turns, results
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Rules, Engine = ns.Rules, ns.Engine

-- A game against the computer runs in Play mode. The player has one colour; the
-- board only lets them move it, on their turn (Game.enforceTurns). The engine
-- thinks in a coroutine resumed every frame for a few ms, so the game never
-- freezes, and its move is played through Game:ExecuteMove.
--
-- The < > buttons work as in free play: a move made from an earlier position
-- (on the player's turn) replaces the moves after it, so it doubles as a takeback.
local Computer = {}
ns.Computer = Computer

-- Difficulty levels, named like the puzzle tiers. The engine settings:
--   depth         deepest search (plies)
--   time          think time limit in ms
--   noise         random error in centipawns added to each move's score
--   randomMove    chance of a completely random move
--   openingNoise  noise for the first OpeningMoves moves only (variety at the
--                 strong levels, which otherwise play the same game every time)
-- The ratings are rough guesses.
Computer.Levels = {
    { key = "RaidFinder", name = "Raid Finder", desc = "Beginner, blunders often", depth = 1, noise = 150, randomMove = 0.05 },
    { key = "Normal", name = "Normal", desc = "Casual, sees simple tactics", depth = 2, noise = 60 },
    { key = "Heroic", name = "Heroic", desc = "Club player", depth = 3, noise = 20, time = 2000 },
    { key = "Mythic", name = "Mythic", desc = "Strong", time = 2000, openingNoise = 15 },
    { key = "CuttingEdge", name = "Cutting Edge", desc = "Full strength", time = 5000, openingNoise = 8 },
}
Computer.DefaultLevel = "Normal"
Computer.OpeningMoves = 5    -- full moves with openingNoise
Computer.OpeningDepth = 4    -- search depth for those
Computer.MaxTime = 10000     -- ms; a safety limit for levels limited by depth
Computer.MaxNodes = 3000000  -- a safety limit, should the clock misbehave
Computer.FrameBudget = 8     -- ms of searching per frame
Computer.MinThinkTime = 0.6  -- seconds, so a quick reply doesn't appear instantly

Computer.active = false      -- a game against the computer is on (maybe suspended)
Computer.suspended = false   -- in puzzle mode; resumed on return to Play
Computer.token = 0           -- bumped to drop a search that is no longer wanted

-- Settings and results -------------------------------------------------------

-- KC.db.global.computer = { level, colour ("w", "b" or "random"),
-- record = { [level key] = { won, lost, drawn } } }
function Computer:GetSettings()
    return KC.db.global.computer
end

function Computer:GetLevel(key)
    key = key or self:GetSettings().level
    for _, level in ipairs(Computer.Levels) do
        if level.key == key then
            return level
        end
    end
    return Computer.Levels[2]
end

function Computer:GetRecord(key)
    local records = self:GetSettings().record
    if not records[key] then
        records[key] = { won = 0, lost = 0, drawn = 0 }
    end
    return records[key]
end

-- Starting and stopping ------------------------------------------------------

-- Starts a game against the computer at level (a key) with the player as colour
-- ("w", "b" or "random"), from the start position or from fen
function Computer:Start(levelKey, colour, fen)
    local game = KC.game
    self:Stop()
    if (colour == "random") then
        colour = (math.random(2) == 1) and "w" or "b"
    end

    if fen then
        local turn, err = game:LoadFEN(fen)
        if not turn then
            return nil, err
        end
    else
        game:StartNewGame()
    end

    Engine.Clear()
    self:GetSettings().level = levelKey
    self.active = true
    self.suspended = false
    self.level = self:GetLevel(levelKey)
    self.playerColour = colour
    self.result = nil
    self:Attach()
    KC:SetBoardFlipped(colour == "b")
    self:Continue()
    return true
end

-- Ends the game against the computer (back to free play, board left as it is)
function Computer:Stop()
    if not self.active then
        return
    end
    self:CancelThinking()
    if not self.suspended then
        -- (Suspended, the board belongs to puzzles and the game is already let go)
        self:Detach()
        KC:SetStatus(nil)
    end
    self.active = false
    self.suspended = false
end

-- Puzzles take over the board: stop thinking and let go of the game
function Computer:Suspend()
    if (self.active and not self.suspended) then
        self:CancelThinking()
        self:Detach()
        self.suspended = true
    end
end

-- Back from puzzles (the board is already restored)
function Computer:Resume()
    if (self.active and self.suspended) then
        self.suspended = false
        self:Attach()
        self:Continue()
    end
end

function Computer:Attach()
    local game = KC.game
    game.announceResults = false
    game.enforceTurns = true
    game.onPlayerMove = function() self:Continue() end
end

function Computer:Detach()
    local game = KC.game
    game.onPlayerMove = nil
    game.enforceTurns = false
    game.allowedColour = nil
    game.announceResults = true
end

-- Turns ----------------------------------------------------------------------

-- The latest position in the game (the computer always plays on from there)
local function latest()
    local game = KC.game
    return game.history[#game.history].pos
end

-- After every move: is the game over, and whose turn is it?
function Computer:Continue()
    local game = KC.game
    self.result = self.result or self:GetResult()
    if self.result then
        self:Finish()
        return
    end

    if (latest().turn == self.playerColour) then
        game.allowedColour = self.playerColour
        self:ShowStatus()
    else
        game.allowedColour = false
        self:Think()
    end
end

-- The engine settings for the next move
function Computer:GetSearchOptions(pos)
    local level = self.level
    local opts = {
        depth = level.depth,
        time = level.time or Computer.MaxTime,
        nodes = Computer.MaxNodes,
        noise = level.noise,
        randomMove = level.randomMove,
    }
    if (level.openingNoise and (pos.fullmove or 1) <= Computer.OpeningMoves) then
        opts.noise = level.openingNoise
        opts.depth = Computer.OpeningDepth
    end
    return opts
end

-- Milliseconds. GetTimePreciseSec rather than debugprofilestop, which any addon
-- can reset with debugprofilestart.
function Computer.Clock()
    if GetTimePreciseSec then
        return GetTimePreciseSec() * 1000
    end
    return debugprofilestop()
end

-- Starts the engine on the latest position; it plays its move when done
function Computer:Think()
    local game = KC.game
    self:CancelThinking()
    local token = self.token
    local pos = Rules.Copy(latest())

    -- Earlier positions, so the engine sees repetitions coming
    local seen = {}
    for i = 1, #game.history - 1 do
        seen[Engine.Hash(game.history[i].pos)] = true
    end

    local opts = self:GetSearchOptions(pos)
    opts.history = seen
    opts.clock = Computer.Clock
    opts.yield = coroutine.yield
    opts.slice = Computer.FrameBudget

    local thread = coroutine.create(function() return Engine.Search(pos, opts) end)
    local started = GetTime()
    local result

    self.thinking = true
    self:ShowStatus()

    if not self.driver then
        self.driver = CreateFrame("FRAME")
    end
    self.driver:SetScript("OnUpdate", function()
        if (token ~= self.token) then
            return
        end
        if (coroutine.status(thread) ~= "dead") then
            local ok, value = coroutine.resume(thread)
            if not ok then
                self:CancelThinking()
                geterrorhandler()(value)
                return
            end
            result = value
            if (coroutine.status(thread) ~= "dead") then
                return
            end
        end
        -- Done: wait out the minimum think time, then move
        if (GetTime() - started >= Computer.MinThinkTime) then
            self:CancelThinking()
            self:PlayMove(result)
        end
    end)
end

function Computer:CancelThinking()
    self.token = self.token + 1
    self.thinking = false
    if self.driver then
        self.driver:SetScript("OnUpdate", nil)
    end
end

function Computer:PlayMove(result)
    if not (result and KC.game:ExecuteMove(result.move)) then
        -- Shouldn't happen: the engine had no move, or one the board refused
        KC:Print("The computer couldn't find a move"..(result and (" ("..result.move..")") or "")..".")
        self.result = { kind = "error" }
        self:Finish()
        return
    end
    self:Continue()
end

-- Results --------------------------------------------------------------------

local function otherColour(colour)
    return (colour == "w") and "b" or "w"
end

-- Position key for repetitions: placement, side to move, castling, en passant
local function repetitionKey(pos)
    return (Rules.ToFEN(pos):match("^(%S+ %S+ %S+ %S+)"))
end

-- Neither side can mate: bare kings, or a lone knight or bishop
local function insufficientMaterial(pos)
    local minors = 0
    for sq = 1, 64 do
        local letter = pos.board[sq]
        if letter then
            local kind = Rules.Type[letter]
            if (kind == "n" or kind == "b") then
                minors = minors + 1
            elseif (kind ~= "k") then
                return false
            end
        end
    end
    return minors <= 1
end

-- How the game ended at the latest position, or nil if it goes on:
-- { kind = "checkmate" | "stalemate" | "repetition" | "fifty" | "material", winner = colour or nil }
function Computer:GetResult()
    local game = KC.game
    local pos = latest()
    local status = Rules.GetStatus(Rules.Copy(pos))
    if (status == "checkmate") then
        return { kind = "checkmate", winner = otherColour(pos.turn) }
    elseif (status == "stalemate") then
        return { kind = "stalemate" }
    elseif insufficientMaterial(pos) then
        return { kind = "material" }
    elseif ((pos.halfmove or 0) >= 100) then
        return { kind = "fifty" }
    end

    local key, count = repetitionKey(pos), 0
    for _, entry in ipairs(game.history) do
        if (repetitionKey(entry.pos) == key) then
            count = count + 1
        end
    end
    if (count >= 3) then
        return { kind = "repetition" }
    end
end

local DrawReasons = {
    stalemate = "Stalemate",
    repetition = "Threefold repetition",
    fifty = "Fifty moves without a capture or pawn move",
    material = "Neither side can checkmate",
}

-- The game is over: no more moves (< > still step through it), and the result
-- counts once towards the level's record
function Computer:Finish()
    local game = KC.game
    game.allowedColour = false
    game:DeselectPiece()

    local result = self.result
    if (not result.recorded and result.kind ~= "error") then
        result.recorded = true
        local record = self:GetRecord(self.level.key)
        if (result.winner == nil) then
            record.drawn = record.drawn + 1
        elseif (result.winner == self.playerColour) then
            record.won = record.won + 1
        else
            record.lost = record.lost + 1
        end
    end
    self:ShowStatus()
end

-- Info bar --------------------------------------------------------------------

local function sideName(colour)
    return (colour == "w") and "White" or "Black"
end

function Computer:GetRecordLine()
    local record = self:GetRecord(self.level.key)
    return self.level.name.." · Won "..record.won.." · Lost "..record.lost.." · Drawn "..record.drawn
end

function Computer:ShowStatus()
    if not (self.active and not self.suspended) then
        return
    end
    local C = ns.Colours
    local footer = self:GetRecordLine()
    local versus = "You play "..sideName(self.playerColour).." against the "..self.level.name.." computer"
    local result = self.result

    if result then
        if (result.kind == "error") then
            KC:SetStatus("Game over", C.Bad, "The computer couldn't move.", footer)
        elseif (result.winner == self.playerColour) then
            KC:SetStatus("Victory!", C.Good, "Checkmate. "..sideName(result.winner).." wins.", footer)
        elseif result.winner then
            KC:SetStatus("Defeat", C.Bad, "Checkmate. "..sideName(result.winner).." wins.", footer)
        else
            KC:SetStatus("Draw", C.Neutral, DrawReasons[result.kind], footer)
        end
    elseif self.thinking then
        KC:SetStatus("Thinking...", C.Neutral, versus, footer)
    else
        local inCheck = Rules.InCheck(latest(), self.playerColour)
        KC:SetStatus(inCheck and "Check!" or "Your move", inCheck and C.Bad or C.Normal, versus, footer)
    end
end
