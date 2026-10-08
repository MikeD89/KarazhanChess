// Karazhan Chess - writes uncompressed BLP2 textures (BGRA8888 with mipmaps),
// the same format as Textures/legalmove.blp, so generated art needs no converter.
const fs = require("fs");

// rgba: Uint8Array of width*height*4 (RGBA). width and height must be powers of two.
function writeBLP(file, width, height, rgba) {
  const mips = [];
  let w = width, h = height, data = Buffer.from(rgba);
  for (;;) {
    mips.push(data);
    if (w === 1 && h === 1) break;
    const nw = Math.max(1, w >> 1), nh = Math.max(1, h >> 1), next = Buffer.alloc(nw * nh * 4);
    for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) for (let k = 0; k < 4; k++) {
      let sum = 0, n = 0;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const sx = Math.min(w - 1, x * 2 + dx), sy = Math.min(h - 1, y * 2 + dy);
        sum += data[(sy * w + sx) * 4 + k]; n++;
      }
      next[(y * nw + x) * 4 + k] = Math.round(sum / n);
    }
    w = nw; h = nh; data = next;
  }
  if (mips.length > 16) throw new Error("too many mip levels");

  const header = Buffer.alloc(148 + 1024);
  header.write("BLP2", 0);
  header.writeUInt32LE(1, 4);   // type: BLP2
  header[8] = 3;                // encoding: uncompressed ARGB
  header[9] = 8;                // alpha depth
  header[10] = 8;               // alpha encoding (unused for uncompressed)
  header[11] = 1;               // has mipmaps
  header.writeUInt32LE(width, 12);
  header.writeUInt32LE(height, 16);
  let offset = header.length;
  const bodies = mips.map((m, i) => {
    const bgra = Buffer.alloc(m.length);
    for (let p = 0; p < m.length; p += 4) {
      bgra[p] = m[p + 2]; bgra[p + 1] = m[p + 1]; bgra[p + 2] = m[p]; bgra[p + 3] = m[p + 3];
    }
    header.writeUInt32LE(offset, 20 + i * 4);
    header.writeUInt32LE(bgra.length, 84 + i * 4);
    offset += bgra.length;
    return bgra;
  });
  fs.writeFileSync(file, Buffer.concat([header, ...bodies]));
}

module.exports = { writeBLP };
