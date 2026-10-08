# Karazhan Chess

A World of Warcraft addon: a chess board in a movable window (`/kc`). Work in progress — the UI, board, piece rendering, selection, themes and full legal move generation (a rules engine with check, checkmate, stalemate, castling and en passant) exist, plus Lichess puzzles (250,000, in a load-on-demand data addon) with a puzzle rating. Free play has no turns or game flow yet.

## Targets

- **WoW Forever** (interface `16001`) is the primary target. Forever uses the modern Mainline UI API, not the old Classic API.
- **Retail** (`120100`, `120105`) is also declared in [KarazhanChess.toc](KarazhanChess.toc).
- The checkout lives in `_classic_beta_\Interface\AddOns\KarazhanChess`. `_retail_\Interface\AddOns\KarazhanChess` is a **directory junction** to it — edits apply to both clients. Never delete through the junction recursively.
- The puzzle data addon lives in the repo at `KarazhanChess_Puzzles/`. WoW only scans top-level addon folders, so both clients have a junction `Interface\AddOns\KarazhanChess_Puzzles` → `_classic_beta_\Interface\AddOns\KarazhanChess\KarazhanChess_Puzzles` (same caution).
- Use modern APIs only: `Settings.OpenToCategory`, `BackdropTemplate` for any frame that calls `SetBackdrop`, `PlaySound(SOUNDKIT.*)`. No `InterfaceOptions*` functions.

## Testing

UI verification is in-game: `/reload`, then `/kc` (window), `/kco` (options). [TESTS.md](TESTS.md) lists the manual test cases (by ID) with FEN setups; add cases there when adding features, as they are meant to become automated suites in a dev-build test mode later. BugSack/BugGrabber are installed in both clients and capture Lua errors. State clearly when a change has not been tested in game.

Code without WoW API (`Rules.lua`, `PuzzleCodec.lua`) is tested offline under [fengari](https://github.com/fengari-lua/fengari) (Lua 5.3 in Node, close enough for 5.1 code). In `Tools/` (run `npm install` once):

- `node lua.js tests/perft.lua` checks move generation against known perft counts plus checkmate/stalemate (add `quick` to skip the slow depths; the full run takes about 40 s). Run it after any change to `Rules.lua`.
- `node lua.js tests/syntax.lua ../KarazhanChess/*.lua` compiles every addon file to catch syntax errors.
- `node lua.js tests/puzzles.lua [N]` loads the puzzle data addon through a stub LibStub and checks counts, unique IDs, lookups, decoding and that every solution is legal (`N` checks every Nth puzzle; 25 takes about 2 minutes). Run it after rebuilding the data or changing `PuzzleCodec.lua`.
- `node lua.js script.lua [args]` runs any Lua script; the global `ADDON_ROOT` is the repo root and `readfile(path)` returns a file's contents (fengari has no `io.open`). Load addon files with `loadfile(path)("KarazhanChess", ns)` to mimic WoW's `...`. `luastate.js` has the same helpers for Node scripts.

## Layout and load order

[KarazhanChess.toc](KarazhanChess.toc) loads [embeds.xml](embeds.xml) (libraries) then [modules.xml](modules.xml) (addon code), in this order:

| File | Role |
|---|---|
| `Init.lua` | Creates the `KC` AceAddon object on the namespace. Must load first |
| `Utils.lua` | Helpers: `ns.showRealDate`, `isNull`, `dir`, `ternary`, `ord`, `removeFromTableByIndex` |
| `Rules.lua` | `Rules`: pure-Lua rules engine (no WoW API) on position snapshots — FEN, legal moves, check, mate, UCI, perft |
| `PuzzleCodec.lua` | `PuzzleCodec`: pure-Lua decoder for the puzzle data format, plus record lookup by index / ID |
| `FrameUtils.lua` | Frame pool, `CreateIcon`, board labels, keep-on-screen |
| `Icons.lua` | Texture paths and theme lists (`Icons.Board.Themes`, `Icons.Piece.Themes`) |
| `Square.lua` | `Square` class: board square frame plus legal-move / legal-capture markers |
| `Piece.lua` | `Piece` class: legal moves (via `Rules`), frame, move/animate, selection highlight |
| `Game.lua` | `Game` class: piece list, new game / clear board (with StaticPopup confirms), selection, moves, capture, board snapshot, check state |
| `Main.lua` | Constants, `OnInitialize`/`OnEnable`, minimap broker, Settings integration, slash commands |
| `Frame.lua` | Builds the main window and the 8×8 `KC.board`; window position and opacity |
| `Promotion.lua` | Pawn promotion picker (`KC:ShowPromotionPicker`): dims the board and shows Q/R/B/N on the promotion file; the pawn becomes the chosen piece via `Piece:PromoteTo` |
| `Puzzles.lua` | `Puzzles`: loads the data addon, picks puzzles, runs the puzzle flow, puzzle rating; `KC:RegisterPuzzles` / `RegisterPuzzleThemes` for the data addon |
| `Options.lua` | AceConfig options table, defaults, getters/setters; reads `ns.Puzzles` at load |

### Namespace — no globals

All addon code shares the private namespace table WoW passes to each file (`local _, ns = ...`). `KC` and every class/helper are fields on `ns`, never globals. Each file:

1. starts (after the header) with `local _, ns = ...`, `local KC = ns.KC`, and locals for what it uses from earlier files (`local FrameUtils, Icons = ns.FrameUtils, ns.Icons`);
2. declares its class as `local X = {}` followed by `ns.X = X`.

Because imports are captured at load time, **a file can only import from files above it in `modules.xml`**. Square loads before Piece for this reason. Inside functions, `ns.X` can be used for anything regardless of order.

The only intended globals are `KarazhanChessDB` (saved variables), the main frame name `"Karazhan Chess"` (needed for `UISpecialFrames`), `SLASH_*`/`SlashCmdList` entries, and `StaticPopupDialogs` keys (prefixed `KARAZHANCHESS_`). The AceAddon object is reachable for debugging via `LibStub("AceAddon-3.0"):GetAddon("KarazhanChess")`.

## Key concepts

- `KC.board[col][row]` — `Square` objects, both indices 1–8 (col 1 = file `a`). `KC:GetBoardPosition("e4")` maps algebraic notation to a square.
- **Orientation.** `KC.boardFlipped` (not saved) puts black at the bottom; `KC:SetBoardFlipped` / `KC:FlipBoard` (the round-arrows button top-left) apply it. `KC.board` indices never change: `Square:UpdatePosition` places each square from `KC:GetDisplayPosition(col, row)` (its own inverse), and everything else is anchored to squares and follows. Every square has a rank and a file label; `Square:UpdateLabels` shows only those on the displayed left / bottom edge. Anything anchored to board corners must use `KC:GetSquareAtDisplay` and be re-anchored on flip, like the promotion overlay (`KC:AnchorPromotionPicker`).
- `Square.currentPiece` ↔ `Piece.currentSquare` is a two-way link; keep both sides in sync when moving or removing pieces.
- Input: pressing a piece selects it (`Piece:HandleMouseDown`); moving the cursor more than `Piece.DragThreshold` px turns it into a drag (piece follows cursor via `OnUpdate`), and release drops onto `KC:GetSquareUnderCursor()` through `Game:HandleBoardSquareClicked(square, false)` or snaps back. A release without dragging is a click. Clicking a square moves the selected piece (animated). `Piece:CancelDrag` runs on hide.
- Indicators follow Lichess (chessground): a tinted dot (`Square.legalMove`), tinted capture corners (`legalCapture`), a hover tint on the destination under the cursor (`Square:SetHovered`, driven by `KC:UpdateHoverSquare` polling on `KC.boardFrame`), the selected-square tint, and the last move's from/to squares (`Game:SetLastMove`). Square tints are ARTWORK sublevels 1–3 (last move, selected, hover) over the square texture. Colours are `Square.MoveColour` / `CaptureColour` / `HoverColour` / `LastMoveColour`; the marker textures are white and tinted with `SetVertexColor`.
- Legal moves are shown by `Square.legalMove` / `legalCapture` marker frames, and **their visibility is the source of truth** for `IsLegalMove()` / `IsLegalCapture()`.
- **Rules engine.** `Rules` works on a position table, not on frames: `pos.board[sq]` holds piece letters (`PNBRQK` white, `pnbrqk` black), squares are 1–64 with `sq = (row - 1) * 8 + col` (`Rules.Index`, `Col`, `Row`, `SquareName`, `SquareIndex`), plus `turn`, `castling` (`K Q k q` booleans), `ep`, `halfmove`, `fullmove`. Moves are tables `{ from, to, piece, captured, capSq, promotion, flag, rookFrom, rookTo }`, flag `"double"`, `"ep"` or `"castle"`. Main entry points: `FromFEN`/`ToFEN`, `GenerateLegalMoves(pos, colour, from)`, `MakeMove`/`UnmakeMove`, `IsAttacked`, `InCheck`, `GetStatus` (checkmate / stalemate), `MoveToUCI`/`FindMove`, `Perft`. Kings are never generated as capture targets (keeps free play sane without turns; legal games never reach it). The file ends with `return Rules` and makes its own `ns` when run offline.
- **Board ↔ engine.** `Game:GetPosition(turn)` snapshots `KC.board` into a position: castling rights come from unmoved kings and rooks on their start squares, `Game.epSquare` (set after a double pawn push, cleared by any other move) gives en passant. `Game:GetSquare(sq)` / `GetPieceAt(sq)` map engine squares back. `Piece:CalculateMoves()` returns `moves, captures` (positions like `"e4"`) from the engine's legal moves for that piece's colour; en passant shows as a move dot (Lichess does the same). There are no turns yet — either colour can move.
- **Making a move.** `Game:ApplyMove(piece, move, animated)` plays an engine move on the frames: removes the piece on `move.capSq` (en passant takes the pawn beside), moves the piece, moves the rook for castling (`Game:CompleteCastle`), sets `epSquare` and the last move, and returns an undo record; promotion and check state are the caller's job. Player moves come through `Game:HandleBoardSquareClicked`, which looks up the engine move (`Game:FindLegalMove`), applies it, then runs `Game:UpdateCheckState(opponent)`. Scripted moves use `Game:ExecuteMove(uci)` (animated, promotes directly from the UCI suffix, returns the move or nil if illegal). Clicking the enemy piece (`Game:SelectPiece` → `HandleCapture`), clicking its square, and dropping onto it all go through there. Promotion: `move.promotion` opens the picker; its overlay swallows board clicks; clicking a choice promotes, clicking the dimmed board cancels and takes the move back via `Game:UndoMove` (restoring any captured piece on its own square, `hasMoved`, `epSquare` and the previous last move). Clear Board / New Game hide it without cancelling.
- **FEN.** `Game:LoadFEN(fen)` clears the board and sets it up; every piece gets `hasMoved = true` except kings and rooks covered by a castling right, so `GetPosition` reproduces the FEN's castling field. The FEN's en passant square becomes `epSquare`. Returns the side to move, or nil and an error. Testing commands: `/kc fen <FEN>` and `/kc move <uci>`.
- **Check.** `Game:UpdateCheckState(colour)` shows the Lichess red glow (`Square:SetCheck`, texture `Textures/check.blp`, ARTWORK sublevel 4) under any king in check and, while `Game.announceResults` is on (free play), puts checkmate / stalemate for the side to move in the info bar.
- **Who may move.** `Game.allowedColour`: nil = either colour (free play), `"w"`/`"b"` = only that side, `false` = nobody (while a puzzle animates). `Game:CanMove(piece)` checks it in `SelectPiece`. `Game.onPlayerMove(move, uci, undo)` is called once a player's move is complete (after the promotion choice; `uci` includes the promotion letter). `Game:UndoMove(undo)` takes back any move from `ApplyMove` (castling rook, promotion back to a pawn via `Piece:SetType`, captured piece, en passant square, last move); callers then run `UpdateCheckState`.
- **Window layout.** Under the board is an info bar (`KC:SetStatus(headline, colour, detail, footer)`, colours in `ns.Colours`), so the window is `KC.fixedHeight` 570. Two Blizzard-style tabs below the window (`PanelTabButtonTemplate`) switch modes with `KC:SetMode("play" | "puzzle")`; each mode has its own three buttons in the bottom-right (`KC.playButtons`, `KC.puzzleButtons`). The tier button opens a `MenuUtil` context menu (it steps through tiers if `MenuUtil` is missing).
- **Puzzle data.** `KarazhanChess_Puzzles` is a LoadOnDemand addon (depends on `KarazhanChess`) loaded by `Puzzles:EnsureLoaded` the first time puzzles open. Its files are generated by `Tools/puzzles/build.js` — never edit them by hand. Each tier file calls `KC:RegisterPuzzles(key, { name, count, chunkSize, chunks })`: records are space-separated inside ~500-record strings, each a 5-character Lichess ID plus a base64 bit stream (format documented at the top of `PuzzleCodec.lua`; the JS encoder in `build.js` must match). `Themes.lua` registers the theme names the records' theme codes index into. Tiers: Raid Finder <1200, Normal 1200–1599, Heroic 1600–1999, Mythic 2000–2399, Cutting Edge 2400+, 50,000 each.
- **Building the data.** `node puzzles/build.js <lichess_db_puzzle.csv.zst>` (download from database.lichess.org; keep it outside the repo). It keeps every already-shipped ID still on Lichess, tops each tier up to `--per-tier` (default 50000) with puzzles passing that tier's filters (`FILTERS`; `node puzzles/stats.js <csv>` counts candidates), spread evenly over 50-point rating buckets with a seeded shuffle, and validates each encoded record in Lua (decodes back to the source, every move legal, mate themes end in mate) on worker threads (`--threads`). The result is deterministic for the same input and seed. To grow the set, raise `--per-tier` and rebuild; `--out dir` makes a trial build elsewhere (don't trial into `KarazhanChess_Puzzles/`, as the next build treats whatever is there as shipped).
- **Puzzle flow** (`Puzzles.lua`, Lichess style). `Start` loads the puzzle position, turns the board to the solver (the side *not* to move in the FEN), then after `ReplyDelay` plays the first move (the opponent's). A player move matching the next move, or any move that mates, is right: the opponent replies, or the puzzle is solved. A wrong move counts as a failure, shows "That's not the move!" and is taken back; the player can keep trying. Solution plays the rest out (counts as a failure). After the end the board is free to explore. Timed steps go through `Puzzles:After`, which drops callbacks from an earlier puzzle (`token`). Entering puzzles keeps the free-play position (as FEN) and orientation, restored on leaving.
- **Puzzle progress** is `KC.db.global.puzzles = { rating, tier, solved = { [id] = true }, failed = { [id] = true }, current }`, keyed by Lichess ID so the data can be rebuilt or extended freely. Rating is Elo (`RatingK` 32, start 1500) against the puzzle's rating, changed on the first attempt at a puzzle only. Next picks a random unattempted puzzle from the chosen tier. Reset Options keeps puzzle progress; the Puzzles section of the options has its own reset.
- `Piece.SunfishLookup` hints at a planned port of the Sunfish engine; nothing is implemented.
- Settings live in `KC.db.global` (AceDB, saved variable `KarazhanChessDB`). Each option has `get*`/`set*`/`update*` methods in `Options.lua`.
- Frames come from `FrameUtils` pool (`getFrameFromPool` / `returnFrameToPool`), parented to `KC.boardFrame`. Board textures have pixel snapping disabled (`FrameUtils:DisablePixelSnapping`) so scaled art stays smooth at any window size — do the same for any new board texture.
- Resizing scales the window (`SetScale`, saved as `windowScale`, limits `KC.minWindowScale`/`maxWindowScale`) via the grip from `KC:createResizeGrip`; the layout itself is fixed-size (`KC.fixedWidth`/`fixedHeight`). Anchor offsets are in the window's own scale, so `RestoreWindowPosition` applies the scale before the saved position.
- `KC.boardFrame` holds everything on the board (squares, markers, pieces, labels) and ignores the window's alpha: WoW applies alpha per texture, so translucent pieces would show the square through them. Window Opacity only affects `KC.frame` (background, border, text, buttons); the mouse-away fade is applied to both. Piece frame levels are relative to it via `Piece:GetBaseLevel()`.

## Conventions

- Lua 5.1 (WoW). Tabs in most files, 4 spaces in some — match the file being edited.
- Classes use `local X = {}; ns.X = X; X.__index = X; function X:new() ... setmetatable ... end`.
- File header block on every source file (name, author, one-line purpose), followed by the namespace imports.
- Every variable is `local` unless it belongs on `ns`, `KC`, or an object. Never assign a bare name.
- Move markers (`legalMove`/`legalCapture`) have mouse disabled so clicks fall through to the square; pieces sit above them and handle their own clicks.

## Libraries

`Libs/` is vendored and **should not be edited**. The copies were taken from a current Questie install (October 2026) to get Forever/retail-compatible versions of Ace3, LibDBIcon, CallbackHandler, LibSharedMedia, LibDataBroker and LibStub. To update, copy newer versions from a maintained addon or from upstream.

AceComm, AceTimer, AceSerializer, AceGUI, AceDBOptions and LibSharedMedia are loaded but not used yet (likely intended for multiplayer and save games).

## Packaging

Releases use the BigWigs packager ([.github/workflows/main.yml](.github/workflows/main.yml)) on tag push; [.pkgmeta](.pkgmeta) lists library externals (which replace `Libs/` in packaged builds), ignored files, and `move-folders`, which ships `KarazhanChess_Puzzles/` as its own top-level addon. The generated data files are marked `-diff` in `.gitattributes`. The `.pkgmeta` file is YAML — spaces only, no tabs. `@project-version@` tokens are substituted by the packager; `Main.lua` falls back to `0.0_dev` locally.

Assets: `Textures/` holds `.blp` files used at runtime; `TextureSource/` holds Paint.NET sources (not packaged) and `TextureSource/Lichess/` the original SVGs for the Lichess piece sets (packaged, since some are GPL). Credits and licences for all third-party art and the Lichess puzzle data are in `Textures/CREDITS.md` — keep it updated when adding art, and only add art whose licence allows redistribution and commercial use. Themes are saved by name (= texture folder name); the `Themes` lists in `Icons.lua` only set dropdown order, so themes can be added, reordered or removed freely (removed ones fall back to Default via `KC:migrateThemeSettings`). Never change `LegacyThemes` — it decodes old index-based settings. `Converter/BLPNGConverter.exe` converts PNG ↔ BLP (GUI only, not packaged). Generated textures are written straight to BLP by scripts in `Tools/textures/` using `Tools/blp.js` (uncompressed BLP2 with mipmaps, the format of `legalmove.blp`); `node textures/check.js` regenerates the check glow.
