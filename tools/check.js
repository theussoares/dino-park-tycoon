// Verificação estática: parseia todos os .lua com luaparse (Lua 5.1; o código evita sintaxe exclusiva do Luau).
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const root = path.join(__dirname, "..");
function walk(dir, acc) {
  for (const f of fs.readdirSync(dir)) {
    if (f === "node_modules" || f === ".git" || f === "assets") continue;
    const p = path.join(dir, f);
    if (fs.statSync(p).isDirectory()) walk(p, acc);
    else if (p.endsWith(".lua")) acc.push(p);
  }
  return acc;
}
let bad = 0;
const files = walk(root, []);
for (const f of files) {
  try {
    luaparse.parse(fs.readFileSync(f, "utf8"), { luaVersion: "5.1" });
    console.log("ok   " + path.relative(root, f));
  } catch (e) {
    bad++;
    console.log("FAIL " + path.relative(root, f) + ": " + e.message);
  }
}
console.log(`${files.length - bad}/${files.length} arquivos sem erro de sintaxe`);
process.exit(bad ? 1 : 0);
