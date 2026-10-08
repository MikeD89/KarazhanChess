# Karazhan Chess

A World of Warcraft addon: a chess board in a movable window (`/kc`). Work in progress — the UI, board, piece rendering, selection, themes and full legal move generation (a rules engine with check, checkmate, stalemate, castling and en passant) exist; turns and game flow do not. Lichess puzzles are in progress.

## Targets

- **WoW Forever** (interface `16001`) is the primary target. Forever uses the modern Mainline UI API, not the old Classic API.
- **Retail** (`120100`, `120105`) is also declared in [KarazhanChess.toc](KarazhanChess.toc).
- The checkout lives in `_classic_beta_\Interface\AddOns\KarazhanChess`. `_retail_\Interface\AddOns\KarazhanChess` is a **directory junction** to it — edits apply to both clients. Never delete through the junction recursively.
- Use modern APIs only: `Settings.OpenToCategory`, `BackdropTemplate` for any frame that calls `SetBackdrop`, `PlaySound(SOUNDKIT.*)`. No `InterfaceOptions*` functions.

## Testing

UI verification is in-game: `/reload`, then `/kc` (window), `/kco` (options). BugSack/BugGrabber are installed in both clients and capture Lua errors. State clearly when a change has not been tested in game.

Code without WoW API (`Rules.lua`) is tested offline under [fengari](https://github.com/fengari-lua/fengari) (Lua 5.3 in Node, close enough for 5.1 code). In `Tools/` (run `npm install` once):

- `node lua.js tests/perft.lua` checks move generation against known perft counts plus checkmate/stalemate (add `quick` to skip the slow depths; the full run takes about 40 s). Run it after any change to `Rules.lua`.
- `node lua.js tests/syntax.lua ../KarazhanChess/*.lua` compiles every addon file to catch syntax errors.
- `node lua.js script.lua [args]` runs any Lua script; the global `ADDON_ROOT` is the repo root. Load addon files with `loadfile(path)("KarazhanChess", ns)` to mimic WoW's `...`.

## Layout and load order

[KarazhanChess.toc](KarazhanChess.toc) loads [embeds.xml](embeds.xml) (libraries) then [modules.xml](modules.xml) (addon code), in this order:

| File | Role |
|---|---|
| `Init.lua` | Creates the `KC` AceAddon object on the namespace. Must load first |
| `Utils.lua` | Helpers: `ns.showRealDate`, `isNull`, `dir`, `ternary`, `ord`, `removeFromTableByIndex` |
| `Rules.lua` | `Rules`: pure-Lua rules engine (no WoW API) on position snapshots — FEN, legal moves, check, mate, UCI, perft |
| `FrameUtils.lua` | Frame pool, `CreateIcon`, board labels, keep-on-screen |
| `Icons.lua` | Texture paths and theme lists (`Icons.Board.Themes`, `Icons.Piece.Themes`) |
| `Square.lua` | `Square` class: board square frame plus legal-move / legal-capture markers |
| `Piece.lua` | `Piece` class: legal moves (via `Rules`), frame, move/animate, selection highlight |
| `Game.lua` | `Game` class: piece list, new game / clear board (with StaticPopup confirms), selection, moves, capture, board snapshot, check state |
| `Main.lua` | Constants, `OnInitialize`/`OnEnable`, minimap broker, Settings integration, slash commands |
| `Frame.lua` | Builds the main window and the 8×8 `KC.board`; window position and opacity |
| `Promotion.lua` | Pawn promotion picker (`KC:ShowPromotionPicker`): dims the board and shows Q/R/B/N on the promotion file; the pawn becomes the chosen piece via `Piece:PromoteTo` |
| `Options.lua` | AceConfig options table, defaults, getters/setters |

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
- **Making a move.** `Game:HandleBoardSquareClicked` looks up the engine move (`Game:FindLegalMove`) and applies it to the frames: removes the piece on `move.capSq` (en passant takes the pawn beside), moves the piece, moves the rook for castling (`Game:CompleteCastle`), sets `epSquare`, then `Game:UpdateCheckState(opponent)`. Clicking the enemy piece (`Game:SelectPiece` → `HandleCapture`), clicking its square, and dropping onto it all go through there. Promotion: `move.promotion` opens the picker; its overlay swallows board clicks; clicking a choice promotes, clicking the dimmed board cancels and takes the move back via `Game:UndoMove` (restoring any captured piece on its own square, `hasMoved`, `epSquare` and the previous last move). Clear Board / New Game hide it without cancelling.
- **Check.** `Game:UpdateCheckState(colour)` shows the Lichess red glow (`Square:SetCheck`, texture `Textures/check.blp`, ARTWORK sublevel 4) under any king in check and prints checkmate / stalemate for the side to move.
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

Releases use the BigWigs packager ([.github/workflows/main.yml](.github/workflows/main.yml)) on tag push; [.pkgmeta](.pkgmeta) lists library externals (which replace `Libs/` in packaged builds) and ignored files. The `.pkgmeta` file is YAML — spaces only, no tabs. `@project-version@` tokens are substituted by the packager; `Main.lua` falls back to `0.0_dev` locally.

Assets: `Textures/` holds `.blp` files used at runtime; `TextureSource/` holds Paint.NET sources (not packaged) and `TextureSource/Lichess/` the original SVGs for the Lichess piece sets (packaged, since some are GPL). Credits and licences for all third-party art are in `Textures/CREDITS.md` — keep it updated when adding art, and only add art whose licence allows redistribution and commercial use. Themes are saved by name (= texture folder name); the `Themes` lists in `Icons.lua` only set dropdown order, so themes can be added, reordered or removed freely (removed ones fall back to Default via `KC:migrateThemeSettings`). Never change `LegacyThemes` — it decodes old index-based settings. `Converter/BLPNGConverter.exe` converts PNG ↔ BLP (GUI only, not packaged). Generated textures are written straight to BLP by scripts in `Tools/textures/` using `Tools/blp.js` (uncompressed BLP2 with mipmaps, the format of `legalmove.blp`); `node textures/check.js` regenerates the check glow.
