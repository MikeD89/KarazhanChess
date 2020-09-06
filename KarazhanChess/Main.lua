

--------------------------
---- Init & Libraries ----
--------------------------

KC = LibStub("AceAddon-3.0"):NewAddon("KarazhanChess", "AceConsole-3.0", 
                                                       "AceEvent-3.0" );

local media = LibStub("LibSharedMedia-3.0")
local config = LibStub("AceConfig-3.0")

-- Get the version. This is set by the packager.
local version = "@project-version@"
if version:find("@", nil, true) then
    version = "0.0_dev"
end

function KC:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KarazhanChessDB")
end
    
function KC:OnEnable()
	KC:Print("Karazhan Chess "..format("v|cff33ffff%s|r",version).." Loaded!")
end

------------------------------
---- Setup Slash Commands ----
------------------------------
SlashCmdList['CHESSCMD'] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg or 'nil')
end

SLASH_CHESSCMD1, SLASH_CHESSCMD2, SLASH_CHESSCMD3, SLASH_CHESSCMD4, SLASH_CHESSCMD5, SLASH_CHESSCMD6 
        = '/kc', '/karazhan', '/karazhanchess', '/chess', '/karachess', '/kchess';


------------------------------------------------------------------------------------------------------------------------


myMessageVar=""
function KC:GetMyMessage(info)
    KC:Print("Get   "..myMessageVar)
    return myMessageVar
end

function KC:SetMyMessage(info, input)
    myMessageVar = input
    KC:Print("Set   "..myMessageVar)
end

local options = {
    name = "Karazhan Chess",
    handler = KC,
    type = 'group',
    args = {
        msg = {
            type = 'input',
            name = 'My Message',
            desc = 'The message for my addon',
            set = 'SetMyMessage',
            get = 'GetMyMessage',
        },
        moreoptions={
            name = "More Options",
            type = "group",
            args={
                texture = {
                    type = "select",
                    name = "Texture",
                    desc = "Set the statusbar texture.",
                    values = media:HashTable("statusbar"),
                    dialogControl = "LSM30_Statusbar",
                  }
            }
        }
    }
}

config:RegisterOptionsTable("KarazhanChess", options, {"kco"})