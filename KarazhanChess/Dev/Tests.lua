-------------------------------------------------------------------------------
-- Karazhan Chess
-- Author:  Mike D (MeloN <Convicted>)
--
-- Manual in-game test cases (dev builds only), shown by the test panel
-------------------------------------------------------------------------------

local _, ns = ...
local KC = ns.KC

-- Dev builds only. Packaged builds leave the Dev folder out entirely.
if not KC.isDevBuild then
	return
end

-- Each test has:
--   id       unique ID, e.g. "R-2" (meant to become automated cases later)
--   section  heading shown above the test
--   name     short title
--   load     what the Load button sets up (nil = just open the window):
--              fen = "<FEN>"     set the board up from a FEN (switches to Play)
--              newGame = true    start position (switches to Play)
--              clear = true      empty board (switches to Play)
--              moves = { uci }   then play these moves, animated one after another
--              flipped = true    black at the bottom (board setups are unflipped otherwise)
--              mode = "puzzle"   switch to puzzles ("play" switches back)
--              computer = { level = "Heroic", colour = "w" }
--                                start a game against the computer from the fen (or
--                                newGame) position, the player as colour (default w)
--   steps    what to do, in order (empty = loading is the whole test)
--   check    what should happen
--
-- Every test also expects BugSack to stay empty. There are no turns in free play,
-- so either colour can move at any time. /kc fen <FEN> and /kc move <uci> work too.
-- Offline tests (perft, syntax, puzzle data) are run from Tools/, see CLAUDE.md.
local Tests = {}
ns.DevTests = Tests

-- Positions used by more than one test
local KIWIPETE = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
local CASTLE_KQ = "r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1"
local PROMOTE = "4k3/1P6/8/8/8/8/8/4K3 w - - 0 1"
local QUEEN_CHECK = "4k3/8/8/8/8/8/3q4/4K3 w - - 0 1"

local function add(section, list)
	for _, test in ipairs(list) do
		test.section = section
		Tests[#Tests + 1] = test
	end
end

-- Rules engine ---------------------------------------------------------------

add("Rules: legal moves", {
	{ id = "R-1", name = "Start position moves", load = { newGame = true },
		steps = { "Select each piece." },
		check = "Pawns show one or two pushes, knights two squares each, the others nothing." },
	{ id = "R-2", name = "Pinned bishop", load = { fen = "4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1" },
		steps = { "Select the e2 bishop." },
		check = "No moves: it is pinned to the king by the e7 rook." },
	{ id = "R-3", name = "Moving along a pin", load = { fen = "4k3/4r3/8/8/8/8/4R3/4K3 w - - 0 1" },
		steps = { "Select the e2 rook." },
		check = "Only e3-e6 and a capture on e7 (a pinned piece may move along the pin)." },
	{ id = "R-4", name = "King in check", load = { fen = QUEEN_CHECK },
		steps = { "Select the white king." },
		check = "Red glow on e1; only f1 and the capture on d2 are offered." },
	{ id = "R-5", name = "Moves that don't escape check", load = { fen = "4k3/8/8/8/8/8/3q4/4K2R w K - 0 1" },
		steps = { "Select the h1 rook." },
		check = "No moves: none of them gets the king out of check." },
	{ id = "R-6", name = "Knight check", load = { fen = "4k3/8/8/8/8/3n4/8/4K3 w - - 0 1" },
		steps = { "Select the white king." },
		check = "Glow on e1 (knight check from d3); d1, d2, e2 and f1 offered, f2 not (the knight covers it)." },
	{ id = "R-7", name = "Kings can't be captured", load = { newGame = true },
		steps = { "Move a white piece next to the black king, then select that piece." },
		check = "The king is never offered as a capture; kings never show a capture marker." },
})

add("Rules: castling", {
	{ id = "C-1", name = "Castling offered (Kiwipete)", load = { fen = KIWIPETE },
		steps = { "Select each king." },
		check = "White king: g1 and c1 offered. Black king: g8 and c8 offered." },
	{ id = "C-2", name = "Castling rights from the FEN", load = { fen = CASTLE_KQ },
		steps = { "Select each king." },
		check = "White: g1 only. Black: c8 only." },
	{ id = "C-3", name = "Castling moves the rook", load = { fen = CASTLE_KQ },
		steps = { "Select the white king and click g1." },
		check = "The rook jumps h1 to f1; last-move tint on e1 and g1." },
	{ id = "C-4", name = "No castling out of check", load = { fen = "4k3/4r3/8/8/8/8/8/R3K2R w KQ - 0 1" },
		steps = { "Select the white king." },
		check = "In check (glow): no castling either way." },
	{ id = "C-5", name = "No castling through check", load = { fen = "4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1" },
		steps = { "Select the white king." },
		check = "f1 is attacked: no g1. c1 is offered." },
	{ id = "C-6", name = "No castling into check", load = { fen = "4k3/8/8/8/8/8/6r1/R3K2R w KQ - 0 1" },
		steps = { "Select the white king." },
		check = "g1 is attacked: no g1. c1 is offered." },
	{ id = "C-7", name = "b1 attacked doesn't stop long castling", load = { fen = "4k3/8/8/8/8/8/1r6/R3K2R w KQ - 0 1" },
		steps = { "Select the white king." },
		check = "Only b1 is attacked: c1 is still offered (the king doesn't cross b1)." },
	{ id = "C-8", name = "Moving the rook loses the right", load = { fen = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1" },
		steps = { "Move the h1 rook away and back.", "Select the white king." },
		check = "Only c1: moving the rook lost kingside castling." },
	{ id = "C-9", name = "Castling by UCI", load = { fen = CASTLE_KQ },
		steps = { "/kc move e1c1", "/kc move e1g1" },
		check = "e1c1 prints \"Not a legal move here: e1c1\"; e1g1 castles." },
})

add("Rules: en passant", {
	{ id = "E-1", name = "En passant after a double push", load = { newGame = true },
		steps = { "Play e2-e4, e4-e5, then black d7-d5.", "Select the e5 pawn and take on d6." },
		check = "d6 shows a move dot; taking it removes the d5 pawn." },
	{ id = "E-2", name = "En passant square from the FEN", load = { fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1" },
		steps = { "Select the e5 pawn." },
		check = "d6 is offered." },
	{ id = "E-3", name = "No en passant square in the FEN", load = { fen = "4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1" },
		steps = { "Select the e5 pawn." },
		check = "No d6." },
	{ id = "E-4", name = "En passant expires", load = { newGame = true, moves = { "e2e4", "e4e5", "d7d5", "a2a3" } },
		steps = { "Wait for the moves to play (e4, e5, d5, a3).", "Select the e5 pawn." },
		check = "No d6: en passant is only possible straight after the double push." },
	{ id = "E-5", name = "En passant exposing the king", load = { fen = "8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1" },
		steps = { "Select the e5 pawn." },
		check = "Only e6: taking en passant would empty rank 5 and expose the a5 king to the h5 rook." },
})

add("Rules: check, checkmate, stalemate", {
	{ id = "M-1", name = "Fool's mate", load = { newGame = true },
		steps = { "/kc move f2f3", "/kc move e7e5", "/kc move g2g4", "/kc move d8h4" },
		check = "Glow on e1; info bar: \"Checkmate\" / \"Black is victorious\"." },
	{ id = "M-2", name = "Back rank mate", load = { fen = "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1" },
		steps = { "Play a1-a8." },
		check = "Glow on g8; info bar: \"Checkmate\" / \"White is victorious\"." },
	{ id = "M-3", name = "Stalemate (queen)", load = { fen = "7k/8/6K1/8/8/8/8/5Q2 w - - 0 1" },
		steps = { "/kc move f1f7" },
		check = "No glow; info bar: \"Stalemate\" / \"The game is a draw\"." },
	{ id = "M-4", name = "Ending a check", load = { fen = QUEEN_CHECK },
		steps = { "Take the d2 queen with the king.", "Make another normal move." },
		check = "The glow disappears; the info bar stays clear." },
	{ id = "M-5", name = "Loading a mated position", load = { fen = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3" },
		steps = {},
		check = "Loading shows the glow on e1 and the checkmate message." },
	{ id = "M-6", name = "Stalemate (corner)", load = { fen = "k7/8/2Q5/8/8/8/8/7K w - - 0 1" },
		steps = { "/kc move c6b6 (or drag the queen to b6)." },
		check = "No glow; info bar: \"Stalemate\" / \"The game is a draw\"." },
})

add("Rules: promotion", {
	{ id = "P-1", name = "Promotion picker", load = { fen = PROMOTE },
		steps = { "Move b7-b8.", "Choose a piece." },
		check = "The board dims; a Q, R, B, N column runs down from b8; choosing one promotes." },
	{ id = "P-2", name = "Cancelling a promotion", load = { fen = "1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1" },
		steps = { "Capture a7xb8.", "Click the dimmed board." },
		check = "The move is taken back: pawn on a7, black rook back on b8, previous last move restored." },
	{ id = "P-3", name = "Promotion by UCI", load = { fen = PROMOTE },
		steps = { "/kc move b7b8n" },
		check = "Promotes straight to a knight with no picker." },
	{ id = "P-4", name = "Promotion gives check", load = { fen = PROMOTE },
		steps = { "Promote to a queen on b8." },
		check = "Glow on e8, as the new queen gives check." },
})

-- Board ----------------------------------------------------------------------

add("Board: flip", {
	{ id = "F-1", name = "Flip command", load = { newGame = true },
		steps = { "Type /kc flip. (The round-arrows flip button, top left, is hidden for now.)" },
		check = "Black moves to the bottom; no flip button shows top left." },
	{ id = "F-2", name = "Labels when flipped", load = { newGame = true, flipped = true },
		steps = { "Look at the board labels." },
		check = "The left edge reads 8 at the bottom up to 1 at the top; the bottom edge reads h to a, left to right." },
	{ id = "F-3", name = "Flip keeps tints", load = { fen = QUEEN_CHECK, moves = { "d2b4" } },
		steps = { "Flip the board (/kc flip)." },
		check = "Pieces, the last-move tint (d2, b4) and the check glow stay on their squares." },
	{ id = "F-4", name = "Input when flipped", load = { newGame = true, flipped = true },
		steps = { "Select a piece, then move one by clicking and another by dragging." },
		check = "Move dots and capture corners are on the right squares; clicking and dragging both work." },
	{ id = "F-5", name = "Promotion picker when flipped", load = { fen = PROMOTE, flipped = true },
		steps = { "Move b7-b8." },
		check = "The overlay covers the whole board; the choices run from b8 towards the centre (upwards on screen)." },
	{ id = "F-6", name = "Flipping with the picker open", load = { fen = PROMOTE },
		steps = { "Move b7-b8.", "Flip the board, and flip it back (/kc flip)." },
		check = "The overlay and choices follow the board." },
	{ id = "F-7", name = "Labels option when flipped", load = { newGame = true, flipped = true },
		steps = { "/kco: turn Show Board Labels off and on again." },
		check = "The labels come back on the displayed edges." },
	{ id = "F-8", name = "Orientation isn't saved", load = { newGame = true, flipped = true },
		steps = { "/reload", "/kc" },
		check = "The board starts unflipped again." },
})

add("Board: input and indicators", {
	{ id = "I-1", name = "Click to move", load = { newGame = true },
		steps = { "Click a piece, then a highlighted square." },
		check = "The piece slides there; last-move tint on both squares." },
	{ id = "I-2", name = "Drag to move", load = { newGame = true },
		steps = { "Drag a piece onto a highlighted square.", "Drag another piece somewhere it can't go." },
		check = "The first drops there; the second snaps back." },
	{ id = "I-3", name = "Hover tint", load = { newGame = true },
		steps = { "Select a piece and hover a legal destination.", "Do the same while dragging." },
		check = "The square tints and its dot / corners hide." },
	{ id = "I-4", name = "Deselect", load = { newGame = true },
		steps = { "Click a piece, then click it again." },
		check = "It deselects." },
	{ id = "I-5", name = "Capture by clicking the enemy piece", load = { fen = "4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1" },
		steps = { "Select the e4 pawn, then click the d5 pawn." },
		check = "It captures." },
	{ id = "I-6", name = "Closing mid-drag", load = { newGame = true },
		steps = { "Start dragging a piece and press Escape (or close the window).", "/kc" },
		check = "The piece is back on its square." },
	{ id = "I-7", name = "Clear Board / New Game confirm", load = { fen = PROMOTE, moves = { "e1e2" } },
		steps = { "Move b7-b8 so the picker opens, then Clear Board and confirm.", "Load again, promote to a queen (check on e8), then New Game and confirm." },
		check = "Each asks for confirmation; the check glow, last move and picker are cleared." },
})

add("Board: move history", {
	{ id = "H-1", name = "History buttons after reload",
		steps = { "/reload", "/kc" },
		check = "Bottom left has < and > (no author or version text); both are greyed out." },
	{ id = "H-2", name = "Back enabled after moves", load = { newGame = true },
		steps = { "Play e4, e5, Nf3." },
		check = "< is enabled, > greyed." },
	{ id = "H-3", name = "Stepping back", load = { newGame = true, moves = { "e2e4", "e7e5", "g1f3" } },
		steps = { "Press < three times." },
		check = "Steps back to the start instantly; the last-move tint follows; < greys out at the start." },
	{ id = "H-4", name = "Stepping forward", load = { newGame = true, moves = { "e2e4", "e7e5", "g1f3" } },
		steps = { "Press < three times.", "Press > three times." },
		check = "Each > replays the next move with the slide animation; > greys out at the latest move." },
	{ id = "H-5", name = "A new move replaces later ones", load = { newGame = true, moves = { "e2e4", "e7e5", "g1f3" } },
		steps = { "Press < twice.", "Play a different move." },
		check = "That move replaces the later ones; > is greyed." },
	{ id = "H-6", name = "Special moves in history", load = { fen = "r3k3/1P6/8/3pP3/8/8/8/R3K2R w KQq d6 0 1" },
		steps = { "Take on d6 en passant, castle kingside, promote b7xa8.", "Step back and forward over each move." },
		check = "Captured pieces return and disappear correctly; the rook moves with the king; the promoted piece is a pawn before and the chosen piece after." },
	{ id = "H-7", name = "Check glow in history", load = { fen = "4k3/8/8/8/8/8/8/R3K3 w - - 0 1" },
		steps = { "Play a1-a8 (check).", "Press <, then >." },
		check = "The check glow follows the position." },
	{ id = "H-8", name = "History blocked by the picker", load = { fen = PROMOTE },
		steps = { "Move b7-b8 so the picker opens.", "Press <." },
		check = "Nothing happens until the promotion is chosen or cancelled." },
	{ id = "H-9", name = "History resets", load = { newGame = true, moves = { "e2e4", "e7e5" } },
		steps = { "New Game (confirm).", "Repeat with Clear Board, and with /kc fen 4k3/8/8/8/8/8/8/4K3 w - - 0 1." },
		check = "The history starts again each time (both buttons greyed)." },
	{ id = "H-10", name = "History in a puzzle", load = { mode = "puzzle" },
		steps = { "After the opponent's move, press <.", "Try to pick up a piece.", "Press >." },
		check = "Shows the position before the opponent's move; pieces can't be picked up until > returns to the latest position." },
	{ id = "H-11", name = "History while the opponent replies", load = { mode = "puzzle" },
		steps = { "Press < while the opponent is about to reply (during \"Get ready\", or straight after a right move)." },
		check = "The reply still plays, from the latest position." },
	{ id = "H-12", name = "History after a wrong puzzle move", load = { mode = "puzzle" },
		steps = { "Make a wrong move and press < before it is taken back." },
		check = "The wrong move disappears from the history; the latest position is shown." },
	{ id = "H-13", name = "Reviewing after a puzzle", load = { mode = "puzzle" },
		steps = { "Finish the puzzle (or press Solution).", "Step back and forward through the moves, and try to move a piece." },
		check = "< and > step through the puzzle; no piece can be picked up at any point." },
})

add("Board: UCI command", {
	{ id = "U-1", name = "Legal UCI move", load = { newGame = true },
		steps = { "/kc move e2e4" },
		check = "The pawn slides e2 to e4." },
	{ id = "U-2", name = "Illegal UCI move", load = { newGame = true },
		steps = { "/kc move e2e5" },
		check = "Prints \"Not a legal move here: e2e5\"." },
	{ id = "U-3", name = "Invalid FEN",
		steps = { "/kc fen not a fen" },
		check = "Prints \"Invalid FEN: malformed FEN\"." },
})

-- Computer opponent -----------------------------------------------------------
-- Results count towards the level's record (/kco, Computer); Reset Computer
-- Record clears it afterwards.

local COMPUTER_MATES = "1r4k1/8/8/8/8/8/5PPP/6K1 b - - 0 1"

add("Computer: starting a game", {
	{ id = "AI-1", name = "New Game menu", load = { mode = "play" },
		steps = { "Click New Game.", "Click Black under Play as." },
		check = "A menu: Two players; Raid Finder, Normal, Heroic, Mythic and Cutting Edge, each with a grey description; Play as White / Black / Random with the current choice ticked. Clicking Black ticks it and the menu stays open." },
	{ id = "AI-2", name = "Starting as white", load = { newGame = true, moves = { "e2e4" } },
		steps = { "New Game, Play as White, then Normal; confirm the popup." },
		check = "The start position, white at the bottom; info bar \"Your move\" / \"You play White against the Normal computer\"; grey line \"Normal · Won 0 · Lost 0 · Drawn 0\" (or your record)." },
	{ id = "AI-3", name = "Turns", load = { newGame = true, computer = { level = "Normal", colour = "w" } },
		steps = { "Try to pick up a black piece.", "Play e4, and while \"Thinking...\" shows, try to pick up a piece.", "Wait for the reply." },
		check = "Black pieces never select; after your move \"Thinking...\" and nothing can be picked up; the reply animates after about half a second, then \"Your move\" again." },
	{ id = "AI-4", name = "Playing black", load = { newGame = true, computer = { level = "Heroic", colour = "b" } },
		steps = { "Watch, then reply." },
		check = "Black at the bottom; the computer (white) opens with a move after \"Thinking...\"; then you can move black pieces only." },
	{ id = "AI-5", name = "Random colour", load = { mode = "play" },
		steps = { "New Game, Play as Random, then Raid Finder. Repeat a few times." },
		check = "Sometimes white, sometimes black; the board always has your colour at the bottom." },
	{ id = "AI-6", name = "Slash command",
		steps = { "/kc computer mythic b", "/kc computer" },
		check = "First a Mythic game as black (no confirm popup); then a game at the last level and colour chosen. /kc fen afterwards ends the computer game (free play, no turns)." },
	{ id = "AI-7", name = "Back to two players", load = { newGame = true, computer = { level = "Normal", colour = "w" } },
		steps = { "Play a move, then New Game, Two players (confirm).", "Load again; Clear Board (confirm)." },
		check = "Either colour can move again with no turns; the info bar clears; the computer never moves." },
})

add("Computer: playing", {
	{ id = "AI-10", name = "The computer mates", load = { fen = COMPUTER_MATES, computer = { level = "Normal", colour = "w" } },
		steps = { "Watch." },
		check = "Black plays Rb1 mate; \"Defeat\" / \"Checkmate. Black wins.\"; Lost +1; no piece can be picked up afterwards; < > still step through." },
	{ id = "AI-11", name = "Mating the computer", load = { fen = "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1", computer = { level = "Normal", colour = "w" } },
		steps = { "Play Ra8 mate." },
		check = "\"Victory!\" in green / \"Checkmate. White wins.\"; Won +1." },
	{ id = "AI-12", name = "Draw: not enough material", load = { fen = "4k3/8/8/8/8/8/3n4/4K3 w - - 0 1", computer = { level = "Normal", colour = "w" } },
		steps = { "Take the knight with the king." },
		check = "\"Draw\" / \"Neither side can checkmate\"; Drawn +1." },
	{ id = "AI-13", name = "Draw: fifty-move rule", load = { fen = "4k3/8/8/8/8/8/R7/4K3 w - - 99 60", computer = { level = "Normal", colour = "w" } },
		steps = { "Play a quiet rook move (not a capture or pawn move)." },
		check = "\"Draw\" / \"Fifty moves without a capture or pawn move\"." },
	{ id = "AI-14", name = "Promotion against the computer", load = { fen = "8/1P6/8/8/8/k7/8/4K3 w - - 0 1", computer = { level = "Normal", colour = "w" } },
		steps = { "Move b7-b8, then click the dimmed board to cancel.", "Promote again, to a knight." },
		check = "Cancelling takes the pawn back and the computer doesn't move; after choosing, the knight appears and the computer replies." },
	{ id = "AI-15", name = "Takeback with <", load = { newGame = true, computer = { level = "Normal", colour = "w" } },
		steps = { "Play three moves (wait for each reply).", "Press < once and try to move.", "Press < again and play a different move." },
		check = "One step back (the computer's turn) nothing can be picked up; two steps back your move replaces the later ones (> greys out) and the computer replies to it." },
	{ id = "AI-16", name = "History while thinking", load = { newGame = true, computer = { level = "CuttingEdge", colour = "w" } },
		steps = { "Play a move, then press < while it thinks." },
		check = "The reply still comes, played from the latest position." },
	{ id = "AI-17", name = "Puzzles pause the game", load = { newGame = true, computer = { level = "CuttingEdge", colour = "w" } },
		steps = { "Play a move, and while \"Thinking...\" click the Puzzles tab; play a puzzle move.", "Click the Play tab." },
		check = "No computer move appears in the puzzle; back in Play the game and its history are as you left them, and the computer thinks again and replies." },
	{ id = "AI-18", name = "Smooth while thinking", load = { newGame = true, computer = { level = "CuttingEdge", colour = "w" } },
		steps = { "Play a few moves, moving the camera and the window while it thinks." },
		check = "No freezes; Cutting Edge takes up to about 5 seconds a move; the fade and drag still work." },
	{ id = "AI-19", name = "Difficulty spread",
		steps = { "Play a few games at Raid Finder and at Mythic (/kc computer raidfinder, /kc computer mythic)." },
		check = "Raid Finder hangs pieces and misses simple tactics; Mythic punishes hanging pieces and rarely blunders." },
	{ id = "AI-20", name = "Record in the options",
		steps = { "/kco, Computer section.", "Reset Options.", "Reset Computer Record, confirm." },
		check = "Shows won / lost / drawn per level played; Reset Options keeps it (and the level and colour reset to Normal / Random); Reset Computer Record clears it." },
})

-- Puzzles --------------------------------------------------------------------
-- Puzzle progress is saved: note your rating first, and use Reset Puzzle Progress
-- in /kco afterwards for a clean start.

add("Puzzles: loading and modes", {
	{ id = "PZ-1", name = "Tabs after reload",
		steps = { "/reload", "/kc" },
		check = "Two tabs below the window, Play selected; the info bar under the board is empty." },
	{ id = "PZ-2", name = "Opening puzzles", load = { mode = "play" },
		steps = { "Click the Puzzles tab." },
		check = "The data loads (a short pause the first time only); a puzzle starts; the bottom buttons become tier / Solution / Next Puzzle." },
	{ id = "PZ-3", name = "Puzzle data disabled",
		steps = { "Disable \"Karazhan Chess Puzzles\" in the AddOns list, /reload.", "Click the Puzzles tab.", "Re-enable the data addon afterwards." },
		check = "Stays on Play; info bar: \"Puzzles unavailable\" and how to enable them." },
	{ id = "PZ-4", name = "Free play is kept", load = { newGame = true, moves = { "e2e4", "e7e5", "g1f3" }, flipped = true },
		steps = { "Click the Puzzles tab, then the Play tab." },
		check = "The free-play position, its move history (< steps back through e4 e5 Nf3) and the flipped orientation come back." },
	{ id = "PZ-5", name = "Slash commands for modes",
		steps = { "Close the window.", "/kc puzzle", "Close the window.", "/kc play" },
		check = "Same as clicking the tabs, opening the window each time." },
})

add("Puzzles: solving", {
	{ id = "PZ-10", name = "Puzzle start", load = { mode = "puzzle" },
		steps = { "Press Next Puzzle and watch." },
		check = "The board turns so the solver is at the bottom; \"Get ready\", then after half a second the opponent's move animates and \"Your turn\" / \"Find the best move for White/Black\"." },
	{ id = "PZ-11", name = "No moves while the opponent moves", load = { mode = "puzzle" },
		steps = { "Press Next Puzzle; during \"Get ready\" (or while the opponent replies) try to pick up a piece." },
		check = "Nothing can be picked up." },
	{ id = "PZ-12", name = "Opponent pieces locked", load = { mode = "puzzle" },
		steps = { "On your turn, try to pick up an opponent piece." },
		check = "It doesn't select." },
	{ id = "PZ-13", name = "Right move", load = { mode = "puzzle" },
		steps = { "In a multi-move puzzle, play the right move (press Solution on another puzzle to learn one if needed)." },
		check = "\"Best move!\" / \"Keep going...\", then the opponent replies." },
	{ id = "PZ-14", name = "Wrong move", load = { mode = "puzzle" },
		steps = { "Play a wrong move (ideally a castle or promotion if available)." },
		check = "\"That's not the move!\" in red; the move is taken back after half a second (castling rook and promoted pawn too); the rating drops (red change in the footer); you can keep trying." },
	{ id = "PZ-15", name = "Solved cleanly", load = { mode = "puzzle" },
		steps = { "Solve a puzzle without mistakes." },
		check = "\"Success!\" in green; the detail line shows \"New Rating\" rising (green change); the grey line shows the difficulty and Solved +1 (no puzzle ID, puzzle rating or puzzle types)." },
	{ id = "PZ-16", name = "Solved after a mistake", load = { mode = "puzzle" },
		steps = { "Make a mistake, then solve the puzzle." },
		check = "\"Puzzle complete\"; no further rating change." },
	{ id = "PZ-17", name = "Alternative mate", load = { mode = "puzzle" },
		steps = { "In a \"Mate in 1\" puzzle, mate with a different move from the solution, if there is one." },
		check = "Counts as solved." },
	{ id = "PZ-18", name = "Solution", load = { mode = "puzzle" },
		steps = { "Press Solution mid-puzzle." },
		check = "The remaining moves play out, then \"Puzzle complete\"; counts as failed on a first attempt; Solution is greyed out afterwards." },
	{ id = "PZ-19", name = "Solution after a wrong move", load = { mode = "puzzle" },
		steps = { "Play a wrong move and press Solution straight away." },
		check = "The wrong move is taken back first, then the solution plays correctly." },
	{ id = "PZ-20", name = "Next mid-animation", load = { mode = "puzzle" },
		steps = { "Press Next Puzzle while a move is animating." },
		check = "The new puzzle starts cleanly; nothing from the old one plays on top." },
	{ id = "PZ-21", name = "No moves after the end", load = { mode = "puzzle" },
		steps = { "Select a piece (so its moves show), then finish the puzzle with another move, or press Solution.", "Try to move pieces of both colours." },
		check = "The selection clears when the puzzle ends; nothing can be picked up until Next Puzzle." },
	{ id = "PZ-22", name = "Promotion in a puzzle", load = { mode = "puzzle" },
		steps = { "Play puzzles until one needs a promotion, and promote." },
		check = "The picker appears; the chosen piece is part of the move that is checked." },
	{ id = "PZ-23", name = "Info button", load = { mode = "puzzle" },
		steps = { "Hover over Info mid-puzzle.", "Finish the puzzle, then hover over Info and click it." },
		check = "A tooltip with the puzzle ID, rating, difficulty, number of moves, result (Solved or Failed), readable themes (e.g. \"Mate in 2\", \"Discovered attack\"); Info is greyed out until the puzzle is over." },
})

add("Puzzles: rating, tiers and progress", {
	{ id = "PZ-30", name = "Tier menu", load = { mode = "puzzle" },
		steps = { "Click the Difficulty button and choose another tier." },
		check = "A menu of Raid Finder, Normal, Heroic, Mythic and Cutting Edge with rating ranges, the current one checked; choosing one starts a puzzle from it; the button still reads \"Difficulty\" and the grey info line shows the new tier." },
	{ id = "PZ-31", name = "Ratings within the tier", load = { mode = "puzzle" },
		steps = { "Play (or show the solution of) several puzzles in each tier." },
		check = "Puzzle ratings (in the Info tooltip) are inside the tier's range." },
	{ id = "PZ-32", name = "Unfinished puzzle resumes", load = { mode = "puzzle" },
		steps = { "Note the puzzle, leave mid-puzzle (Play tab or /reload), come back to Puzzles." },
		check = "The same unfinished puzzle starts again." },
	{ id = "PZ-33", name = "Solved puzzles don't repeat", load = { mode = "puzzle" },
		steps = { "Note a solved puzzle's ID (Info button) and keep playing." },
		check = "It doesn't come up again." },
	{ id = "PZ-34", name = "Progress in options", load = { mode = "puzzle" },
		steps = { "/kco, Puzzles section." },
		check = "Lichess credit; rating / solved / failed match the footer." },
	{ id = "PZ-35", name = "Reset Puzzle Progress",
		steps = { "/kco: Reset Puzzle Progress, confirm." },
		check = "Rating 1500, counts 0." },
	{ id = "PZ-36", name = "Reset Options keeps progress",
		steps = { "/kco: Reset Options." },
		check = "Options reset, including puzzle types (all ticked again); puzzle rating and counts are kept." },
	{ id = "PZ-37", name = "Puzzle Types page",
		steps = { "/reload, /kco, click Puzzle Types in the Puzzles section (or the Puzzle Types entry under Karazhan Chess)." },
		check = "Groups Tactics (10 boxes), Mates (4), Endgames (5) and Other (1), all ticked by default." },
	{ id = "PZ-38", name = "Only ticked types", load = { mode = "puzzle" },
		steps = { "Puzzle Types: Untick All, then tick Bishop endgames.", "Press Next Puzzle a few times, in a couple of tiers." },
		check = "Every puzzle is a bishop endgame (kings, bishops, pawns), found without a pause." },
	{ id = "PZ-39", name = "Every type unticked", load = { mode = "puzzle" },
		steps = { "Puzzle Types: Untick All.", "Press Next Puzzle.", "Tick All, press Next Puzzle." },
		check = "\"No puzzles\" / \"No Normal puzzles match the puzzle types you ticked.\" (with your tier name), straight away; after Tick All a puzzle starts." },
	{ id = "PZ-41", name = "Mates only", load = { mode = "puzzle" },
		steps = { "Puzzle Types: Untick All, then tick Mate in 1 and Mate in 2.", "Solve or show the solution of a few puzzles." },
		check = "Each ends in checkmate within one or two of your moves." },
	{ id = "PZ-40", name = "Puzzle types are saved",
		steps = { "Untick a few types, /reload, open Puzzle Types." },
		check = "The same types are still unticked." },
})

-- Window and options ---------------------------------------------------------

add("Window and options", {
	{ id = "W-1", name = "Window position is saved",
		steps = { "Drag the window by its title.", "/reload", "/kc" },
		check = "The window reopens where it was." },
	{ id = "W-2", name = "Window size is saved",
		steps = { "Resize with the grip (bottom right).", "/reload", "/kc" },
		check = "The size is kept; board art stays smooth." },
	{ id = "W-3", name = "Window opacity", load = { newGame = true },
		steps = { "/kco: change Window Opacity." },
		check = "The window background fades; pieces and squares don't." },
	{ id = "W-4", name = "Fade out", load = { newGame = true },
		steps = { "/kco: turn Fade Out Window on.", "Move the mouse away from the window, then back." },
		check = "The whole window fades; it returns on hover." },
	{ id = "W-5", name = "Themes", load = { newGame = true, flipped = true },
		steps = { "/kco: change the board and piece themes." },
		check = "Squares and pieces update immediately, including while flipped." },
	{ id = "W-6", name = "Close on Escape", load = { newGame = true },
		steps = { "Press Escape." },
		check = "The window closes." },
})

return Tests
