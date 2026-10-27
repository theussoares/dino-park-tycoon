// Executa tests/logic_test.lua no interpretador Lua 5.3 do fengari (sem Roblox).
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("../tools/node_modules/fengari");
const root = path.join(__dirname, "..");
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
for (const [name, file] of [["SRC_CONFIG", "src/ReplicatedStorage/Shared/Config.lua"], ["SRC_LOGIC", "src/ReplicatedStorage/Shared/Logic.lua"]]) {
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(root, file), "utf8")));
  lua.lua_setglobal(L, to_luastring(name));
}
let exitCode = 0;
for (const file of ["logic_test.lua", "fluxos_test.lua"]) {
  const code = fs.readFileSync(path.join(__dirname, file), "utf8");
  const status = lauxlib.luaL_dostring(L, to_luastring(code));
  if (status !== lua.LUA_OK) {
    console.log("ERRO em " + file + ": " + lua.lua_tojsstring(L, -1));
    exitCode = 1;
  }
}
process.exit(exitCode);
