# Karazhan Chess

A World of Warcraft addon: a chess board in a movable window (`/kc`). Work in progress — the UI, board, piece rendering, selection, themes and per-piece movement (with blocking and castling) exist; captures, turns, check and game flow do not.

## Targets

- **WoW Forever** (interface `16001`) is the primary target. Forever uses the modern Mainline UI API, not the old Classic API.
- **Retail** (`120100`, `120105`) is also declared in [KarazhanChess.toc](KarazhanChess.toc).
- The checkout lives in `_classic_beta_\Interface\AddOns\KarazhanChess`. `_retail_\Interface\AddOns\KarazhanChess` is a **directory junction** to it — edits apply to both clients. Never delete through the junction recursively.
- Use modern APIs only: `Settings.OpenToCategory`, `BackdropTemplate` for any frame that calls `SetBackdrop`, `PlaySound(SOUNDKIT.*)`. No `InterfaceOptions*` functions.

## Testing

There is no Lua toolchain or test suite. Verification is in-game: `/reload`, then `/kc` (window), `/kco` (options). BugSack/BugGrabber are installed in both clients and capture Lua errors. State clearly when a change has not been tested in game.

## Layout and load order

[KarazhanChess.toc](KarazhanChess.toc) loads [embeds.xml](embeds.xml) (libraries) then [modules.xml](modules.xml) (addon code), in this order:

| File | Role |
|---|---|
| `Init.lua` | Creates the `KC` AceAddon object on the namespace. Must load first |
| `Utils.lua` | Helpers: `ns.showRealDate`, `isNull`, `dir`, `ternary`, `ord`, `removeFromTableByIndex` |
| `FrameUtils.lua` | Frame pool, `CreateIcon`, board labels, keep-on-screen |
| `Icons.lua` | Texture paths and theme lists (`Icons.Board.Themes`, `Icons.Piece.Themes`) |
| `Square.lua` | `Square` class: board square frame plus legal-move / legal-capture markers |
| `Piece.lua` | `Piece` class: movement rules, castling, frame, move/animate, selection highlight |
| `Game.lua` | `Game` class: piece list, new game / clear board (with StaticPopup confirms), selection, moves, capture |
| `Main.lua` | Constants, `OnInitialize`/`OnEnable`, minimap broker, Settings integration, slash commands |
| `Frame.lua` | Builds the main window and the 8×8 `KC.board`; window position and opacity |
| `Options.lua` | AceConfig options table, defaults, getters/setters |

### Namespace — no globals

All addon code shares the private namespace table WoW passes to each file (`local _, ns = ...`). `KC` and every class/helper are fields on `ns`, never globals. Each file:

1. starts (after the header) with `local _, ns = ...`, `local KC = ns.KC`, and locals for what it uses from earlier files (`local FrameUtils, Icons = ns.FrameUtils, ns.Icons`);
2. declares its class as `local X = {}` followed by `ns.X = X`.

Because imports are captured at load time, **a file can only import from files above it in `modules.xml`**. Square loads before Piece for this reason. Inside functions, `ns.X` can be used for anything regardless of order.

The only intended globals are `KarazhanChessDB` (saved variables), the main frame name `"Karazhan Chess"` (needed for `UISpecialFrames`), `SLASH_*`/`SlashCmdList` entries, and `StaticPopupDialogs` keys (prefixed `KARAZHANCHESS_`). The AceAddon object is reachable for debugging via `LibStub("AceAddon-3.0"):GetAddon("KarazhanChess")`.

## Key concepts

- `KC.board[col][row]` — `Square` objects, both indices 1–8 (col 1 = file `a`). `KC:GetBoardPosition("e4")` maps algebraic notation to a square.
- `Square.currentPiece` ↔ `Piece.currentSquare` is a two-way link; keep both sides in sync when moving or removing pieces.
- Input: pressing a piece selects it (`Piece:HandleMouseDown`); moving the cursor more than `Piece.DragThreshold` px turns it into a drag (piece follows cursor via `OnUpdate`), and release drops onto `KC:GetSquareUnderCursor()` through `Game:HandleBoardSquareClicked(square, false)` or snaps back. A release without dragging is a click. Clicking a square moves the selected piece (animated). `Piece:CancelDrag` runs on hide.
- Legal moves are shown by `Square.legalMove` / `legalCapture` marker frames, and **their visibility is the source of truth** for `IsLegalMove()` / `IsLegalCapture()`.
- `Game:CalculateValidMoves()` delegates to `Piece:CalculateMoves()`, which uses `Piece.Movement` (steps vs slides) plus special-cased pawns. Moves only go to empty squares: slides and pawn pushes stop at the first piece in the way. Castling: `Piece:CanCastle` checks `hasMoved` flags and empty squares, and `Game:CompleteCastle` moves the rook. Not yet: captures (`CalculateValidCaptures()` returns `{}`), en passant, promotion, check.
- `Piece.SunfishLookup` hints at a planned port of the Sunfish engine; nothing is implemented.
- Settings live in `KC.db.global` (AceDB, saved variable `KarazhanChessDB`). Each option has `get*`/`set*`/`update*` methods in `Options.lua`.
- Frames come from `FrameUtils` pool (`getFrameFromPool` / `returnFrameToPool`), parented to `KC.boardFrame`.
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

Assets: `Textures/` holds `.blp` files used at runtime; `TextureSource/` holds Paint.NET sources (not packaged) and `TextureSource/Lichess/` the original SVGs for the Lichess piece sets (packaged, since some are GPL). Credits and licences for all third-party art are in `Textures/CREDITS.md` — keep it updated when adding art, and only add art whose licence allows redistribution and commercial use. Themes are saved by name (= texture folder name); the `Themes` lists in `Icons.lua` only set dropdown order, so themes can be added, reordered or removed freely (removed ones fall back to Default via `KC:migrateThemeSettings`). Never change `LegacyThemes` — it decodes old index-based settings. `Converter/BLPNGConverter.exe` converts PNG ↔ BLP (not packaged).
