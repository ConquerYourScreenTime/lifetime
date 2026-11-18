// ============ BLIP NOMAD (prototype, Barcelona only) ============
// Spec: /mnt/project-files/lifetime/game-mechanics/Blip Nomad - Spain France Italy.docx (draft 4).
// Runs instead of Blip Classic when NOMAD is true (index.html). Its own save ('blip-nomad'): the Classic save is only read
// (name, look, goal), never written, so the Classic Blip doesn't age while Nomad is being tried.
// Miles come only from phone-down time and are never sold. No shop, no analytics, no shares in the prototype.
(function(){
if (typeof NOMAD === 'undefined' || !NOMAD) return;
const NKEY = 'blip-nomad';
const SHIFT_FROM = 8, SHIFT_TO = 22;           // the odd job runs 8 AM to 10 PM
const KEY_NEEDS = {small: 2, big: 1, lesson: 2, shift: 5};

// ---------- Barcelona ----------
const ACTS = [
  {id:'es1', kind:'lesson', emoji:'🗣️', title:'Spanish lesson 1: Hello', cost:60, min:15,
    phrase:'Hola, me llamo {name}. Gracias.', say:'OH-lah, meh YAH-moh {name}. GRAH-see-ahs.', mean:'Hello, my name is {name}. Thank you.',
    real:['Spanish works everywhere in Barcelona. Catalan is the city\'s other language, and locals love it when you try "Bon dia" (good morning).', 'Short courses for visitors run all year, from a single morning to a few weeks.', 'Tip: "Gracias" goes a long way. So does a smile when you get it wrong.']},
  {id:'es2', kind:'lesson', emoji:'🥘', title:'Spanish lesson 2: Order food', cost:60, min:15, needs:'es1',
    phrase:'Una paella para dos, por favor.', say:'OO-nah pah-EH-yah PAH-rah dohs, por fah-VOR.', mean:'A paella for two, please.',
    real:['Paella is usually made to order for at least two people, so it\'s normal to wait 20 to 30 minutes.', 'Spaniards eat late: lunch around 2 PM and dinner after 9 PM.', 'Tip: a "menú del día" at lunch is the best-value meal in town.']},
  {id:'laia', kind:'meet', emoji:'🧡', title:'Meet Laia', cost:80, min:20,
    line:'Laia runs the hostel and knows every rooftop in the city. She takes {name} up to the Bunkers del Carmel for sunset.',
    real:['The Bunkers del Carmel are old anti-aircraft gun sites on a hill, with one of the widest free views of Barcelona.', 'Get there about an hour before sunset. It\'s a steep walk up from the nearest bus stop.', 'Tip: bring water and a jacket. It gets windy at the top.']},
  {id:'montserrat', kind:'small', emoji:'⛰️', title:'Hike up Montserrat', cost:150, min:30,
    line:'{name} hikes up the jagged mountain to the monastery tucked into the rocks.',
    real:['Montserrat is about an hour from Barcelona by train. A rack railway or a cable car takes you up the last part.', 'The monastery sits about 720 m up. Hiking up from the bottom takes about 1.5 to 2 hours.', 'Tip: go early on a weekday. The trails above the monastery are much quieter than the plaza.']},
  {id:'sagrada', kind:'small', emoji:'⛪', title:'Climb a Sagrada Família tower', cost:150, min:30,
    line:'{name} rides up a tower of Gaudí\'s basilica and walks down the narrow spiral stairs.',
    real:['Tower visits need a timed ticket booked ahead. A lift takes you up and you walk down a tight spiral staircase.', 'The basilica has been under construction since 1882.', 'Tip: book online days ahead, and check the age limit for children before you go.']},
  {id:'balloon', kind:'big', emoji:'🎈', title:'Sunrise balloon over the Garrotxa volcanoes', cost:400, min:60,
    line:'{name} floats over the old volcanoes and beech forests of the Garrotxa at sunrise.',
    real:['Balloon flights run near Olot, about 2 hours north of Barcelona, over the Garrotxa Volcanic Zone Natural Park.', 'You meet before dawn. The flight lasts about an hour, and the whole morning takes 3 to 4 hours.', 'Tip: flights depend on the wind, so keep a spare day in case yours is moved.']}
];
const KINDS = {lesson:'Lesson', meet:'Meet someone', small:'Small adventure', big:'Big adventure'};
const JOB = {emoji:'🛎️', title:'Hostel front desk', line:'{name} works the hostel front desk in exchange for a bed, a common work-exchange for travelers.'};

// ---------- save ----------
function nload(){ try { return JSON.parse(localStorage.getItem(NKEY)) || null; } catch(e){ return null; } }
function nsave(){ try { localStorage.setItem(NKEY, JSON.stringify(N)); } catch(e){} }
const C = S || {};   // the Classic save, read only
let N = nload() || {v:1, name: C.name || 'Sam', skin: C.skin || SKINS[1], hair: C.hair || HAIRS[1], girl: !!C.girl, goal: C.goal || 120,
  miles:150, city:'Barcelona', stamps:['es'], done:{}, act:null, credited:{}, keyp:{small:0, big:0, lesson:0, shift:0},
  day:null, snap:null, polaroids:[], born: Date.now(), welcomed:false};
let view = 'city', live = {today:null, hours:null, pay:0, over:false}, TF = !IS_APP;
const nm = t => String(t).replace(/\{name\}/g, N.name);

// ---------- time and the counter ----------
function key(d){ return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0'); }
function todayKey(){ return key(new Date()); }
function yestKey(){ const d = new Date(); d.setDate(d.getDate() - 1); return key(d); }
const P = () => nativePlugin('ScreenTime');
function readDay(day){
  const p = P();
  if (!p) return Promise.resolve({m: N.sim && N.sim[day] || 0, hours: null});
  return Promise.all([p.minutesFor({day}).catch(() => null), p.checkLog ? p.checkLog({day}).catch(() => null) : null])
    .then(([a, b]) => ({m: a && typeof a.minutes === 'number' ? a.minutes : 0, hours: b && b.hours ? b.hours : null}));
}
// Shift pay: 1 Mile for every 5 phone-down minutes from 8 AM to 10 PM, worked out hour by hour from the counter.
// The shift ends for the day once the count reaches the goal. Earned Miles are never taken back.
function shiftPay(day, total, hours, final){
  const now = new Date(), isToday = day === todayKey();
  let down = 0, used = 0, over = total >= N.goal;
  if (hours) {
    for (let h = 0; h < SHIFT_FROM; h++) used += hours['daily-'+h] || 0;
    for (let h = SHIFT_FROM; h < SHIFT_TO; h++) {
      if (isToday && !final && h > now.getHours()) break;
      const span = isToday && !final && h === now.getHours() ? now.getMinutes() : 60, u = Math.min(span, hours['daily-'+h] || 0);
      if (used + u >= N.goal) { const left = Math.max(0, N.goal - used); down += Math.max(0, span - u) * (u ? left / u : 0); used = N.goal; break; }
      used += u; down += Math.max(0, span - u);
    }
  } else {
    // No hour-by-hour numbers (website preview): shift time so far minus the day's count.
    const end = isToday && !final ? Math.min(SHIFT_TO * 60, Math.max(SHIFT_FROM * 60, now.getHours() * 60 + now.getMinutes())) : SHIFT_TO * 60;
    down = over ? 0 : Math.max(0, end - SHIFT_FROM * 60 - total);
  }
  return {miles: Math.floor(down / 5), over};
}
function credit(day, miles){
  const had = N.credited[day] || 0;
  if (miles > had) { N.miles += miles - had; N.credited[day] = miles; }
  for (const k in N.credited) if (k < yestKey()) delete N.credited[k];
}

// A new calendar day: settle yesterday's shift, pay tips, count a full shift toward the key.
function rollover(){
  const t = todayKey();
  if (N.day === t) return Promise.resolve(null);
  if (!N.day) { N.day = t; nsave(); return Promise.resolve(null); }
  const y = yestKey(), wasYest = N.day === y;
  N.day = t; nsave();
  if (!wasYest) return Promise.resolve(null);   // away for more than a day: nothing to settle in the prototype
  return readDay(y).then(r => {
    const pay = shiftPay(y, r.m, r.hours, true); credit(y, pay.miles);
    const under = r.m < N.goal, tips = under ? N.goal - r.m : 0;
    if (tips) N.miles += tips;
    if (under) N.keyp.shift = Math.min(KEY_NEEDS.shift, N.keyp.shift + 1);
    nsave();
    return {y, m: r.m, tips, under, pay: N.credited[y] || pay.miles};
  });
}

// Phone-down progress on the current activity: real time while Blip is closed, minus what the counter gained meanwhile.
// It pauses while the phone is in use (or Blip is open) and never resets.
function advance(nowM, snapDayEnd){
  const now = Date.now(), t = todayKey();
  if (N.act && N.snap) {
    const mins = (now - N.snap.t) / 60000;
    const used = N.snap.day === t ? Math.max(0, nowM - N.snap.m) : nowM + Math.max(0, (snapDayEnd != null ? snapDayEnd : N.snap.m) - N.snap.m);
    N.act.prog = Math.min(N.act.need, N.act.prog + Math.max(0, mins - used));
  }
  N.snap = {t: now, day: t, m: nowM};
  nsave();
}

function refresh(firstOpen){
  const snapDay = N.snap && N.snap.day !== todayKey() ? N.snap.day : null;
  return rollover().then(tip => Promise.all([readDay(todayKey()), snapDay ? readDay(snapDay) : null]).then(([r, old]) => {
    live.today = r.m; live.hours = r.hours;
    if (firstOpen) advance(r.m, old ? old.m : null); else if (N.snap) { N.snap.t = Date.now(); N.snap.m = r.m; N.snap.day = todayKey(); nsave(); }
    const pay = shiftPay(todayKey(), r.m, r.hours, false); credit(todayKey(), pay.miles);
    live.pay = N.credited[todayKey()] || 0; live.over = pay.over;
    nsave(); draw();
    if (tip) showMorning(tip);
    else if (N.act && N.act.prog >= N.act.need && !document.querySelector('.modal')) finish();
  }));
}

// ---------- art ----------
function sam(o){ return charSVG(Object.assign({name:N.name, age:18, log:[{tier:'good'}], h:70, s:60, j:75, skin:N.skin, hair:N.hair, girl:N.girl, wear:{}, mood:'happy', nobg:true}, o || {})); }
const BACK = {
  lesson:'<rect width="250" height="194" fill="#fff3d6"/><rect x="20" y="22" width="130" height="80" rx="6" fill="#2f5d50" stroke="#3b2a4a" stroke-width="4"/>',
  meet:'<rect width="250" height="194" fill="#ffb37a"/><circle cx="190" cy="70" r="26" fill="#ffe08a"/><path d="M0 150 L40 120 L70 135 L110 100 L150 130 L200 110 L250 140 V194 H0Z" fill="#7a4e8f"/>',
  small:'<rect width="250" height="194" fill="#bfe6ff"/><path d="M0 160 L50 60 L80 110 L120 30 L160 100 L200 50 L250 150 V194 H0Z" fill="#b08968" stroke="#3b2a4a" stroke-width="3"/>',
  big:'<rect width="250" height="194" fill="#ffd8a8"/><circle cx="60" cy="40" r="18" fill="#fff3b0"/><path d="M0 170 Q60 120 120 160 T250 150 V194 H0Z" fill="#5c9e5c"/><path d="M150 168 Q170 130 190 168Z M60 172 Q85 135 110 172Z" fill="#6b4f3a"/>'
};
function polaroid(a){
  const sc = a.kind === 'big' ? '<g transform="translate(150 18)"><ellipse cx="34" cy="40" rx="32" ry="38" fill="#ff5a8a" stroke="#3b2a4a" stroke-width="3"/><path d="M14 66 L24 92 H44 L54 66" fill="none" stroke="#3b2a4a" stroke-width="3"/><rect x="22" y="90" width="24" height="16" rx="3" fill="#b97c48" stroke="#3b2a4a" stroke-width="3"/></g>' : '';
  const board = a.kind === 'lesson' ? '<text x="85" y="58" text-anchor="middle" font-family="Fredoka" font-size="15" fill="#fff">'+esc(nm(a.phrase).split(' ').slice(0,3).join(' '))+'</text>' : '';
  return '<div class="npol"><svg viewBox="0 0 250 194" width="100%">'+BACK[a.kind]+board+sc+
    '<svg x="'+(a.kind === 'big' ? 20 : 95)+'" y="40" width="120" height="150" viewBox="0 0 200 240">'+sam().replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '')+'</svg></svg>'+
    '<div class="npcap">'+a.emoji+' '+esc(a.title)+'</div></div>';
}

// ---------- screens ----------
const app = document.getElementById('app');
function bar(p, c){ return '<div class="nbar"><i style="width:'+Math.min(100, Math.round(p*100))+'%;background:'+(c || 'var(--accent2)')+'"></i></div>'; }
function keyLine(){ const k = N.keyp, row = (l, have, need) => '<div class="nkrow"><span>'+l+'</span><b>'+Math.min(have, need)+' / '+need+'</b></div>';
  return row('Small adventures', k.small, KEY_NEEDS.small)+row('Big adventure', k.big, KEY_NEEDS.big)+row('Spanish lessons', k.lesson, KEY_NEEDS.lesson)+row('Full shifts (a day under your goal)', k.shift, KEY_NEEDS.shift); }
function keyDone(){ return Object.keys(KEY_NEEDS).every(k => N.keyp[k] >= KEY_NEEDS[k]); }
function cityHTML(){
  const a = N.act, pay = live.pay, h = new Date().getHours(), onShift = h >= SHIFT_FROM && h < SHIFT_TO && !live.over;
  let s = '<div class="card nhero"><div class="nsam">'+sam()+'</div><div class="nhi"><div class="ncity">📍 '+esc(N.city)+', Spain</div><h2>'+esc(N.name)+', 18</h2>'+
    '<div class="nmiles">✈️ <b>'+N.miles+'</b> Miles</div></div></div>';
  s += '<div class="card"><div class="nrow"><span class="nem">'+JOB.emoji+'</span><div><b>'+JOB.title+'</b><div class="muted small">'+esc(nm(JOB.line))+'</div></div></div>'+
    '<div class="npay">'+esc(N.name)+'\'s pay today: <b>'+pay+' Miles</b></div>'+
    '<div class="muted small">'+(live.over ? 'You reached your goal, so the shift is over for today. '+esc(N.name)+' keeps everything earned. Back on shift tomorrow at 8 AM.' :
      onShift ? 'On shift until 10 PM. Put your phone down and '+esc(N.name)+' earns 1 Mile every 5 minutes.' : 'The shift runs 8 AM to 10 PM.')+
    (live.today != null ? ' Blip\'s count today: '+fmtTime(live.today)+' of '+fmtTime(N.goal)+'.' : '')+'</div></div>';
  if (a) { const x = ACTS.find(z => z.id === a.id);
    s += '<div class="card nnow"><div class="nrow"><span class="nem">'+x.emoji+'</span><div><b>'+esc(x.title)+'</b><div class="muted small">'+Math.floor(a.prog)+' of '+a.need+' min with your phone down</div></div></div>'+
      bar(a.prog / a.need)+'<p class="muted small" style="margin:6px 0 0">Close Blip and put your phone down. It pauses when you pick up your phone and never resets.</p>'+
      (a.prog >= a.need ? '<button class="btn" id="nfin" style="margin-top:10px">See how it went ✨</button>' : '')+'</div>';
  }
  s += '<h3 class="nh3">Things to do in Barcelona</h3>';
  for (const x of ACTS) {
    const done = N.done[x.id], locked = x.needs && !N.done[x.needs], busy = !!a, afford = N.miles >= x.cost;
    s += '<div class="card nact'+(done ? ' ndone' : '')+'"><div class="nrow"><span class="nem">'+x.emoji+'</span><div style="flex:1"><small class="nk">'+KINDS[x.kind]+'</small><b>'+esc(x.title)+'</b>'+
      '<div class="muted small">'+x.cost+' Miles · '+(x.min >= 60 ? '1 hour' : x.min+' min')+' phone down</div></div>'+
      (done ? '<span class="ntick">✓</span>' : '<button class="btn nsm" data-go="'+x.id+'"'+(locked || busy || !afford ? ' disabled' : '')+'>'+(locked ? 'After lesson 1' : busy ? 'One at a time' : !afford ? 'Need '+(x.cost - N.miles) : 'Go')+'</button>')+'</div></div>';
  }
  return s;
}
function passportHTML(){
  let s = '<div class="card npass"><h2>🛂 '+esc(N.name)+'\'s passport</h2><div class="nstamps"><div class="nstamp">🇪🇸<b>España</b><small>Barcelona</small></div>'+
    '<div class="nstamp nlock">🇫🇷<b>France</b><small>'+(keyDone() ? 'Key earned!' : 'Locked')+'</small></div><div class="nstamp nlock">🇮🇹<b>Italia</b><small>Locked</small></div></div></div>';
  s += '<div class="card"><h3 style="margin-top:0">🔑 France key</h3><p class="muted small">Finish Spain\'s goals to earn the key that opens France.</p>'+keyLine()+
    (keyDone() ? '<p><b>🔑 Key earned! France opens in the next version of the prototype.</b></p>' : '')+'</div>';
  if (N.polaroids.length) s += '<h3 class="nh3">Photos</h3>'+N.polaroids.slice().reverse().map(id => { const x = ACTS.find(z => z.id === id); return x ? '<div class="card">'+polaroid(x)+realHTML(x)+'</div>' : ''; }).join('');
  return s;
}
function settingsHTML(){
  return '<div class="card"><h2 style="margin-top:0">Settings</h2><div class="nrow" style="justify-content:space-between"><span>Daily goal</span><span><button class="btn nsm" id="gm">–</button> <b>'+fmtTime(N.goal)+'</b> <button class="btn nsm" id="gp">+</button></span></div>'+
    '<p class="muted small">A new goal starts tomorrow in the full game. In the prototype it counts right away.</p></div>'+
    '<div class="card"><h3 style="margin-top:0">About this prototype</h3><p class="muted small">Blip Nomad, Barcelona only. Your Blip Classic save is kept as it is and doesn\'t age while you try this.</p>'+
    (TF ? '<p class="muted small"><b>Test tools</b> (TestFlight only)</p><button class="btn ghost" id="t30">Add 30 phone-down minutes to the activity</button><button class="btn ghost" id="tday" style="margin-top:8px">Pretend a new day started</button><button class="btn ghost" id="treset" style="margin-top:8px">Start Nomad over</button>' : '')+'</div>';
}
function realHTML(x){ return '<div class="nreal"><div class="nrk">Do it for real</div>'+(x.phrase ? '<p class="nphr">"'+esc(nm(x.phrase))+'"<br><small>Say it: '+esc(nm(x.say))+'<br>Means: '+esc(nm(x.mean))+'</small></p>' : '')+'<ul>'+x.real.map(r => '<li>'+esc(r)+'</li>').join('')+'</ul></div>'; }

function draw(){
  const nav = '<div class="nnav">'+[['city','📍','Barcelona'],['passport','🛂','Passport'],['settings','⚙️','Settings']].map(t => '<button data-v="'+t[0]+'" class="'+(view === t[0] ? 'on' : '')+'"><b>'+t[1]+'</b>'+t[2]+'</button>').join('')+'</div>';
  app.innerHTML = '<div class="top"><div class="logo">Blip <small>Nomad prototype</small></div><div class="streak">✈️ '+N.miles+'</div></div>'+
    (view === 'city' ? cityHTML() : view === 'passport' ? passportHTML() : settingsHTML())+nav;
  app.querySelectorAll('[data-v]').forEach(b => b.onclick = () => { view = b.dataset.v; draw(); window.scrollTo(0, 0); });
  app.querySelectorAll('[data-go]').forEach(b => b.onclick = () => start(b.dataset.go));
  const on = (id, f) => { const e = document.getElementById(id); if (e) e.onclick = f; };
  on('nfin', finish);
  on('gm', () => { N.goal = Math.max(15, N.goal - 15); nsave(); refresh(false); });
  on('gp', () => { N.goal = Math.min(960, N.goal + 15); nsave(); refresh(false); });
  on('t30', () => { if (N.act) { N.act.prog = Math.min(N.act.need, N.act.prog + 30); nsave(); refresh(false); } });
  on('tday', () => { N.day = yestKey(); nsave(); refresh(false); });
  on('treset', () => { localStorage.removeItem(NKEY); location.reload(); });
}
function start(id){
  const x = ACTS.find(z => z.id === id); if (!x || N.act || N.miles < x.cost || N.done[id]) return;
  N.miles -= x.cost; N.act = {id, prog:0, need:x.min, at:Date.now()}; N.snap = {t: Date.now(), day: todayKey(), m: live.today || 0}; nsave(); draw();
  modal('<div class="mbig">'+x.emoji+'</div><h2 style="margin:4px 0">'+esc(x.title)+'</h2><p>'+esc(nm(x.line || x.mean || ''))+'</p>'+
    '<p class="muted">It takes '+(x.min >= 60 ? 'an hour' : x.min+' minutes')+' with your phone down. Close Blip now and come back later to see how it went.</p><button class="btn" data-close>Got it</button>');
}
function finish(){
  const a = N.act; if (!a || a.prog < a.need) return;
  const x = ACTS.find(z => z.id === a.id);
  N.done[x.id] = true; N.act = null; N.polaroids.push(x.id);
  if (x.kind in N.keyp) N.keyp[x.kind] = Math.min(KEY_NEEDS[x.kind], N.keyp[x.kind] + 1);
  nsave(); draw();
  modal('<div class="nrk" style="text-align:center">'+KINDS[x.kind]+' done!</div>'+polaroid(x)+(x.line ? '<p>'+esc(nm(x.line))+'</p>' : '')+realHTML(x)+
    (keyDone() ? '<p><b>🔑 That\'s everything for the France key!</b></p>' : '')+'<button class="btn" data-close>Done</button>');
  confetti([x.emoji, '✨', '📸']);
}
function showMorning(t){
  modal('<div class="mbig">☀️</div><h2 style="margin:4px 0">Good morning</h2><p>Yesterday '+esc(N.name)+' earned <b>'+t.pay+' Miles</b> at the hostel.</p>'+
    (t.under ? '<p>You finished '+fmtTime(N.goal - t.m)+' under your goal, so guests left <b>'+t.tips+' Miles</b> in tips. That\'s a full shift toward the France key.</p>' :
      '<p>The shift ended at your goal. '+esc(N.name)+' kept every Mile and is back at the desk at 8 AM.</p>')+'<button class="btn" data-close>Let\'s go</button>');
}
function welcome(){
  N.welcomed = true; nsave();
  modal('<div class="nsamw">'+sam()+'</div><h2 style="margin:4px 0">'+esc(N.name)+' lands in Barcelona!</h2><p>'+esc(N.name)+' is 18, with a backpack and <b>150 Miles</b> saved from home.</p>'+
    '<p class="muted">While your phone is down, '+esc(N.name)+' works the hostel front desk and earns Miles. Spend them on lessons, friends and adventures. Every one is something you can really do.</p><button class="btn" data-close>Let\'s explore</button>');
}

// ---------- styles ----------
document.head.insertAdjacentHTML('beforeend', '<style>'+
  '.nav{display:none!important}.nhero{display:flex;gap:12px;align-items:center;background:linear-gradient(180deg,#fff3d6,#fff 80%)}.nsam svg{width:110px;height:132px;display:block}'+
  '.nhi h2{margin:2px 0}.ncity{font-size:13px;color:var(--soft)}.nmiles{font-size:18px;margin-top:4px}.nrow{display:flex;gap:10px;align-items:center}.nem{font-size:30px}'+
  '.npay{font-size:20px;margin:10px 0 4px}.nbar{height:12px;border-radius:6px;background:#eee8ff;margin-top:10px;overflow:hidden}.nbar i{display:block;height:100%;border-radius:6px}'+
  '.nh3{color:#fff;margin:18px 4px 10px}.nact .nk{display:block;color:var(--soft);font-size:12px}.nact b{display:block}.ndone{opacity:.6}.ntick{font-size:24px;color:var(--good)}'+
  '.btn.nsm{width:auto;padding:8px 14px;font-size:14px;margin:0}.btn[disabled]{opacity:.45}'+
  '.npol{background:#fff;padding:10px 10px 6px;border-radius:6px;box-shadow:0 6px 18px rgba(0,0,0,.18);transform:rotate(-1.5deg);margin:8px 0 12px}.npol svg{display:block;border-radius:3px}.npcap{text-align:center;padding:8px 0 4px;font-weight:600}'+
  '.nreal{background:#eefaf1;border-radius:14px;padding:10px 12px;text-align:left;margin:8px 0}.nrk{font-size:12px;font-weight:700;color:#1d8a55;text-transform:uppercase;letter-spacing:.5px}.nreal ul{margin:6px 0 0;padding-left:18px}.nreal li{margin:4px 0;font-size:14px}.nphr{font-size:17px;margin:6px 0}'+
  '.nstamps{display:flex;gap:8px}.nstamp{flex:1;text-align:center;border:3px dashed #c0264a;border-radius:14px;padding:10px 4px;font-size:28px;transform:rotate(-4deg)}.nstamp b{display:block;font-size:14px}.nstamp small{font-size:11px;color:var(--soft)}.nlock{filter:grayscale(1);opacity:.45;border-color:#999;transform:none}'+
  '.nkrow{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--line);font-size:15px}.nsamw svg{width:140px;height:168px}'+
  '.nnav{position:fixed;left:0;right:0;bottom:0;display:flex;background:#fff;border-top:1px solid var(--line);padding:6px 6px calc(6px + env(safe-area-inset-bottom))}.nnav button{flex:1;border:0;background:none;font-size:12px;color:var(--soft);padding:4px}.nnav button b{display:block;font-size:22px}.nnav button.on{color:var(--accent2);font-weight:600}'+
  '</style>');

// ---------- start ----------
draw();
if (!N.welcomed) welcome();
refresh(true);
const p = P();
if (p && p.env) p.env().then(r => { TF = !!(r && r.testflight); if (view === 'settings') draw(); }).catch(() => {});
if (p && p.resync) setTimeout(() => p.resync().catch(() => {}), 1500);
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') refresh(true);
  else if (N.snap) { N.snap.t = Date.now(); nsave(); } // the phone-down clock starts now (Blip open doesn't count)
});
setInterval(() => { if (document.visibilityState === 'visible') refresh(false); }, 30000);
})();
