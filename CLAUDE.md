# Karazhan Chess

A World of Warcraft addon: a chess board in a movable window (`/kc`). Work in progress — the UI, board, piece rendering, selection, themes and per-piece movement patterns exist; blocking, captures, turns, check and game flow do not.

## Targets

- **WoW Forever** (interface `16001`) is the primary target. Forever uses the modern Mainline UI API, not the old Classic API.
- **Retail** (`120100`, `120105`) is also declared in [KarazhanChess.toc](KarazhanChess.toc).
- The checkout lives in `_classic_beta_\Interface\AddOns\KarazhanChess`. `_retail_\Interface\AddOns\KarazhanChess` is a **directory junction** to it — edits apply to both clients. Never delete through the junction recursively.
- Use modern APIs only: `Settings.OpenToCategory`, `BackdropTemplate` for any frame that calls `SetBackdrop`, `PlaySound(SOUNDKIT.*)`. No `InterfaceOptions*` functions.

## Testing

There is no Lua toolchain or test suite. Verification is in-game: `/reload`, then `/kc` (window), `/kco` (options). BugSack/BugGrabber are installed in both clients and capture Lua errors. State clearly when a change has not been tested in game.

## Layout and load order

[KarazhanChess.toc](KarazhanChess.toc) loads [embeds.xml](embeds.xml) (libraries) then [modules.xml](modules.xml) (addon code). Order in `modules.xml` matters — files define globals used by later files:

| File | Role |
|---|---|
| `Utils.lua` | Global helpers: `showRealDate`, `isNull`, `dir`, `ternary`, `ord`, `removeFromTableByIndex` |
| `FrameUtils.lua` | Frame pool, `CreateIcon`, board labels, keep-on-screen |
| `Icons.lua` | Texture paths and theme lists (`Icons.Board.Themes`, `Icons.Piece.Themes`) |
| `Piece.lua` | `Piece` class: frame, texture, move/animate, selection highlight |
| `Square.lua` | `Square` class: board square frame plus legal-move / legal-capture markers |
| `Game.lua` | `Game` class: piece list, new game / clear board (with StaticPopup confirms), selection, capture |
| `Main.lua` | `KC` AceAddon object, constants, `OnInitialize`/`OnEnable`, minimap broker, slash commands |
| `Frame.lua` | Builds the main window and the 8×8 `KC.board` |
| `Options.lua` | AceConfig options table, defaults, getters/setters |

`Options.lua` and `Frame.lua` define methods on `KC`, so they must load after `Main.lua`; `Options.lua` reads `Icons.*.Themes` at load time.

## Key concepts

- `KC.board[col][row]` — `Square` objects, both indices 1–8 (col 1 = file `a`). `KC:GetBoardPosition("e4")` maps algebraic notation to a square.
- `Square.currentPiece` ↔ `Piece.currentSquare` is a two-way link; keep both sides in sync when moving or removing pieces.
- Legal moves are shown by `Square.legalMove` / `legalCapture` marker frames, and **their visibility is the source of truth** for `IsLegalMove()` / `IsLegalCapture()`.
- `Game:CalculateValidMoves()` delegates to `Piece:CalculateMoves()`, which uses `Piece.Movement` (steps vs slides) plus special-cased pawns. It ignores other pieces: no blocking, no captures, no castling/en passant/promotion. `CalculateValidCaptures()` returns `{}`.
- `Piece.SunfishLookup` hints at a planned port of the Sunfish engine; nothing is implemented.
- Settings live in `KC.db.global` (AceDB, saved variable `KarazhanChessDB`). Each option has `get*`/`set*`/`update*` methods in `Options.lua`.
- Frames come from `FrameUtils` pool (`getFrameFromPool` / `returnFrameToPool`).

## Conventions

- Lua 5.1 (WoW). Tabs in most files, 4 spaces in some — match the file being edited.
- Classes use `X = {}; X.__index = X; function X:new() ... setmetatable ... end`.
- File header block on every source file (name, author, one-line purpose).
- Prefer `local` variables. The existing code leaks several accidental globals — don't add more, and fix them when touching that code.

## Libraries

`Libs/` is vendored and **should not be edited**. The copies were taken from a current Questie install (October 2026) to get Forever/retail-compatible versions of Ace3, LibDBIcon, CallbackHandler, LibSharedMedia, LibDataBroker and LibStub. To update, copy newer versions from a maintained addon or from upstream.

AceComm, AceTimer, AceSerializer, AceGUI, AceDBOptions and LibSharedMedia are loaded but not used yet (likely intended for multiplayer and save games).

## Packaging

Releases use the BigWigs packager ([.github/workflows/main.yml](.github/workflows/main.yml)) on tag push; [.pkgmeta](.pkgmeta) lists library externals (which replace `Libs/` in packaged builds) and ignored files. The `.pkgmeta` file is YAML — spaces only, no tabs. `@project-version@` tokens are substituted by the packager; `Main.lua` falls back to `0.0_dev` locally.

Assets: `Textures/` holds `.blp` files used at runtime; `TextureSource/` holds Paint.NET sources; `Converter/BLPNGConverter.exe` converts PNG ↔ BLP. Neither is packaged.
