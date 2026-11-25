// Copies the game into www/ for the phone app.
// Since build 1 of the friends game (2026-11-25), the app runs friends/index.html. Blip Classic stays on branch
// blip-classic and the website (../index.html on main) is unchanged.
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', '..'), www = path.join(__dirname, '..', 'www');
fs.rmSync(www, {recursive: true, force: true});
fs.mkdirSync(www, {recursive: true});
fs.copyFileSync(path.join(root, 'friends', 'index.html'), path.join(www, 'index.html'));
fs.copyFileSync(path.join(root, 'friends', 'config.js'), path.join(www, 'config.js'));
for (const f of ['icon.png', 'manifest.json']) fs.copyFileSync(path.join(root, f), path.join(www, f));
console.log('Copied the friends game into app/www');
