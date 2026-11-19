// ============ BLIP NOMAD ART (look 1A "Living postcard", approved by Matthew 2026-11-18) ============
// All Nomad drawings live here as SVG strings: the player's Blip with a travel kit, Barcelona scenes,
// real places drawn faithfully (Sagrada Família as it stands in 2026, Montserrat, the Bunkers del Carmel,
// the Eixample, Santa Margarida crater in the Garrotxa), postcard tiles, Polaroid photos, the passport stamp.
// Art rules: mitten hands only, no phones or screens, no real people, no hearts for friends, no $ signs.
// nomad.js calls window.NART.*; this file has no game logic.
(function(){
const O = '#3b2a4a';
const W = 'stroke="'+O+'" stroke-width="4" stroke-linejoin="round"';
const T = (x, y, t, sz, f, extra) => '<text x="'+x+'" y="'+y+'" font-family="'+(f || 'Fredoka')+',sans-serif" font-size="'+sz+'" '+(extra || '')+'>'+t+'</text>';
let uid = 0;

// ---------- the player's Blip, 18, with a travel kit ----------
// o: skin, hair, girl, wave, hat, pack_on, shirt, pants, boots, bun (Laia), walk
function blip(o){
  o = Object.assign({skin:'#f2c27b', hair:'#6b3f1f', shirt:'#1fa3a8', pants:'#c9a66b', pack:'#e2603f', hat:true, pack_on:true, wave:false, walk:false, boots:'#7a4a2a'}, o);
  let s = '';
  const bodyY = 118, bodyH = 66, legTop = bodyY + bodyH - 8, legH = 40, shoeY = legTop + legH + 2;
  if (o.pack_on) s += '<rect x="56" y="'+(bodyY-10)+'" width="88" height="'+(bodyH+12)+'" rx="22" fill="'+o.pack+'" '+W+'/>'+
    '<rect x="62" y="'+(bodyY-30)+'" width="76" height="24" rx="12" fill="#5b8c4a" '+W+'/><path d="M72 '+(bodyY-30)+' v24 M128 '+(bodyY-30)+' v24" stroke="'+O+'" stroke-width="3"/>';
  const lx = o.walk ? [78,107] : [80,105], sx = o.walk ? [80,120] : [86,114];
  s += '<rect x="'+lx[0]+'" y="'+legTop+'" width="15" height="'+legH+'" rx="7" fill="'+o.pants+'" '+W+(o.walk ? ' transform="rotate(10 '+(lx[0]+7)+' '+legTop+')"' : '')+'/>';
  s += '<rect x="'+lx[1]+'" y="'+legTop+'" width="15" height="'+legH+'" rx="7" fill="'+o.pants+'" '+W+(o.walk ? ' transform="rotate(-10 '+(lx[1]+7)+' '+legTop+')"' : '')+'/>';
  s += '<ellipse cx="'+sx[0]+'" cy="'+shoeY+'" rx="14" ry="8" fill="'+o.boots+'" '+W+'/><ellipse cx="'+sx[1]+'" cy="'+shoeY+'" rx="14" ry="8" fill="'+o.boots+'" '+W+'/>';
  const ay = bodyY + 10, ra = o.wave ? -130 : -16;
  s += '<rect x="56" y="'+ay+'" width="16" height="44" rx="8" fill="'+o.shirt+'" '+W+' transform="rotate(16 72 '+ay+')"/><ellipse cx="58" cy="'+(ay+44)+'" rx="10" ry="9" fill="'+o.skin+'" '+W+'/>';
  s += '<g class="'+(o.wave ? 'nwave' : '')+'" style="transform-origin:128px '+ay+'px"><g transform="rotate('+ra+' 128 '+ay+')"><rect x="128" y="'+ay+'" width="16" height="44" rx="8" fill="'+o.shirt+'" '+W+'/><ellipse cx="136" cy="'+(ay+46)+'" rx="10" ry="9" fill="'+o.skin+'" '+W+'/></g></g>';
  s += '<rect x="68" y="'+bodyY+'" width="64" height="'+bodyH+'" rx="24" fill="'+o.shirt+'" '+W+'/>';
  if (o.pack_on) s += '<path d="M76 '+(bodyY+2)+' L80 '+(bodyY+bodyH-6)+' M124 '+(bodyY+2)+' L120 '+(bodyY+bodyH-6)+'" stroke="#8a3a22" stroke-width="7" stroke-linecap="round"/><path d="M79 '+(bodyY+30)+' H121" stroke="#8a3a22" stroke-width="4"/>';
  if (o.bun) s += '<circle cx="100" cy="28" r="18" fill="'+o.hair+'" '+W+'/>';
  const longHair = o.bun || o.girl;
  if (o.girl && !o.hat) s += '';
  s += '<circle cx="100" cy="82" r="48" fill="'+o.skin+'" '+W+'/>';
  s += longHair ? '<path d="M52 88 Q46 30 100 30 Q154 30 148 88 Q146 64 134 54 Q112 66 80 52 Q64 62 52 88Z" fill="'+o.hair+'" '+W+'/>'
               : '<path d="M52 86 Q48 30 100 30 Q152 30 148 86 Q140 60 124 56 Q116 68 98 60 Q82 70 70 58 Q58 66 52 86Z" fill="'+o.hair+'" '+W+'/>';
  if (o.girl) s += '<path d="M52 80 Q42 120 58 136 Q60 112 62 96Z M148 80 Q158 120 142 136 Q140 112 138 96Z" fill="'+o.hair+'" '+W+'/>';
  if (o.hat) s += '<path d="M62 54 Q64 22 100 22 Q136 22 138 54Z" fill="#f2d16b" '+W+'/><path d="M64 46 Q100 38 136 46" stroke="#e2603f" stroke-width="7" fill="none"/><ellipse cx="100" cy="56" rx="58" ry="11" fill="#f2d16b" '+W+'/>';
  s += '<g class="nblink" style="transform-origin:100px 92px">';
  for (const x of [82,118]) s += '<ellipse cx="'+x+'" cy="92" rx="8" ry="10" fill="#2b1d3a"/><circle cx="'+(x-3)+'" cy="88" r="3.2" fill="#fff"/><circle cx="'+(x+3)+'" cy="96" r="1.6" fill="#fff"/>';
  s += '</g>';
  if (o.girl || o.bun) s += '<path d="M74 88 l-5 -3 M75 84 l-3 -5 M126 88 l5 -3 M125 84 l3 -5" stroke="'+O+'" stroke-width="2.5" stroke-linecap="round"/>';
  s += '<ellipse cx="70" cy="106" rx="8" ry="5" fill="#ff8fa3" opacity=".6"/><ellipse cx="130" cy="106" rx="8" ry="5" fill="#ff8fa3" opacity=".6"/>';
  s += '<path d="M90 106 Q100 120 110 106 Z" fill="#a33a4f" stroke="'+O+'" stroke-width="2.5" stroke-linejoin="round"/>';
  return s;
}
// Blip standing with feet at (x, y), h tall, inside another SVG
const blipAt = (x, y, h, o, cls) => '<svg x="'+(x-h*100/240)+'" y="'+(y-h)+'" width="'+(h*200/240)+'" height="'+h+'" viewBox="0 0 200 240" overflow="visible"'+(cls ? ' class="'+cls+'"' : '')+'>'+blip(o || {})+'</svg>';
const blipSVG = (o, w) => '<svg viewBox="0 0 200 240" overflow="visible"'+(w ? ' width="'+w+'"' : '')+' class="nbob">'+blip(o || {})+'</svg>';

// Laia, an invented friend who runs the hostel. Waves like a friend. No hearts.
const LAIA = {hair:'#2b1d1a', skin:'#c98d5f', shirt:'#f2b632', pants:'#3f5d8a', boots:'#ffffff', hat:false, pack_on:false, bun:true};

// ---------- small shared bits ----------
// A plain gold coin with a star (the currency is "Coins" for now; never a $ sign)
function coinAt(x, y, r){
  let p = ''; for (let k = 0; k < 10; k++) { const a = k*Math.PI/5 - Math.PI/2, rr = k%2 ? r*.25 : r*.55; p += (k ? 'L' : 'M')+(x+rr*Math.cos(a)).toFixed(1)+' '+(y+rr*Math.sin(a)).toFixed(1); }
  return '<circle cx="'+x+'" cy="'+y+'" r="'+r+'" fill="#ffc84a" stroke="'+O+'" stroke-width="'+Math.max(1.5, r/5)+'"/><circle cx="'+x+'" cy="'+y+'" r="'+(r*.74)+'" fill="none" stroke="#e0a21f" stroke-width="'+Math.max(1, r/9)+'"/><path d="'+p+'Z" fill="#fff6c8"/>';
}
const coin = (sz) => '<svg class="ncoin" viewBox="0 0 24 24" width="'+(sz || 20)+'" height="'+(sz || 20)+'" aria-hidden="true">'+coinAt(12, 12, 10.5)+'</svg>';
const palm = (x, y, s) => '<g transform="translate('+x+' '+y+') scale('+s+')"><path d="M0 0 Q-4 -40 4 -78" stroke="#7a4a2a" stroke-width="7" fill="none" stroke-linecap="round"/><g fill="#3e9b5b" stroke="'+O+'" stroke-width="2.5" stroke-linejoin="round"><path d="M4 -78 Q-26 -92 -40 -70 Q-18 -80 4 -78Z"/><path d="M4 -78 Q34 -94 48 -70 Q26 -82 4 -78Z"/><path d="M4 -78 Q-14 -104 -28 -100 Q-6 -96 4 -78Z"/><path d="M4 -78 Q24 -106 38 -98 Q16 -96 4 -78Z"/></g></g>';
// Barcelona's flower-pattern pavement tile (the "panot")
const panot = id => '<pattern id="'+id+'" width="28" height="28" patternUnits="userSpaceOnUse"><rect width="28" height="28" fill="#cfc2ae"/><circle cx="14" cy="14" r="6" fill="none" stroke="#b5a68f" stroke-width="2.5"/><circle cx="0" cy="0" r="5" fill="#b5a68f"/><circle cx="28" cy="0" r="5" fill="#b5a68f"/><circle cx="0" cy="28" r="5" fill="#b5a68f"/><circle cx="28" cy="28" r="5" fill="#b5a68f"/></pattern>';

function sagradaFull(x, y, s, opt){
  opt = opt || {};
  const sw = (opt.sw || 1.6) / 1;            // outline width in local units
  const OL = 'stroke="'+O+'" stroke-width="'+sw+'" stroke-linejoin="round"';
  const stone = '#d9b98a', stoneD = '#b8925f', nat = '#c49a62', natD = '#8f6a3e', white = '#efe9dd', ribs = '#c9c1b2';
  let g = '<g transform="translate('+x+' '+y+') scale('+s+')">';

  // tower crane on the right, behind everything
  if (opt.crane !== false) {
    g += '<g opacity=".55"><g stroke="'+O+'" stroke-width="'+(sw*.7)+'" fill="none"><path d="M112 0 V-262 M118 0 V-262"/>';
    for (let k = 0; k < 13; k++) g += '<path d="M112 '+(-k*20)+' L118 '+(-k*20-20)+'"/>';
    g += '<path d="M90 -262 H190 M90 -270 H190 M115 -262 L115 -282 L90 -270 M115 -282 L190 -270"/><path d="M180 -262 V-232"/></g>'+
         '<rect x="90" y="-272" width="100" height="10" fill="#ffcf3f" opacity=".85" stroke="'+O+'" stroke-width="'+(sw*.7)+'"/><rect x="106" y="-256" width="18" height="12" fill="#ffcf3f" stroke="'+O+'" stroke-width="'+(sw*.7)+'"/></g>';
  }

  // nave and apse mass behind
  g += '<path d="M-98 -60 L-92 -98 Q-60 -112 -30 -104 L0 -118 L30 -104 Q60 -112 92 -98 L98 -60Z" fill="'+stoneD+'" '+OL+'/>';
  // pointed nave windows
  for (const wx of [-70,-48,48,70]) g += '<path d="M'+(wx-5)+' -66 V-84 Q'+wx+' -96 '+(wx+5)+' -84 V-66Z" fill="#6f5a7a" opacity=".55"/>';

  // central tower: shape of a parabolic spire with vertical ribs and a light ceramic skin
  const central = (cx, base, h, w, top) => {
    let t = '<path d="M'+(cx-w)+' '+base+' L'+(cx-w*.92)+' '+(-h*.55)+' Q'+(cx-w*.7)+' '+(-h*.9)+' '+cx+' '+(-h)+' Q'+(cx+w*.7)+' '+(-h*.9)+' '+(cx+w*.92)+' '+(-h*.55)+' L'+(cx+w)+' '+base+'Z" fill="'+stone+'" '+OL+'/>';
    // upper ceramic section (whitish, the newest parts)
    t += '<path d="M'+(cx-w*.9)+' '+(-h*.6)+' Q'+(cx-w*.7)+' '+(-h*.9)+' '+cx+' '+(-h)+' Q'+(cx+w*.7)+' '+(-h*.9)+' '+(cx+w*.9)+' '+(-h*.6)+'Z" fill="'+white+'" '+OL+'/>';
    for (let k = -2; k <= 2; k++) t += '<path d="M'+(cx+k*w*.36)+' '+(-h*.6)+' Q'+(cx+k*w*.22)+' '+(-h*.88)+' '+cx+' '+(-h*.99)+'" stroke="'+ribs+'" stroke-width="'+(sw*.8)+'" fill="none"/>';
    // rows of small windows
    for (let r = 0; r < 4; r++) { const yy = -h*.32 - r*h*.06; for (let k = -1; k <= 1; k++) t += '<rect x="'+(cx+k*w*.5-1.5)+'" y="'+yy+'" width="3" height="6" rx="1.5" fill="#6f5a7a" opacity=".6"/>'; }
    return t + top;
  };
  // Virgin Mary (right, behind), with its glowing 12-point star
  const star = (cx, cy, r) => { let p = ''; for (let k = 0; k < 24; k++) { const a = k*Math.PI/12 - Math.PI/2, rr = k%2 ? r*.55 : r; p += (k ? 'L' : 'M')+(cx+rr*Math.cos(a)).toFixed(1)+' '+(cy+rr*Math.sin(a)).toFixed(1); } return '<circle cx="'+cx+'" cy="'+cy+'" r="'+(r*1.6)+'" fill="#fff6c8" opacity=".55"/><path d="'+p+'Z" fill="#fff8e0" '+OL+'/>'; };
  g += central(70, -80, 230, 15, '<path d="M70 -230 V-238" stroke="'+O+'" stroke-width="'+sw+'"/>'+star(70, -246, 10));
  // Evangelists (two visible), each topped by its sculpted symbol
  g += central(-46, -90, 225, 15, '<circle cx="-46" cy="-231" r="7" fill="#e9d9a8" '+OL+'/><path d="M-53 -233 q7 -9 14 0" stroke="'+O+'" stroke-width="'+(sw*.7)+'" fill="none"/>');
  g += central(40, -90, 225, 15, '<circle cx="40" cy="-231" r="7" fill="#e9d9a8" '+OL+'/><path d="M33 -229 l7 -8 l7 8" stroke="'+O+'" stroke-width="'+(sw*.7)+'" fill="none"/>');
  // Jesus Christ, the tallest, with the white four-armed glass cross
  g += central(-3, -90, 280, 20, '<g fill="#ffffff" '+OL+'><rect x="-6" y="-306" width="6" height="26" rx="1"/><rect x="-16" y="-296" width="26" height="6" rx="1"/></g><rect x="-6" y="-296" width="6" height="6" fill="#d7ecff"/>');

  // bell tower: square base rising into a slender spindle full of spiral louvres, mosaic pinnacle on top
  const bell = (cx, h) => {
    const w = 9, base = -40;
    let t = '<path d="M'+(cx-w)+' '+base+' L'+(cx-w)+' '+(-h*.38)+' Q'+(cx-w*1.02)+' '+(-h*.62)+' '+(cx-w*.55)+' '+(-h*.84)+' Q'+(cx-w*.3)+' '+(-h*.9)+' '+cx+' '+(-h*.92)+' Q'+(cx+w*.3)+' '+(-h*.9)+' '+(cx+w*.55)+' '+(-h*.84)+' Q'+(cx+w*1.02)+' '+(-h*.62)+' '+(cx+w)+' '+(-h*.38)+' L'+(cx+w)+' '+base+'Z" fill="'+stone+'" '+OL+'/>';
    // spiral louvres: diagonal slits climbing the spindle
    for (let r = 0; r < 11; r++) { const yy = -h*.4 - r*h*.04, ww = w*(1 - r*.045); for (let k = -1; k <= 1; k++) t += '<path d="M'+(cx+k*ww*.55-2).toFixed(1)+' '+(yy+2).toFixed(1)+' l4 -3" stroke="'+natD+'" stroke-width="'+(sw*.9)+'" stroke-linecap="round"/>'; }
    // lettering band ("Sanctus") hint
    t += '<path d="M'+(cx-w*.8)+' '+(-h*.66)+' H'+(cx+w*.8)+'" stroke="#e9d9a8" stroke-width="'+(sw*1.6)+'"/>';
    // the Venetian-glass mosaic pinnacle: a stem, the faceted "mitre" in red, gold and white, and a cross of white balls
    const py = -h*.92;
    t += '<path d="M'+(cx-2)+' '+py+' V'+(py-6)+' H'+(cx+2)+' V'+py+'Z" fill="'+white+'" '+OL+'/>';
    t += '<path d="M'+cx+' '+(py-6)+' L'+(cx-7)+' '+(py-14)+' L'+(cx-5)+' '+(py-24)+' L'+cx+' '+(py-28)+' L'+(cx+5)+' '+(py-24)+' L'+(cx+7)+' '+(py-14)+'Z" fill="#d8392b" '+OL+'/>';
    t += '<path d="M'+cx+' '+(py-6)+' L'+(cx-3)+' '+(py-16)+' L'+cx+' '+(py-28)+' L'+(cx+3)+' '+(py-16)+'Z" fill="#f4c430"/><circle cx="'+(cx-4)+'" cy="'+(py-19)+'" r="1.6" fill="#fff"/><circle cx="'+(cx+4)+'" cy="'+(py-13)+'" r="1.6" fill="#fff"/>';
    t += '<path d="M'+cx+' '+(py-28)+' V'+(py-40)+' M'+(cx-6)+' '+(py-34)+' H'+(cx+6)+'" stroke="#d4a017" stroke-width="'+(sw*1.4)+'"/>';
    for (const [bx, by] of [[0,-40],[-6,-34],[6,-34],[0,-28]]) t += '<circle cx="'+(cx+bx)+'" cy="'+(py+by)+'" r="2.6" fill="#fff" '+OL+'/>';
    return t;
  };
  g += bell(-80, 192) + bell(80, 192) + bell(-30, 208) + bell(30, 208);

  g += '<g transform="scale(1 1.3)">';
  // the Nativity façade: three portals of sculpted stone that seems to drip and melt
  g += '<path d="M-92 0 V-46 Q-86 -52 -80 -46 Q-74 -56 -66 -48 Q-60 -58 -52 -50 Q-46 -60 -42 -52 V-66 Q-36 -74 -30 -66 Q-24 -78 -16 -70 Q-8 -86 0 -84 Q8 -86 16 -70 Q24 -78 30 -66 Q36 -74 42 -66 V-52 Q46 -60 52 -50 Q60 -58 66 -48 Q74 -56 80 -46 Q86 -52 92 -46 V0Z" fill="'+nat+'" '+OL+'/>';
  // drips and sculpted texture
  for (let k = -84; k <= 84; k += 6) g += '<path d="M'+k+' '+(-30 - (Math.abs(k)%12))+' q1.5 6 0 12" stroke="'+natD+'" stroke-width="'+(sw*.8)+'" fill="none" stroke-linecap="round"/>';
  // three pointed portals (Charity, center and tallest; Hope; Faith)
  g += '<path d="M-16 0 V-34 Q-16 -60 0 -66 Q16 -60 16 -34 V0Z" fill="#5d4636" '+OL+'/><path d="M-62 0 V-22 Q-62 -40 -52 -44 Q-42 -40 -42 -22 V0Z" fill="#5d4636" '+OL+'/><path d="M42 0 V-22 Q42 -40 52 -44 Q62 -40 62 -22 V0Z" fill="#5d4636" '+OL+'/>';
  // central door column and the green cypress (Tree of Life) with white doves, rising above the Charity portal
  g += '<path d="M0 -66 V0" stroke="'+natD+'" stroke-width="'+(sw*1.5)+'"/>';
  g += '<path d="M0 -122 Q-9 -100 -10 -84 Q-6 -78 0 -80 Q6 -78 10 -84 Q9 -100 0 -122Z" fill="#3f8a4e" '+OL+'/>';
  for (const [dx, dy] of [[-4,-96],[3,-104],[-2,-110],[5,-90],[-5,-88]]) g += '<circle cx="'+dx+'" cy="'+dy+'" r="1.6" fill="#fff"/>';
  g += '<path d="M0 -122 V-128 M-3 -126 H3" stroke="#d4a017" stroke-width="'+sw+'"/>';
  g += '</g>';
  return g + '</g>';
}
function montserrat(x, y, s){
  let g = '<g transform="translate('+x+' '+y+') scale('+s+')" stroke="'+O+'" stroke-width="2" stroke-linejoin="round">';
  // far ridge of rounded "fingers"
  const fingers = (y0, list, fill) => { let d = 'M'+list[0][0]+' '+y0; for (const [fx, fh, fw] of list) d += ' L'+(fx-fw)+' '+(y0-fh*.6)+' Q'+(fx-fw)+' '+(y0-fh)+' '+fx+' '+(y0-fh)+' Q'+(fx+fw)+' '+(y0-fh)+' '+(fx+fw)+' '+(y0-fh*.6); d += ' L'+list[list.length-1][0]+' '+y0+'Z'; return '<path d="'+d+'" fill="'+fill+'"/>'; };
  g += fingers(0, [[-70,60,8],[-56,78,8],[-42,70,7],[-30,92,8],[-16,84,7],[-2,100,8],[12,88,7],[26,96,8],[40,80,7],[54,70,8],[68,56,8]], '#d8b8ad');
  g += fingers(0, [[-64,40,9],[-46,52,9],[-28,46,9],[-10,58,9],[8,50,9],[26,56,9],[44,46,9],[62,36,9]], '#c79c90');
  // vertical grooves in the rock
  for (let k = -60; k <= 60; k += 9) g += '<path d="M'+k+' -6 V-'+(26 + (Math.abs(k*7)%22))+'" stroke="#a87b70" stroke-width="1.4"/>';
  // monastery: long block, basilica front with a rose window, red roofs
  g += '<rect x="-30" y="-30" width="46" height="16" fill="#efe2cc"/><rect x="-6" y="-38" width="16" height="24" fill="#f5ead6"/><circle cx="2" cy="-30" r="3" fill="#8fb7d6" stroke-width="1.2"/>';
  g += '<path d="M-32 -30 H18 L14 -34 H-28Z" fill="#c8553d"/>';
  for (let k = -26; k < 14; k += 6) if (k < -8 || k > 10) g += '<rect x="'+k+'" y="-25" width="3" height="5" fill="#6f5a7a" stroke="none"/>';
  // scrub
  g += '<path d="M-74 0 Q-50 -10 -30 -4 Q0 -12 30 -4 Q52 -10 74 0Z" fill="#6a9b58"/>';
  return g + '</g>';
}

// Small Eixample block grid seen from above: the city's chamfered (cut-corner) octagonal blocks.
function eixample(x, y, w, h, cell){
  let g = '<g>'; for (let i = 0; i * cell < w; i++) for (let j = 0; j * cell < h; j++) {
    const bx = x + i*cell, by = y + j*cell, c = cell*.78, k = cell*.18;
    g += '<path d="M'+(bx+k)+' '+by+' H'+(bx+c-k)+' L'+(bx+c)+' '+(by+k)+' V'+(by+c-k)+' L'+(bx+c-k)+' '+(by+c)+' H'+(bx+k)+' L'+bx+' '+(by+c-k)+' V'+(by+k)+'Z" fill="'+((i+j)%3 ? '#f0c9a0' : '#e7b48a')+'" stroke="#b9876a" stroke-width="1"/><rect x="'+(bx+c*.3)+'" y="'+(by+c*.3)+'" width="'+(c*.4)+'" height="'+(c*.4)+'" fill="#9cc58a"/>';
  }
  return g + '</g>';
}


// ---------- Garrotxa: Santa Margarida volcano, a grassy crater ringed by beech forest, with the little Romanesque hermitage in the middle ----------
function garrotxa(){
  let g = '<path d="M0 140 Q40 110 80 128 Q120 92 170 120 Q210 104 250 126 V194 H0Z" fill="#6aa357" stroke="'+O+'" stroke-width="2"/>';
  // the crater: a round green bowl seen from above at an angle
  g += '<ellipse cx="96" cy="160" rx="70" ry="22" fill="#4f8a45" stroke="'+O+'" stroke-width="2"/><ellipse cx="96" cy="162" rx="48" ry="13" fill="#9fd07a" stroke="'+O+'" stroke-width="1.5"/>';
  g += '<rect x="92" y="153" width="9" height="7" fill="#efe2cc" stroke="'+O+'" stroke-width="1"/><path d="M91 153 L96.5 149 L102 153Z" fill="#c8553d"/>';
  // beech trees on the rim
  for (let k = 0; k < 14; k++) { const a = k/14*Math.PI*2, x = 96 + Math.cos(a)*62, y = 160 + Math.sin(a)*18; if (y < 170) g += '<circle cx="'+x.toFixed(1)+'" cy="'+(y-4).toFixed(1)+'" r="6" fill="'+(k%3 ? '#3e7a3a' : '#c9862f')+'" stroke="'+O+'" stroke-width="1"/>'; }
  // other old cones on the horizon
  g += '<path d="M160 124 Q190 96 220 124Z" fill="#5c9a4f" stroke="'+O+'" stroke-width="1.5"/>';
  return g;
}

// ---------- the Barcelona home scene (full-bleed hero). Sky follows the real time of day. ----------
function skyFor(h){
  if (h >= 6 && h < 9) return ['#8fb6f0', '#ffc7a0', '#ffe9b0', '#fff1b8', 70];        // morning
  if (h >= 9 && h < 17) return ['#62b8f0', '#9fd8f6', '#dff3ff', '#fff6c8', 40];       // day
  if (h >= 17 && h < 21) return ['#7a6cd6', '#ff9a7a', '#ffd27a', '#fff1b8', 120];     // sunset
  return ['#1d1b3f', '#33306b', '#4b4a8a', '#f4f1de', 50];                              // night
}
function scene(o){
  o = o || {}; const id = 'n'+(uid++), h = o.hour != null ? o.hour : new Date().getHours(), sk = skyFor(h), night = h < 6 || h >= 21;
  let s = '<svg viewBox="0 0 360 330" preserveAspectRatio="xMidYMax slice" class="nscene" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="'+id+'s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="'+sk[0]+'"/><stop offset=".5" stop-color="'+sk[1]+'"/><stop offset="1" stop-color="'+sk[2]+'"/></linearGradient>'+panot(id+'p')+'</defs>';
  s += '<rect width="360" height="330" fill="url(#'+id+'s)"/>';
  if (night) for (let i = 0; i < 26; i++) s += '<circle cx="'+((i*67)%360)+'" cy="'+((i*29)%140 + 8)+'" r="'+(i%3 ? 1.2 : 1.8)+'" fill="#fff" opacity=".8"/>';
  s += '<circle cx="'+(night ? 70 : 300)+'" cy="'+sk[4]+'" r="'+(night ? 18 : 30)+'" fill="'+sk[3]+'" opacity=".95"/>';
  // Collserola hills behind the city, then the sea
  s += '<path d="M0 190 Q60 150 130 172 Q200 192 260 168 Q320 150 360 174 V230 H0Z" fill="'+(night ? '#3a3770' : '#8f7bc4')+'" opacity=".55"/>';
  s += '<rect y="196" width="360" height="34" fill="'+(night ? '#1f5a73' : '#1fa3a8')+'"/><path d="M10 206 h30 M90 214 h40 M200 204 h26 M280 218 h36" stroke="#bff0ec" stroke-width="3" stroke-linecap="round" opacity=".8"/>';
  // rooftops of the old town
  let rx = -6; const rc = ['#e2603f','#f08a5d','#d9534f','#f2a65a'];
  for (let i = 0; i < 10; i++) { const w = 34 + ((i*13)%18), hh = 34 + ((i*29)%28);
    s += '<rect x="'+rx+'" y="'+(236-hh)+'" width="'+w+'" height="'+(hh+10)+'" fill="'+(night ? '#c9b7a0' : '#fbe3c4')+'" stroke="'+O+'" stroke-width="2.5"/><path d="M'+(rx-2)+' '+(236-hh)+' L'+(rx+w/2)+' '+(222-hh)+' L'+(rx+w+2)+' '+(236-hh)+'Z" fill="'+rc[i%4]+'" stroke="'+O+'" stroke-width="2.5" stroke-linejoin="round"/>'+
      '<rect x="'+(rx+w/2-5)+'" y="'+(248-hh)+'" width="10" height="12" rx="5" fill="'+(night ? '#ffd76a' : '#3b6f8f')+'"/>'; rx += w; }
  s += sagradaFull(272, 238, .6, {sw:3});
  s += '<rect y="236" width="360" height="94" fill="url(#'+id+'p)"/><path d="M0 236 H360" stroke="'+O+'" stroke-width="3"/>';
  s += palm(26, 312, 1) + palm(338, 318, 1.08);
  const bx = o.bx || 150;
  s += '<ellipse cx="'+bx+'" cy="316" rx="40" ry="7" fill="rgba(0,0,0,.18)"/>'+blipAt(bx, 320, 140, Object.assign({}, o.blip || {}, {wave: true}), 'nbob');
  return s + '</svg>';
}

// ---------- small postcard art for each activity (86 x 72) ----------
function paellaPan(cx, cy, r){
  let g = '<path d="M'+(cx-r-10)+' '+cy+' h10 M'+(cx+r)+' '+cy+' h10" stroke="#3b3b3b" stroke-width="'+(r/7)+'" stroke-linecap="round"/>';
  g += '<ellipse cx="'+cx+'" cy="'+cy+'" rx="'+r+'" ry="'+(r*.42)+'" fill="#4a4a4a" stroke="'+O+'" stroke-width="2"/><ellipse cx="'+cx+'" cy="'+(cy-1)+'" rx="'+(r*.88)+'" ry="'+(r*.34)+'" fill="#f2b632"/>';
  // mussels, prawns, peas, red pepper, a lemon wedge
  for (const [dx, dy] of [[-.5,-.05],[.35,.08],[-.1,.12],[.55,-.1]]) g += '<ellipse cx="'+(cx+dx*r)+'" cy="'+(cy+dy*r)+'" rx="'+(r*.13)+'" ry="'+(r*.07)+'" fill="#2b2440"/>';
  for (const [dx, dy] of [[-.25,-.12],[.15,-.15],[.3,.12]]) g += '<path d="M'+(cx+dx*r)+' '+(cy+dy*r)+' q'+(r*.1)+' '+(-r*.1)+' '+(r*.2)+' 0" stroke="#ff7a59" stroke-width="'+(r/10)+'" fill="none" stroke-linecap="round"/>';
  for (const [dx, dy] of [[-.4,.1],[0,0],[.1,.18],[-.15,-.2]]) g += '<circle cx="'+(cx+dx*r)+'" cy="'+(cy+dy*r)+'" r="'+(r*.04)+'" fill="#4caf50"/>';
  g += '<path d="M'+(cx-r*.1)+' '+(cy-r*.05)+' l'+(r*.18)+' '+(r*.06)+'" stroke="#d8392b" stroke-width="'+(r/12)+'" stroke-linecap="round"/>';
  g += '<path d="M'+(cx+r*.6)+' '+(cy+r*.12)+' a'+(r*.12)+' '+(r*.12)+' 0 0 1 '+(r*.22)+' 0z" fill="#fff36b" stroke="'+O+'" stroke-width="1"/>';
  return g;
}
function balloonAt(x, y, s, withBlip, o){
  let g = '<g transform="translate('+x+' '+y+') scale('+s+')"><path d="M0 -60 C-34 -60 -38 -22 -14 0 H14 C38 -22 34 -60 0 -60Z" fill="#e2603f" stroke="'+O+'" stroke-width="2.5"/>'+
    '<path d="M0 -60 C-14 -60 -16 -22 -6 0 M0 -60 C14 -60 16 -22 6 0" stroke="'+O+'" stroke-width="1.5" fill="#ffc84a"/><path d="M-12 -6 H12" stroke="'+O+'" stroke-width="1.5"/>'+
    '<path d="M-12 0 L-11 20 M12 0 L11 20" stroke="'+O+'" stroke-width="1.5"/>';
  if (withBlip) g += blipAt(0, 44, 42, o);
  g += '<rect x="-12" y="20" width="24" height="15" rx="2" fill="#b97c48" stroke="'+O+'" stroke-width="2"/><path d="M-10 17 H10" stroke="#8a5a34" stroke-width="1.5"/></g>';
  return g;
}
function hostelDesk(o){
  return '<rect width="250" height="194" fill="#fbe3c4"/><rect x="0" y="0" width="250" height="70" fill="#f2d3a8"/>'+
    // key board with numbered room keys
    '<rect x="150" y="16" width="80" height="50" rx="4" fill="#b97c48" stroke="'+O+'" stroke-width="2.5"/>'+[0,1,2,3,4,5].map(k => '<circle cx="'+(164+(k%3)*24)+'" cy="'+(28+Math.floor(k/3)*22)+'" r="3" fill="'+O+'"/><path d="M'+(164+(k%3)*24)+' '+(31+Math.floor(k/3)*22)+' v8" stroke="#ffc84a" stroke-width="3"/>').join('')+
    '<rect x="20" y="20" width="96" height="30" rx="4" fill="#fff4e0" stroke="'+O+'" stroke-width="2.5"/>'+T(68,41,'HOSTAL','16','Lilita One','text-anchor="middle" fill="#e2603f"')+
    blipAt(100, 190, 130, Object.assign({}, o, {hat:false, pack_on:false, wave:true}))+
    '<rect x="0" y="140" width="250" height="54" fill="#8a5a34" stroke="'+O+'" stroke-width="3"/><rect x="0" y="134" width="250" height="10" fill="#b97c48" stroke="'+O+'" stroke-width="3"/>'+
    // the front desk bell
    '<ellipse cx="190" cy="134" rx="16" ry="4" fill="#3b3b3b"/><path d="M176 132 Q190 106 204 132Z" fill="#ffc84a" stroke="'+O+'" stroke-width="2"/><circle cx="190" cy="112" r="3" fill="#ffc84a" stroke="'+O+'" stroke-width="1.5"/>';
}

const TILE = {
  sagrada: () => '<rect width="86" height="72" fill="#ffd9a8"/><circle cx="66" cy="20" r="10" fill="#fff1b8"/>'+sagradaFull(40, 72, .21, {sw:5, crane:false}),
  montserrat: () => '<rect width="86" height="72" fill="#bfe3f0"/>'+montserrat(43, 70, .52),
  laia: () => '<rect width="86" height="72" fill="#ffb88a"/><circle cx="62" cy="40" r="12" fill="#ffe6a8"/><path d="M0 50 H86 V72 H0Z" fill="#8f7bc4" opacity=".6"/>'+
    '<path d="M0 60 Q43 46 86 60 V72 H0Z" fill="#cfc6b8" stroke="'+O+'" stroke-width="1.5"/><ellipse cx="22" cy="62" rx="12" ry="4" fill="#bdb3a4" stroke="'+O+'" stroke-width="1.2"/>'+
    blipAt(40, 70, 46, Object.assign({}, LAIA, {wave:true})),
  es1: () => '<rect width="86" height="72" fill="#d6f1ee"/><rect x="10" y="12" width="66" height="34" rx="12" fill="#fff" stroke="'+O+'" stroke-width="2"/><path d="M24 44 l-4 12 l14 -10" fill="#fff" stroke="'+O+'" stroke-width="2" stroke-linejoin="round"/>'+T(43,36,'¡Hola!','17','Lilita One','text-anchor="middle" fill="#e2603f"'),
  es2: () => '<rect width="86" height="72" fill="#fff0d0"/><rect y="46" width="86" height="26" fill="#e2603f"/><path d="M0 46 H86" stroke="'+O+'" stroke-width="2"/>'+paellaPan(43, 44, 28),
  balloon: () => '<rect width="86" height="72" fill="#ffd9a8"/><circle cx="18" cy="18" r="9" fill="#fff1b8"/><g transform="scale(.344)">'+garrotxa()+'</g>'+balloonAt(58, 40, .42, false),
  job: () => '<svg viewBox="0 0 250 194" width="86" height="72" preserveAspectRatio="xMidYMid slice">'+hostelDesk({})+'</svg>'
};
const tile = id => '<svg viewBox="0 0 86 72" class="ntile" aria-hidden="true">'+(TILE[id] ? TILE[id]() : '<rect width="86" height="72" fill="#fff0d0"/>')+'</svg>';

// ---------- Polaroid photos for each activity (250 x 194), with the player's Blip in them ----------
function eixample(x, y, w, h, cell){
  let g = ''; for (let i = 0; i * cell < w; i++) for (let j = 0; j * cell < h; j++) {
    const bx = x + i*cell, by = y + j*cell, c = cell*.78, k = cell*.18;
    g += '<path d="M'+(bx+k)+' '+by+' H'+(bx+c-k)+' L'+(bx+c)+' '+(by+k)+' V'+(by+c-k)+' L'+(bx+c-k)+' '+(by+c)+' H'+(bx+k)+' L'+bx+' '+(by+c-k)+' V'+(by+k)+'Z" fill="'+((i+j)%3 ? '#f0c9a0' : '#e7b48a')+'" stroke="#b9876a" stroke-width="1"/><rect x="'+(bx+c*.3)+'" y="'+(by+c*.3)+'" width="'+(c*.4)+'" height="'+(c*.4)+'" fill="#9cc58a"/>';
  }
  return g;
}
const PHOTO = {
  es1: o => '<rect width="250" height="194" fill="#fff3d6"/><rect x="18" y="18" width="140" height="80" rx="6" fill="#2f5d50" stroke="'+O+'" stroke-width="4"/>'+
    T(88,52,'Hola, me llamo','15','Fredoka','text-anchor="middle" fill="#fff"')+T(88,74,'¡Gracias!','15','Fredoka','text-anchor="middle" fill="#fff"')+
    '<rect x="0" y="160" width="250" height="34" fill="#c9a66b"/>'+blipAt(190, 186, 150, Object.assign({}, o, {wave:true})),
  es2: o => '<rect width="250" height="194" fill="#fff0d0"/><rect x="0" y="0" width="250" height="60" fill="#f2a65a" opacity=".5"/>'+
    '<path d="M0 0 H250 V34 Q232 46 214 34 Q196 46 178 34 Q160 46 142 34 Q124 46 106 34 Q88 46 70 34 Q52 46 34 34 Q16 46 0 34Z" fill="#e2603f" stroke="'+O+'" stroke-width="2.5"/>'+   // terrace awning
    blipAt(70, 170, 130, Object.assign({}, o, {wave:true}))+
    '<rect x="0" y="140" width="250" height="54" fill="#f4f1ea" stroke="'+O+'" stroke-width="3"/><path d="M0 152 H250" stroke="#d8392b" stroke-width="2" stroke-dasharray="8 8"/>'+paellaPan(160, 140, 52),
  laia: o => '<defs><linearGradient id="ngl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a6cd6"/><stop offset=".6" stop-color="#ff9a7a"/><stop offset="1" stop-color="#ffd27a"/></linearGradient></defs><rect width="250" height="194" fill="url(#ngl)"/>'+
    '<circle cx="196" cy="96" r="22" fill="#fff1b8"/><rect y="110" width="250" height="16" fill="#1fa3a8"/>'+
    // the whole city below, Sagrada Família on the skyline
    '<g opacity=".85">'+[0,1,2,3,4,5,6,7,8,9,10,11].map(k => '<rect x="'+(k*22)+'" y="'+(122-((k*17)%14))+'" width="20" height="30" fill="#c79c90"/>').join('')+'</g>'+sagradaFull(70, 128, .16, {sw:6, crane:false})+
    // the round concrete gun pads of the Bunkers del Carmel
    '<path d="M0 150 Q125 128 250 150 V194 H0Z" fill="#cfc6b8" stroke="'+O+'" stroke-width="2.5"/><ellipse cx="60" cy="168" rx="38" ry="10" fill="#bdb3a4" stroke="'+O+'" stroke-width="2"/><ellipse cx="60" cy="168" rx="24" ry="5" fill="#a9a091"/>'+
    blipAt(120, 186, 100, Object.assign({}, LAIA, {wave:true}))+blipAt(178, 186, 100, Object.assign({}, o, {wave:false})),
  montserrat: o => '<rect width="250" height="194" fill="#bfe3f0"/>'+montserrat(125, 150, 1.5)+
    '<path d="M0 170 Q60 140 140 160 T250 150 V194 H0Z" fill="#6a9b58" stroke="'+O+'" stroke-width="2.5"/><path d="M40 194 Q80 170 120 176 T200 160" stroke="#e8d9b8" stroke-width="6" fill="none"/>'+
    blipAt(70, 186, 100, Object.assign({}, o, {wave:true, walk:true})),
  sagrada: o => '<rect width="252" height="226" fill="#9fd8f2"/><rect y="40" width="252" height="30" fill="#2aa5b8"/><g transform="translate(-40 70) skewX(-8)">'+eixample(0, 0, 340, 160, 26)+'</g>'+
    '<path d="M0 170 H252 V226 H0Z" fill="#d9b98a" stroke="'+O+'" stroke-width="3"/><path d="M0 182 H252" stroke="#b8925f" stroke-width="3"/>'+
    '<g transform="translate(205 172) scale(2.3)"><path d="M0 0 L-9 -14 L-6 -30 L0 -36 L6 -30 L9 -14Z" fill="#d8392b" stroke="'+O+'" stroke-width="1.4"/><path d="M0 0 L-4 -18 L0 -36 L4 -18Z" fill="#f4c430"/><circle cx="-5" cy="-22" r="2" fill="#fff"/><circle cx="5" cy="-14" r="2" fill="#fff"/><path d="M0 -36 V-48 M-6 -42 H6" stroke="#d4a017" stroke-width="2"/><circle cx="0" cy="-50" r="3" fill="#fff" stroke="'+O+'" stroke-width="1.2"/><circle cx="-7" cy="-42" r="3" fill="#fff" stroke="'+O+'" stroke-width="1.2"/><circle cx="7" cy="-42" r="3" fill="#fff" stroke="'+O+'" stroke-width="1.2"/></g>'+
    blipAt(92, 222, 150, Object.assign({}, o, {wave:true})),
  balloon: o => '<rect width="250" height="194" fill="#ffcf9a"/><circle cx="48" cy="120" r="26" fill="#fff1b8"/><rect y="118" width="250" height="20" fill="#f2b8a0" opacity=".5"/>'+garrotxa()+balloonAt(170, 82, 1.25, true, o),
  job: o => hostelDesk(o)
};
function photo(id, o){
  const vb = id === 'sagrada' ? '0 0 252 226' : '0 0 250 194';
  return '<svg viewBox="'+vb+'" class="nphoto" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">'+(PHOTO[id] ? PHOTO[id](o || {}) : '<rect width="250" height="194" fill="#fff0d0"/>'+blipAt(125, 186, 150, o))+'</svg>';
}

// ---------- passport: an oval entry stamp in red ink with a tiny skyline ----------
function stamp(country, city, date, color){
  color = color || '#c0392b';
  const sky = country === 'ESPAÑA' ? sagradaFull(110, 256, .14, {sw:7, crane:false}).replace(/fill="#[0-9a-f]{6}"/g, 'fill="none"').replace(/stroke="#3b2a4a"/g, 'stroke="'+color+'"') : '';
  return '<svg viewBox="30 168 160 124" class="nstampsvg" aria-label="'+country+' stamp"><g transform="rotate(-8 110 230)"><ellipse cx="110" cy="230" rx="70" ry="52" fill="none" stroke="'+color+'" stroke-width="3.5"/><ellipse cx="110" cy="230" rx="62" ry="44" fill="none" stroke="'+color+'" stroke-width="1.5"/>'+
    T(110,206,country,'17','Lilita One','text-anchor="middle" fill="'+color+'" letter-spacing="2"')+'<g opacity=".9">'+sky+'</g>'+
    T(110,266,(city+' · '+date).toUpperCase(),'8','Fredoka','text-anchor="middle" font-weight="700" fill="'+color+'"')+'</g></svg>';
}
const keyIcon = (c, sz) => '<svg viewBox="0 0 40 24" width="'+(sz || 34)+'" aria-hidden="true"><circle cx="10" cy="12" r="7" fill="'+(c || '#ffc84a')+'" stroke="'+O+'" stroke-width="2.5"/><circle cx="10" cy="12" r="2.5" fill="#fff"/><path d="M17 12 H36 M30 12 V19 M35 12 V17" stroke="'+O+'" stroke-width="3.5" stroke-linecap="round"/></svg>';

// ---------- styles (look 1A). Loaded after nomad.js's own block so these win. ----------
const CSS = `
body.nomad{background:#fff4e0;color:#3b2a4a}
body.nomad .app{padding-bottom:96px}
.nscene{display:block;width:100%;height:100%}
.nhero1a{position:relative;margin:-16px -16px 0;height:min(64vh,420px);overflow:hidden;border-bottom:3px solid #3b2a4a}
.nhero1a .nscene{position:absolute;inset:0}
.nhud{position:absolute;left:12px;right:12px;top:calc(10px + env(safe-area-inset-top));display:flex;justify-content:space-between;align-items:flex-start;gap:8px;z-index:2}
.npill{display:flex;align-items:center;gap:6px;background:#fff;border:3px solid #3b2a4a;border-radius:22px;padding:5px 12px 5px 6px;font-family:'Lilita One',Fredoka,sans-serif;font-size:21px;color:#3b2a4a;box-shadow:0 3px 0 rgba(59,42,74,.25)}
.npill small{font-family:Fredoka,sans-serif;font-size:12px;font-weight:600;color:#6d6787}
.npill.npay2{font-size:15px;flex-direction:column;align-items:flex-start;gap:0;padding:4px 12px;line-height:1.1}
.nbanner{position:absolute;left:14px;top:calc(62px + env(safe-area-inset-top));transform:rotate(-3deg);background:#fff4e0;border:3px solid #3b2a4a;border-radius:6px;padding:3px 14px;font-family:'Lilita One',sans-serif;font-size:22px;letter-spacing:2px;color:#e2603f;z-index:2}
.nbanner small{display:block;font-family:Fredoka,sans-serif;font-size:11px;letter-spacing:.5px;color:#6d6787;margin-top:-3px}
.nsay{position:absolute;left:14px;top:calc(122px + env(safe-area-inset-top));max-width:170px;background:#fff;border:3px solid #3b2a4a;border-radius:16px;padding:7px 11px;font-size:14px;font-weight:600;line-height:1.25;z-index:2}
.nsay:after{content:'';position:absolute;left:96px;bottom:-14px;border:8px solid transparent;border-top:10px solid #3b2a4a}
.nsheet{background:#fff4e0;border:3px solid #3b2a4a;border-radius:24px 24px 0 0;margin:-22px -16px 0;padding:16px 16px 4px;position:relative;z-index:3}
body.nomad .card{background:#fff;border:3px solid #3b2a4a;border-radius:18px;box-shadow:0 4px 0 rgba(59,42,74,.18);color:#3b2a4a}
body.nomad .nh3{color:#3b2a4a;font-family:'Lilita One',Fredoka,sans-serif;font-weight:400;font-size:21px;margin:16px 2px 10px}
body.nomad h2,body.nomad .modal h2{font-family:'Lilita One',Fredoka,sans-serif;font-weight:400}
body.nomad .btn{background:#e2603f;color:#fff;border:3px solid #3b2a4a;border-radius:18px;box-shadow:0 5px 0 #a8402a,0 5px 0 2px #3b2a4a;font-family:'Lilita One',Fredoka,sans-serif;font-weight:400;letter-spacing:.5px;text-shadow:0 1px 0 rgba(59,42,74,.4);margin-bottom:6px}
body.nomad .btn:active{transform:translateY(4px);box-shadow:0 1px 0 #a8402a,0 1px 0 2px #3b2a4a}
body.nomad .btn.ghost{background:#fff;color:#3b2a4a;box-shadow:0 4px 0 #d9cbb5,0 4px 0 2px #3b2a4a;text-shadow:none}
body.nomad .btn[disabled]{background:#e9dfcf;color:#8d84a3;box-shadow:0 3px 0 #cfc2ae,0 3px 0 2px #3b2a4a;text-shadow:none;opacity:1}
body.nomad .btn.nsm{padding:7px 14px;font-size:15px;border-radius:14px}
.nrow2{display:flex;gap:12px;align-items:center}
.ntile{display:block;width:86px;height:72px;flex:none;border:2.5px solid #3b2a4a;border-radius:8px;background:#fff}
.npost{display:flex;gap:12px;align-items:center}
.npost .nbody{flex:1;min-width:0}
.npost .nk{display:block;color:#e2603f;font-size:11px;font-weight:700;letter-spacing:.8px;text-transform:uppercase}
.npost b{display:block;font-size:16px;line-height:1.2}
.ncost{display:flex;align-items:center;gap:4px;font-size:13px;color:#6d6787;margin-top:3px}
.ncost b{display:inline;font-family:'Lilita One',sans-serif;font-weight:400;font-size:15px;color:#3b2a4a}
body.nomad .nact:nth-of-type(odd){transform:rotate(-.6deg)} body.nomad .nact:nth-of-type(even){transform:rotate(.5deg)}
body.nomad .ndone{opacity:1;background:#f3ecdf}
.nstamped{position:absolute;right:10px;top:8px;transform:rotate(12deg);border:2.5px solid #c0392b;color:#c0392b;border-radius:8px;padding:1px 7px;font-family:'Lilita One',sans-serif;font-size:13px;letter-spacing:1px;background:rgba(255,255,255,.7)}
body.nomad .nact{position:relative}
body.nomad .nbar{height:14px;border-radius:8px;background:#f0e6d6;border:2px solid #3b2a4a}
body.nomad .nbar i{background:linear-gradient(90deg,#1fa3a8,#5ec4d6)!important}
.ncoin{display:inline-block;vertical-align:-4px;flex:none}
.nnav1a{position:fixed;left:0;right:0;bottom:0;display:flex;gap:6px;background:#3b2a4a;padding:7px 10px calc(7px + env(safe-area-inset-bottom));z-index:20}
.nnav1a button{flex:1;border:0;background:none;color:#fff;font-family:Fredoka,sans-serif;font-size:12px;font-weight:600;padding:6px 2px;border-radius:14px}
.nnav1a button b{display:block;font-size:21px;line-height:1.1}
.nnav1a button.on{background:#e2603f}
body.nomad .npol{background:#fff;border:3px solid #3b2a4a;border-radius:4px;padding:10px 10px 4px;box-shadow:0 8px 20px rgba(0,0,0,.2);transform:rotate(-2deg)}
.nphoto{display:block;width:100%;height:auto;border:2px solid #3b2a4a}
body.nomad .npcap{font-family:Caveat,Fredoka,cursive;font-size:23px;font-weight:700;color:#2a3f6e;padding:6px 0 2px}
body.nomad .nreal{background:#fff4e0;border:3px solid #3b2a4a;border-radius:16px;padding:0 12px 10px;overflow:hidden}
body.nomad .nreal .nrk{margin:0 -12px 8px;background:#1fa3a8;color:#fff;font-family:'Lilita One',sans-serif;font-weight:400;font-size:15px;letter-spacing:1.5px;text-align:center;padding:7px}
.npassbook{background:#2a3f6e;border:3px solid #3b2a4a;border-radius:16px;padding:9px}
.npassbook .pg{background:#fffaf0 repeating-linear-gradient(0deg,transparent 0 22px,#ece6f6 22px 24px);border-radius:10px;padding:12px;display:grid;grid-template-columns:1fr 1fr;gap:10px;align-items:center}
.npassbook h2{grid-column:1/-1;text-align:center;margin:0;color:#2a3f6e;font-size:19px;letter-spacing:1.5px}
.nstampsvg{width:100%;height:auto;display:block}
.nslot{border:2.5px dashed #9aa3c0;border-radius:12px;min-height:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#9aa3c0;font-family:'Lilita One',sans-serif;letter-spacing:1.5px;font-size:15px;gap:4px;text-align:center}
.nslot.open{border-color:#e2603f;color:#e2603f}
.nslot small{font-family:Fredoka,sans-serif;letter-spacing:0;font-size:11px}
.nkdots{display:flex;gap:5px}.nkdots i{width:15px;height:15px;border-radius:50%;border:2px solid #3b2a4a;background:#f0e6d6;display:block}.nkdots i.on{background:#e2603f}
body.nomad .nkrow{align-items:center;border-bottom:1px dashed #e4d8c4}
.nwelcome{margin:-20px -20px 0;position:relative;height:300px;overflow:hidden;border-bottom:3px solid #3b2a4a;border-radius:20px 20px 0 0}
.nwelcome .nscene{position:absolute;inset:0}
.nribbon{display:inline-block;transform:rotate(-3deg);background:#e2603f;color:#fff;border:3px solid #3b2a4a;border-radius:8px;padding:4px 18px;font-family:'Lilita One',sans-serif;font-size:24px;letter-spacing:1.5px;margin:-22px 0 8px;position:relative;z-index:2}
.nbob{animation:nbob 2.6s ease-in-out infinite;transform-origin:50% 100%}
@keyframes nbob{0%,100%{transform:translateY(0)}50%{transform:translateY(-3px)}}
.nwave{animation:nwave 1.6s ease-in-out infinite}
@keyframes nwave{0%,100%{transform:rotate(0)}50%{transform:rotate(-14deg)}}
.nblink{animation:nblink 4.5s infinite}
@keyframes nblink{0%,94%,100%{transform:scaleY(1)}96%{transform:scaleY(.1)}}
@media (prefers-reduced-motion:reduce){.nbob,.nwave,.nblink{animation:none}}
body.nomad .modal{border:3px solid #3b2a4a;background:#fff4e0}
`;
function injectCSS(){
  if (!document.querySelector('link[data-nart]')) document.head.insertAdjacentHTML('beforeend', '<link data-nart rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Caveat:wght@700&family=Lilita+One&display=swap">');
  document.head.insertAdjacentHTML('beforeend', '<style data-nart>'+CSS+'</style>');
  document.body.classList.add('nomad');
}

// Styles go in after nomad.js has added its own block (it loads right after this file), so these win.
if (typeof NOMAD !== 'undefined' && NOMAD) setTimeout(injectCSS, 0);
window.NART = {blip, blipSVG, blipAt, LAIA, coin, coinAt, scene, tile, photo, stamp, keyIcon, sagradaFull, injectCSS, TILE, PHOTO};
})();
