-- GLOBALS: math, string, table

KarazhanChess = LibStub("AceAddon-3.0"):NewAddon("KarazhanChess", "AceConsole-3.0", "AceEvent-3.0" );

function KarazhanChess:OnInitialize()
	-- Called when the addon is loaded

	-- Print a message to the chat frame
	self:Print("OnInitialize Event Fired: Hello")
end

function KarazhanChess:OnEnable()
	-- Called when the addon is enabled
		
	-- Print a message to the chat frame
	self:Print("OnEnable Event Fired: Hello world again ;)")
end


SLASH_CHESSCMD1, SLASH_CHESSCMD2, SLASH_CHESSCMD3, SLASH_CHESSCMD4, SLASH_CHESSCMD5, SLASH_CHESSCMD6 
		= '/kc', '/karazhan', '/karazhanchess', '/chess', '/karachess', '/kchess';
function SlashCmdList.CHESSCMD(msg, editBox)
	self:Print(msg)
end
