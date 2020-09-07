-------------------------------------------------------------------------------
-- Karazhan Chess (https://github.com/MikeD89/KarazhanChess)
-- Author:  Mike D (MeloN <Convicted>)
--
-- Main Loader and Entry Point
-------------------------------------------------------------------------------

--------------------
---- Addon Init ----
--------------------

KC = LibStub("AceAddon-3.0"):NewAddon("KarazhanChess", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0");

-- Get the version & date. This is set by the packager.
KC.version = "@project-version@"
KC.dateChanged = "@project_date_integer@"
if KC.version:find("@", nil, true) then
    KC.version = "0.0_dev"
end

if KC.dateChanged:find("@", nil, true) then
    KC.dateChanged = "20080808133730"
end

-------------------
---- Libraries ----
-------------------

-- Libraries
KC.CONFIG = LibStub("AceConfig-3.0")                              
KC.ICON = LibStub("LibDBIcon-1.0")
KC.LSM = LibStub("LibSharedMedia-3.0")
KC.SER = LibStub("AceSerializer-3.0");
KC.ACD = LibStub("AceConfigDialog-3.0")
KC.ACR = LibStub("AceConfigRegistry-3.0");
KC.LDB = LibStub("LibDataBroker-1.1");

-- Globals
KC.name = "Karazhan Chess"
KC.formattedName = KC.name.." ("..format("|cff33ffff%s|r","v"..KC.version)..")"
KC.dbName = "KarazhanChessDB"
KC.dateChangedReal = showRealDate(KC.dateChanged)
KC.player = UnitName("player")
KC.realm = GetRealmName();
KC.faction = UnitFactionGroup("player");

function KC:OnInitialize()
	-- Open the databace and register options
	self.db = LibStub("AceDB-3.0"):New(KC.dbName, KC.optionDefaults, "Default");
	
	-- Register options
	LibStub("AceConfig-3.0"):RegisterOptionsTable(KC.name, KC.options);
	self.KCOptions = KC.ACD:AddToBlizOptions(KC.name, KC.name);

	-- TODO - Multiplayer Comms
	--self:RegisterComm(self.commPrefix);

	-- Setup Methods
	KC:createBroker()
end

function KC:OnEnable()
    KC:Print(KC.formattedName.." Loaded!")
end


----------------------
---- Minimap Icon ----
----------------------

function KC:createBroker()
	-- Data for the Minimap Broker
	-- TODO - Why does this not display my icon?
	-- "Interface\\AddOns\\KarazhanChess\\Textures\\minimap.png"
	local data = {
		type = "launcher", 
		label = KC.name, 
		icon = "Interface\\AddOns\\ElvUI\\Media\\Textures\\Button-Backpack-Up.tga"
	}
	
	-- Create minimap button
	local dataBroker = KC.LDB:NewDataObject(KC.name, data);

	-- Register Click Function
	function dataBroker.OnClick(self, button)
		if (button == "LeftButton") then
			KC:OpenWindow()
		elseif (button == "RightButton") then
			if (InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown()) then
				InterfaceOptionsFrame:Hide();
			else
				KC:OpenConfig();
			end
		end
	end

	-- Tooltip Options	
	function dataBroker.OnTooltipShow(GameTooltip)
		GameTooltip:SetText("Karazhan Chess", 1, 1, 1)
		GameTooltip:AddLine(("%s (%s)"):format(KC.version, KC.dateChangedReal), 0.2, 0.4, 0.6, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Click to Open!", 1, 1, 1, 1)
		GameTooltip:AddLine("Right Click for Config.", 1, 1, 1, 1)
	end

	-- Register Minimap Icon
	KC.ICON:Register(KC.name, dataBroker, KC.db.global.minimapIcon);
end

---------------------------
---- Window Management ----
---------------------------

function KC:OpenConfig()
	--Opening the frame needs to be run twice to avoid a bug.
	InterfaceOptionsFrame_OpenToCategory(KC.name);
	InterfaceOptionsFrame_OpenToCategory(KC.name);
end

function KC:OpenWindow() 
    shown = not shown
    print("Toggle Window! ")
    print(shown)
end 
	
------------------------------
---- Setup Slash Commands ----
------------------------------

-- Main Window
SlashCmdList['CHESSCMD'] = function(msg)
    KC:OpenWindow() 
end

SLASH_CHESSCMD1, SLASH_CHESSCMD2, SLASH_CHESSCMD3, SLASH_CHESSCMD4, SLASH_CHESSCMD5 
	= '/kc', '/karazhanchess', '/chess', '/karachess', '/kchess';

-- Options
SlashCmdList['CHESSOPTIONCMD'] = function(msg)
    KC:OpenConfig()
end

SLASH_CHESSOPTIONCMD1, SLASH_CHESSOPTIONCMD2, SLASH_CHESSOPTIONCMD3, SLASH_CHESSOPTIONCMD4, SLASH_CHESSOPTIONCMD5 
	= '/kco', '/karazhanchessoptions', '/chessoptions', '/karachessoptions', '/kchessoptions';


