// Karazhan Chess - runs a Lua file under fengari (Lua 5.3 in JS), standing in
// for a Lua interpreter: node lua.js script.lua [args...]
// The script gets its arguments in `arg` and can print / io.write as usual;
// the global ADDON_ROOT is the repo root.
const { createState, doFile, lua, to_luastring } = require("./luastate");

const [script, ...args] = process.argv.slice(2);
if (!script) {
  console.error("usage: node lua.js script.lua [args...]");
  process.exit(2);
}

const L = createState();

// arg table, like the standalone interpreter
lua.lua_createtable(L, args.length, 1);
lua.lua_pushstring(L, to_luastring(script));
lua.lua_rawseti(L, -2, 0);
args.forEach((a, i) => {
  lua.lua_pushstring(L, to_luastring(a));
  lua.lua_rawseti(L, -2, i + 1);
});
lua.lua_setglobal(L, to_luastring("arg"));

try {
  doFile(L, script);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
