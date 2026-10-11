-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Games against a friend over addon messages: invitations, moves, results
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Rules = ns.Rules

-- A game against another player with the addon, in its own tab (mode "friend").
-- Both clients keep the whole game (saved, so it survives /reload and logging
-- out) and send each other whispered addon messages through AceComm:
--
--   PING version                  is the addon there? (answered with PONG)
--   PONG version
--   INVITE version id colour      colour is the one the invited player gets
--   ACCEPT id / DECLINE id reason [version] / CANCEL id
--   MOVE id ply uci               ply counts the moves, 1 = white's first
--   SYNC id moves result          "here is my game, send me yours" (answered
--   STATE id moves result         with STATE); moves is a comma list or "-"
--   RESIGN id / DRAWOFFER id / DRAWACCEPT id / DRAWDECLINE id
--   NOGAME id                     "I have no game with that id"
--
-- Inviting checks the other side first (PING): no answer means they are offline
-- or don't have the addon, and the versions must match. Each side judges the
-- board results itself (checkmate, draws); resignations and agreed draws are
-- sent. A move that arrives out of step, and opening the tab, sends SYNC, so a
-- side that missed a move (offline, or a lost message) catches up.
local Friend = {}
ns.Friend = Friend

Friend.Prefix = "KarazhanChess"   -- addon message prefix (16 characters at most)
Friend.PingTimeout = 5            -- seconds to wait for PONG
Friend.InviteTimeout = 60         -- seconds to wait for an answer to an invitation
Friend.StartFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

Friend.InviteDiag = "KARAZHANCHESS_FRIEND_INVITE"
Friend.NameDiag = "KARAZHANCHESS_FRIEND_NAME"
Friend.DrawDiag = "KARAZHANCHESS_FRIEND_DRAW"
Friend.ResignDiag = "KARAZHANCHESS_FRIEND_RESIGN"

Friend.active = false   -- the Play vs Friend tab is shown
Friend.history = nil    -- the game's positions (Game.history format); nil before any game
Friend.checking = nil   -- { target, timer } while waiting for PONG
Friend.pending = nil    -- { id, target, colour, timer }: our invitation, unanswered
Friend.incoming = nil   -- { id, from, colour }: an invitation shown to us
Friend.notice = nil     -- { headline, colour, detail } for the info bar between games
Friend.note = nil       -- replaces the info bar detail during a game (draw offers)
Friend.drawOffered = false
Friend.drawFrom = nil   -- game id of the opponent's draw offer being shown

local unpack = unpack or table.unpack

-- Names ------------------------------------------------------------------------

local function ownRealm()
    if GetNormalizedRealmName then
        local realm = GetNormalizedRealmName()
        if realm then
            return realm
        end
    end
    return ((GetRealmName() or ""):gsub("[%s%-]", ""))
end

-- WoW Forever characters have a first and a last name ("Jane Smith") and no
-- realm suffixes (one realm of each type). Told apart by our own name, as
-- GetUnitName(unit, true) gives the whole name there (UnitName returns the last
-- name where the realm would be).
function Friend.HasSurnames()
    if (Friend.surnames == nil) then
        local own = GetUnitName and GetUnitName("player", true)
        if not own then
            return false -- Not known yet: ask again later
        end
        Friend.surnames = own:find(" ", 1, true) ~= nil
    end
    return Friend.surnames
end

-- Our own name, in the form FullName gives
function Friend.OwnName()
    return Friend.FullName((GetUnitName and GetUnitName("player", true)) or KC.player)
end

local function capitalise(word)
    return word:sub(1, 1):upper()..word:sub(2)
end

-- A character name as typed or as a message sender to the form we keep, or nil
-- if it isn't a name: "First Last" on WoW Forever (each word capitalised),
-- elsewhere "Name-Realm" with the realm normalised ("Name" gets our realm)
function Friend.FullName(name)
    name = strtrim(name or ""):gsub("%s+", " ")
    if Friend.HasSurnames() then
        local first, last = name:match("^([^%s%d]+) ([^%s%d]+)$")
        if not (first and first:match("^[^%p]") and last:match("^[^%p]")) then
            return nil
        end
        return capitalise(first).." "..capitalise(last)
    end

    local char, realm = name:match("^([^%-%s]+)%-(.+)$")
    if not char then
        char, realm = name:match("^[^%-%s]+$"), ownRealm()
    end
    if (not char or char:find("[%d%p]")) then
        return nil
    end
    realm = realm:gsub("[%s%-]", "")
    if (realm == "") then
        return nil
    end
    return char.."-"..realm
end

-- Whether two full names are the same character (names aren't case sensitive)
local function same(a, b)
    return a ~= nil and b ~= nil and a:lower() == b:lower()
end

-- A full name for showing: the realm is left off for players on our own
function Friend.Display(name)
    if (Ambiguate and not Friend.HasSurnames()) then
        return Ambiguate(name, "none")
    end
    return name
end
local Display = Friend.Display

local function otherColour(colour)
    return (colour == "w") and "b" or "w"
end

local function sideName(colour)
    return (colour == "w") and "White" or "Black"
end

-- Settings and records ---------------------------------------------------------

-- KC.db.global.friend = { colour ("w", "b" or "random"), last (full name of the
-- last opponent), game, record = { [lower case full name] = { name, won, lost, drawn } } }
-- game = { id, opponent (full name), colour (ours), moves = { uci }, result }
function Friend:GetSettings()
    return KC.db.global.friend
end

function Friend:GetGame()
    return self:GetSettings().game
end

function Friend:InProgress()
    local game = self:GetGame()
    return game ~= nil and game.result == nil
end

function Friend:GetRecord(name)
    local records = self:GetSettings().record
    local key = name:lower()
    if not records[key] then
        records[key] = { name = name, won = 0, lost = 0, drawn = 0 }
    end
    return records[key]
end

-- The friend game is on screen (its tab, with the window open)
function Friend:IsShown()
    return self.active and KC.frame ~= nil and KC.frame:IsShown()
end

-- Game history -------------------------------------------------------------------

-- Plays uci on the last position in history and adds the entry Game:RecordMove
-- would. Returns the move, or nil if it isn't legal there.
local function appendMove(history, uci)
    local pos = Rules.Copy(history[#history].pos)
    local move = Rules.FindMove(pos, uci)
    if not move then
        return nil
    end
    Rules.MakeMove(pos, move)
    history[#history + 1] = { pos = pos, from = move.from, to = move.to, uci = uci }
    return move
end

local function latest(self)
    return self.history[#self.history].pos
end

local function newHistory()
    return { { pos = Rules.FromFEN(Friend.StartFEN) } }
end

-- Rebuilds the history of a saved game from its moves
function Friend:LoadGame(game)
    self.history = newHistory()
    for i, uci in ipairs(game.moves) do
        if not appendMove(self.history, uci) then
            for j = #game.moves, i, -1 do
                game.moves[j] = nil
            end
            break
        end
    end
end

-- Copies the moves from the history into the saved game
function Friend:Save()
    local game = self:GetGame()
    if not game then
        return
    end
    local moves = {}
    for i = 2, #self.history do
        moves[#moves + 1] = self.history[i].uci
    end
    game.moves = moves
end

-- Setting up ---------------------------------------------------------------------

function Friend:Init()
    self:CreatePopups()
    local game = self:GetGame()
    if game then
        self:LoadGame(game)
    end
    KC:RegisterComm(Friend.Prefix, function(_, message, distribution, sender)
        self:OnMessage(message, distribution, sender)
    end)
    self:AddUnitMenus()
end

function Friend:CreatePopups()
    local function editBoxOf(dialog)
        return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox
    end

    StaticPopupDialogs[Friend.InviteDiag] = {
        text = "%s invites you to a game of Karazhan Chess.\nYou would play %s.",
        button1 = ACCEPT or "Accept",
        button2 = DECLINE or "Decline",
        OnAccept = function() self:AcceptInvite() end,
        OnCancel = function() self:DeclineInvite() end,
        timeout = Friend.InviteTimeout,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs[Friend.NameDiag] = {
        text = Friend.HasSurnames()
            and "Invite a player to a game of chess.\nEnter their first and last name:"
            or "Invite a player to a game of chess.\nEnter their character name, with the realm if it isn't yours (Name-Realm):",
        button1 = "Invite",
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 64,
        OnShow = function(dialog)
            local editBox = editBoxOf(dialog)
            editBox:SetText("")
            editBox:SetFocus()
        end,
        OnAccept = function(dialog)
            self:Invite(editBoxOf(dialog):GetText())
        end,
        EditBoxOnEnterPressed = function(editBox)
            local name = editBox:GetText()
            StaticPopup_Hide(Friend.NameDiag)
            self:Invite(name)
        end,
        EditBoxOnEscapePressed = function()
            StaticPopup_Hide(Friend.NameDiag)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs[Friend.DrawDiag] = {
        text = "%s offers a draw.",
        button1 = ACCEPT or "Accept",
        button2 = DECLINE or "Decline",
        OnAccept = function() self:AnswerDraw(true) end,
        OnCancel = function() self:AnswerDraw(false) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs[Friend.ResignDiag] = {
        text = "Resign your game against %s?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() self:Resign() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Entering and leaving the tab -----------------------------------------------------

-- Puts the friend game on the board, keeping the Play board (and a game against
-- the computer, paused) to restore on leaving, like puzzles do
function Friend:Enter()
    if self.active then
        return
    end
    local game = KC.game
    ns.Computer:Suspend()
    self.active = true
    self.savedHistory, self.savedIndex = game.history, game.historyIndex
    self.savedFlip = KC.boardFlipped

    game.announceResults = false
    game.enforceTurns = true
    game.lockHistory = true
    game.onPlayerMove = function(_, uci) self:OnPlayerMove(uci) end
    self:ShowGame()

    -- Catch up with anything missed while away
    if self:InProgress() then
        self:SendSync("SYNC")
    end
end

function Friend:Leave()
    if not self.active then
        return
    end
    self.active = false

    local game = KC.game
    game.onPlayerMove = nil
    game.allowedColour = nil
    game.enforceTurns = false
    game.lockHistory = false
    game.announceResults = true

    if (self.savedHistory and #self.savedHistory > 0) then
        game.history = self.savedHistory
        game:ShowHistory(self.savedIndex)
    else
        game:ClearBoard()
        game:ResetHistory("w")
    end
    self.savedHistory = nil
    KC:SetBoardFlipped(self.savedFlip or false)
    ns.Computer:Resume()
end

-- Shows the game on the board (the start position before the first game). The
-- board's history is ours while shown, so moves made on it land in self.history.
function Friend:ShowGame()
    local game = KC.game
    local current = self:GetGame()
    game.allowedColour = false
    if self.history then
        game.history = self.history
        game:ShowHistory(#self.history)
    else
        game:StartNewGame()
    end
    KC:SetBoardFlipped(current ~= nil and current.colour == "b")
    self:Update()
end

-- Who may move, the info bar and the buttons
function Friend:Update()
    if self.active then
        local game = KC.game
        local current = self:GetGame()
        if (self:InProgress() and latest(self).turn == current.colour) then
            game.allowedColour = current.colour
        else
            game.allowedColour = false
            game:DeselectPiece()
        end
    end
    self:ShowStatus()
    KC:UpdateFriendButtons()
end

-- Messages -----------------------------------------------------------------------

function Friend:Send(target, ...)
    KC:SendCommMessage(Friend.Prefix, table.concat({ ... }, " "), "WHISPER", target, "ALERT")
end

local Handlers = {}

function Friend:OnMessage(message, distribution, sender)
    if (distribution ~= "WHISPER") then
        return
    end
    local args = {}
    for word in message:gmatch("%S+") do
        args[#args + 1] = word
    end
    local handler = Handlers[args[1] or ""]
    local from = Friend.FullName(sender)
    if (handler and from) then
        handler(self, from, unpack(args, 2))
    end
end

-- Our game with id against sender, still being played
function Friend:IsOpponentGame(sender, id)
    local game = self:GetGame()
    return game ~= nil and game.id == id and game.result == nil and same(sender, game.opponent)
end

-- Sends our moves and any resignation or agreed draw (kind "SYNC" or "STATE")
function Friend:SendSync(kind)
    local game = self:GetGame()
    if not game then
        return
    end
    local moves = (#game.moves > 0) and table.concat(game.moves, ",") or "-"
    local result = "-"
    if (game.result and (game.result.kind == "resign" or game.result.kind == "agreed")) then
        result = game.result.kind..":"..(game.result.winner or "-")
    end
    self:Send(game.opponent, kind, game.id, moves, result)
end

function Handlers.PING(self, sender)
    self:Send(sender, "PONG", KC.version)
end

function Handlers.PONG(self, sender, version)
    local check = self.checking
    if not (check and same(sender, check.target)) then
        return
    end
    check.timer:Cancel()
    self.checking = nil
    if (version ~= KC.version) then
        self:SetNotice("Different versions", ns.Colours.Bad, Display(sender).." has Karazhan Chess "..tostring(version)
            ..", you have "..KC.version..". You both need the same version.")
        return
    end
    self:SendInvite(sender)
end

function Handlers.INVITE(self, sender, version, id, colour)
    if not (id and (colour == "w" or colour == "b")) then
        return
    end
    local name = Display(sender)
    if (version ~= KC.version) then
        self:Send(sender, "DECLINE", id, "version", KC.version)
        KC:Print(name.." invited you to a game of chess, but has Karazhan Chess "..tostring(version)
            .." and you have "..KC.version..". You both need the same version.")
        return
    end
    if (self:InProgress() or self.incoming) then
        self:Send(sender, "DECLINE", id, "busy")
        if self:InProgress() then
            KC:Print(name.." invited you to a game of chess, but you are still playing "
                ..Display(self:GetGame().opponent)..". Finish or resign that game first.")
        end
        return
    end
    self.incoming = { id = id, from = sender, colour = colour }
    PlaySound(SOUNDKIT.READY_CHECK)
    StaticPopup_Show(Friend.InviteDiag, name, sideName(colour))
end

function Handlers.ACCEPT(self, sender, id)
    local invite = self.pending
    if not (invite and invite.id == id and same(sender, invite.target)) then
        -- Too late: we withdrew it (or it timed out)
        self:Send(sender, "CANCEL", id or "-")
        return
    end
    invite.timer:Cancel()
    self.pending = nil
    self:StartGame(id, invite.target, invite.colour)
    PlaySound(SOUNDKIT.READY_CHECK)
    if not self:IsShown() then
        KC:Print(Display(invite.target).." accepted your invitation. You play "..sideName(invite.colour)..". (/kc friend)")
    end
end

function Handlers.DECLINE(self, sender, id, reason, version)
    local invite = self.pending
    if not (invite and invite.id == id and same(sender, invite.target)) then
        return
    end
    invite.timer:Cancel()
    self.pending = nil
    local name, bad = Display(sender), ns.Colours.Bad
    if (reason == "version") then
        self:SetNotice("Different versions", bad, name.." has Karazhan Chess "..tostring(version)
            ..", you have "..KC.version..". You both need the same version.")
    elseif (reason == "busy") then
        self:SetNotice("Busy", bad, name.." is busy with another game.")
    else
        self:SetNotice("Declined", bad, name.." declined your invitation.")
    end
end

function Handlers.CANCEL(self, sender, id)
    local invite = self.incoming
    if (invite and invite.id == id and same(sender, invite.from)) then
        self.incoming = nil
        StaticPopup_Hide(Friend.InviteDiag)
        KC:Print(Display(sender).." withdrew the invitation to a game of chess.")
        return
    end
    -- Our acceptance came too late: the game never started on their side
    local game = self:GetGame()
    if (self:IsOpponentGame(sender, id) and #game.moves == 0) then
        self:Finish({ kind = "abandoned" })
    end
end

function Handlers.MOVE(self, sender, id, ply, uci)
    local game = self:GetGame()
    if not (game and game.id == id) then
        self:Send(sender, "NOGAME", id or "-")
        return
    end
    if not self:IsOpponentGame(sender, id) then
        return
    end
    ply = tonumber(ply)
    local count = #self.history - 1
    if (not ply or ply <= count) then
        return -- Already have it
    end
    local pos = latest(self)
    if (ply > count + 1 or pos.turn == game.colour or not Rules.FindMove(Rules.Copy(pos), uci or "")) then
        -- Out of step: swap games to catch up
        self:SendSync("SYNC")
        return
    end
    self:AddMoves({ uci })
    if (self:InProgress() and not self:IsShown()) then
        KC:Print(Display(game.opponent).." has moved. Your move! (/kc friend)")
    end
end

local function syncHandler(reply)
    return function(self, sender, id, moves, result)
        local game = self:GetGame()
        if not (game and game.id == id) then
            if reply then
                self:Send(sender, "NOGAME", id or "-")
            end
            return
        end
        if not same(sender, game.opponent) then
            return
        end
        self:Reconcile(moves, result)
        if reply then
            self:SendSync("STATE")
        end
    end
end
Handlers.SYNC = syncHandler(true)
Handlers.STATE = syncHandler(false)

function Handlers.NOGAME(self, sender, id)
    if self:IsOpponentGame(sender, id) then
        self:Finish({ kind = "abandoned" })
    end
end

function Handlers.RESIGN(self, sender, id)
    if self:IsOpponentGame(sender, id) then
        self:Finish({ kind = "resign", winner = self:GetGame().colour })
    end
end

function Handlers.DRAWOFFER(self, sender, id)
    if self:IsOpponentGame(sender, id) then
        self.drawFrom = id
        StaticPopup_Show(Friend.DrawDiag, Display(sender))
    end
end

function Handlers.DRAWACCEPT(self, sender, id)
    if (self:IsOpponentGame(sender, id) and self.drawOffered) then
        self:Finish({ kind = "agreed" })
    end
end

function Handlers.DRAWDECLINE(self, sender, id)
    if (self:IsOpponentGame(sender, id) and self.drawOffered) then
        self.drawOffered = false
        self.note = Display(sender).." declined your draw offer."
        self:Update()
    end
end

-- Takes the opponent's moves we don't have yet (theirs is a comma list or "-"),
-- and a resignation or agreed draw
function Friend:Reconcile(moves, result)
    local game = self:GetGame()
    local theirs = {}
    for uci in (moves or "-"):gmatch("[^,%-]+") do
        theirs[#theirs + 1] = uci
    end

    local count = #self.history - 1
    for i = 1, math.min(#theirs, count) do
        if (theirs[i] ~= self.history[i + 1].uci) then
            KC:Print("Your game against "..Display(game.opponent).." doesn't match theirs.")
            return
        end
    end
    if (game.result == nil and #theirs > count) then
        local extra = {}
        for i = count + 1, #theirs do
            extra[#extra + 1] = theirs[i]
        end
        self:AddMoves(extra)
    end

    local kind, winner = (result or ""):match("^(%a+):(.)$")
    if (game.result == nil and (kind == "resign" or kind == "agreed")) then
        self:Finish({ kind = kind, winner = (winner == "w" or winner == "b") and winner or nil })
    end
end

-- Inviting -----------------------------------------------------------------------

-- Checks that name has the addon (and the same version), then invites them
function Friend:Invite(name)
    local C = ns.Colours
    if self:InProgress() then
        self:SetNotice("Game in progress", C.Bad, "Finish or resign your game against "..Display(self:GetGame().opponent).." first.")
        return
    end
    local target = Friend.FullName(name)
    if not target then
        local how = Friend.HasSurnames() and "Enter their first and last name, like Jane Smith." or "Use Name, or Name-Realm for another realm."
        self:SetNotice("Not a name", C.Bad, "\""..strtrim(name or "").."\" isn't a character name. "..how)
        return
    end
    if same(target, Friend.OwnName()) then
        self:SetNotice("That's you", C.Bad, "Invite someone else to play against.")
        return
    end

    self:CancelInvite()
    self.notice = nil
    local check = { target = target }
    check.timer = C_Timer.NewTimer(Friend.PingTimeout, function()
        if (self.checking == check) then
            self.checking = nil
            self:SetNotice("No answer", C.Bad, Display(target).." didn't answer: offline, out of reach, or without Karazhan Chess.")
        end
    end)
    self.checking = check
    self:Send(target, "PING", KC.version)
    self:Update()
end

local function newId()
    return string.format("%x%04x", time() % 0x1000000, math.random(0, 0xffff))
end

function Friend:SendInvite(target)
    local colour = self:GetSettings().colour
    if (colour ~= "w" and colour ~= "b") then
        colour = (math.random(2) == 1) and "w" or "b"
    end
    local invite = { id = newId(), target = target, colour = colour }
    invite.timer = C_Timer.NewTimer(Friend.InviteTimeout, function()
        if (self.pending == invite) then
            self.pending = nil
            self:Send(target, "CANCEL", invite.id)
            self:SetNotice("No answer", ns.Colours.Bad, Display(target).." didn't answer your invitation.")
        end
    end)
    self.pending = invite
    self:Send(target, "INVITE", KC.version, invite.id, otherColour(colour))
    self:Update()
end

-- Withdraws our invitation (or the check before it), if any
function Friend:CancelInvite()
    if self.checking then
        self.checking.timer:Cancel()
        self.checking = nil
    end
    if self.pending then
        self.pending.timer:Cancel()
        self:Send(self.pending.target, "CANCEL", self.pending.id)
        self.pending = nil
    end
    self:Update()
end

function Friend:AcceptInvite()
    local invite = self.incoming
    self.incoming = nil
    if not invite then
        return
    end
    if self:InProgress() then
        self:Send(invite.from, "DECLINE", invite.id, "busy")
        return
    end
    self:CancelInvite()
    self:Send(invite.from, "ACCEPT", invite.id)
    self:StartGame(invite.id, invite.from, invite.colour)
    if KC:HasWindow() then
        if not KC.frame:IsShown() then
            KC:ShowWindow()
        end
        KC:SetMode("friend")
    end
end

function Friend:DeclineInvite()
    local invite = self.incoming
    self.incoming = nil
    if invite then
        self:Send(invite.from, "DECLINE", invite.id, "no")
    end
end

-- Right-click menus on players (in the world, unit frames, names in chat, the
-- friends, guild and community lists) get "Invite to Karazhan Chess"
Friend.UnitMenus = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_BN_FRIEND", "MENU_UNIT_GUILD",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_MEMBER",
}

function Friend:AddUnitMenus()
    if not (Menu and Menu.ModifyMenu) then
        return
    end
    for _, tag in ipairs(Friend.UnitMenus) do
        Menu.ModifyMenu(tag, function(_, root, contextData)
            local name = Friend.GetMenuName(contextData)
            if not name then
                return
            end
            root:CreateDivider()
            local button = root:CreateButton("Invite to Karazhan Chess", function() self:InviteFromMenu(name) end)
            if (self:InProgress() and button.SetEnabled) then
                button:SetEnabled(false)
            end
        end)
    end
end

-- The player a unit menu is for (in FullName form), or nil for ourselves,
-- creatures and players we can't whisper (the other faction)
function Friend.GetMenuName(contextData)
    if not contextData then
        return nil
    end
    local name
    local unit = contextData.unit
    if (unit and UnitExists(unit)) then
        if (not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
                or UnitFactionGroup(unit) ~= UnitFactionGroup("player")) then
            return nil
        end
        -- The whole name: UnitName gives a Forever last name as if it were the realm
        name = GetUnitName(unit, true)
    elseif (contextData.accountInfo and contextData.accountInfo.gameAccountInfo) then
        local info = contextData.accountInfo.gameAccountInfo
        if not (info.isOnline and info.clientProgram == BNET_CLIENT_WOW and info.characterName) then
            return nil
        end
        name = info.characterName
        if (info.realmName and info.realmName ~= "" and not Friend.HasSurnames()) then
            name = name.."-"..info.realmName
        end
    else
        name = contextData.chatTarget or contextData.name
        local server = contextData.server
        if (name and server and server ~= "" and not name:find("[%s%-]")) then
            -- On Forever the "server" can be the last name
            name = name..(Friend.HasSurnames() and " " or "-")..server
        end
    end

    local full = Friend.FullName(name)
    if (not full or same(full, Friend.OwnName())) then
        return nil
    end
    return full
end

-- Invite from a unit menu: opens the window on Play vs Friend first
function Friend:InviteFromMenu(name)
    if KC:HasWindow() then
        if not KC.frame:IsShown() then
            KC:ShowWindow()
        end
        KC:SetMode("friend")
    end
    self:Invite(name)
end

-- Online friends to invite: character friends, and Battle.net friends in this
-- version of WoW. Each is { name (to invite), label }.
function Friend:GetOnlineFriends()
    local list, seen = {}, {}
    local function add(name, label)
        local full = Friend.FullName(name)
        if (full and not seen[full:lower()]) then
            seen[full:lower()] = true
            list[#list + 1] = { name = full, label = label }
        end
    end

    if (C_FriendList and C_FriendList.GetNumFriends) then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if (info and info.connected and info.name) then
                add(info.name, Display(info.name))
            end
        end
    end

    if (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
        for i = 1, BNGetNumFriends() do
            local account = C_BattleNet.GetFriendAccountInfo(i)
            local info = account and account.gameAccountInfo
            if (info and info.isOnline and info.clientProgram == BNET_CLIENT_WOW and info.characterName
                    and (WOW_PROJECT_ID == nil or info.wowProjectID == WOW_PROJECT_ID)) then
                local name = info.characterName
                if (info.realmName and info.realmName ~= "" and not Friend.HasSurnames()) then
                    name = name.."-"..info.realmName
                end
                add(name, info.characterName.." |cff82c5ff("..(account.accountName or "Battle.net")..")|r")
            end
        end
    end

    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

-- Playing ------------------------------------------------------------------------

function Friend:StartGame(id, opponent, colour)
    local settings = self:GetSettings()
    settings.game = { id = id, opponent = opponent, colour = colour, moves = {} }
    settings.last = opponent
    self.history = newHistory()
    self.notice, self.note, self.drawOffered, self.drawFrom = nil, nil, false, nil
    self:GetRecord(opponent)
    if self.active then
        self:ShowGame()
    else
        self:Update()
    end
end

-- A move made on the board (the board has already added it to self.history)
function Friend:OnPlayerMove(uci)
    local game = self:GetGame()
    if not self:InProgress() then
        return
    end
    self.note = nil
    self:Save()
    self:Send(game.opponent, "MOVE", game.id, #self.history - 1, uci)
    self:Continue()
end

-- Adds moves after the latest position: a single one is animated on the board
-- when the game is shown, several are put straight on
function Friend:AddMoves(list)
    if (self.active and #list == 1) then
        -- The board's history is self.history, so it records the move there
        if not KC.game:ExecuteMove(list[1]) then
            return
        end
    else
        for _, uci in ipairs(list) do
            if not appendMove(self.history, uci) then
                break
            end
        end
        if self.active then
            KC.game:ShowHistory(#self.history)
        end
    end
    self.note = nil
    self:Save()
    self:Continue()
end

-- After every move: is the game over?
function Friend:Continue()
    if self:InProgress() then
        local result = ns.Computer:GetResult(self.history)
        if result then
            self:Finish(result)
            return
        end
    end
    self:Update()
end

function Friend:OfferDraw()
    local game = self:GetGame()
    if (not self:InProgress() or self.drawOffered) then
        return
    end
    self.drawOffered = true
    self.note = "You offered "..Display(game.opponent).." a draw."
    self:Send(game.opponent, "DRAWOFFER", game.id)
    self:Update()
end

function Friend:AnswerDraw(accept)
    local id = self.drawFrom
    self.drawFrom = nil
    local game = self:GetGame()
    if not (id and self:InProgress() and game.id == id) then
        return
    end
    if accept then
        self:Send(game.opponent, "DRAWACCEPT", id)
        self:Finish({ kind = "agreed" })
    else
        self:Send(game.opponent, "DRAWDECLINE", id)
    end
end

function Friend:ResignWithConfirm()
    if self:InProgress() then
        StaticPopup_Show(Friend.ResignDiag, Display(self:GetGame().opponent))
    end
end

function Friend:Resign()
    if not self:InProgress() then
        return
    end
    local game = self:GetGame()
    self:Send(game.opponent, "RESIGN", game.id)
    self:Finish({ kind = "resign", winner = otherColour(game.colour) })
end

-- The game is over: it counts once towards the record against the opponent
-- (unless abandoned), and no more moves (< > still step through it)
function Friend:Finish(result)
    local game = self:GetGame()
    if (not game or game.result) then
        return
    end
    game.result = result
    self.drawOffered, self.drawFrom, self.note = false, nil, nil
    StaticPopup_Hide(Friend.DrawDiag)
    StaticPopup_Hide(Friend.ResignDiag)

    if (result.kind ~= "abandoned") then
        local record = self:GetRecord(game.opponent)
        if (result.winner == nil) then
            record.drawn = record.drawn + 1
        elseif (result.winner == game.colour) then
            record.won = record.won + 1
        else
            record.lost = record.lost + 1
        end
    end
    self:Update()
    if not self:IsShown() then
        local headline, _, detail = self:DescribeResult(game)
        KC:Print("Your game against "..Display(game.opponent)..": "..headline.." "..detail)
    end
end

-- Info bar ------------------------------------------------------------------------

-- A message for the info bar between games (also printed if the tab isn't shown)
function Friend:SetNotice(headline, colour, detail)
    self.notice = { headline, colour, detail }
    if not self:IsShown() then
        KC:Print(detail)
    end
    self:Update()
end

-- Headline, colour and detail for a finished game
function Friend:DescribeResult(game)
    local C = ns.Colours
    local result = game.result
    local name = Display(game.opponent)
    if (result.kind == "abandoned") then
        return "Game abandoned", C.Neutral, name.." no longer has this game. It doesn't count."
    elseif (result.kind == "agreed") then
        return "Draw", C.Neutral, "Draw agreed."
    elseif (result.winner == nil) then
        return "Draw", C.Neutral, ns.Computer.DrawReasons[result.kind] or ""
    end

    local won = (result.winner == game.colour)
    local detail
    if (result.kind == "resign") then
        detail = won and (name.." resigned.") or "You resigned."
    else
        detail = "Checkmate. "..sideName(result.winner).." wins."
    end
    if won then
        return "Victory!", C.Good, detail
    end
    return "Defeat", C.Bad, detail
end

function Friend:GetRecordLine(name)
    local record = self:GetRecord(name)
    return "vs "..Display(record.name).." · Won "..record.won.." · Lost "..record.lost.." · Drawn "..record.drawn
end

function Friend:ShowStatus()
    if not self.active then
        return
    end
    local C = ns.Colours
    local game = self:GetGame()
    local opponent = (game and game.opponent) or self:GetSettings().last
    local footer = opponent and self:GetRecordLine(opponent) or nil

    if self.checking then
        KC:SetStatus("Looking for "..Display(self.checking.target), C.Neutral, "Checking that they have Karazhan Chess...", footer)
    elseif self.pending then
        KC:SetStatus("Invitation sent", C.Neutral, "Waiting for "..Display(self.pending.target).." to accept...", footer)
    elseif (self.notice and not self:InProgress()) then
        KC:SetStatus(self.notice[1], self.notice[2], self.notice[3], footer)
    elseif not game then
        KC:SetStatus("Play vs Friend", C.Normal, "Click Invite to play a friend who has Karazhan Chess.", footer)
    elseif game.result then
        local headline, colour, detail = self:DescribeResult(game)
        KC:SetStatus(headline, colour, detail, footer)
    else
        local detail = self.note or ("You play "..sideName(game.colour).." against "..Display(game.opponent))
        local pos = latest(self)
        if (pos.turn == game.colour) then
            local inCheck = Rules.InCheck(pos, game.colour)
            KC:SetStatus(inCheck and "Check!" or "Your move", inCheck and C.Bad or C.Normal, detail, footer)
        else
            KC:SetStatus(Display(game.opponent).."'s move", C.Neutral, detail, footer)
        end
    end
end
