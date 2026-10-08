// Karazhan Chess - generates Textures/check.blp, the red glow under a king in check.
// Same gradient as Lichess (chessground CSS):
//   radial-gradient(ellipse at center, #f00 0%, #e70000 25%, rgba(169,0,0,0) 89%, rgba(158,0,0,0) 100%)
// "ellipse at center" on a square is a circle reaching the farthest corner.
// Run: node textures/check.js
const path = require("path");
const { writeBLP } = require("../blp");

const N = 128, R = Math.SQRT2 * N / 2;
const stops = [[0, 255, 0, 0, 1], [0.25, 231, 0, 0, 1], [0.89, 169, 0, 0, 0], [1, 158, 0, 0, 0]];

function colourAt(t) {
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) {
      const a = stops[i - 1], b = stops[i], f = (t - a[0]) / (b[0] - a[0]);
      return a.slice(1).map((v, k) => v + (b[k + 1] - v) * f);
    }
  }
  return stops[stops.length - 1].slice(1);
}

const rgba = new Uint8Array(N * N * 4);
for (let y = 0; y < N; y++) {
  for (let x = 0; x < N; x++) {
    const [r, g, b, a] = colourAt(Math.hypot(x + 0.5 - N / 2, y + 0.5 - N / 2) / R);
    rgba.set([Math.round(r), Math.round(g), Math.round(b), Math.round(a * 255)], (y * N + x) * 4);
  }
}
writeBLP(path.join(__dirname, "..", "..", "Textures", "check.blp"), N, N, rgba);
