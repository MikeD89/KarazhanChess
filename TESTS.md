# Karazhan Chess — Tests

Manual and offline tests. Every in-game test has an ID so it can later become an automated case in a dev-build test mode (planned: test suites inside the addon, enabled only when the version is `0.0_dev`).

Most in-game tests start from a FEN, so they don't depend on playing moves by hand. Type the commands in WoW's chat box, not in a terminal.

## Setup

1. `/reload` after any code change. BugSack must stay empty for every test.
2. `/kc` opens the window, `/kco` the options.
3. Testing commands:
   - `/kc fen <FEN>` sets the board up from a FEN.
   - `/kc move <uci>` plays a move, for example `e2e4`, `e1g1` (castling) or `e7e8q` (promotion).
   - `/kc computer [level] [w|b|random]` starts a game against the computer (levels: `raidfinder`, `normal`, `heroic`, `mythic`, `cuttingedge`).
   - `/kc friend [name]` opens Play vs Friend and invites `name` (`First Last` on WoW Forever; elsewhere `Name`, or `Name-Realm` on another realm).

There are no turns in free play (two players), so either colour can move at any time. Games against the computer have turns.

## Offline (no game needed)

Run these in `Tools/` (`npm install` once). Run them after any change to `Rules.lua`, and run the syntax check after any change to Lua files.

| ID | Command | Expected |
|---|---|---|
| OFF-1 | `node lua.js tests/perft.lua quick` | Every line `ok`, then `all passed` (a few seconds) |
| OFF-2 | `node lua.js tests/perft.lua` | Also start position depth 4 = 197281 and Kiwipete depth 3 = 97862 (about 40 s) |
| OFF-3 | `node lua.js tests/syntax.lua ../KarazhanChess/*.lua` | `N/N files compile` |
| OFF-4 | `node lua.js tests/puzzles.lua 25` | Six files load, tiers of 80000 / 120000 / 130000 / 120000 / 50000, `all passed` (about 2 minutes) |
| OFF-5 | `node lua.js tests/engine.lua quick` | Engine perft counts, best moves, mate / stalemate, repetition, noise, coroutine checks all `ok`, then `all passed` (a few seconds) |
| OFF-6 | `node lua.js tests/engine.lua` | Also deeper perft (up to 674624 for position 3) and the depth 3-5 benchmark (about 1 minute) |
| OFF-7 | `node lua.js tests/selfplay.lua RaidFinder Normal 6` | Every game ends (no "illegal move" error); the stronger level (second) scores clearly more. Also try `Normal Heroic 4` and `Heroic Mythic 2` (slow: several minutes a game) |
| OFF-8 | `node lua.js tests/friend.lua` | Simulated clients invite, play, draw, resign and catch up after lost messages: `76/76 checks passed`, including WoW Forever "First Last" names and names from right-click menus |

## Rules engine

### Legal moves

| ID | Setup | Do | Expected |
|---|---|---|---|
| R-1 | New Game | Select each piece | Pawns show one or two pushes, knights two squares each, the others nothing |
| R-2 | `/kc fen 4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1` | Select the e2 bishop | No moves (it is pinned to the king by the e7 rook) |
| R-3 | `/kc fen 4k3/4r3/8/8/8/8/4R3/4K3 w - - 0 1` | Select the e2 rook | Only e3–e6 and a capture on e7 (a pinned piece may move along the pin) |
| R-4 | `/kc fen 4k3/8/8/8/8/8/3q4/4K3 w - - 0 1` | Select the white king | Red glow on e1; only f1 and the capture on d2 are offered |
| R-5 | `/kc fen 4k3/8/8/8/8/8/3q4/4K2R w K - 0 1` | Select the h1 rook | No moves: none of them gets the king out of check |
| R-6 | `/kc fen 4k3/8/8/8/8/3n4/8/4K3 w - - 0 1` | Select the white king | Glow on e1 (knight check from d3); d1, d2, e2 and f1 offered, f2 not (the knight covers it) |
| R-7 | New Game | Move a white piece next to the black king | It can never be captured; kings never show a capture marker |

### Castling

| ID | Setup | Do | Expected |
|---|---|---|---|
| C-1 | `/kc fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1` (Kiwipete) | Select each king | White king: g1 and c1 offered. Black king: g8 and c8 offered |
| C-2 | `/kc fen r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1` | Select each king | White: g1 only. Black: c8 only |
| C-3 | C-2 setup | Castle white kingside (click g1) | Rook jumps h1 → f1; last-move tint on e1 and g1 |
| C-4 | `/kc fen 4k3/4r3/8/8/8/8/8/R3K2R w KQ - 0 1` | Select the white king | In check (glow): no castling either way |
| C-5 | `/kc fen 4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1` | Select the white king | f1 is attacked: no g1 (can't castle through check); c1 is offered |
| C-6 | `/kc fen 4k3/8/8/8/8/8/6r1/R3K2R w KQ - 0 1` | Select the white king | g1 is attacked: no g1 (can't castle into check); c1 is offered |
| C-7 | `/kc fen 4k3/8/8/8/8/8/1r6/R3K2R w KQ - 0 1` | Select the white king | Only b1 is attacked: c1 is still offered (the king doesn't cross b1) |
| C-8 | `/kc fen 4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1` | Move the h1 rook away and back, then select the king | Only c1: moving the rook loses kingside castling |
| C-9 | `/kc move e1g1` in C-2 | | Castles; `/kc move e1c1` in C-2 prints "Not a legal move here" |

### En passant

| ID | Setup | Do | Expected |
|---|---|---|---|
| E-1 | New Game | e2–e4, e4–e5, then black d7–d5; select the e5 pawn | d6 shows a move dot; taking it removes the d5 pawn |
| E-2 | `/kc fen 4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1` | Select the e5 pawn | d6 offered (en passant square from the FEN) |
| E-3 | `/kc fen 4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1` | Select the e5 pawn | No d6 (no en passant square in the FEN) |
| E-4 | E-1, but play another move (e.g. a2–a3) before selecting e5 | | No d6: en passant is only possible straight after the double push |
| E-5 | `/kc fen 8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1` | Select the e5 pawn | Only e6: taking en passant would empty rank 5 and expose the a5 king to the h5 rook |

### Check, checkmate, stalemate

| ID | Setup | Do | Expected |
|---|---|---|---|
| M-1 | New Game | `/kc move f2f3`, `/kc move e7e5`, `/kc move g2g4`, `/kc move d8h4` | Glow on e1; info bar: "Checkmate" / "Black is victorious" |
| M-2 | `/kc fen 6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1` | Play a1–a8 | Glow on g8; info bar: "Checkmate" / "White is victorious" |
| M-3 | `/kc fen 7k/8/6K1/8/8/8/8/5Q2 w - - 0 1` | `/kc move f1f7` | No glow; info bar: "Stalemate" / "The game is a draw" |
| M-4 | Any check | Make a move that ends the check | Glow disappears; a following normal move clears the info bar |
| M-6 | `/kc fen k7/8/2Q5/8/8/8/8/7K w - - 0 1` | `/kc move c6b6` (or drag the queen to b6) | No glow; info bar: "Stalemate" / "The game is a draw" |
| M-5 | `/kc fen rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3` | Load it | Loading a mated position shows the glow and the checkmate message |

### Promotion

| ID | Setup | Do | Expected |
|---|---|---|---|
| P-1 | `/kc fen 4k3/1P6/8/8/8/8/8/4K3 w - - 0 1` | Move b7–b8 | Board dims; Q, R, B, N column runs down from b8; choosing one promotes |
| P-2 | `/kc fen 1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1` | Capture a7×b8, then click the dimmed board | Move is taken back: pawn on a7, black rook back on b8, previous last move restored |
| P-3 | `/kc fen 4k3/1P6/8/8/8/8/8/4K3 w - - 0 1` | `/kc move b7b8n` | Promotes straight to a knight with no picker |
| P-4 | `/kc fen 4k3/1P6/8/8/8/8/8/4K3 w - - 0 1` | Promote to a queen on b8 | Glow on e8, as the new queen gives check |

## Board

### Flip

| ID | Setup | Do | Expected |
|---|---|---|---|
| F-1 | New Game | `/kc flip` (the round-arrows flip button, top left, is hidden for now) | Black at the bottom; no flip button shows |
| F-2 | Flipped | Look at the labels | Left edge reads 8 at the bottom up to 1 at the top; bottom edge reads h to a, left to right |
| F-3 | Make a move, give check, then flip | | Pieces, last-move tint and check glow stay on their squares |
| F-4 | Flipped, a piece selected | | Move dots and capture corners are on the right squares; clicking and dragging both work |
| F-5 | Flipped, P-1 setup | Move b7–b8 | Overlay covers the whole board; the choices run from b8 towards the centre (upwards on screen) |
| F-6 | Picker open | Flip | Overlay and choices follow the board |
| F-7 | Flipped | Toggle Board Labels off and on in `/kco` | Labels come back on the displayed edges |
| F-8 | Flipped | `/reload` | The board starts unflipped again (orientation isn't saved) |

### Input and indicators

| ID | Do | Expected |
|---|---|---|
| I-1 | Click a piece, then a highlighted square | Piece slides there; last-move tint on both squares |
| I-2 | Drag a piece onto a highlighted square | Drops there; dropping anywhere else snaps it back |
| I-3 | Hover a legal destination with a piece selected (or while dragging) | The square tints and its dot/corners hide |
| I-4 | Click a selected piece again | Deselects |
| I-5 | Select a piece, then click an enemy piece it can capture | Captures |
| I-6 | Close the window mid-drag and reopen | Piece is back on its square |
| I-7 | Clear Board / New Game with a board in play | Confirmation; check glow, last move and picker are cleared |

### Move history (< >)

| ID | Do | Expected |
|---|---|---|
| H-1 | `/reload`, `/kc` | Bottom left has < and > (no author or version text); both greyed out |
| H-2 | New Game, play e4, e5, Nf3 | < enabled, > greyed |
| H-3 | Press < three times | Steps back to the start position instantly; last-move tint follows; < greys out at the start |
| H-4 | Press > | Each press replays the next move with the slide animation; > greys out at the latest move |
| H-5 | Go back two moves and play a different move | That move replaces the later ones; > is greyed |
| H-6 | Play a capture, castle, en passant and a promotion; step back and forward over each | Captured pieces return and disappear correctly; the rook moves with the king; the promoted piece is a pawn before and the chosen piece after |
| H-7 | Give check, step back past it and forward again | Check glow follows the position |
| H-8 | Open the promotion picker, press < | Nothing happens until the promotion is chosen or cancelled |
| H-9 | New Game / Clear Board / `/kc fen` | History starts again (both buttons greyed) |
| H-10 | In a puzzle, after the opponent's move, press < | Shows the position before it; pieces can't be picked up until > returns to the latest position |
| H-11 | In a puzzle, press < while the opponent is about to reply | The reply still plays, from the latest position |
| H-12 | Make a wrong puzzle move and press < before it is taken back | The wrong move disappears from the history; the latest position is shown |
| H-13 | Finish a puzzle, step back and forward, and try to move a piece | < and > step through the puzzle; no piece can be picked up at any point |

### UCI command

| ID | Do | Expected |
|---|---|---|
| U-1 | New Game, `/kc move e2e4` | Pawn slides e2 → e4 |
| U-2 | `/kc move e2e5` | "Not a legal move here: e2e5" |
| U-3 | `/kc fen not a fen` | "Invalid FEN: malformed FEN" |

## Computer opponent

Results count towards the level's record (`/kco`, Computer section); **Reset Computer Record** clears it afterwards.

### Starting a game

| ID | Setup | Do | Expected |
|---|---|---|---|
| AI-1 | Play vs AI tab | Click New Game, then Black under Play as | Menu: Two players; Raid Finder, Normal, Heroic, Mythic, Cutting Edge with grey descriptions; Play as White / Black / Random with the current one ticked. Clicking Black ticks it and the menu stays open |
| AI-2 | New Game, play e4 | New Game, Play as White, Normal; confirm | Start position, white at the bottom; "Your move" / "You play White against the Normal computer"; grey line "Normal · Won 0 · Lost 0 · Drawn 0" (or your record) |
| AI-3 | `/kc computer normal w` | Try a black piece; play e4 and try to pick up a piece while "Thinking..."; wait | Black never selects; nothing can be picked up while thinking; the reply animates after about half a second, then "Your move" |
| AI-4 | `/kc computer heroic b` | Watch, then reply | Black at the bottom; the computer opens as white; then only black pieces move |
| AI-5 | Play vs AI tab | New Game, Play as Random, Raid Finder; repeat a few times | Sometimes white, sometimes black; your colour always at the bottom |
| AI-6 | — | `/kc computer mythic b`, then `/kc computer`, then `/kc fen 4k3/8/8/8/8/8/8/4K3 w - - 0 1` | A Mythic game as black (no confirm popup); then a game at the last level and colour chosen; the FEN ends the computer game (no turns) |
| AI-7 | `/kc computer normal w` | Play a move, New Game, Two players (confirm); repeat with Clear Board | Either colour moves again with no turns; the info bar clears; the computer never moves |

### Playing

| ID | Setup | Do | Expected |
|---|---|---|---|
| AI-10 | Test panel (FEN `1r4k1/8/8/8/8/8/5PPP/6K1 b - - 0 1`, Normal, you white) | Watch | Black plays Rb1 mate; "Defeat" / "Checkmate. Black wins."; Lost +1; no piece can be picked up; < > still step through |
| AI-11 | Test panel (FEN `6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1`, Normal, you white) | Play Ra8 mate | "Victory!" in green / "Checkmate. White wins."; Won +1 |
| AI-12 | Test panel (FEN `4k3/8/8/8/8/8/3n4/4K3 w - - 0 1`) | Take the knight with the king | "Draw" / "Neither side can checkmate"; Drawn +1 |
| AI-13 | Test panel (FEN `4k3/8/8/8/8/8/R7/4K3 w - - 99 60`) | A quiet rook move | "Draw" / "Fifty moves without a capture or pawn move" |
| AI-14 | Test panel (FEN `8/1P6/8/8/8/k7/8/4K3 w - - 0 1`) | b7-b8, cancel on the dimmed board; promote again to a knight | Cancelling takes the pawn back and the computer doesn't move; after choosing, the knight appears and the computer replies |
| AI-15 | `/kc computer normal w` | Play three moves; press < once and try to move; press < again and play a different move | One step back (computer's turn) nothing can be picked up; two steps back your move replaces the later ones and the computer replies |
| AI-16 | `/kc computer cuttingedge w` | Play a move, press < while it thinks | The reply still comes, played from the latest position |
| AI-17 | `/kc computer cuttingedge w` | Play a move; while "Thinking..." click Puzzles and play a puzzle move; click Play | No computer move appears in the puzzle; back in Play the game and its history are as left, and the computer thinks again and replies |
| AI-18 | `/kc computer cuttingedge w` | Play a few moves, moving the camera and window while it thinks | No freezes; up to about 5 seconds a move; fade and drag still work |
| AI-19 | — | A few games at Raid Finder and at Mythic | Raid Finder hangs pieces and misses simple tactics; Mythic punishes hanging pieces and rarely blunders |
| AI-20 | — | `/kco` Computer section; Reset Options; Reset Computer Record | Won / lost / drawn per level played; Reset Options keeps it; Reset Computer Record clears it |

## Play vs Friend

Needs a second client (a friend, or a second account) with Karazhan Chess. Results count towards the record against that player (`/kco`, Friends section). `/kc friend [name]` opens the tab (and invites `name`). Offline, `node lua.js tests/friend.lua` plays the protocol between simulated clients.

### Inviting

| ID | Do | Expected |
|---|---|---|
| FR-1 | Look below the window. Click Play vs Friend. | Three tabs: Play vs AI, Play vs Friend, Puzzles. Play vs Friend shows the start position (nothing moves), "Play vs Friend" in the info bar, and Offer Draw / Resign (greyed) / Invite. |
| FR-2 | Click Invite. | A menu: Rematch <name> (after a first game); Friends online (character and Battle.net friends in this WoW version, or None); Enter a name...; Play as White / Black / Random, the menu staying open on a choice. |
| FR-3 | Invite an online friend without Karazhan Chess (or Enter a name of anyone online without it). | "Looking for <name>" / "Checking that they have Karazhan Chess...", then after 5 seconds "No answer". No popup on their side. |
| FR-4 | Enter a name: your own name; then just a first name (WoW Forever) or "two words" (elsewhere). | "That's you"; then "Not a name" (on Forever with the hint to enter a first and last name). Nothing is sent. |
| FR-5 | With a friend on another Karazhan Chess version, invite them. | "Different versions" naming both versions; no game starts. Inviting you from their side prints the same in your chat and declines. |
| FR-6 | Invite your friend (second client), Play as White. On their side, accept the popup. | You see "Invitation sent" / "Waiting for <name> to accept..."; they get a ready-check sound and the popup "<you> invites you to a game of Karazhan Chess. You would play Black.". Accepting opens their window on Play vs Friend with black at the bottom; you get "Your move", they get "<you>'s move". |
| FR-7 | Invite, and decline on their side. Invite again, then Invite > Withdraw invitation. Invite again and let it run for 60 seconds. | "Declined"; the withdrawn popup closes on their side (with a chat line); after 60 seconds "No answer" and their popup closes. |
| FR-8 | During a game, have a third player (or the opponent from a new session) invite you. | They get "Busy"; you get a chat line that you are still playing. Invite is greyed out during a game. |

### Playing

| ID | Do | Expected |
|---|---|---|
| FR-10 | Play e4, try to move again or move their pieces. Let them reply. | Only your pieces on your turn; their reply animates on your board within a second or so; the info bar alternates "Your move" / "<name>'s move". |
| FR-11 | Play fool's mate: white f3, black e5, white g4, black Qh4. | "Defeat" for white and "Victory!" for black, "Checkmate. Black wins."; the footer "vs <name> · Won · Lost · Drawn" counts it once on each side; no more moves; < > still step through. |
| FR-12 | Reach a promotion and pick a knight. | The knight appears on both boards. |
| FR-13 | Offer Draw; decline on their side. Offer Draw again; accept. | Their popup "<you> offers a draw."; declining shows "<name> declined your draw offer."; accepting ends it as "Draw" / "Draw agreed." on both, Drawn +1. Offer Draw is greyed while an offer is out. |
| FR-14 | Resign (confirm). | "Defeat" / "You resigned." for you, "Victory!" / "<you> resigned." for them; counted once each. |
| FR-15 | During a game, switch to Play vs AI (or close the window) and let them move. | A chat line "<name> has moved. Your move!"; back on Play vs Friend the move is there; the Play vs AI board and any computer game come back as left. |
| FR-16 | /reload on one side during a game, then open Play vs Friend. Let the other side move while the first is still loading. | The game comes back with the same moves and orientation; a move missed while loading arrives when the tab opens (it syncs). |
| FR-17 | Press < during a game and try to move. | Earlier positions show, but nothing can be moved until > reaches the latest; an incoming move jumps to it. |
| FR-18 | /kco, Friends section. Reset Options. Reset Friend Record, confirm. | Won / lost / drawn per opponent; Reset Options keeps it and any game in progress; Reset Friend Record clears it. |
| FR-19 | After a game, Invite > Rematch <name>. | Invites the last opponent directly (with the addon check). |
| FR-21 | On WoW Forever, Invite > Enter a name..., type the friend's first and last name in lower case | The popup asks for a first and last name; the invitation reaches them; "First Last" shows capitalised in the info bar, footer and /kco |
| FR-22 | Right-click a player in the world (or portrait, chat name, friends list) > Invite to Karazhan Chess; then right-click an NPC, yourself, the other faction | The window opens on Play vs Friend and the invitation starts; no entry for NPCs, yourself or the other faction; greyed out during a game |
| FR-20 | /kc friend <name> | Opens the window on Play vs Friend and invites <name>. /kc move is refused on this tab. |

## Puzzles

Puzzle progress is saved, so note your rating before testing and use **Reset Puzzle Progress** in `/kco` afterwards if you want a clean start. `/kc puzzle` opens puzzles directly.

### Loading and modes

| ID | Do | Expected |
|---|---|---|
| PZ-1 | `/reload`, `/kc` | Three tabs below the window, Play vs AI selected; the info bar under the board is empty; the window is taller than before |
| PZ-2 | Click the Puzzles tab | The data loads (a short pause the first time only); a puzzle starts; the bottom buttons become tier / Solution / Next Puzzle |
| PZ-3 | Disable "Karazhan Chess Puzzles" in the AddOns list, `/reload`, click Puzzles | Stays on Play; info bar: "Puzzles unavailable" and how to enable them |
| PZ-4 | Set up a position in Play (a few moves, board flipped), go to Puzzles, then back to Play | The free-play position, its move history and the orientation come back |
| PZ-5 | `/kc puzzle` then `/kc play` | Same as clicking the tabs, opening the window if needed |

### Solving

| ID | Do | Expected |
|---|---|---|
| PZ-10 | Start a puzzle | The board turns so the solver is at the bottom; "Get ready", then after half a second the opponent's move animates and "Your turn" / "Find the best move for White/Black" |
| PZ-11 | During "Get ready" or while the opponent replies, try to pick up a piece | Nothing can be picked up |
| PZ-12 | On your turn, try to pick up an opponent piece | It doesn't select |
| PZ-13 | Play the right move in a multi-move puzzle | "Best move!" / "Keep going...", then the opponent replies |
| PZ-14 | Play a wrong move | "That's not the move!" in red; the move is taken back after half a second (including a castling rook or a promoted pawn); the rating drops (the footer shows a red change); you can keep trying |
| PZ-15 | Solve a puzzle without mistakes | "Success!" in green; the detail line shows "New Rating" rising (green change); the grey line shows the difficulty and Solved +1 (no puzzle ID, puzzle rating or puzzle types) |
| PZ-16 | Solve after a mistake | "Puzzle complete"; no further rating change |
| PZ-17 | A "Mate in 1" puzzle: mate with a different move from the solution, if there is one | Counts as solved |
| PZ-18 | Press Solution mid-puzzle | The remaining moves play out, then "Puzzle complete"; counts as failed if it was the first attempt; Solution is greyed out afterwards |
| PZ-19 | Press Solution straight after a wrong move | The wrong move is taken back first, then the solution plays correctly |
| PZ-20 | Press Next Puzzle mid-animation | The new puzzle starts cleanly; nothing from the old one plays on top |
| PZ-21 | After a puzzle ends (solved or Solution), try to move pieces of both colours | Nothing can be picked up until Next Puzzle; any selection clears when it ends |
| PZ-22 | Promotion during a puzzle | The picker appears; the chosen piece is part of the move that is checked |
| PZ-23 | Info button, mid-puzzle and after finishing | Tooltip with the puzzle ID, rating, difficulty, number of moves, result (Solved or Failed), readable themes ("Mate in 2", "Discovered attack"); greyed out until the puzzle is over |

### Rating, tiers and progress

| ID | Do | Expected |
|---|---|---|
| PZ-30 | Tier button | Menu of Raid Finder, Normal, Heroic, Mythic and Cutting Edge with rating ranges; the current one is checked; choosing one starts a puzzle from it; the button always reads "Difficulty" and the grey info line shows the chosen tier |
| PZ-31 | Several puzzles per tier | Puzzle ratings (in the Info tooltip) are inside the tier's range |
| PZ-32 | Leave mid-puzzle (Play vs AI tab or `/reload`), come back | The same unfinished puzzle starts again |
| PZ-33 | Note a solved puzzle's ID (Info button); keep playing | It doesn't come up again |
| PZ-34 | `/kco`, Puzzles section | Lichess credit; rating / solved / failed match the footer |
| PZ-35 | Reset Puzzle Progress (confirm) | Rating 1500, counts 0 |
| PZ-36 | Reset Options | Options reset, including puzzle types (all ticked again); puzzle rating and counts are kept |
| PZ-37 | `/reload`, `/kco`, Puzzle Types (button in the Puzzles section, or the entry under Karazhan Chess) | Groups Tactics (10 boxes), Mates (4), Endgames (5) and Other (1), all ticked by default |
| PZ-38 | Untick All, tick Bishop endgames, press Next Puzzle a few times in a couple of tiers | Every puzzle is a bishop endgame (kings, bishops, pawns), found without a pause |
| PZ-39 | Untick All, press Next Puzzle; then Tick All and Next Puzzle | "No puzzles" / "No <tier> puzzles match the puzzle types you ticked.", straight away; after Tick All a puzzle starts |
| PZ-40 | Untick a few types, `/reload`, open Puzzle Types | The same types are still unticked |
| PZ-41 | Untick All, tick Mate in 1 and Mate in 2; solve or show a few puzzles | Each ends in checkmate within one or two of your moves |

## Sounds

| ID | Do | Expected |
|---|---|---|
| S-1 | `4k3/8/8/3p4/4P3/8/8/R3K3 w Q - 0 1`: castle O-O-O; `<`, exd5; `<`, Ra8+ | Move sound, capture sound, check sound |
| S-2 | `4k3/1P6/8/8/8/8/8/4K3 w - - 0 1`: b8=Q; `<`, b8 and cancel | Sound (check) when the piece is picked, none when cancelled |
| S-3 | Raid Finder game: play, `<` then `>`, close the window while it thinks | Computer replies and `>` replays make sounds, `<` doesn't; silent while closed |
| S-4 | `/kco`: each Move Sounds theme, then Off; make a move | Each choice previews its move sound; Off is silent |
| S-5 | Computer game from `6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1`: Ra8#; then lose / draw a game (computer or friend) | Victory after the mate, Defeat on a loss, Draw on a draw; once each, not again after `/reload` |

## Window and options

| ID | Do | Expected |
|---|---|---|
| W-1 | Drag the title, `/reload` | Window reopens where it was |
| W-2 | Resize with the grip, `/reload` | Size is kept; board art stays smooth |
| W-3 | Change Window Opacity | Window background fades, pieces and squares don't |
| W-4 | Fade-out on, move the mouse away | Whole window fades; returns on hover |
| W-5 | Change board and piece themes | Squares and pieces update immediately, including while flipped |
| W-7 | Karazhan piece theme: drag, click-move, flip, untick and tick Animated Pieces, back to Default | Karazhan chess models (Alliance white, Horde black) fill their squares facing the viewer, pawns smallest; drags and animations work and they stay clickable; Animated Pieces only for Karazhan, stops / restarts the idle animation; Default brings flat pieces back with no models left |
| W-8 | Karazhan: promote (`8/4P3/8/8/8/8/8/K6k w - - 0 1`, e7-e8), captures, Clear Board, New Game, Fade Out Window | Picker shows models; no stray models on empty squares; models fade with the board |
| W-6 | Escape with Close on Escape on | Window closes |
