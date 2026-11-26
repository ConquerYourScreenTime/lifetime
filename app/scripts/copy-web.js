// Copies the game into www/ for the phone app.
// Since build 1 of the friends game (2026-11-25), the app runs friends/index.html. Blip Classic stays on branch
// blip-classic and the website (../index.html on main) is unchanged.
// Build 4 (Conquer) adds the bundled Playfair Display font, the win chime and the wax seal picture for notifications.
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', '..'), www = path.join(__dirname, '..', 'www');
fs.rmSync(www, {recursive: true, force: true});
fs.mkdirSync(www, {recursive: true});
for (const f of ['index.html', 'config.js', 'chime.wav', 'seal.png']) fs.copyFileSync(path.join(root, 'friends', f), path.join(www, f));
fs.cpSync(path.join(root, 'friends', 'fonts'), path.join(www, 'fonts'), {recursive: true});
for (const f of ['icon.png', 'manifest.json']) fs.copyFileSync(path.join(root, f), path.join(www, f));
console.log('Copied the friends game into app/www');
