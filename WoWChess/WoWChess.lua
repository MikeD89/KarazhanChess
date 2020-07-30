WoWChess = LibStub("AceAddon-3.0"):NewAddon("WoWChess", "AceConsole-3.0", "AceEvent-3.0" );

function WoWChess:OnInitialize()
		-- Called when the addon is loaded

		-- Print a message to the chat frame
		self:Print("OnInitialize Event Fired: Hello")
end

function WoWChess:OnEnable()
		-- Called when the addon is enabled

		-- Print a message to the chat frame
		self:Print("OnEnable Event Fired: Hello world again ;)")
end

function WoWChess:OnDisable()
		-- Called when the addon is disabled
end
