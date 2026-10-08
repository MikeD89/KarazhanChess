-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Main Loader and Entry Point
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local Game, Icons = ns.Game, ns.Icons
local showRealDate, isNull = ns.showRealDate, ns.isNull

------------------------
---- Initialisation ----
------------------------

-- The addon object (KC) is created in Init.lua

-- Get the version & date. This is set by the packager.
KC.version = "@project-version@"
KC.dateChanged = "@project_date_integer@"
if KC.version:find("@", nil, true) then
    KC.version = "0.0_dev"
end

if KC.dateChanged:find("@", nil, true) then
    KC.dateChanged = "20080808133730"
end

-- Utility function that lets me check for debug print statements
function KC:P(text)
	KC:Print(text)
end

-------------------
---- Libraries ----
-------------------

-- Libraries
KC.CONFIG = LibStub("AceConfig-3.0");
KC.ICON = LibStub("LibDBIcon-1.0");
KC.LDB = LibStub("LibDataBroker-1.1");
KC.LSM = LibStub("LibSharedMedia-3.0");
KC.SER = LibStub("AceSerializer-3.0");
KC.ACD = LibStub("AceConfigDialog-3.0");
KC.ACR = LibStub("AceConfigRegistry-3.0");
KC.GUI = LibStub("AceGUI-3.0");

-- Globals
KC.loaded = false
KC.name = "Karazhan Chess"
KC.dbName = "KarazhanChessDB"
KC.formattedVersion = format("|cff33ffff%s|r","v"..KC.version)
KC.formattedName = KC.name.." - "..KC.formattedVersion
KC.dateChangedReal = showRealDate(KC.dateChanged)
KC.player = UnitName("player")
KC.realm = GetRealmName();
KC.faction = UnitFactionGroup("player");
KC.profileName = "Default"

-- Frame Globals
KC.frame = nil
KC.game = nil
KC.fixedWidth = 450
KC.fixedHeight = 500
KC.boardAlpha = 0.8
KC.boardDim = 8 
KC.boardSectionSize = floor(KC.fixedWidth / (KC.boardDim + 0.75))
KC.boardWidth = KC.boardSectionSize * KC.boardDim
KC.boardHeight = KC.boardWidth
KC.frameMargin = (KC.fixedWidth - KC.boardWidth) / 2

-- Init Function
function KC:OnInitialize()
	-- Open the databace and register options
	self.db = LibStub("AceDB-3.0"):New(KC.dbName, KC.optionDefaults, KC.profileName);
	
	-- Register options
	LibStub("AceConfig-3.0"):RegisterOptionsTable(KC.name, KC.options);
	self.KCOptions, self.KCOptionsID = KC.ACD:AddToBlizOptions(KC.name, KC.name);

	-- Setup Brokers
	KC:createBroker()

	-- Create the frame. We do this early so the position is loaded
	KC.frame = CreateFrame("FRAME", KC.name, UIParent, "BackdropTemplate")
	KC.frame:SetMovable(true)
	KC.frame:SetDontSavePosition(true) -- We save the position ourselves in the DB
	KC.frame:Hide()

	-- Create the game
	KC.game = Game:new()

	-- Insert ourselves into the special frame list so we close on ESC
	KC:SetCloseOnEscape(true)

	-- Being in UISpecialFrames means opening or closing the Settings panel closes us too.
	-- While Settings is open we leave UISpecialFrames, so closing it doesn't touch us.
	-- Opening it still hides us before OnShow fires, so re-show if we were hidden that frame.
	KC.frame:HookScript("OnHide", function() KC.frameHiddenAt = GetTime() end)
	if SettingsPanel then
		SettingsPanel:HookScript("OnShow", function()
			KC:SetCloseOnEscape(false)

			local shownAt = GetTime()
			local function restore()
				if KC.frameHiddenAt == shownAt then
					KC.frame:Show()
				end
			end
			restore()
			C_Timer.After(0, restore)
		end)
		SettingsPanel:HookScript("OnHide", function()
			-- Wait a frame so whatever is closing Settings has finished closing windows
			C_Timer.After(0, function() KC:SetCloseOnEscape(true) end)
		end)
	end
end

-- Enable Function
function KC:OnEnable()
	KC:createChessFrame(KC.frame);
	KC:Print(KC.formattedName.." Loaded!")
	KC.loaded = true
end

----------------------
---- Minimap Icon ----
----------------------

function KC:createBroker()
	-- Data for the Minimap Broker
	local data = {
		type = "launcher", 
		label = KC.name, 
		icon = Icons.MiniMap
	}
	
	-- Create minimap button
	local dataBroker = KC.LDB:NewDataObject(KC.name, data);

	-- Register Click Function
	function dataBroker.OnClick(self, button)
		if (button == "LeftButton") then
			KC:ToggleWindow()
		elseif (button == "RightButton") then
			if (SettingsPanel and SettingsPanel:IsShown()) then
				HideUIPanel(SettingsPanel);
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

-- Small function that checks if we have a window that can be loaded
function KC:HasWindow()
	if isNull(self.frame) or not self.loaded then
		return false
	else 
		return true
	end
end

-- Adds or removes the window from the list of frames closed by Escape
function KC:SetCloseOnEscape(enabled)
	for i = #UISpecialFrames, 1, -1 do
		if UISpecialFrames[i] == KC.name then
			tremove(UISpecialFrames, i)
		end
	end
	if enabled then
		tinsert(UISpecialFrames, KC.name)
	end
end

function KC:OpenConfig()
	Settings.OpenToCategory(KC.KCOptionsID);
end

-- Toggles the state of the window
function KC:ToggleWindow() 
	if KC:HasWindow() then
		if (self.frame:IsShown()) then
			KC:HideWindow() 
		else
			KC:ShowWindow()
		end
	end
end 

-- Safely shows the window
function KC:ShowWindow() 
	if KC:HasWindow() then
		PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
		self.frame:Show()
	end
end 

-- Safely hides the window
function KC:HideWindow() 
	if KC:HasWindow() then
		self.frame:Hide()
	end
end 
	
------------------------
---- Slash Commands ----
------------------------

-- Main Window
SlashCmdList['CHESSCMD'] = function(msg)
    KC:ToggleWindow() 
end

SLASH_CHESSCMD1, SLASH_CHESSCMD2, SLASH_CHESSCMD3, SLASH_CHESSCMD4, SLASH_CHESSCMD5 
	= '/kc', '/karazhanchess', '/chess', '/karachess', '/kchess';

-- Options
SlashCmdList['CHESSOPTIONCMD'] = function(msg)
    KC:OpenConfig()
end

SLASH_CHESSOPTIONCMD1, SLASH_CHESSOPTIONCMD2, SLASH_CHESSOPTIONCMD3, SLASH_CHESSOPTIONCMD4, SLASH_CHESSOPTIONCMD5 
	= '/kco', '/karazhanchessoptions', '/chessoptions', '/karachessoptions', '/kchessoptions';

