// Karazhan Chess - puzzle validation worker for build.js. Each worker has its own
// fengari Lua state running validate.lua (the addon's own decoder and rules).
// Receives { id, themes } once, then { id, jobs: [{ record, fen, moves, themes }] }
// and answers { id, results: ["ok" | reason, ...] } in the same order.
const path = require("path");
const { parentPort } = require("worker_threads");
const { createState, doFile, call } = require("../luastate");

const L = createState();
doFile(L, path.join(__dirname, "validate.lua"));

parentPort.on("message", msg => {
  if (msg.themes !== undefined) {
    call(L, "setThemes", msg.themes);
    parentPort.postMessage({ id: msg.id });
    return;
  }
  const results = msg.jobs.map(j => call(L, "validate", j.record, j.fen, j.moves, j.themes));
  parentPort.postMessage({ id: msg.id, results });
});
