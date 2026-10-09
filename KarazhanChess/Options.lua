-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author: Mike D (MeloN <Convicted>)
--
-- Option Handler
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Icons = ns.Icons

-------------
-- Options --
-------------
KC.options = {
	name =  "",
	handler = KC,
	type = 'group',
	args = {
		titleText = {
			type = "description",
			name = KC.formattedName,
			fontSize = "large",
			order = 1,
        },
		authorText = {
			type = "description",
			name = "|cFF9CD6DE" .. "By MeloN <".."|cffff5c33Convicted".."|cFF9CD6DE>",
			fontSize = "small",
			order = 3,
		},
		lichessText = {
			type = "description",
			name = "|cFF9CD6DE" .. "Piece sets, board colours and puzzles from lichess.org",
			fontSize = "small",
			order = 2,
		},
		mainText = {
			type = "description",
			name = "|cFFFFFF00" .. "\n/kc -  Play Chess\n/kc puzzle - Puzzles\n/kco - Options Panel",
			fontSize = "medium",
			order = 4,
		},
		resetOptionsButton = {
			type = "execute",
            name = "Reset Options",
            desc = "Resets all Options to the Defaults",
			order = 5,
			func = "resetProfile"
		},
		resetSizeButton = {
			type = "execute",
            name = "Reset Size",
            desc = "Resets the chess window to its default size",
			order = 6,
			func = "resetWindowSize"
		},
		testsButton = {
			type = "execute",
			name = "Tests",
			desc = "Opens the manual test panel (development builds only)",
			order = 7,
			hidden = function() return not ns.TestPanel end,
			func = function() ns.TestPanel:OpenFromOptions() end,
		},
        generalHeader = {
			type = "header",
			name = "General",
			order = 20,
		},
		minimapButton = {
			type = "toggle",
            name = "Show Minimap Button",
            desc = "Toggle the Minimap Button On and Off",
			order = 21,
			get = "getMinimapButton",
			set = "setMinimapButton",
		},
		fadeOutWindowToggle = {
			type = "toggle",
            name = "Fade Out Window",
            desc = "Fades the window out when the mouse leaves.",
			order = 22,
			get = "getWindowFadeout",
			set = "setWindowFadeout",
		},
		boardLabelToggle = {
			type = "toggle",
            name = "Show Board Labels",
            desc = "Show the board coordinates for each file and rank.",
			order = 23,
			get = "getBoardLabelsVisible",
			set = "setBoardLabelsVisible",
		},
		windowSizeSlider = {
			type = "range",
            name = "Window Size",
            desc = "Size of the chess window. You can also drag the grip in its bottom-right corner.",
			order = 25,
			min = KC.minWindowScale,
			max = KC.maxWindowScale,
			step = 0.05,
			isPercent = true,
			get = "getWindowSize",
			set = "setWindowSize",
		},
		windowOpacitySlider = {
			type = "range",
            name = "Window Opacity",
            desc = "Opacity of the window background, border and text. The board and pieces always stay solid.",
			order = 24,
			min = 0.2,
			max = 1,
			step = 0.05,
			isPercent = true,
			get = "getWindowOpacity",
			set = "setWindowOpacity",
		},
		colorHeader = {
			type = "header",
			name = "Themes",
			order = 40,
		},
		boardTheme = {
			type = "select",
            name = "Board Theme",
			order = 41,
			values = Icons.Board.ThemeValues,
			sorting = Icons.Board.Themes,
			style = "dropdown",
			get = "getBoardTheme",
			set = "setBoardTheme",
		},
		pieceTheme = {
			type = "select",
            name = "Piece Theme",
			order = 42,
			values = Icons.Piece.ThemeValues,
			sorting = Icons.Piece.Themes,
			style = "dropdown",
			get = "getPieceTheme",
			set = "setPieceTheme",
		},
		puzzleHeader = {
			type = "header",
			name = "Puzzles",
			order = 60,
		},
		puzzleProgress = {
			type = "description",
			name = function() return KC:getPuzzleProgressText() end,
			fontSize = "medium",
			order = 62,
		},
		puzzleTypesButton = {
			type = "execute",
			name = "Puzzle Types",
			desc = "Choose which kinds of puzzle you get",
			order = 62.5,
			func = function() Settings.OpenToCategory(KC.KCPuzzleTypesID) end,
		},
		resetPuzzlesButton = {
			type = "execute",
			name = "Reset Puzzle Progress",
			desc = "Sets your puzzle rating back to "..ns.Puzzles.StartRating.." and forgets which puzzles you have solved or failed.",
			confirm = true,
			confirmText = "Reset your puzzle rating and forget all solved and failed puzzles?",
			order = 63,
			func = function() ns.Puzzles:ResetProgress() end,
		},
		hiddenHeader = {
			type = "header",
			hidden = true,
			name = "------- HIDDEN OPTION VALUES BELOW HERE -------",
		}
	},
};


-- Puzzle Types: its own page under Karazhan Chess, with a tick box per type
-- (Puzzles.TypeGroups), in one inline group per group of types
KC.puzzleTypesAppName = KC.name.." Puzzle Types"
KC.puzzleTypeOptions = {
	name = "",
	type = "group",
	args = {
		intro = {
			type = "description",
			name = "Tick the kinds of puzzle you want. A puzzle is offered if any of its types is ticked; Other puzzles are those with none of these types. The current puzzle isn't affected.\n",
			fontSize = "medium",
			order = 1,
		},
		allOn = {
			type = "execute",
			name = "Tick All",
			order = 2,
			func = function() ns.Puzzles:SetAllTypesEnabled(true) end,
		},
		allOff = {
			type = "execute",
			name = "Untick All",
			order = 3,
			func = function() ns.Puzzles:SetAllTypesEnabled(false) end,
		},
	},
}

for i, group in ipairs(ns.Puzzles.TypeGroups) do
	local args = {}
	for j, puzzleType in ipairs(group.types) do
		args[puzzleType.key] = {
			type = "toggle",
			name = puzzleType.name,
			order = j,
			width = 1.2,
			get = function() return ns.Puzzles:IsTypeEnabled(puzzleType.key) end,
			set = function(info, value) ns.Puzzles:SetTypeEnabled(puzzleType.key, value) end,
		}
	end
	KC.puzzleTypeOptions.args[group.key] = {
		type = "group",
		inline = true,
		name = group.name,
		order = 10 + i,
		args = args,
	}
end


---------------------
-- Default Options --
---------------------
KC.optionDefaults = {
	global = {
		minimapIcon = {["minimapPos"] = 180, ["hide"] = false},
		minimapButton = true,
		fadeoutWindow = false,
		boardLabels = true,
		windowOpacity = 0.75,
		windowScale = 1.0,
		boardTheme = "Default",
		pieceTheme = "Default",
		puzzleTypesOff = {}, -- puzzle types unticked: { [type key] = true } (Puzzles.TypeGroups)
		puzzles = {
			rating = 1500,
			tier = "Normal",
			solved = {},
			failed = {},
			current = nil,
		},
	},
};

-------------------
-- Reset Options --
-------------------
function KC:resetProfile(info)
	-- Puzzle progress isn't an option, so it survives (it has its own reset)
	local puzzles = self.db.global.puzzles
	self.db:ResetDB(KC.profileName)
	self.db.global.puzzles = puzzles

	-- ResetDB replaces db.global, so point the minimap icon at the new settings table
	KC.ICON:Refresh(KC.name, KC.db.global.minimapIcon)

	-- Call all the update methods
	KC:updateMinimapButton()
	KC:updateWindowFadeout()
	KC:updateBoardLabelsVisible()
	KC:updateWindowOpacity()
	KC:RestoreWindowPosition()
	KC:updateBoardTheme()
	KC:updatePieceTheme()
end


----------------
-- Reset Size --
----------------
function KC:resetWindowSize(info)
	-- Scale back to the default, keeping the window's top-left corner where it is
	self:setWindowSize(info, KC.optionDefaults.global.windowScale)
	KC.ACR:NotifyChange(KC.name)
end


-----------------------
-- Getters & Setters --
-----------------------

-- Minimap Button

function KC:setMinimapButton(info, value)
	self.db.global.minimapButton = value;
	self.db.global.minimapIcon.hide = not value;

	KC.updateMinimapButton()
end

function KC:getMinimapButton(info)
	return self.db.global.minimapButton;
end

function KC:updateMinimapButton()
	if (KC.db.global.minimapButton) then
		KC.ICON:Show(KC.name);
	else
		KC.ICON:Hide(KC.name);
	end
end


-- Fadeout Toggle

function KC:setWindowFadeout(info, value)
	self.db.global.fadeoutWindow = value;
	self:updateWindowFadeout()
end

function KC:getWindowFadeout(info)
	return self.db.global.fadeoutWindow;
end

function KC:updateWindowFadeout()
	-- Make sure we can see the window if we're turning it off
	if (not KC:getWindowFadeout()) then
		KC.frame:SetAlpha(KC:getWindowOpacity())
	end
end


-- Board Labels

function KC:setBoardLabelsVisible(info, value)
	self.db.global.boardLabels = value;
	self:updateBoardLabelsVisible()
end

function KC:getBoardLabelsVisible(info)
	return self.db.global.boardLabels;
end

function KC:updateBoardLabelsVisible()
	self:applyBoardLabelVisibility();
end


-- Window Size

function KC:setWindowSize(info, value)
	KC:SetWindowScale(value)
	KC:SaveWindowPosition()
end

function KC:getWindowSize(info)
	return self.db.global.windowScale;
end


-- Window Opacity

function KC:setWindowOpacity(info, value)
	self.db.global.windowOpacity = value;
	self:updateWindowOpacity()
end

function KC:getWindowOpacity(info)
	return self.db.global.windowOpacity;
end

function KC:updateWindowOpacity()
	self:applyWindowOpacity()
end


-- Puzzle Progress

function KC:getPuzzleProgressText()
	local progress = self.db.global.puzzles
	local solved, failed = 0, 0
	for _ in pairs(progress.solved) do solved = solved + 1 end
	for _ in pairs(progress.failed) do failed = failed + 1 end
	return "Puzzle rating: |cffffffff"..progress.rating.."|r   Solved: |cffffffff"..solved.."|r   Failed: |cffffffff"..failed.."|r\n"
end


-- Theme Migration

-- Themes used to be saved as an index into the theme list. Convert any index to
-- the theme name it meant, and fall back to Default for anything unknown (for
-- example a theme that has since been removed).
local function migrateTheme(value, themes)
	if type(value) == "number" then
		value = themes.LegacyThemes[value]
	end
	if value == nil or themes.ThemeValues[value] == nil then
		return "Default"
	end
	return value
end

function KC:migrateThemeSettings()
	self.db.global.boardTheme = migrateTheme(self.db.global.boardTheme, Icons.Board)
	self.db.global.pieceTheme = migrateTheme(self.db.global.pieceTheme, Icons.Piece)
end


-- Board Theme

function KC:setBoardTheme(info, value)
	self.db.global.boardTheme = value;
	self:updateBoardTheme()
end

function KC:getBoardTheme(info)
	return self.db.global.boardTheme;
end

function KC:updateBoardTheme()
	self:applyBoardTextures();
end


-- Piece Theme

function KC:setPieceTheme(info, value)
	self.db.global.pieceTheme = value;
	KC:updatePieceTheme()
end

function KC:getPieceTheme(info)
	return self.db.global.pieceTheme;
end

function KC:updatePieceTheme()
	self:applyPieceTextures();
end


