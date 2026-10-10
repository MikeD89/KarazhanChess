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

-- Puzzle types for the Puzzle Types options: each groups one or more Lichess
-- themes. A puzzle is offered if any of its types is ticked. Broad themes that
-- nearly every puzzle has (phase, goal, length, origin) aren't types, so a puzzle
-- with none of the themes below belongs to "other".
Puzzles.TypeGroups = {
    { key = "tactics", name = "Tactics", types = {
        { key = "forks", name = "Forks", themes = { "fork" } },
        { key = "pins", name = "Pins and skewers", themes = { "pin", "skewer", "xRayAttack", "collinearMove" } },
        { key = "discovered", name = "Discovered attacks", themes = { "discoveredAttack", "discoveredCheck", "doubleCheck" } },
        { key = "sacrifices", name = "Sacrifices", themes = { "sacrifice" } },
        { key = "decoys", name = "Deflection and decoys", themes = { "attraction", "deflection", "capturingDefender", "interference", "clearance" } },
        { key = "hanging", name = "Hanging and trapped pieces", themes = { "hangingPiece", "trappedPiece" } },
        { key = "kingAttack", name = "King attacks", themes = { "kingsideAttack", "queensideAttack", "exposedKing", "attackingF2F7" } },
        { key = "quiet", name = "Quiet and defensive moves", themes = { "quietMove", "defensiveMove", "zugzwang", "intermezzo" } },
        { key = "pawns", name = "Advanced pawns", themes = { "advancedPawn" } },
        { key = "special", name = "Promotion, castling, en passant", themes = { "promotion", "underPromotion", "castling", "enPassant" } },
    } },
    { key = "mates", name = "Mates", types = {
        { key = "mate1", name = "Mate in 1", themes = { "mateIn1" } },
        { key = "mate2", name = "Mate in 2", themes = { "mateIn2" } },
        { key = "mate3", name = "Mate in 3 or more", themes = { "mateIn3", "mateIn4", "mateIn5" } },
        { key = "matePatterns", name = "Named mating patterns", themes = { "anastasiaMate", "arabianMate",
            "backRankMate", "balestraMate", "blindSwineMate", "bodenMate", "cornerMate", "doubleBishopMate",
            "dovetailMate", "epauletteMate", "hookMate", "killBoxMate", "morphysMate", "operaMate",
            "pillsburysMate", "smotheredMate", "swallowstailMate", "triangleMate", "vukovicMate" } },
    } },
    { key = "endgames", name = "Endgames", types = {
        { key = "pawnEndgame", name = "Pawn endgames", themes = { "pawnEndgame" } },
        { key = "knightEndgame", name = "Knight endgames", themes = { "knightEndgame" } },
        { key = "bishopEndgame", name = "Bishop endgames", themes = { "bishopEndgame" } },
        { key = "rookEndgame", name = "Rook endgames", themes = { "rookEndgame" } },
        { key = "queenEndgame", name = "Queen endgames", themes = { "queenEndgame", "queenRookEndgame" } },
    } },
    { key = "other", name = "Other", types = {
        { key = "other", name = "Other puzzles", themes = {} },
    } },
}

-- Theme name -> type key
local TypeOfTheme = {}
for _, group in ipairs(Puzzles.TypeGroups) do
    for _, puzzleType in ipairs(group.types) do
        for _, theme in ipairs(puzzleType.themes) do
            TypeOfTheme[theme] = puzzleType.key
        end
    end
end

-- Types the player unticked: KC.db.global.puzzleTypesOff = { [type key] = true }
function Puzzles:IsTypeEnabled(key)
    return not KC.db.global.puzzleTypesOff[key]
end

function Puzzles:SetTypeEnabled(key, enabled)
    KC.db.global.puzzleTypesOff[key] = (not enabled) or nil
    self.allowedCache = nil
end

function Puzzles:AnyTypeEnabled()
    for _, group in ipairs(Puzzles.TypeGroups) do
        for _, puzzleType in ipairs(group.types) do
            if self:IsTypeEnabled(puzzleType.key) then
                return true
            end
        end
    end
    return false
end

function Puzzles:SetAllTypesEnabled(enabled)
    local off = KC.db.global.puzzleTypesOff
    wipe(off)
    if not enabled then
        for _, group in ipairs(Puzzles.TypeGroups) do
            for _, puzzleType in ipairs(group.types) do
                off[puzzleType.key] = true
            end
        end
    end
    self.allowedCache = nil
end

-- Whether a puzzle may be offered: it has a ticked type, or has no type at all
-- and "other" is ticked. eachType(visit) calls visit(type key) for each of the
-- puzzle's types, stopping and returning true as soon as visit does.
local function typesAllowed(off, eachType)
    local any = false
    local allowed = eachType(function(key)
        any = true
        return not off[key]
    end)
    return allowed or (not any and not off.other)
end

-- Whether a decoded puzzle may be offered
function Puzzles:IsAllowed(puzzle)
    local off = KC.db.global.puzzleTypesOff
    if next(off) == nil then
        return true
    end
    return typesAllowed(off, function(visit)
        for _, theme in ipairs(puzzle.themes) do
            local key = TypeOfTheme[theme]
            if key and visit(key) then
                return true
            end
        end
        return false
    end)
end

-- The filter cache for the current types: { off, allows = fn(record), tiers = {} },
-- or nil when nothing is unticked. Rebuilt when the types change (off is compared
-- as well, as Reset Options replaces the table).
function Puzzles:GetFilter()
    local off = KC.db.global.puzzleTypesOff
    if next(off) == nil then
        return nil
    end
    local cache = self.allowedCache
    if not (cache and cache.off == off) then
        -- Theme code (from 0) -> type key, for checking records without decoding them
        local typeOfCode = {}
        for i, name in ipairs(self.themeNames) do
            typeOfCode[i - 1] = TypeOfTheme[name]
        end
        local function allows(record)
            return typesAllowed(off, function(visit)
                return Codec.AnyThemeCode(record, function(code)
                    local key = typeOfCode[code]
                    return key and visit(key)
                end)
            end)
        end
        cache = { off = off, allows = allows, tiers = {} }
        self.allowedCache = cache
    end
    return cache
end

-- Whether a record may be offered, without decoding it
function Puzzles:IsRecordAllowed(record)
    local filter = self:GetFilter()
    return not filter or filter.allows(record)
end

-- The indexes of a tier's allowed records, as { list = { index, ... },
-- set = { [index] = true } }, or nil when nothing is unticked. Scans the whole
-- tier (a noticeable pause), so it is only built when random picks can't find an
-- allowed puzzle, and kept until the types change.
function Puzzles:GetAllowed(key)
    local filter = self:GetFilter()
    if not filter then
        return nil
    end
    if not filter.tiers[key] then
        local allowed = { list = {}, set = {} }
        for index, record in Codec.Records(self.data[key]) do
            if filter.allows(record) then
                allowed.list[#allowed.list + 1] = index
                allowed.set[index] = true
            end
        end
        filter.tiers[key] = allowed
    end
    return filter.tiers[key]
end

-- Entering and leaving puzzle mode -------------------------------------------

-- Switches the board to puzzles: keeps the Play game (its whole history, and a
-- game against the computer is paused) to restore later, then resumes the
-- unfinished puzzle or starts a new one
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
    ns.Computer:Suspend()
    self.active = true
    self.savedHistory, self.savedIndex = game.history, game.historyIndex
    self.savedFlip = KC.boardFlipped

    game.announceResults = false
    game.lockHistory = true
    game.onPlayerMove = function(move, uci, undo) self:OnPlayerMove(move, uci, undo) end

    local current = self:GetProgress().current
    local puzzle = current and self:FindPuzzle(current)
    if puzzle and not self:IsAttempted(puzzle.id) and self:IsAllowed(puzzle) then
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

    if (self.savedHistory and #self.savedHistory > 0) then
        game.history = self.savedHistory
        game:ShowHistory(self.savedIndex)
    else
        game:ClearBoard()
        game:ResetHistory("w")
    end
    self.savedHistory = nil
    KC:SetBoardFlipped(self.savedFlip or false)
    KC:UpdatePuzzleButtons()
    ns.Computer:Resume()
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

-- A random unattempted puzzle from the chosen tier allowed by the ticked types,
-- or any allowed one if every allowed puzzle has been attempted. Returns
-- nil if the tier is missing or none of its puzzles is allowed.
function Puzzles:PickPuzzle()
    local tier = self.data[self:GetTier().key]
    if not tier then
        return nil
    end

    local current = self.puzzle and self.puzzle.id
    local key = self:GetTier().key
    local filter = self:GetFilter()
    if (filter and not self:AnyTypeEnabled()) then
        return nil -- everything unticked: no need to scan
    end

    -- With types unticked, try random records first, checking their types
    -- cheaply; usually enough unless the types rule out nearly everything
    if (filter and not filter.tiers[key]) then
        for _ = 1, 1000 do
            local record = Codec.GetRecord(tier, math.random(tier.count))
            local id = Codec.GetId(record)
            if id ~= current and not self:IsAttempted(id) and self:IsRecordAllowed(record) then
                return Codec.Decode(record, self.themeNames)
            end
        end
    end

    -- Pick from the allowed records only (all of them when no type is unticked)
    local allowed = self:GetAllowed(key)
    local count = allowed and #allowed.list or tier.count
    if (count == 0) then
        return nil
    end
    local function randomRecord()
        local k = math.random(count)
        return Codec.GetRecord(tier, allowed and allowed.list[k] or k)
    end

    for _ = 1, 200 do
        local record = randomRecord()
        local id = Codec.GetId(record)
        if id ~= current and not self:IsAttempted(id) then
            return Codec.Decode(record, self.themeNames)
        end
    end

    -- Random picks keep landing on attempted puzzles, so look through them all
    for index, record in Codec.Records(tier) do
        if (not allowed or allowed.set[index]) and not self:IsAttempted(Codec.GetId(record)) then
            return Codec.Decode(record, self.themeNames)
        end
    end

    self.tierFinished = true
    return Codec.Decode(randomRecord(), self.themeNames)
end

function Puzzles:Next()
    self.tierFinished = false
    local puzzle = self:PickPuzzle()
    if puzzle then
        self:Start(puzzle)
    elseif self.data[self:GetTier().key] then
        KC:SetStatus("No puzzles", ns.Colours.Bad, "No "..self:GetTier().name.." puzzles match the puzzle types you ticked.",
            "Choose your puzzle types in the options (/kco, Puzzle Types).")
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

    -- No more moves once it's over; < and > still step through the moves to review them
    KC.game.allowedColour = false
    KC.game:DeselectPiece()
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

-- The player's rating, with the change from this puzzle once it is over
function Puzzles:GetRatingLine()
    local rating = self:GetProgress().rating
    if not self.ratingChange then
        return "Rating: "..rating
    end
    local colour = (self.ratingChange >= 0) and "|cff40d040+" or "|cffe04040"
    return "New Rating: "..rating.." ("..colour..self.ratingChange.."|r)"
end

-- Difficulty, the player's rating until the puzzle is over (then it has its
-- own line), and the player's counts
function Puzzles:GetStatsLine()
    local progress = self:GetProgress()
    local tierName = self:GetTier().name
    local line = self.tierFinished and ("Every "..tierName.." puzzle tried!") or tierName
    if not self.done then
        line = line.." · Rating "..progress.rating
    end
    return line.." · Solved "..countKeys(progress.solved).." · Failed "..countKeys(progress.failed)
end

-- Lichess theme names that don't read well split at the capitals
local ThemeNames = {
    attackingF2F7 = "Attacking f2/f7",
    xRayAttack = "X-ray attack",
    underPromotion = "Underpromotion",
    superGM = "Super GM",
    masterVsMaster = "Master vs master",
}

-- "mateIn2" -> "Mate in 2"
local function themeName(theme)
    if ThemeNames[theme] then
        return ThemeNames[theme]
    end
    local words = theme:gsub("(%u)", " %1"):gsub("(%d+)", " %1"):lower()
    return (words:gsub("^%l", string.upper))
end

-- Lines for the Info button tooltip (enabled once a puzzle is over): { label, value }
-- pairs, nil without a puzzle
function Puzzles:GetInfo()
    local puzzle = self.puzzle
    if not puzzle then
        return nil
    end
    local progress = self:GetProgress()
    local themes = {}
    for _, theme in ipairs(puzzle.themes) do
        table.insert(themes, themeName(theme))
    end
    local result = "Not tried"
    if progress.solved[puzzle.id] then
        result = "Solved"
    elseif progress.failed[puzzle.id] then
        result = "Failed"
    end
    return {
        { "Puzzle", puzzle.id },
        { "Rating", puzzle.rating },
        { "Difficulty", self:GetTier().name },
        { "Moves", math.floor(#puzzle.moves / 2) },
        { "Result", result },
        { "Themes", (#themes > 0) and table.concat(themes, ", ") or "None" },
    }
end

function Puzzles:ShowStatus()
    local C = ns.Colours
    local footer = self:GetStatsLine()
    local feedback = self.feedback

    if self.done then
        local detail = self:GetRatingLine()
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
