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
        generalHeader = {
			type = "header",
			name = "General",
			order = 5,
		},
		minimapButton = {
			type = "toggle",
            name = "Show Minimap Button",
            desc = "Toggle the Minimap Button On and Off",
			order = 20,
			get = "getMinimapButton",
			set = "setMinimapButton",
		},
	},
};

---------------------
-- Default Options --
---------------------
KC.optionDefaults = {
	global = {
		minimapIcon = {["minimapPos"] = 180, ["hide"] = false},
		minimapButton = true,
	},
};


--Minimap button
function KC:setMinimapButton(info, value)
	self.db.global.minimapButton = value;
	if (value) then
		KC.ICON:Show(KC.name);
		self.db.global.minimapIcon.hide = false;
	else
		KC.ICON:Hide(KC.name);
		self.db.global.minimapIcon.hide = true;
	end
end

function KC:getMinimapButton(info)
	return self.db.global.minimapButton;
end
