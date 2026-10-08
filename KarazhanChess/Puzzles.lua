-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Lichess Puzzles: data loading, puzzle flow and the puzzle rating
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Rules, Codec = ns.Rules, ns.PuzzleCodec

-- The flow follows Lichess: the board turns to the solver's side, the opponent's
-- move (the first move in the data) is played, then the player finds the rest.
-- A correct move is answered by the opponent's next move; a wrong one is taken
-- back and the player may try again (the puzzle counts as failed). Any move that
-- gives checkmate solves the puzzle, even if it isn't the move in the data.
local Puzzles = {}
ns.Puzzles = Puzzles

Puzzles.DataAddon = "KarazhanChess_Puzzles"
Puzzles.ReplyDelay = 0.5      -- seconds before the opponent moves
Puzzles.SolutionDelay = 0.8   -- seconds between moves when showing the solution
Puzzles.StartRating = 1500
Puzzles.RatingK = 32          -- Elo K-factor

-- Tiers in difficulty order; the data addon registers each by key
Puzzles.Tiers = {
    { key = "RaidFinder", name = "Raid Finder", range = "below 1200" },
    { key = "Normal", name = "Normal", range = "1200-1599" },
    { key = "Heroic", name = "Heroic", range = "1600-1999" },
    { key = "Mythic", name = "Mythic", range = "2000-2399" },
    { key = "CuttingEdge", name = "Cutting Edge", range = "2400+" },
}
Puzzles.DefaultTier = "Normal"

Puzzles.data = {}       -- registered tiers by key
Puzzles.themeNames = {} -- theme names by code (1-based)
Puzzles.active = false

-- Registration (called by the data addon) ----------------------------------

function KC:RegisterPuzzles(key, data)
    Puzzles.data[key] = data
end

function KC:RegisterPuzzleThemes(names)
    Puzzles.themeNames = names
end

-- Loads the data addon if it isn't already. Returns true, or false and a message.
function Puzzles:EnsureLoaded()
    if next(self.data) then
        return true
    end

    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    local loaded, reason = load(Puzzles.DataAddon)
    if not loaded then
        if reason == "DISABLED" then
            return false, "Enable \"Karazhan Chess Puzzles\" in the AddOns list to play puzzles."
        elseif reason == "MISSING" then
            return false, "The Karazhan Chess Puzzles addon is not installed."
        end
        return false, "Couldn't load the puzzles ("..tostring(reason)..")."
    end
    if not next(self.data) then
        return false, "The puzzle data is empty."
    end
    return true
end

-- Saved progress: KC.db.global.puzzles = { rating, tier, solved = { [id] = true },
-- failed = { [id] = true }, current = id }
function Puzzles:GetProgress()
    return KC.db.global.puzzles
end

function Puzzles:GetTier()
    local key = self:GetProgress().tier
    for _, tier in ipairs(Puzzles.Tiers) do
        if tier.key == key then
            return tier
        end
    end
    return Puzzles.Tiers[2]
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Theme names for display: "mateIn2" -> "Mate in 2", "backRankMate" -> "Back rank mate"
local ThemeLabels = {
    superGM = "Super GM",
    attackingF2F7 = "Attacking f2/f7",
    xRayAttack = "X-ray attack",
    mateIn1 = "Mate in 1", mateIn2 = "Mate in 2", mateIn3 = "Mate in 3",
    mateIn4 = "Mate in 4", mateIn5 = "Mate in 5",
}
function Puzzles:ThemeLabel(name)
    if ThemeLabels[name] then
        return ThemeLabels[name]
    end
    local words = name:gsub("(%u)", " %1"):gsub("(%d+)", " %1"):lower()
    return (words:gsub("^%l", string.upper))
end

-- Entering and leaving puzzle mode -------------------------------------------

-- Switches the board to puzzles: keeps the free-play position to restore later,
-- then resumes the unfinished puzzle or starts a new one
function Puzzles:Enter()
    if self.active then
        return
    end

    local ok, message = self:EnsureLoaded()
    if not ok then
        KC:SetStatus("Puzzles unavailable", ns.Colours.Bad, message)
        return false
    end

    local game = KC.game
    self.active = true
    self.savedFEN = (#game.pieces > 0) and Rules.ToFEN(game:GetPosition("w")) or nil
    self.savedFlip = KC.boardFlipped

    game.announceResults = false
    game.lockHistory = true
    game.onPlayerMove = function(move, uci, undo) self:OnPlayerMove(move, uci, undo) end

    local current = self:GetProgress().current
    local puzzle = current and self:FindPuzzle(current)
    if puzzle and not self:IsAttempted(puzzle.id) then
        self:Start(puzzle)
    else
        self:Next()
    end
    return true
end

-- Back to free play, restoring the board as it was
function Puzzles:Leave()
    if not self.active then
        return
    end
    self.active = false
    self.token = (self.token or 0) + 1

    local game = KC.game
    game.onPlayerMove = nil
    game.allowedColour = nil
    game.announceResults = true
    game.lockHistory = false

    if self.savedFEN then
        game:LoadFEN(self.savedFEN)
    else
        game:ClearBoard()
        game:ResetHistory("w")
    end
    KC:SetBoardFlipped(self.savedFlip or false)
    KC:UpdatePuzzleButtons()
end

-- Choosing puzzles -----------------------------------------------------------

function Puzzles:IsAttempted(id)
    local progress = self:GetProgress()
    return progress.solved[id] or progress.failed[id]
end

-- Decodes the puzzle with this ID from any tier, or nil
function Puzzles:FindPuzzle(id)
    for _, tier in pairs(self.data) do
        local record = Codec.FindRecord(tier, id)
        if record then
            return Codec.Decode(record, self.themeNames)
        end
    end
end

-- A random puzzle from the chosen tier that hasn't been attempted, or any one if
-- every puzzle in the tier has been
function Puzzles:PickPuzzle()
    local tier = self.data[self:GetTier().key]
    if not tier then
        return nil
    end

    local current = self.puzzle and self.puzzle.id
    for _ = 1, 200 do
        local record = Codec.GetRecord(tier, math.random(tier.count))
        local id = Codec.GetId(record)
        if id ~= current and not self:IsAttempted(id) then
            return Codec.Decode(record, self.themeNames)
        end
    end

    -- Random picks keep landing on attempted puzzles, so look through them all
    for i = 1, tier.count do
        local record = Codec.GetRecord(tier, i)
        if not self:IsAttempted(Codec.GetId(record)) then
            return Codec.Decode(record, self.themeNames)
        end
    end

    self.tierFinished = true
    return Codec.Decode(Codec.GetRecord(tier, math.random(tier.count)), self.themeNames)
end

function Puzzles:Next()
    self.tierFinished = false
    local puzzle = self:PickPuzzle()
    if puzzle then
        self:Start(puzzle)
    else
        KC:SetStatus("No puzzles", ns.Colours.Bad, "The "..self:GetTier().name.." tier has no puzzles.")
    end
end

function Puzzles:SetTier(key)
    self:GetProgress().tier = key
    if self.active then
        self:Next()
    end
end

-- Playing a puzzle -----------------------------------------------------------

-- Runs fn after delay seconds, unless another puzzle has started (or puzzles
-- were left) in the meantime
function Puzzles:After(delay, fn)
    local token = self.token
    C_Timer.After(delay, function()
        if self.active and self.token == token then
            fn()
        end
    end)
end

function Puzzles:Start(puzzle)
    local game = KC.game
    self.token = (self.token or 0) + 1
    self.puzzle = puzzle
    self.step = 1          -- index of the next move in puzzle.moves
    self.mistake = false   -- a wrong move was made or the solution was shown
    self.done = false
    self.ratingChange = nil
    self.pendingUndo = nil -- a wrong move still on the board, about to be taken back
    self.feedback = "ready"
    self:GetProgress().current = puzzle.id

    -- The opponent moves first, so the solver is the other side
    game.lockHistory = true
    local opponent = game:LoadPosition(Rules.Copy(puzzle.position))
    self.solver = (opponent == "w") and "b" or "w"
    KC:SetBoardFlipped(self.solver == "b")
    game.allowedColour = false

    self:ShowStatus()
    KC:UpdatePuzzleButtons()
    self:After(Puzzles.ReplyDelay, function()
        self:PlayNextMove()
        game.allowedColour = self.solver
        self.feedback = "turn"
        self:ShowStatus()
    end)
end

-- Plays the next move in the data (the opponent's reply, or any move when
-- showing the solution)
function Puzzles:PlayNextMove()
    KC.game:ExecuteMove(self.puzzle.moves[self.step])
    self.step = self.step + 1
end

function Puzzles:OnPlayerMove(move, uci, undo)
    if self.done then
        return
    end
    local game = KC.game

    -- Right if it's the move in the data, or any move that mates
    local status = Rules.GetStatus(game:GetPosition(self.solver == "w" and "b" or "w"))
    if (uci == self.puzzle.moves[self.step] or status == "checkmate") then
        self.step = self.step + 1
        if (self.step > #self.puzzle.moves or status == "checkmate") then
            self:Finish(true)
            return
        end

        self.feedback = "good"
        game.allowedColour = false
        self:ShowStatus()
        self:After(Puzzles.ReplyDelay, function()
            self:PlayNextMove()
            game.allowedColour = self.solver
            self:ShowStatus()
        end)
    else
        -- Wrong: counts as a failure on the first attempt; take it back after a moment
        if not self.mistake then
            self.mistake = true
            self:RecordResult(false)
        end
        self.feedback = "bad"
        self.pendingUndo = undo
        game.allowedColour = false
        self:ShowStatus()
        KC:UpdatePuzzleButtons()
        self:After(Puzzles.ReplyDelay, function()
            self:TakeBackWrongMove()
            game.allowedColour = self.solver
        end)
    end
end

function Puzzles:TakeBackWrongMove()
    if self.pendingUndo then
        local game = KC.game
        if game:IsAtLatest() then
            game:UndoMove(self.pendingUndo)
            game:PopHistory()
            game:UpdateCheckState(self.solver)
        else
            -- The player is looking at an earlier position: just drop the move
            game:PopHistory()
            game:ShowHistory(#game.history)
        end
        self.pendingUndo = nil
    end
end

-- Plays out the rest of the solution; the puzzle counts as failed
function Puzzles:ShowSolution()
    if (not self.active or self.done or self.puzzle == nil) then
        return
    end
    if not self.mistake then
        self.mistake = true
        self:RecordResult(false)
    end

    local game = KC.game
    game.allowedColour = false
    self.token = self.token + 1
    self.feedback = "solution"
    self:ShowStatus()
    KC:UpdatePuzzleButtons()

    -- A wrong move may still be on the board, waiting to be taken back
    self:TakeBackWrongMove()

    local function playNext()
        if (self.step > #self.puzzle.moves) then
            self:Finish(false)
            return
        end
        self:PlayNextMove()
        self:After(Puzzles.SolutionDelay, playNext)
    end
    self:After(Puzzles.ReplyDelay, playNext)
end

function Puzzles:Finish(solved)
    self.done = true
    if (solved and not self.mistake) then
        self:RecordResult(true)
    end
    self.feedback = solved and "solved" or "complete"

    -- Free to move pieces around afterwards, as on Lichess, including from an
    -- earlier position in the history
    KC.game.allowedColour = nil
    KC.game.lockHistory = false
    self:ShowStatus()
    KC:UpdatePuzzleButtons()
end

-- Elo update on the first attempt at a puzzle only
function Puzzles:RecordResult(won)
    local progress = self:GetProgress()
    local id = self.puzzle.id
    if self:IsAttempted(id) then
        return
    end

    local expected = 1 / (1 + 10 ^ ((self.puzzle.rating - progress.rating) / 400))
    local change = Puzzles.RatingK * ((won and 1 or 0) - expected)
    local newRating = math.floor(progress.rating + change + 0.5)
    self.ratingChange = newRating - progress.rating
    progress.rating = newRating

    if won then
        progress.solved[id] = true
    else
        progress.failed[id] = true
    end
end

-- Info bar --------------------------------------------------------------------

local function sideName(colour)
    return (colour == "w") and "White" or "Black"
end

function Puzzles:GetRatingLine()
    local progress = self:GetProgress()
    local line = self:GetTier().name.." · Puzzle rating "..progress.rating
    if self.ratingChange then
        local colour = (self.ratingChange >= 0) and "|cff40d040+" or "|cffe04040"
        line = line.." ("..colour..self.ratingChange.."|r)"
    end
    return line.." · Solved "..countKeys(progress.solved).." · Failed "..countKeys(progress.failed)
end

function Puzzles:ShowStatus()
    local C = ns.Colours
    local puzzle = self.puzzle
    local footer = self:GetRatingLine()
    local feedback = self.feedback

    if self.done then
        local themes = {}
        for i, name in ipairs(puzzle.themes) do
            themes[i] = self:ThemeLabel(name)
        end
        local detail = "Puzzle "..puzzle.id.." · Rated "..puzzle.rating
        if #themes > 0 then
            detail = detail.." · "..table.concat(themes, ", ")
        end
        if self.tierFinished then
            detail = "You have tried every puzzle in this tier! · "..detail
        end
        if (feedback == "solved" and not self.mistake) then
            KC:SetStatus("Success!", C.Good, detail, footer)
        else
            KC:SetStatus("Puzzle complete", C.Neutral, detail, footer)
        end
    elseif (feedback == "solution") then
        KC:SetStatus("Solution", C.Neutral, "Showing the moves...", footer)
    elseif (feedback == "ready") then
        KC:SetStatus("Get ready", C.Neutral, sideName(self.solver).." to play after the opponent's move", footer)
    elseif (feedback == "good") then
        KC:SetStatus("Best move!", C.Good, "Keep going...", footer)
    elseif (feedback == "bad") then
        KC:SetStatus("That's not the move!", C.Bad, "Try something else.", footer)
    else
        KC:SetStatus("Your turn", C.Normal, "Find the best move for "..sideName(self.solver)..".", footer)
    end
end

-- Progress reset (Options panel)
function Puzzles:ResetProgress()
    local progress = self:GetProgress()
    progress.rating = Puzzles.StartRating
    progress.solved = {}
    progress.failed = {}
    progress.current = nil
    self.ratingChange = nil
    if self.active and self.puzzle then
        self:ShowStatus()
    end
end
