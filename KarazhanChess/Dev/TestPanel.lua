-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Test panel (dev builds only): steps through the manual tests in Tests.lua
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Tests = ns.DevTests

-- Dev builds only. Packaged builds leave the Dev folder out entirely.
if not KC.isDevBuild or not Tests then
	return
end

-- Opened from the Tests button in the options (or /kc tests). Shows one test at a
-- time: what Load sets up, the steps to take and what to check. The current test
-- is saved by ID, so it survives a /reload in the middle of a test.
local TestPanel = {}
ns.TestPanel = TestPanel

TestPanel.Width = 380
TestPanel.Padding = 18
TestPanel.MoveDelay = 0.3 -- seconds between scripted setup moves (the slide takes 0.1)

TestPanel.index = 1
TestPanel.token = 0 -- bumped on every load, so pending setup moves from an earlier one stop

-- Current test -----------------------------------------------------------------

function TestPanel:GetIndex()
	local saved = KC.db.global.devTest
	if saved then
		for i, test in ipairs(Tests) do
			if (test.id == saved) then
				return i
			end
		end
	end
	return 1
end

function TestPanel:SetIndex(index)
	self.index = math.max(1, math.min(index, #Tests))
	KC.db.global.devTest = Tests[self.index].id
	self:Refresh()
end

function TestPanel:Step(delta)
	self:SetIndex(self.index + delta)
end

-- Describes what Load does for a test, for the panel
local function describeLoad(load)
	if not load then
		return "Load just opens the window."
	end

	local parts = {}
	if load.fen then
		parts[#parts + 1] = "FEN |cffffffff"..load.fen.."|r"
	elseif load.newGame then
		parts[#parts + 1] = "New Game"
	elseif load.clear then
		parts[#parts + 1] = "empty board"
	end
	if load.computer then
		parts[#parts + 1] = "against the "..load.computer.level.." computer, you play "..((load.computer.colour == "b") and "black" or "white")
	end
	if load.flipped then
		parts[#parts + 1] = "board flipped"
	end
	if load.moves then
		parts[#parts + 1] = "then plays |cffffffff"..table.concat(load.moves, " ").."|r"
	end
	if (load.mode == "puzzle") then
		parts[#parts + 1] = "switches to Puzzles"
	elseif (load.mode == "play") then
		parts[#parts + 1] = "switches to Play"
	end
	return "Load: "..table.concat(parts, ", ")
end

-- Loading a test -----------------------------------------------------------------

-- Sets the board up as the test describes (see the load fields in Tests.lua)
function TestPanel:Load(test)
	local load = test.load or {}
	local game = KC.game
	self.token = self.token + 1

	if not KC.frame:IsShown() then
		KC:ShowWindow()
	end

	local setsBoard = load.fen or load.newGame or load.clear
	if (setsBoard or load.mode == "play") then
		KC:SetMode("play")
	elseif (load.mode == "puzzle") then
		KC:SetMode("puzzle")
	end

	if setsBoard then
		StaticPopup_Hide(game.NewGameConfirmDiag)
		StaticPopup_Hide(game.ClearBoardConfirmDiag)
		ns.Computer:Stop()
		if load.computer then
			-- Sets the board up (FEN or start position) and turns it to the player
			local ok, err = ns.Computer:Start(load.computer.level, load.computer.colour or "w", load.fen)
			if not ok then
				KC:Print(test.id..": invalid FEN: "..tostring(err))
			end
			return
		elseif load.fen then
			local turn, err = game:LoadFEN(load.fen)
			if not turn then
				KC:Print(test.id..": invalid FEN: "..err)
				return
			end
		elseif load.newGame then
			game:StartNewGame()
		else
			game:ClearBoard()
			game:ResetHistory("w")
		end
		KC:SetBoardFlipped(load.flipped and true or false)
	end

	if load.moves then
		self:PlayMoves(test, load.moves, 1, self.token)
	end
end

-- Plays the setup moves one after another, animated
function TestPanel:PlayMoves(test, moves, i, token)
	if (token ~= self.token or moves[i] == nil) then
		return
	end
	if not KC.game:ExecuteMove(moves[i]) then
		KC:Print(test.id..": setup move "..moves[i].." isn't legal here")
		return
	end
	C_Timer.After(self.MoveDelay, function() self:PlayMoves(test, moves, i + 1, token) end)
end

-- Frame ---------------------------------------------------------------------------

local function createButton(parent, text, width, onClick)
	local button = CreateFrame("BUTTON", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function createText(parent, font, r, g, b)
	local text = parent:CreateFontString(nil, "ARTWORK", font)
	text:SetWidth(TestPanel.Width - 2 * TestPanel.Padding)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(true)
	if r then
		text:SetTextColor(r, g, b)
	end
	return text
end

function TestPanel:Create()
	local inset = 8
	local pad = self.Padding

	local frame = CreateFrame("FRAME", nil, UIParent, "BackdropTemplate")
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = inset, right = inset, top = inset, bottom = inset }
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:SetWidth(self.Width)
	frame:SetFrameStrata("DIALOG") -- above the chess window and the Settings panel
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
	self.frame = frame

	local title = frame:CreateFontString(nil, "ARTWORK")
	title:SetFont("Fonts\\MORPHEUS.TTF", 20, "OUTLINE")
	title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	title:SetText("Karazhan Chess Tests")
	title:SetPoint("TOP", frame, "TOP", 0, -16)

	local close = CreateFrame("BUTTON", nil, frame, "UIPanelCloseButton")
	close:SetSize(30, 30)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset + 2, -inset + 2)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- Section button: shows the current section and opens a menu to jump to another
	self.sectionButton = createButton(frame, "", self.Width - 2 * pad, function(button) self:OpenSectionMenu(button) end)
	self.sectionButton:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -44)

	self.counter = createText(frame, "GameFontDisableSmall")
	self.counter:SetJustifyH("RIGHT")
	self.counter:SetPoint("TOPRIGHT", self.sectionButton, "BOTTOMRIGHT", 0, -10)

	self.heading = createText(frame, "GameFontHighlightLarge")
	self.heading:SetPoint("TOPLEFT", self.sectionButton, "BOTTOMLEFT", 0, -10)

	self.loadText = createText(frame, "GameFontNormalSmall")
	self.loadText:SetPoint("TOPLEFT", self.heading, "BOTTOMLEFT", 0, -8)

	self.stepsLabel = createText(frame, "GameFontNormal")
	self.stepsLabel:SetText("Steps")
	self.stepsLabel:SetPoint("TOPLEFT", self.loadText, "BOTTOMLEFT", 0, -14)

	self.stepsText = createText(frame, "GameFontHighlight")
	self.stepsText:SetSpacing(3)
	self.stepsText:SetPoint("TOPLEFT", self.stepsLabel, "BOTTOMLEFT", 0, -4)

	self.checkLabel = createText(frame, "GameFontNormal")
	self.checkLabel:SetText("Check")
	self.checkLabel:SetPoint("TOPLEFT", self.stepsText, "BOTTOMLEFT", 0, -14)

	self.checkText = createText(frame, "GameFontHighlight")
	self.checkText:SetPoint("TOPLEFT", self.checkLabel, "BOTTOMLEFT", 0, -4)

	-- Bottom row: previous, load, next
	self.loadButton = createButton(frame, "Load", 100, function() self:Load(Tests[self.index]) end)
	self.loadButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)

	self.prevButton = createButton(frame, "< Previous", 100, function() self:Step(-1) end)
	self.prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, 18)

	self.nextButton = createButton(frame, "Next >", 100, function() self:Step(1) end)
	self.nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, 18)
end

-- Fills the panel with the current test and fits the height to the text
function TestPanel:Refresh()
	if not self.frame then
		return
	end
	local test = Tests[self.index]

	self.sectionButton:SetText(test.section)
	self.counter:SetText(self.index.." / "..#Tests)
	self.heading:SetText("|cffffd100"..test.id.."|r  "..test.name)
	self.loadText:SetText(describeLoad(test.load))

	local steps = {}
	for i, step in ipairs(test.steps or {}) do
		steps[i] = i..". "..step
	end
	if (#steps == 0) then
		steps[1] = "Press Load."
	end
	self.stepsText:SetText(table.concat(steps, "\n"))
	self.checkText:SetText(test.check.."\n\nBugSack stays empty.")

	self.prevButton:SetEnabled(self.index > 1)
	self.nextButton:SetEnabled(self.index < #Tests)

	-- Everything from the section button down to the check text, plus the button row
	local height = 44 + self.sectionButton:GetHeight() + 10
	for _, text in ipairs({ self.heading, self.loadText, self.stepsLabel, self.stepsText, self.checkLabel, self.checkText }) do
		height = height + text:GetStringHeight()
	end
	height = height + 8 + 14 + 4 + 14 + 4 -- gaps between the texts
	self.frame:SetHeight(height + 24 + 22 + 18)
end

-- Menu of sections; choosing one jumps to its first test
function TestPanel:OpenSectionMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Jump to section")
		local last
		for i, test in ipairs(Tests) do
			if (test.section ~= last) then
				last = test.section
				root:CreateRadio(test.section,
					function() return Tests[self.index].section == test.section end,
					function() self:SetIndex(i) end)
			end
		end
	end)
end

function TestPanel:Show()
	if not self.frame then
		self:Create()
		self.index = self:GetIndex()
	end
	self.frame:Show()
	self.frame:Raise()
	self:Refresh() -- after Show, so the text heights are measured
end

function TestPanel:Toggle()
	if (self.frame and self.frame:IsShown()) then
		self.frame:Hide()
	else
		self:Show()
	end
end

-- From the options panel: close Settings so the board is free to use
function TestPanel:OpenFromOptions()
	if (SettingsPanel and SettingsPanel:IsShown()) then
		HideUIPanel(SettingsPanel)
	end
	if not KC.frame:IsShown() then
		KC:ShowWindow()
	end
	self:Show()
end
