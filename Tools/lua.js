// Karazhan Chess - runs a Lua file under fengari (Lua 5.3 in JS), standing in
// for a Lua interpreter: node lua.js script.lua [args...]
// The script gets its arguments in `arg` and can print / io.write as usual.
// Addon files are plain Lua 5.1, which fengari also runs.
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const [script, ...args] = process.argv.slice(2);
if (!script) {
  console.error("usage: node lua.js script.lua [args...]");
  process.exit(2);
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// arg table, like the standalone interpreter
lua.lua_createtable(L, args.length, 1);
lua.lua_pushstring(L, to_luastring(script));
lua.lua_rawseti(L, -2, 0);
args.forEach((a, i) => {
  lua.lua_pushstring(L, to_luastring(a));
  lua.lua_rawseti(L, -2, i + 1);
});
lua.lua_setglobal(L, to_luastring("arg"));

// Scripts can find the repo root (the addon folder) through this global
lua.lua_pushstring(L, to_luastring(path.resolve(__dirname, "..").split(path.sep).join("/")));
lua.lua_setglobal(L, to_luastring("ADDON_ROOT"));

if (lauxlib.luaL_dofile(L, to_luastring(script)) !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
