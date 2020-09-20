-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author: Mike D (MeloN <Convicted>)
--
-- Option Handler
-------------------------------------------------------------------------------

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
			name = "|cFF9CD6DE" .. "by MeloN <Convicted>",
			fontSize = "medium",
			order = 2,
		},
		mainText = {
			type = "description",
			name = "|cFFFFFF00" .. "\n/kc -  Play Chess\n/kco - Options Panel",
			fontSize = "medium",
			order = 3,
		},
		resetOptionsButton = {
			type = "execute",
            name = "Reset Options",
            desc = "Resets all Options to the Defaults",
			order = 4,
			func = "resetProfile"
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
		colorHeader = {
			type = "header",
			name = "Themes",
			order = 40,
		},
		boardTheme = {
			type = "select",
            name = "Board Theme",
			order = 41,
			values = Icons.Board.Themes,
			style = "dropdown",
			get = "getBoardTheme",
			set = "setBoardTheme",
		},
		pieceTheme = {
			type = "select",
            name = "Piece Theme",
			order = 41,
			values = Icons.Piece.Themes,
			style = "dropdown",
			get = "getPieceTheme",
			set = "setPieceTheme",
		},
		hiddenHeader = {
			type = "header",
			hidden = true,
			name = "------- HIDDEN OPTION VALUES BELOW HERE -------",
		}
	},
};


---------------------
-- Default Options --
---------------------
KC.optionDefaults = {
	global = {
		minimapIcon = {["minimapPos"] = 180, ["hide"] = false},
		minimapButton = true,
		fadeoutWindow = false,
		boardTheme = 1,
		pieceTheme = 1,
	},
};


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

-- Reset the Postion of the Window

function KC:resetWindowPosition(info)
	print("TODO - Reset Window Pos")
end

function KC:resetProfile(info)
	self.db:ResetDB(KC.profileName)

	-- Make sure the set functions that change things get exectuted
	KC.updateMinimapButton()
end

-- Fadeout Toggle

function KC:setWindowFadeout(info, value)
	self.db.global.fadeoutWindow = value;

	-- Make sure we can see the window if we're turning it off
	if (not value) then
		KC.frame:SetAlpha(1.0)
	end
end

function KC:getWindowFadeout(info)
	return self.db.global.fadeoutWindow;
end

-- Board Theme

function KC:setBoardTheme(info, value)
	self.db.global.boardTheme = value;
	-- TODO - refresh board and apply theme
end

function KC:getBoardTheme(info)
	return self.db.global.boardTheme;
end

-- Piece Theme

function KC:setPieceTheme(info, value)
	self.db.global.pieceTheme = value;
	-- TODO - refresh pieces and apply theme
end

function KC:getPieceTheme(info)
	return self.db.global.pieceTheme;
end

