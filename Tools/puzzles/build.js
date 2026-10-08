// Karazhan Chess - builds the KarazhanChess_Puzzles data addon from the Lichess
// puzzle database (https://database.lichess.org/#puzzles, CC0).
//
//   node puzzles/build.js <lichess_db_puzzle.csv.zst> [--per-tier 50000] [--seed 20261008] [--threads N] [--out dir]
//
// --out writes somewhere other than KarazhanChess_Puzzles/ (for trial runs).
//
// 1. Streams the CSV and keeps puzzles passing each tier's filters.
// 2. Keeps every puzzle already shipped (IDs read from the current data files),
//    wherever its rating now puts it, so the set only ever grows and saved
//    progress (keyed by puzzle ID) stays valid. Shipped puzzles that Lichess has
//    since removed are dropped.
// 3. Tops each tier up to --per-tier with new puzzles, spread evenly across
//    50-point rating buckets, chosen with a seeded shuffle (repeatable).
// 4. Encodes each puzzle (format in KarazhanChess/PuzzleCodec.lua) and checks it
//    with the addon's own Lua (Tools/puzzles/validate.lua under fengari, on
//    --threads worker threads, default one per core less one): it must decode
//    back to the source and every move must be legal. Failures are skipped. The
//    selection doesn't depend on the thread count.
// 5. Writes one Lua file per tier plus Themes.lua into KarazhanChess_Puzzles/.
//
// To grow the database later, raise --per-tier (or loosen a tier's filters) and
// run again: existing puzzles stay, new ones are added.
const fs = require("fs");
const path = require("path");
const { readPuzzles, TIERS, tierOf } = require("./csv");
const os = require("os");
const { Worker } = require("worker_threads");
const { ADDON_ROOT } = require("../luastate");

// Filters per tier: Popularity >= pop, NbPlays >= plays, RatingDeviation <= rd.
// Chosen from puzzles/stats.js counts (October 2026 database): Cutting Edge has
// the fewest candidates, so its filters are the loosest.
const FILTERS = {
  RaidFinder: { pop: 95, plays: 1000, rd: 80 },
  Normal: { pop: 95, plays: 1000, rd: 80 },
  Heroic: { pop: 95, plays: 1000, rd: 80 },
  Mythic: { pop: 90, plays: 1000, rd: 80 },
  CuttingEdge: { pop: 90, plays: 300, rd: 90 },
};

const BUCKET = 50;        // rating bucket width for even sampling
const CHUNK_SIZE = 500;   // records per Lua string

// Arguments
const argv = process.argv.slice(2);
const csvFile = argv.find((a, i) => !a.startsWith("--") && !(i > 0 && argv[i - 1].startsWith("--")));
const option = (name, fallback) => {
  const i = argv.indexOf("--" + name);
  return i >= 0 ? Number(argv[i + 1]) : fallback;
};
const PER_TIER = option("per-tier", 50000);
const SEED = option("seed", 20261008);
const THREADS = option("threads", Math.max(1, os.availableParallelism() - 1));
const outIndex = argv.indexOf("--out");
const OUT_DIR = outIndex >= 0 ? path.resolve(argv[outIndex + 1]) : path.join(ADDON_ROOT, "KarazhanChess_Puzzles");
if (!csvFile) {
  console.error("usage: node puzzles/build.js <lichess_db_puzzle.csv.zst> [--per-tier N] [--seed N]");
  process.exit(2);
}

// Seeded random numbers (mulberry32), so the same inputs give the same selection
function random(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = random(SEED);
function shuffle(list) {
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
}

// Encoding (must match PuzzleCodec.lua) -------------------------------------

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const PIECES = "PNBRQKpnbrqk";
const PROMOTIONS = "qrbn";
const square = name => (name.charCodeAt(1) - 49) * 8 + (name.charCodeAt(0) - 97); // a1 = 0

function encode(row, themeIndex) {
  const bits = [];
  const put = (value, n) => {
    if (value < 0 || value >= 2 ** n) throw new Error(`${row.PuzzleId}: ${value} doesn't fit in ${n} bits`);
    for (let i = n - 1; i >= 0; i--) bits.push((value >> i) & 1);
  };

  const [placement, turn, castling, ep] = row.FEN.split(" ");
  put(row.Rating, 12);
  put(turn === "b" ? 1 : 0, 1);
  for (const right of "KQkq") put(castling.includes(right) ? 1 : 0, 1);
  if (ep === "-") {
    put(0, 1);
  } else {
    put(1, 1);
    put(ep.charCodeAt(0) - 97, 3);
  }

  const board = new Array(64).fill(null);
  placement.split("/").forEach((rank, i) => {
    let col = 0;
    for (const ch of rank) {
      if (/\d/.test(ch)) col += Number(ch);
      else board[(7 - i) * 8 + col++] = ch;
    }
  });
  for (const p of board) put(p ? 1 : 0, 1);
  for (const p of board) if (p) put(PIECES.indexOf(p), 4);

  const moves = row.Moves.split(" ");
  put(moves.length, 6);
  for (const m of moves) {
    put(square(m.slice(0, 2)), 6);
    put(square(m.slice(2, 4)), 6);
    if (m.length === 5) {
      put(1, 1);
      put(PROMOTIONS.indexOf(m[4]), 2);
    } else {
      put(0, 1);
    }
  }

  const themes = row.Themes.split(" ").filter(Boolean);
  put(themes.length, 4);
  for (const t of themes) put(themeIndex.get(t), 7);

  while (bits.length % 6) bits.push(0);
  let text = row.PuzzleId;
  for (let i = 0; i < bits.length; i += 6) {
    let v = 0;
    for (let k = 0; k < 6; k++) v = v * 2 + bits[i + k];
    text += ALPHABET[v];
  }
  return text;
}

// Existing data ---------------------------------------------------------------

// IDs of puzzles in the current data files: each record starts with its ID
function readShippedIds() {
  const ids = new Set();
  if (!fs.existsSync(OUT_DIR)) return ids;
  for (const tier of TIERS) {
    const file = path.join(OUT_DIR, tier.key + ".lua");
    if (!fs.existsSync(file)) continue;
    for (const [, chunk] of fs.readFileSync(file, "utf8").matchAll(/^\t\t"([^"]*)",$/gm)) {
      for (const record of chunk.split(" ")) ids.add(record.slice(0, 5));
    }
  }
  return ids;
}

// Output --------------------------------------------------------------------

const HEADER = (purpose) => `-------------------------------------------------------------------------------
-- Karazhan Chess Puzzles
-- Generated by Tools/puzzles/build.js - do not edit by hand.
--
-- ${purpose}
-- Puzzles from the Lichess puzzle database (https://database.lichess.org/#puzzles),
-- released under CC0. Format: see KarazhanChess/PuzzleCodec.lua.
-------------------------------------------------------------------------------

local KC = LibStub("AceAddon-3.0"):GetAddon("KarazhanChess")
`;

function luaString(s) {
  if (/["\\\n]/.test(s)) throw new Error("unsafe string");
  return `"${s}"`;
}

function writeTier(tier, records) {
  const chunks = [];
  for (let i = 0; i < records.length; i += CHUNK_SIZE) {
    chunks.push(records.slice(i, i + CHUNK_SIZE).join(" "));
  }
  const lua = HEADER(`${tier.name} tier: ${records.length} puzzles rated ${tier.min}${tier.max > 9000 ? "+" : "-" + tier.max}.`) + `
KC:RegisterPuzzles("${tier.key}", {
	name = "${tier.name}",
	count = ${records.length},
	chunkSize = ${CHUNK_SIZE},
	chunks = {
${chunks.map(c => `\t\t${luaString(c)},`).join("\n")}
	},
})
`;
  fs.writeFileSync(path.join(OUT_DIR, tier.key + ".lua"), lua);
}

function writeThemes(themes) {
  const lua = HEADER("Theme names, indexed by the codes in the puzzle records (code 0 is the first).") + `
KC:RegisterPuzzleThemes({
${themes.map(t => `\t"${t}",`).join("\n")}
})
`;
  fs.writeFileSync(path.join(OUT_DIR, "Themes.lua"), lua);
}

// Main ----------------------------------------------------------------------

async function main() {
  const shipped = readShippedIds();
  console.log(`${shipped.size} puzzles already shipped`);

  // Candidates per tier, bucketed by rating; shipped puzzles found in the CSV
  const candidates = TIERS.map(() => new Map());
  const kept = TIERS.map(() => []);
  const allThemes = new Set();
  let total = 0;
  await readPuzzles(csvFile, row => {
    total++;
    const t = tierOf(row.Rating);
    const slim = { PuzzleId: row.PuzzleId, FEN: row.FEN, Moves: row.Moves, Rating: row.Rating, Themes: row.Themes };
    if (shipped.has(row.PuzzleId)) {
      kept[t].push(slim);
      return;
    }
    const f = FILTERS[TIERS[t].key];
    if (row.Popularity >= f.pop && row.NbPlays >= f.plays && row.RatingDeviation <= f.rd) {
      const bucket = Math.floor(row.Rating / BUCKET);
      if (!candidates[t].has(bucket)) candidates[t].set(bucket, []);
      candidates[t].get(bucket).push(slim);
    }
  });
  console.log(`${total} puzzles read`);
  const keptCount = kept.reduce((n, k) => n + k.length, 0);
  if (keptCount < shipped.size) console.log(`${shipped.size - keptCount} shipped puzzles are no longer in the database and are dropped`);

  // Choose new puzzles first, so the theme list covers everything that ships
  const chosen = TIERS.map((tier, t) => {
    const need = Math.max(0, PER_TIER - kept[t].length);
    const buckets = [...candidates[t].keys()].sort((a, b) => a - b).map(b => shuffle(candidates[t].get(b)));
    const available = buckets.reduce((n, b) => n + b.length, 0);
    if (available < need) console.warn(`WARNING: ${tier.name} has only ${available} candidates for ${need} places`);

    // Even split across buckets: the smallest buckets give all they have and
    // the rest is shared between the larger ones
    const quota = new Map();
    let remaining = Math.min(need, available);
    const order = buckets.map((b, i) => i).sort((a, b) => buckets[a].length - buckets[b].length);
    order.forEach((i, n) => {
      const share = Math.ceil(remaining / (order.length - n));
      const take = Math.min(buckets[i].length, share);
      quota.set(i, take);
      remaining -= take;
    });
    return { buckets, quota, need };
  });
  for (const k of kept) for (const row of k) row.Themes.split(" ").filter(Boolean).forEach(x => allThemes.add(x));
  for (const c of chosen) for (const b of c.buckets) for (const row of b) row.Themes.split(" ").filter(Boolean).forEach(x => allThemes.add(x));
  const themes = [...allThemes].sort();
  if (themes.length > 128) throw new Error("too many themes for 7 bits");
  const themeIndex = new Map(themes.map((t, i) => [t, i]));

  // Validation in Lua (the addon's own decoder and rules engine), spread over
  // worker threads, each with its own Lua state
  const pool = createPool(THREADS, themes.join(" "));
  await pool.ready;
  console.log(`validating on ${THREADS} threads`);

  const failures = {};
  // Encodes and validates rows; returns { rating, id, record } or null per row, in order
  async function checkAll(rows) {
    const jobs = rows.map(row => ({
      record: encode(row, themeIndex),
      fen: row.FEN,
      moves: row.Moves,
      themes: row.Themes.split(" ").filter(Boolean).join(" "),
    }));
    const results = await pool.validate(jobs);
    return results.map((result, i) => {
      const row = rows[i];
      if (result !== "ok") {
        const reason = result.split(":")[0];
        failures[reason] = (failures[reason] || 0) + 1;
        if (failures[reason] <= 3) console.warn(`  ${row.PuzzleId} rejected: ${result}`);
        return null;
      }
      return { rating: row.Rating, id: row.PuzzleId, record: jobs[i].record };
    });
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  writeThemes(themes);

  const started = Date.now();
  let size = 0;
  for (let t = 0; t < TIERS.length; t++) {
    const tier = TIERS[t];
    const out = (await checkAll(kept[t])).filter(Boolean);

    // Each bucket gives the first `quota` puzzles of its shuffled list that pass
    // validation. Rounds validate just enough rows to cover what is still
    // missing, so the result is the same as checking one row at a time.
    const { buckets, quota, need } = chosen[t];
    const want = buckets.map((b, i) => quota.get(i));
    const next = buckets.map(() => 0); // index of the next unchecked row per bucket
    let added = 0;
    for (;;) {
      const batch = [], owners = [];
      buckets.forEach((bucket, i) => {
        const rows = bucket.slice(next[i], next[i] + want[i]);
        next[i] += rows.length;
        for (const row of rows) { batch.push(row); owners.push(i); }
      });
      if (batch.length === 0) break;
      const results = await checkAll(batch);
      results.forEach((r, k) => {
        if (r) { out.push(r); want[owners[k]]--; added++; }
      });
    }

    // Rows no bucket needed fill any shortfall left by rejected puzzles
    const leftovers = shuffle(buckets.flatMap((bucket, i) => bucket.slice(next[i])));
    let from = 0;
    while (added < need && from < leftovers.length) {
      const rows = leftovers.slice(from, from + (need - added));
      from += rows.length;
      for (const r of await checkAll(rows)) {
        if (r) { out.push(r); added++; }
      }
    }

    out.sort((a, b) => a.rating - b.rating || (a.id < b.id ? -1 : 1));
    writeTier(tier, out.map(r => r.record));
    size += fs.statSync(path.join(OUT_DIR, tier.key + ".lua")).size;
    const ratings = out.map(r => r.rating);
    console.log(`${tier.name.padEnd(12)} ${String(out.length).padStart(6)} puzzles (${kept[t].length} kept, ${added} new), ratings ${Math.min(...ratings)}-${Math.max(...ratings)}, ${((Date.now() - started) / 1000).toFixed(0)}s`);
  }
  await pool.close();

  console.log(`${themes.length} themes; data ${(size / 1048576).toFixed(1)} MB`);
  if (Object.keys(failures).length) console.log("rejected:", failures);
}

// Worker pool -------------------------------------------------------------------

// threads workers running validator-worker.js. validate(jobs) splits the jobs
// into batches, hands them to whichever worker is free and returns the results
// in the original order.
function createPool(threads, themes) {
  const workers = [];
  const idle = [];
  const waiting = [];   // batches queued for a free worker
  let nextId = 0;
  const callbacks = new Map();

  function send(worker, msg) {
    return new Promise((resolve, reject) => {
      const id = nextId++;
      callbacks.set(id, { resolve, reject });
      worker.postMessage({ id, ...msg });
    });
  }
  function release(worker) {
    const job = waiting.shift();
    if (job) run(worker, job); else idle.push(worker);
  }
  function run(worker, job) {
    send(worker, { jobs: job.jobs }).then(msg => {
      job.resolve(msg.results);
      release(worker);
    }, job.reject);
  }

  for (let i = 0; i < threads; i++) {
    const worker = new Worker(path.join(__dirname, "validator-worker.js"));
    worker.on("message", msg => {
      const cb = callbacks.get(msg.id);
      callbacks.delete(msg.id);
      cb.resolve(msg);
    });
    worker.on("error", e => { for (const cb of callbacks.values()) cb.reject(e); });
    workers.push(worker);
  }
  const ready = Promise.all(workers.map(w => send(w, { themes }))).then(() => idle.push(...workers));

  async function validate(jobs) {
    // Small enough that every worker gets a share, large enough to keep messages few
    const BATCH = Math.max(1, Math.min(250, Math.ceil(jobs.length / threads)));
    const parts = [];
    for (let i = 0; i < jobs.length; i += BATCH) {
      const part = jobs.slice(i, i + BATCH);
      parts.push(new Promise((resolve, reject) => {
        const job = { jobs: part, resolve, reject };
        const worker = idle.pop();
        if (worker) run(worker, job); else waiting.push(job);
      }));
    }
    return (await Promise.all(parts)).flat();
  }

  return { ready, validate, close: () => Promise.all(workers.map(w => w.terminate())) };
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
