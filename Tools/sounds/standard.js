// Downloads Lichess's "standard" sound set into Sounds/Standard.
//
// Lichess lists these sounds as non-free (COPYING.md, "The other sounds in
// public/sound"); permission to redistribute them has been requested (see
// Textures/CREDITS.md). Run from Tools/: node sounds/standard.js

const fs = require("fs");
const path = require("path");

const BASE = "https://raw.githubusercontent.com/lichess-org/lila/master/public/sound/standard/";
// Victory, Defeat and Draw are symlinks to GenericNotify in Lichess's repo.
// Check is a link to Silence (Lichess plays only the move or capture sound),
// so the theme has no Check file (Sounds.NoCheck in Sounds.lua).
const FILES = {
	Move: "Move",
	Capture: "Capture",
	Victory: "GenericNotify",
	Defeat: "GenericNotify",
	Draw: "GenericNotify",
};
const OUT = path.join(__dirname, "..", "..", "Sounds", "Standard");

(async () => {
	fs.mkdirSync(OUT, { recursive: true });
	for (const [name, source] of Object.entries(FILES)) {
		const res = await fetch(BASE + source + ".ogg");
		if (!res.ok) {
			throw new Error(source + ".ogg: HTTP " + res.status);
		}
		const data = Buffer.from(await res.arrayBuffer());
		if (data.length < 1000 || data.toString("latin1", 0, 4) !== "OggS") {
			throw new Error(source + ".ogg is not an Ogg file (a symlink?)");
		}
		fs.writeFileSync(path.join(OUT, name + ".ogg"), data);
		console.log(name + ".ogg", data.length, "bytes");
	}
})().catch((err) => {
	console.error(err.message);
	process.exit(1);
});
