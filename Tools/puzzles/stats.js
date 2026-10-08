// Karazhan Chess - counts puzzles per tier under candidate filter thresholds,
// to choose the builder's filters. Run: node puzzles/stats.js <csv.zst>
const { readPuzzles, TIERS, tierOf } = require("./csv");

const POP = [80, 85, 90, 95], PLAYS = [100, 300, 1000], RD = [75, 80, 90];
const counts = {};
let total = 0;
readPuzzles(process.argv[2], row => {
  total++;
  const t = tierOf(row.Rating);
  for (const p of POP) for (const n of PLAYS) for (const r of RD) {
    if (row.Popularity >= p && row.NbPlays >= n && row.RatingDeviation <= r) {
      const k = `${p}/${n}/${r}`;
      (counts[k] = counts[k] || [0, 0, 0, 0, 0])[t]++;
    }
  }
}).then(() => {
  console.log(`${total} puzzles. Popularity>=/NbPlays>=/RD<= : ${TIERS.map(t => t.key).join(" ")}`);
  for (const [k, v] of Object.entries(counts)) console.log(k.padEnd(12), v.map(x => String(x).padStart(8)).join(""));
});
