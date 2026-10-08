# Karazhan Chess — Tests

Manual and offline tests. Every in-game test has an ID so it can later become an automated case in a dev-build test mode (planned: test suites inside the addon, enabled only when the version is `0.0_dev`).

Most in-game tests start from a FEN, so they don't depend on playing moves by hand. Type the commands in WoW's chat box, not in a terminal.

## Setup

1. `/reload` after any code change. BugSack must stay empty for every test.
2. `/kc` opens the window, `/kco` the options.
3. Testing commands:
   - `/kc fen <FEN>` sets the board up from a FEN.
   - `/kc move <uci>` plays a move, for example `e2e4`, `e1g1` (castling) or `e7e8q` (promotion).

There are no turns in free play yet, so either colour can move at any time.

## Offline (no game needed)

Run these in `Tools/` (`npm install` once). Run them after any change to `Rules.lua`, and run the syntax check after any change to Lua files.

| ID | Command | Expected |
|---|---|---|
| OFF-1 | `node lua.js tests/perft.lua quick` | Every line `ok`, then `all passed` (a few seconds) |
| OFF-2 | `node lua.js tests/perft.lua` | Also start position depth 4 = 197281 and Kiwipete depth 3 = 97862 (about 40 s) |
| OFF-3 | `node lua.js tests/syntax.lua ../KarazhanChess/*.lua` | `N/N files compile` |

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
| M-1 | New Game | `/kc move f2f3`, `/kc move e7e5`, `/kc move g2g4`, `/kc move d8h4` | Glow on e1; chat: "Checkmate. Black is victorious." |
| M-2 | `/kc fen 6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1` | Play a1–a8 | Glow on g8; "Checkmate. White is victorious." |
| M-3 | `/kc fen 7k/8/6K1/8/8/8/8/5Q2 w - - 0 1` | `/kc move f1f7` | No glow; chat: "Stalemate. The game is a draw." |
| M-4 | Any check | Make a move that ends the check | Glow disappears |
| M-6 | `/kc fen k7/8/2Q5/8/8/8/8/7K w - - 0 1` | `/kc move c6b6` (or drag the queen to b6) | No glow; chat: "Stalemate. The game is a draw." |
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
| F-1 | New Game | Click the round-arrows button (top left) | Black at the bottom; tooltip "Flip board" on hover |
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

### UCI command

| ID | Do | Expected |
|---|---|---|
| U-1 | New Game, `/kc move e2e4` | Pawn slides e2 → e4 |
| U-2 | `/kc move e2e5` | "Not a legal move here: e2e5" |
| U-3 | `/kc fen not a fen` | "Invalid FEN: malformed FEN" |

## Window and options

| ID | Do | Expected |
|---|---|---|
| W-1 | Drag the title, `/reload` | Window reopens where it was |
| W-2 | Resize with the grip, `/reload` | Size is kept; board art stays smooth |
| W-3 | Change Window Opacity | Window background fades, pieces and squares don't |
| W-4 | Fade-out on, move the mouse away | Whole window fades; returns on hover |
| W-5 | Change board and piece themes | Squares and pieces update immediately, including while flipped |
| W-6 | Escape with Close on Escape on | Window closes |
