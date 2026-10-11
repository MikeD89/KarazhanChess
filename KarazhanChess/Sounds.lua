-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Sound effects for moves and game results
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC
local dir = ns.dir

-- Sound themes are saved by name, which is also the folder under Sounds\ ("Off"
-- plays nothing). Each folder holds Move, Capture, Check, Victory, Defeat and
-- Draw (.ogg). The Themes list only sets the order shown in the options dropdown.
local Sounds = {}
ns.Sounds = Sounds
Sounds.Folder = dir("Sounds\\")
Sounds.Off = "Off"
Sounds.Themes = { "Sfx", "Piano", "Nes", "Futuristic", Sounds.Off }
Sounds.ThemeValues = {
    Sfx = "SFX",
    Piano = "Piano",
    Nes = "NES",
    Futuristic = "Futuristic",
    Off = "Off",
}
Sounds.Default = "Sfx"

-- Plays one of the theme's sounds (see above) on the sound effects channel, so
-- it follows the game's effects volume. Silent while the window is closed (the
-- computer can still move then).
function Sounds:Play(name)
    local theme = KC:getSoundTheme()
    if (theme == Sounds.Off or not (KC.frame and KC.frame:IsShown())) then
        return
    end
    PlaySoundFile(Sounds.Folder..theme.."\\"..name..".ogg", "SFX")
end

-- The sound for a rules engine move just played: Check if it gave check,
-- Capture if it took a piece, otherwise Move (castling and promotions included)
function Sounds:PlayMove(move, givesCheck)
    if givesCheck then
        self:Play("Check")
    elseif move.captured then
        self:Play("Capture")
    else
        self:Play("Move")
    end
end

-- The end of a game for the player playing colour: Victory if winner is their
-- colour, Defeat if it's the other, Draw if there is no winner
function Sounds:PlayResult(winner, colour)
    if (winner == nil) then
        self:Play("Draw")
    elseif (winner == colour) then
        self:Play("Victory")
    else
        self:Play("Defeat")
    end
end
