// Karazhan Chess - streams rows out of the Lichess puzzle database
// (lichess_db_puzzle.csv.zst, https://database.lichess.org/#puzzles) without
// unpacking it to disk. Calls onRow(row) with an object per puzzle.
const fs = require("fs");
const { Decompress } = require("fzstd");

const COLUMNS = ["PuzzleId", "FEN", "Moves", "Rating", "RatingDeviation", "Popularity", "NbPlays", "Themes", "GameUrl", "OpeningTags"];

function readPuzzles(file, onRow) {
  return new Promise((resolve, reject) => {
    const decoder = new TextDecoder();
    let pending = "", header = true;

    function lines(text) {
      pending += text;
      let nl;
      while ((nl = pending.indexOf("\n")) >= 0) {
        const line = pending.slice(0, nl).replace(/\r$/, "");
        pending = pending.slice(nl + 1);
        if (header) { header = false; continue; }
        if (!line) continue;
        // No field contains a comma, so a plain split is safe
        const f = line.split(",");
        const row = {};
        COLUMNS.forEach((c, i) => { row[c] = f[i]; });
        row.Rating = +row.Rating; row.RatingDeviation = +row.RatingDeviation;
        row.Popularity = +row.Popularity; row.NbPlays = +row.NbPlays;
        onRow(row);
      }
    }

    const stream = new Decompress((chunk, final) => {
      lines(decoder.decode(chunk, { stream: !final }));
      if (final) { if (pending) lines("\n"); resolve(); }
    });
    fs.createReadStream(file, { highWaterMark: 1 << 20 })
      .on("data", buf => stream.push(new Uint8Array(buf.buffer, buf.byteOffset, buf.length)))
      .on("end", () => stream.push(new Uint8Array(0), true))
      .on("error", reject);
  });
}

// Lichess rating bands under raid difficulty names
const TIERS = [
  { key: "RaidFinder", name: "Raid Finder", min: 0, max: 1199 },
  { key: "Normal", name: "Normal", min: 1200, max: 1599 },
  { key: "Heroic", name: "Heroic", min: 1600, max: 1999 },
  { key: "Mythic", name: "Mythic", min: 2000, max: 2399 },
  { key: "CuttingEdge", name: "Cutting Edge", min: 2400, max: 99999 },
];
const tierOf = rating => TIERS.findIndex(t => rating >= t.min && rating <= t.max);

module.exports = { readPuzzles, TIERS, tierOf };
