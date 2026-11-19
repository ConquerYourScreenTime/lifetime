// ============ BLIP NOMAD (prototype, Barcelona only) ============
// Spec: /mnt/project-files/lifetime/game-mechanics/Blip Nomad - Spain France Italy.docx (draft 4).
// Runs instead of Blip Classic when NOMAD is true (index.html). Its own save ('blip-nomad'): the Classic save is only read
// (name, look, goal), never written, so the Classic Blip doesn't age while Nomad is being tried.
// Coins come only from phone-down time and are never sold. No shop, no analytics, no shares in the prototype.
// Phase 1 (mechanics plan v1, 2026-11-19): Miles renamed Coins, a goal the player chooses (plus a gentle raise offer they can
// turn down), a plan of up to 3 activities that run one after another, the calm "Blip's off!" screen, optional morning note only.
(function(){
if (typeof NOMAD === 'undefined' || !NOMAD) return;
const NKEY = 'blip-nomad';
const SHIFT_FROM = 8, SHIFT_TO = 22;           // the odd job runs 8 AM to 10 PM
const KEY_NEEDS = {small: 2, big: 1, lesson: 2, shift: 5};
const CUR = 'Coins', CUR_ICON = '🪙';          // the currency's name lives here only (placeholder, may be renamed)
const COIN_RULE = 'Coins only come from phone-down time. They can\'t be bought.';
const PLAN_MAX = 3;                            // activities Blip can have lined up (the one running plus 2 more)

// ---------- Barcelona ----------
const ACTS = [
  {id:'es1', kind:'lesson', emoji:'🗣️', title:'Spanish lesson 1: Hello', cost:60, min:15,
    phrase:'Hola, me llamo {name}. Gracias.', say:'OH-lah, meh YAH-moh {name}. GRAH-see-ahs.', mean:'Hello, my name is {name}. Thank you.',
    real:['Spanish works everywhere in Barcelona. Catalan is the city\'s other language, and locals love it when you try "Bon dia" (good morning).', 'Short courses for visitors run all year, from a single morning to a few weeks.', 'Tip: "Gracias" goes a long way. So does a smile when you get it wrong.']},
  {id:'es2', kind:'lesson', emoji:'🥘', title:'Spanish lesson 2: Order food', cost:60, min:15, needs:'es1',
    phrase:'Una paella para dos, por favor.', say:'OO-nah pah-EH-yah PAH-rah dohs, por fah-VOR.', mean:'A paella for two, please.',
    real:['Paella is usually made to order for at least two people, so it\'s normal to wait 20 to 30 minutes.', 'Spaniards eat late: lunch around 2 PM and dinner after 9 PM.', 'Tip: a "menú del día" at lunch is the best-value meal in town.']},
  {id:'laia', kind:'meet', emoji:'👋', title:'Meet Laia', cost:80, min:20,
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
  coins:150, city:'Barcelona', stamps:['es'], done:{}, act:null, credited:{}, keyp:{small:0, big:0, lesson:0, shift:0},
  day:null, snap:null, polaroids:[], born: Date.now(), welcomed:false};
// Phase 1 save fields (older saves get them here; Miles carry over one for one as Coins).
if (N.coins == null) { N.coins = N.miles != null ? N.miles : 150; delete N.miles; }
N.queue = N.queue || [];      // activities lined up after the current one (already paid for)
N.ready = N.ready || [];      // finished while the phone was down, waiting for their Polaroid
N.hist = N.hist || {};        // day -> true if that day finished under the goal (kept 14 days, for the raise offer only)
N.remind = N.remind || {on:false, h:8, m:0};
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
// Shift pay: 1 Coin for every 5 phone-down minutes from 8 AM to 10 PM, worked out hour by hour from the counter.
// The shift ends for the day once the count reaches the goal. Earned Coins are never taken back.
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
  if (miles > had) { N.coins += miles - had; N.credited[day] = miles; }
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
    if (tips) N.coins += tips;
    if (under) N.keyp.shift = Math.min(KEY_NEEDS.shift, N.keyp.shift + 1);
    N.hist[y] = under;
    const old = new Date(); old.setDate(old.getDate() - 14);
    for (const k in N.hist) if (k < key(old)) delete N.hist[k];
    nsave();
    return {y, m: r.m, tips, under, pay: N.credited[y] || pay.miles};
  });
}

// ---------- Blip's plan: the running activity plus up to 2 more, done one after another ----------
const actOf = id => ACTS.find(z => z.id === id);
function planIds(){ return (N.act ? [N.act.id] : []).concat(N.queue); }
function planned(id){ return planIds().indexOf(id) >= 0; }
// A lesson that needs an earlier one can be lined up once the earlier one is done or already in the plan.
function unlocked(x){ return !x.needs || N.done[x.needs] || planned(x.needs); }
function begin(id){ const x = actOf(id); N.act = {id, prog:0, need:x.min, at:Date.now()}; }
function complete(){
  const x = actOf(N.act.id);
  N.done[x.id] = true; N.ready.push(x.id); N.polaroids.push(x.id);
  if (x.kind in N.keyp) N.keyp[x.kind] = Math.min(KEY_NEEDS[x.kind], N.keyp[x.kind] + 1);
  N.act = null;
  if (N.queue.length) begin(N.queue.shift());
}
// Phone-down minutes go to the running activity; when it finishes, the rest carries straight into the next one.
function addDown(mins){
  while (mins > 0 && N.act) {
    const take = Math.min(mins, N.act.need - N.act.prog);
    N.act.prog += take; mins -= take;
    if (N.act.prog >= N.act.need) complete();
  }
}

// Phone-down progress: real time while Blip is closed, minus what the counter gained meanwhile.
// It pauses while the phone is in use (or Blip is open) and never resets.
function advance(nowM, snapDayEnd){
  const now = Date.now(), t = todayKey();
  if (N.act && N.snap) {
    const mins = (now - N.snap.t) / 60000;
    const used = N.snap.day === t ? Math.max(0, nowM - N.snap.m) : nowM + Math.max(0, (snapDayEnd != null ? snapDayEnd : N.snap.m) - N.snap.m);
    addDown(Math.max(0, mins - used));
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
    if (firstOpen && N.ready.length && !document.querySelector('.modal')) reveal();
    if (tip) showMorning(tip);   // added last, so it sits on top: the morning note first, then the Polaroids
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
    '<div class="nmiles">'+CUR_ICON+' <b>'+N.coins+'</b> '+CUR+'</div><div class="nrule">'+COIN_RULE+'</div></div></div>';
  s += '<div class="card"><div class="nrow"><span class="nem">'+JOB.emoji+'</span><div><b>'+JOB.title+'</b><div class="muted small">'+esc(nm(JOB.line))+'</div></div></div>'+
    '<div class="npay">'+esc(N.name)+'\'s pay today: <b>'+pay+' '+CUR+'</b></div>'+
    '<div class="muted small">'+(live.over ? 'You reached your goal, so the shift is over for today. '+esc(N.name)+' keeps everything earned. Back on shift tomorrow at 8 AM.' :
      onShift ? 'On shift until 10 PM. Put your phone down and '+esc(N.name)+' earns 1 Coin every 5 minutes.' : 'The shift runs 8 AM to 10 PM.')+
    (live.today != null ? ' Blip\'s count today: '+fmtTime(live.today)+' of '+fmtTime(N.goal)+'.' : '')+'</div></div>';
  if (N.ready.length) s += '<div class="card nnow"><b>📸 '+N.ready.length+' new Polaroid'+(N.ready.length > 1 ? 's' : '')+'</b><button class="btn" id="nfin" style="margin-top:10px">See how it went ✨</button></div>';
  if (a) {
    const x = actOf(a.id);
    s += '<div class="card nnow"><h3 style="margin:0 0 8px">'+esc(N.name)+'\'s plan</h3><div class="nrow"><span class="nem">'+x.emoji+'</span><div style="flex:1"><small class="nk">Now</small><b>'+esc(x.title)+'</b><div class="muted small">'+Math.floor(a.prog)+' of '+a.need+' min with your phone down</div></div></div>'+
      bar(a.prog / a.need);
    N.queue.forEach((id, i) => { const q = actOf(id);
      s += '<div class="nrow nq"><span class="nem">'+q.emoji+'</span><div style="flex:1"><small class="nk">'+(i ? 'Then' : 'Next')+'</small><b>'+esc(q.title)+'</b></div>'+
        '<button class="btn ghost nsm" data-unq="'+i+'">Remove</button></div>'; });
    s += '<p class="muted small" style="margin:8px 0 0">Close Blip and put your phone down. '+esc(N.name)+' does these one after another. Picking up your phone pauses the plan, and it never resets.</p></div>';
  }
  s += '<h3 class="nh3">Things to do in Barcelona</h3>';
  const full = planIds().length >= PLAN_MAX;
  for (const x of ACTS) {
    const done = N.done[x.id], inPlan = planned(x.id), locked = !unlocked(x), afford = N.coins >= x.cost;
    const label = inPlan ? 'In the plan' : locked ? 'After lesson 1' : full ? 'Plan is full' : !afford ? 'Need '+(x.cost - N.coins) : a ? 'Add to plan' : 'Go';
    s += '<div class="card nact'+(done ? ' ndone' : '')+'"><div class="nrow"><span class="nem">'+x.emoji+'</span><div style="flex:1"><small class="nk">'+KINDS[x.kind]+'</small><b>'+esc(x.title)+'</b>'+
      '<div class="muted small">'+x.cost+' '+CUR+' · '+(x.min >= 60 ? '1 hour' : x.min+' min')+' phone down</div></div>'+
      (done ? '<span class="ntick">✓</span>' : '<button class="btn nsm" data-go="'+x.id+'"'+(inPlan || locked || full || !afford ? ' disabled' : '')+'>'+label+'</button>')+'</div></div>';
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
    '<p class="muted small">You choose the goal, and Blip never changes it on its own. A new goal starts tomorrow in the full game. In the prototype it counts right away.</p></div>'+
    (IS_APP ? '<div class="card"><h3 style="margin-top:0">⏰ Morning note</h3><div class="switch"><span>One note in the morning when '+esc(N.name)+'\'s news is ready. Never during the day.</span><input type="checkbox" id="rmon" '+(N.remind.on ? 'checked' : '')+'></div>'+
      (N.remind.on ? '<div class="switch"><span>Time</span><input type="time" id="rmtime" value="'+String(N.remind.h).padStart(2, '0')+':'+String(N.remind.m).padStart(2, '0')+'"></div>' : '')+
      (remindNote ? '<p class="muted small">'+esc(remindNote)+'</p>' : '')+'</div>' : '')+
    '<div class="card"><h3 style="margin-top:0">About this prototype</h3><p class="muted small">Blip Nomad, Barcelona only. Your Blip Classic save is kept as it is and doesn\'t age while you try this.</p>'+
    (TF ? '<p class="muted small"><b>Test tools</b> (TestFlight only)</p><button class="btn ghost" id="t30">Add 30 phone-down minutes to the activity</button><button class="btn ghost" id="tday" style="margin-top:8px">Pretend a new day started</button><button class="btn ghost" id="treset" style="margin-top:8px">Start Nomad over</button>' : '')+'</div>';
}
function realHTML(x){ return '<div class="nreal"><div class="nrk">Do it for real</div>'+(x.phrase ? '<p class="nphr">"'+esc(nm(x.phrase))+'"<br><small>Say it: '+esc(nm(x.say))+'<br>Means: '+esc(nm(x.mean))+'</small></p>' : '')+'<ul>'+x.real.map(r => '<li>'+esc(r)+'</li>').join('')+'</ul></div>'; }

function draw(){
  const nav = '<div class="nnav">'+[['city','📍','Barcelona'],['passport','🛂','Passport'],['settings','⚙️','Settings']].map(t => '<button data-v="'+t[0]+'" class="'+(view === t[0] ? 'on' : '')+'"><b>'+t[1]+'</b>'+t[2]+'</button>').join('')+'</div>';
  app.innerHTML = '<div class="top"><div class="logo">Blip <small>Nomad prototype</small></div><div class="streak">'+CUR_ICON+' '+N.coins+'</div></div>'+
    (view === 'city' ? cityHTML() : view === 'passport' ? passportHTML() : settingsHTML())+nav;
  app.querySelectorAll('[data-v]').forEach(b => b.onclick = () => { view = b.dataset.v; draw(); window.scrollTo(0, 0); });
  app.querySelectorAll('[data-go]').forEach(b => b.onclick = () => start(b.dataset.go));
  const on = (id, f) => { const e = document.getElementById(id); if (e) e.onclick = f; };
  app.querySelectorAll('[data-unq]').forEach(b => b.onclick = () => unqueue(+b.dataset.unq));
  on('nfin', reveal);
  on('gm', () => { N.goal = Math.max(15, N.goal - 15); nsave(); refresh(false); });
  on('gp', () => { N.goal = Math.min(960, N.goal + 15); nsave(); refresh(false); });
  const rm = document.getElementById('rmon');
  if (rm) rm.onchange = () => { N.remind.on = rm.checked; remindNote = ''; nsave(); draw();
    nremindSync().then(ok => { if (!ok && N.remind.on) { N.remind.on = false; nsave(); remindNote = 'Notifications are off for Blip. You can turn them on in iPhone Settings > Notifications > Blip.'; draw(); } }); };
  const rt = document.getElementById('rmtime');
  if (rt) rt.onchange = () => { const [h, m] = rt.value.split(':').map(Number); if (isNaN(h)) return; N.remind.h = h; N.remind.m = m || 0; nsave(); nremindSync(); };
  on('t30', () => { if (N.act) { addDown(30); nsave(); refresh(false); if (N.ready.length) reveal(); } });
  on('tday', () => { N.day = yestKey(); nsave(); refresh(false); });
  on('treset', () => { localStorage.removeItem(NKEY); location.reload(); });
}
// Go (nothing running) starts it now; Add to plan lines it up. Either way it is paid now, and then Blip heads off.
function start(id){
  const x = actOf(id); if (!x || N.done[id] || planned(id) || !unlocked(x) || planIds().length >= PLAN_MAX || N.coins < x.cost) return;
  N.coins -= x.cost;
  if (N.act) N.queue.push(id);
  else { begin(id); N.snap = {t: Date.now(), day: todayKey(), m: live.today || 0}; }
  nsave(); draw(); calm();
}
// Taking something out of the plan gives its Coins back. Anything lined up after it that needed it comes out too.
function unqueue(i){
  const id = N.queue[i]; if (id == null) return;
  N.queue.splice(i, 1); N.coins += actOf(id).cost;
  for (let j = N.queue.length - 1; j >= 0; j--) { const q = actOf(N.queue[j]); if (!unlocked(q)) { N.queue.splice(j, 1); N.coins += q.cost; } }
  nsave(); draw();
}
// The calm screen: nothing to tap but the screen itself. Its only job is to send you off.
function calm(){
  const ids = planIds(), now = actOf(ids[0]), later = ids.slice(1).map(actOf);
  const c = document.createElement('div');
  c.className = 'ncalm';
  c.innerHTML = '<div class="ncalmin"><div class="nsamw">'+sam()+'</div><h1>'+esc(N.name)+'\'s off!</h1><p class="ncbig">Put your phone down.</p>'+
    '<p>'+now.emoji+' '+esc(now.title)+(later.length ? '<br><span class="ncsoft">then '+later.map(q => q.emoji+' '+esc(q.title)).join(', then ')+'</span>' : '')+'</p>'+
    '<p class="ncsoft ncfoot">'+esc(N.name)+' is earning '+CUR+' at the hostel the whole time. Tap anywhere to come back.</p></div>';
  c.onclick = () => c.remove();
  document.body.appendChild(c);
}
// Polaroids for everything finished while the phone was down, oldest on top.
function reveal(){
  const ids = N.ready.slice(); if (!ids.length) return;
  N.ready = []; nsave(); draw();
  ids.slice().reverse().forEach((id, i) => { const x = actOf(id), last = i === 0;
    modal('<div class="nrk" style="text-align:center">'+KINDS[x.kind]+' done!</div>'+polaroid(x)+(x.line ? '<p>'+esc(nm(x.line))+'</p>' : '')+realHTML(x)+
      (last && keyDone() ? '<p><b>🔑 That\'s everything for the France key!</b></p>' : '')+'<button class="btn" data-close>'+(last ? 'Done' : 'Next photo')+'</button>'); });
  confetti([actOf(ids[0]).emoji, '✨', '📸']);
}
// After a good week (5 of the last 7 days under goal), Blip offers 15 minutes less, at most once a week. Saying no is fine,
// and the goal never changes on its own.
function raiseReady(){
  if (N.goal <= 30) return false;
  if (N.raiseAt && (new Date(todayKey()) - new Date(N.raiseAt)) / 864e5 < 7) return false;
  let good = 0; const d = new Date();
  for (let i = 1; i <= 7; i++) { d.setDate(d.getDate() - 1); if (N.hist[key(d)]) good++; }
  return good >= 5;
}
function showMorning(t){
  const raise = raiseReady();
  if (raise) { N.raiseAt = todayKey(); nsave(); }
  modal('<div class="mbig">☀️</div><h2 style="margin:4px 0">Good morning</h2><p>Yesterday '+esc(N.name)+' earned <b>'+t.pay+' '+CUR+'</b> at the hostel.</p>'+
    (t.under ? '<p>You finished '+fmtTime(N.goal - t.m)+' under your goal, so guests left <b>'+t.tips+' '+CUR+'</b> in tips. That\'s a full shift toward the France key.</p>' :
      '<p>The shift ended at your goal. '+esc(N.name)+' kept every Coin and is back at the desk at 8 AM.</p>')+
    (raise ? '<div class="nraise"><p><b>What a week!</b> You were under your goal on 5 of the last 7 days. Want to try 15 minutes less? It\'s your call, and you can change it back any time in Settings.</p>'+
      '<button class="btn" id="nrup" data-close>Try '+fmtTime(N.goal - 15)+'</button><button class="btn ghost" data-close style="margin-top:8px">Keep '+fmtTime(N.goal)+'</button></div>' :
      '<button class="btn" data-close>Let\'s go</button>'));
  const up = document.getElementById('nrup');
  if (up) up.addEventListener('click', () => { N.goal = Math.max(15, N.goal - 15); nsave(); refresh(false); });
}
function welcome(){
  N.welcomed = true; nsave();
  modal('<div class="nsamw">'+sam()+'</div><h2 style="margin:4px 0">'+esc(N.name)+' lands in Barcelona!</h2><p>'+esc(N.name)+' is 18, with a backpack and <b>150 '+CUR+'</b> saved from home.</p>'+
    '<p class="muted">While your phone is down, '+esc(N.name)+' works the hostel front desk and earns '+CUR+'. Spend them on lessons, friends and adventures. Every one is something you can really do.</p>'+
    '<p class="muted small">'+COIN_RULE+'</p><button class="btn" data-close id="nwel">Let\'s explore</button>');
  const w = document.getElementById('nwel'); if (w && !N.goalSet) w.addEventListener('click', chooseGoal);
}
// Choosing the goal (first run, and once for players from build 29). Blip suggests a little under a usual day; the player picks.
function usualDay(){
  const days = []; const d = new Date();
  for (let i = 1; i <= 7; i++) { d.setDate(d.getDate() - 1); days.push(key(d)); }
  return Promise.all(days.map(k => readDay(k).catch(() => ({m:0})))).then(rs => {
    const ms = rs.map(r => r.m).filter(m => m > 0);
    return ms.length ? Math.round(ms.reduce((a, b) => a + b, 0) / ms.length) : null;
  });
}
function chooseGoal(){
  usualDay().then(avg => {
    const suggest = avg ? Math.max(30, Math.floor((avg - 15) / 15) * 15) : (C.goal || 120);
    let g = Math.min(960, suggest);
    const m = document.createElement('div');
    m.className = 'modal';
    const paint = () => { m.innerHTML = '<div class="card"><div class="mbig">🎯</div><h2 style="margin:4px 0">Pick your daily goal</h2>'+
      (avg ? '<p>Blip\'s count says a usual day for you is about <b>'+fmtTime(avg)+'</b>. A goal a little under that is a good start.</p>' :
        '<p>Pick a goal that feels a little easier than a usual day. You can change it any time.</p>')+
      '<div class="ngoal"><button class="btn nsm" id="cgm">–</button><b>'+fmtTime(g)+'</b><button class="btn nsm" id="cgp">+</button></div>'+
      '<p class="muted small">Stay under it and '+esc(N.name)+' works a full shift. Go over and the shift ends early, but nothing is ever taken away. Blip never changes your goal on its own.</p>'+
      '<button class="btn" id="cgok">Set my goal</button></div>';
      m.querySelector('#cgm').onclick = () => { g = Math.max(15, g - 15); paint(); };
      m.querySelector('#cgp').onclick = () => { g = Math.min(960, g + 15); paint(); };
      m.querySelector('#cgok').onclick = () => { N.goal = g; N.goalSet = true; nsave(); m.remove(); refresh(false); };
    };
    paint(); document.body.appendChild(m);
  });
}

// ---------- the one optional notification: a morning note, never during the day ----------
let remindNote = '';
function nremindSync(){
  const p = P(); if (!p || !p.remindOn) return Promise.resolve(true);
  if (!N.remind.on) return p.remindOff().then(() => true).catch(() => true);
  return p.remindOn({name: N.name, hour: N.remind.h, minute: N.remind.m, body: 'Good morning! '+N.name+' has news from '+N.city+'.'})
    .then(r => !!(r && r.granted)).catch(() => false);
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
  '.nrule{font-size:11px;color:var(--soft);margin-top:2px}.nq{margin-top:10px;padding-top:10px;border-top:1px solid var(--line)}.nq .nk{display:block;color:var(--soft);font-size:12px}.nnow .nk{display:block;color:var(--soft);font-size:12px}'+
  '.ngoal{display:flex;gap:16px;align-items:center;justify-content:center;font-size:28px;margin:12px 0}.nraise{background:#fff3d6;border-radius:14px;padding:10px 12px;margin-top:8px}'+
  '.ncalm{position:fixed;inset:0;z-index:60;background:linear-gradient(180deg,#2b3a67,#1b2440);color:#f4f1ea;display:flex;align-items:center;justify-content:center;text-align:center;padding:24px;animation:ncin .5s ease}'+
  '.ncalmin{max-width:340px}.ncalm h1{margin:8px 0 4px;font-size:34px}.ncbig{font-size:22px;margin:0 0 18px}.ncsoft{opacity:.7;font-size:14px}.ncfoot{margin-top:28px}.ncalm .nsamw svg{width:150px;height:180px}'+
  '@keyframes ncin{from{opacity:0}to{opacity:1}}'+
  '.nkrow{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--line);font-size:15px}.nsamw svg{width:140px;height:168px}'+
  '.nnav{position:fixed;left:0;right:0;bottom:0;display:flex;background:#fff;border-top:1px solid var(--line);padding:6px 6px calc(6px + env(safe-area-inset-bottom))}.nnav button{flex:1;border:0;background:none;font-size:12px;color:var(--soft);padding:4px}.nnav button b{display:block;font-size:22px}.nnav button.on{color:var(--accent2);font-weight:600}'+
  '</style>');

// ---------- start ----------
draw();
if (!N.welcomed) welcome();        // the goal picker follows when the welcome closes
else if (!N.goalSet) chooseGoal();
refresh(true);
nremindSync();                     // replaces any Classic "next year" note with Nomad's own (or turns it off)
const p = P();
if (p && p.env) p.env().then(r => { TF = !!(r && r.testflight); if (view === 'settings') draw(); }).catch(() => {});
if (p && p.resync) setTimeout(() => p.resync().catch(() => {}), 1500);
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') { document.querySelectorAll('.ncalm').forEach(c => c.remove()); refresh(true); }
  else if (N.snap) { N.snap.t = Date.now(); nsave(); } // the phone-down clock starts now (Blip open doesn't count)
});
setInterval(() => { if (document.visibilityState === 'visible') refresh(false); }, 30000);
})();
