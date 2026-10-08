// Karazhan Chess - fengari (Lua 5.3 in JS) helpers shared by lua.js and the
// puzzle builder. Addon files are plain Lua 5.1, which fengari also runs.
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const ADDON_ROOT = path.resolve(__dirname, "..").split(path.sep).join("/");

// A fresh Lua state with the standard libraries, the ADDON_ROOT global (the
// repo root, i.e. the addon folder) and readfile(path), which returns a file's
// contents (fengari has no io.open)
function createState() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_pushstring(L, to_luastring(ADDON_ROOT));
  lua.lua_setglobal(L, to_luastring("ADDON_ROOT"));
  lua.lua_pushcfunction(L, L2 => {
    const file = lua.lua_tojsstring(L2, 1);
    lua.lua_pushstring(L2, new Uint8Array(fs.readFileSync(file)));
    return 1;
  });
  lua.lua_setglobal(L, to_luastring("readfile"));
  return L;
}

// Runs a Lua file; throws with the Lua error message on failure
function doFile(L, file) {
  if (lauxlib.luaL_dofile(L, to_luastring(file)) !== lua.LUA_OK) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
}

// Calls a global Lua function with string arguments and returns its first result as a string
function call(L, name, ...args) {
  lua.lua_getglobal(L, to_luastring(name));
  for (const a of args) lua.lua_pushstring(L, to_luastring(String(a)));
  if (lua.lua_pcall(L, args.length, 1, 0) !== lua.LUA_OK) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
  const result = lua.lua_isnil(L, -1) ? null : lua.lua_tojsstring(L, -1);
  lua.lua_pop(L, 1);
  return result;
}

module.exports = { ADDON_ROOT, createState, doFile, call, lua, to_luastring };
