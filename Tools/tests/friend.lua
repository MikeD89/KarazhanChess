-- Karazhan Chess - checks games against a friend (Friend.lua) offline: two or
-- more clients, each with its own copy of the module, whisper to each other
-- through a fake AceComm. Covers inviting (addon and version checks), playing,
-- results and records, draws, resigning, lost messages and catching up.
-- Run: node lua.js tests/friend.lua
local Rules = assert(loadfile(ADDON_ROOT .. "/KarazhanChess/Rules.lua"))("KarazhanChess", {})

local failed, checks = 0, 0
local function check(cond, message)
    checks = checks + 1
    if not cond then
        failed = failed + 1
        print("FAIL: " .. message)
    end
end

-- Clock and timers (C_Timer.NewTimer) -------------------------------------------

local now, timers = 0, {}
local function advance(seconds)
    now = now + seconds
    for _, timer in ipairs(timers) do
        if not timer.cancelled and not timer.fired and timer.at <= now then
            timer.fired = true
            timer.fn()
        end
    end
end

-- Whispers --------------------------------------------------------------------

local clients = {}   -- [lower case Name-Realm] = client
local queue = {}
local dropNext = 0   -- drop this many of the next messages sent

local function deliver()
    while #queue > 0 do
        local m = table.remove(queue, 1)
        local to = clients[m.to:lower()]
        if to then
            -- Senders on the receiver's realm show without it, like in WoW
            local sender = (m.realm == to.realm) and m.name or (m.name .. "-" .. m.realm)
            to.onComm(m.prefix, m.text, "WHISPER", sender)
        end
    end
end

local function newClient(name, realm, version)
    local client = { name = name, realm = realm, prints = {}, popups = {}, sent = {} }
    local env = setmetatable({}, { __index = _G })
    env.GetNormalizedRealmName = function() return realm end
    -- The whole name, as GetUnitName(unit, true) gives it (no realm for our own)
    env.GetUnitName = function(unit) if unit == "player" then return name end; return client.target end
    env.UnitExists = function(unit) return unit == "target" and client.target ~= nil end
    env.UnitIsPlayer = function() return true end
    env.UnitIsUnit = function() return false end
    env.UnitFactionGroup = function(unit) return (unit == "target" and client.targetFaction) or "Alliance" end
    env.GetRealmName = function() return realm end
    env.Ambiguate = function(full, _) local n, r = full:match("^(.-)%-(.+)$"); return (r == realm) and n or full end
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.time = function() return 1700000000 + now end
    env.C_Timer = { NewTimer = function(delay, fn)
        local timer = { at = now + delay, fn = fn }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end }
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(which, a, b) client.popups[which] = { a, b } end
    env.StaticPopup_Hide = function(which) client.popups[which] = nil end
    env.PlaySound = function() end
    env.SOUNDKIT = { READY_CHECK = 1 }
    env.unpack = table.unpack

    local KC = {
        version = version or "1.0", player = name, mode = "play",
        db = { global = { friend = { colour = "random", record = {} } } },
    }
    function KC:Print(text) client.prints[#client.prints + 1] = text end
    function KC:SetStatus() end
    function KC:UpdateFriendButtons() end
    function KC:HasWindow() return false end
    function KC:RegisterComm(_, fn) client.onComm = fn end
    function KC:SendCommMessage(prefix, text, distribution, target)
        client.sent[#client.sent + 1] = text
        if dropNext > 0 then
            dropNext = dropNext - 1
            return
        end
        queue[#queue + 1] = { prefix = prefix, text = text, to = target:find("-", 1, true) and target or (target .. "-" .. realm), name = name, realm = realm }
    end

    local ns = { KC = KC, Rules = Rules, Sounds = { PlayResult = function() end }, Colours = { Good = {}, Bad = {}, Neutral = {}, Normal = {} } }
    local function loadAddonFile(file)
        local path = ADDON_ROOT .. "/KarazhanChess/" .. file
        return assert(load(readfile(path), "@" .. path, "t", env))("KarazhanChess", ns)
    end
    loadAddonFile("Computer.lua")
    loadAddonFile("Friend.lua")
    client.KC, client.F, client.env = KC, ns.Friend, env
    client.F:Init()
    clients[(name .. "-" .. realm):lower()] = client
    return client
end

-- Helpers ----------------------------------------------------------------------

local function lastPrint(client) return client.prints[#client.prints] or "" end
local function moveCount(client) return #client.F.history - 1 end
local function game(client) return client.F:GetGame() end
local function record(client, other) return client.F:GetRecord(other.name .. "-" .. other.realm) end

-- A move on the board: the board records it in the history, then tells Friend
local function play(client, uci)
    local history = client.F.history
    local pos = Rules.Copy(history[#history].pos)
    assert(pos.turn == game(client).colour, client.name .. " moved out of turn")
    local move = assert(Rules.FindMove(pos, uci), "illegal test move " .. uci)
    Rules.MakeMove(pos, move)
    history[#history + 1] = { pos = pos, from = move.from, to = move.to, uci = uci }
    client.F:OnPlayerMove(uci)
    deliver()
end

-- Plays moves alternately, each by whoever has the move
local function playMoves(a, b, moves)
    for _, uci in ipairs(moves) do
        local pos = a.F.history[#a.F.history].pos
        play((pos.turn == game(a).colour) and a or b, uci)
    end
end

-- from invites to (typed as name), to accepts the popup
local function startGame(from, to, typed, colour)
    from.KC.db.global.friend.colour = colour
    from.F:Invite(typed)
    deliver()
    check(to.popups[to.F.InviteDiag] ~= nil, to.name .. " sees the invitation")
    to.env.StaticPopupDialogs[to.F.InviteDiag].OnAccept()
    to.popups[to.F.InviteDiag] = nil
    deliver()
end

-- Tests --------------------------------------------------------------------------

local alice = newClient("Alice", "Realm")
local bob = newClient("Bob", "OtherRealm")

-- Names
local F = alice.F
check(F.FullName("bob") == "bob-Realm", "a name gets our realm")
check(F.FullName(" Bob-Other Realm ") == "Bob-OtherRealm", "realm spaces dropped")
check(F.FullName("Bob-Azjol-Nerub") == "Bob-AzjolNerub", "realm hyphens dropped")
check(F.FullName("") == nil and F.FullName("two words") == nil and F.FullName("Bob1") == nil, "bad names refused")

F:Invite("Alice")
check(F.notice and F.notice[1] == "That's you", "can't invite yourself")
F:Invite("not a name")
check(F.notice and F.notice[1] == "Not a name", "bad name refused")

-- No addon: no answer within the ping timeout
F:Invite("Carol")
deliver()
check(F.checking ~= nil, "waiting for an answer")
advance(5)
check(F.checking == nil and F.notice and F.notice[1] == "No answer", "no answer from someone without the addon")
check(lastPrint(alice):find("Carol"), "no answer is printed when the tab isn't shown")

-- Version mismatch, both ways
local old = newClient("Olga", "Realm", "0.9")
F:Invite("Olga")
deliver()
check(F.notice and F.notice[1] == "Different versions", "version mismatch found by the ping")
check(game(alice) == nil, "no game after a version mismatch")
old.F:Invite("Alice")
deliver()
check(old.F.notice and old.F.notice[1] == "Different versions", "version mismatch the other way")

-- Declining
F:Invite("bob-OtherRealm")
deliver()
check(F.pending ~= nil, "invitation pending")
check(bob.popups[bob.F.InviteDiag] ~= nil, "Bob sees the invitation")
bob.env.StaticPopupDialogs[bob.F.InviteDiag].OnCancel()
deliver()
check(F.pending == nil and F.notice[1] == "Declined", "declined")

-- Withdrawing
F:Invite("Bob-OtherRealm")
deliver()
F:CancelInvite()
deliver()
check(bob.popups[bob.F.InviteDiag] == nil and bob.F.incoming == nil, "withdrawn invitation closes the popup")

-- Invitation timing out
F:Invite("Bob-OtherRealm")
deliver()
advance(60)
deliver()
check(F.pending == nil and F.notice[1] == "No answer", "unanswered invitation times out")
check(bob.F.incoming == nil, "the timeout withdraws it on Bob's side")

-- Fool's mate: Alice white (lower case name), Bob black and mates
startGame(alice, bob, "bob-otherrealm", "w")
check(game(alice) and game(bob) and game(alice).id == game(bob).id, "both have the game")
check(game(alice).colour == "w" and game(bob).colour == "b", "colours as chosen")
check(game(alice).opponent == "Bob-OtherRealm", "opponent stored with the name as sent")
check(alice.KC.db.global.friend.last == "Bob-OtherRealm", "last opponent remembered")
playMoves(alice, bob, { "f2f3", "e7e5", "g2g4", "d8h4" })
check(moveCount(alice) == 4 and moveCount(bob) == 4, "both have all moves")
check(table.concat(game(alice).moves, ",") == "f2f3,e7e5,g2g4,d8h4", "moves saved")
check(game(alice).result and game(alice).result.kind == "checkmate" and game(alice).result.winner == "b", "Alice sees the mate")
check(game(bob).result and game(bob).result.winner == "b", "Bob sees the mate")
check(record(alice, bob).lost == 1 and record(bob, alice).won == 1, "records count the mate")

-- Busy: a third player invites Alice during a game; Alice can't invite either
startGame(bob, alice, "Alice-Realm", "b")
check(game(alice).colour == "w", "rematch: Alice white again")
local carol = newClient("Carol", "Realm")
carol.F:Invite("Alice")
deliver()
check(carol.F.notice and carol.F.notice[1] == "Busy", "busy players decline")
check(lastPrint(alice):find("still playing"), "Alice is told about the declined invitation")
alice.F:Invite("Carol")
check(alice.F.notice[1] == "Game in progress", "no invitations during a game")

-- Out of turn and illegal moves are refused
local before = moveCount(alice)
alice.F:OnMessage("MOVE " .. game(alice).id .. " 1 e7e5", "WHISPER", "Bob-OtherRealm")
check(moveCount(alice) == before, "a black move on white's turn is refused")
alice.F:OnMessage("MOVE " .. game(alice).id .. " 1 e2e5", "WHISPER", "Carol")
check(moveCount(alice) == before, "moves from someone else are ignored")

-- A lost move: Bob catches up by syncing
play(alice, "e2e4")
dropNext = 1
play(bob, "e7e5")
check(moveCount(alice) == 1 and moveCount(bob) == 2, "Bob's move was lost")
bob.F:SendSync("SYNC")
deliver()
check(moveCount(alice) == 2, "Alice catches up from the sync")
-- Alice's move lost, then her next message makes Bob ask to sync
dropNext = 1
play(alice, "g1f3")
check(moveCount(bob) == 2, "Alice's move was lost")
alice.F:SendSync("SYNC")
deliver()
check(moveCount(bob) == 3, "Bob catches up")

-- Saved games rebuild after a reload
local saved = game(bob)
bob.F.history = nil
bob.F:LoadGame(saved)
check(moveCount(bob) == 3 and bob.F.history[4].pos.turn == "b", "history rebuilt from the saved moves")

-- Draw offer, declined then accepted
alice.F:OfferDraw()
deliver()
check(bob.popups[bob.F.DrawDiag] ~= nil, "Bob sees the draw offer")
bob.env.StaticPopupDialogs[bob.F.DrawDiag].OnCancel()
deliver()
check(alice.F.drawOffered == false and alice.F.note:find("declined"), "draw declined")
alice.F:OfferDraw()
deliver()
bob.env.StaticPopupDialogs[bob.F.DrawDiag].OnAccept()
deliver()
check(game(alice).result.kind == "agreed" and game(bob).result.kind == "agreed", "draw agreed on both sides")
check(record(alice, bob).drawn == 1 and record(bob, alice).drawn == 1, "draw recorded")

-- Resigning
startGame(alice, bob, "Bob-OtherRealm", "b")
check(game(alice).colour == "b", "Alice black")
bob.F:Resign()
deliver()
check(game(alice).result.kind == "resign" and game(alice).result.winner == "b", "Alice wins by resignation")
check(record(alice, bob).won == 1 and record(bob, alice).lost == 1, "resignation recorded")
check(record(alice, bob).lost == 1 and record(alice, bob).drawn == 1, "record totals")

-- A resignation that got lost arrives with the next sync
startGame(alice, bob, "Bob-OtherRealm", "w")
play(alice, "d2d4")
dropNext = 1
bob.F:Resign()
check(game(alice).result == nil, "resignation lost")
alice.F:SendSync("SYNC")
deliver()
check(game(alice).result and game(alice).result.kind == "resign" and game(alice).result.winner == "w", "resignation arrives by sync")

-- The opponent no longer has the game
startGame(alice, bob, "Bob-OtherRealm", "w")
bob.KC.db.global.friend.game = nil
bob.F.history = nil
play(alice, "e2e4")
check(game(alice).result and game(alice).result.kind == "abandoned", "abandoned when the opponent lost the game")
local r = record(alice, bob)
check(r.won == 2 and r.lost == 1 and r.drawn == 1, "abandoned games don't count")

-- Stalemate and other board draws are found on both sides (fastest stalemate)
startGame(alice, bob, "Bob-OtherRealm", "w")
playMoves(alice, bob, { "e2e3", "a7a5", "d1h5", "a8a6", "h5a5", "h7h5", "h2h4", "a6h6", "a5c7", "f7f6",
    "c7d7", "e8f7", "d7b7", "d8d3", "b7b8", "d3h7", "b8c8", "f7g6", "c8e6" })
check(game(alice).result and game(alice).result.kind == "stalemate", "stalemate for Alice")
check(game(bob).result and game(bob).result.kind == "stalemate", "stalemate for Bob")
check(record(alice, bob).drawn == 2, "stalemate recorded")

-- WoW Forever: "First Last" names, no realms ------------------------------------

local jane = newClient("Jane Smith", "Forever")
local john = newClient("John Doe", "Forever")
local JF = jane.F
check(JF.HasSurnames() and not alice.F.HasSurnames(), "Forever told apart by our own name")
check(JF.FullName("  john   doe ") == "John Doe", "two words, capitalised")
check(JF.FullName("John") == nil and JF.FullName("John Doe Smith") == nil, "Forever names need a first and last name")
JF:Invite("John")
check(JF.notice[1] == "Not a name" and JF.notice[3]:find("first and last name"), "single name refused with a hint")
JF:Invite("jane smith")
check(JF.notice[1] == "That's you", "can't invite yourself on Forever")
startGame(jane, john, "john doe", "w")
check(game(jane) and game(jane).opponent == "John Doe" and game(john).opponent == "Jane Smith", "Forever game started")
playMoves(jane, john, { "f2f3", "e7e5", "g2g4", "d8h4" })
check(game(jane).result and game(jane).result.winner == "b", "Forever game played to mate")
check(JF:GetRecord("John Doe").lost == 1 and john.F:GetRecord("Jane Smith").won == 1, "Forever records")

-- Names from right-click menus
check(JF.GetMenuName({ name = "John", server = "Doe" }) == "John Doe", "menu: Forever last name in the server field")
check(JF.GetMenuName({ chatTarget = "John Doe" }) == "John Doe", "menu: chat name")
check(JF.GetMenuName({ chatTarget = "Jane Smith" }) == nil, "menu: not for ourselves")
check(alice.F.GetMenuName({ name = "Bob", server = "OtherRealm" }) == "Bob-OtherRealm", "menu: realm elsewhere")
check(alice.F.GetMenuName({ name = "Bob" }) == "Bob-Realm", "menu: same realm")
jane.target = "John Doe"
check(JF.GetMenuName({ unit = "target" }) == "John Doe", "menu: a player in the world")
jane.targetFaction = "Horde"
check(JF.GetMenuName({ unit = "target" }) == nil, "menu: not for the other faction")
check(JF.GetMenuName({ accountInfo = { gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "John Doe", realmName = "Forever" } } }) == nil,
    "menu: Battle.net friend not in WoW (stub has no BNET_CLIENT_WOW)")

print(checks - failed .. "/" .. checks .. " checks passed")
if failed > 0 then error("friend tests failed") end
