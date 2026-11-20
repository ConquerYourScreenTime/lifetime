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
    home:'Said it for real: "Hola, me llamo..."', phrase:'Hola, me llamo {name}. Gracias.', say:'OH-lah, meh YAH-moh {name}. GRAH-see-ahs.', mean:'Hello, my name is {name}. Thank you.',
    real:['Spanish works everywhere in Barcelona. Catalan is the city\'s other language, and locals love it when you try "Bon dia" (good morning).', 'Short courses for visitors run all year, from a single morning to a few weeks.', 'Tip: "Gracias" goes a long way. So does a smile when you get it wrong.']},
  {id:'es2', kind:'lesson', emoji:'🥘', title:'Spanish lesson 2: Order food', cost:60, min:15, needs:'es1',
    home:'Said it for real: "Una paella para dos"', phrase:'Una paella para dos, por favor.', say:'OO-nah pah-EH-yah PAH-rah dohs, por fah-VOR.', mean:'A paella for two, please.',
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
const JOB = {emoji:'⛵', title:'Deckhand on a sailing boat', line:'{name} crews a charter sailboat in the old harbor, Port Vell: coiling ropes, setting sails and seeing Barcelona from the sea. Charter boats really do take travelers on as crew.'};

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
    const travel = settleTravel(y, N.credited[y] || pay.miles);
    nsave();
    return {y, m: r.m, tips, under, pay: N.credited[y] || pay.miles, travel};
  });
}

// ---------- Blip's plan: the running activity plus up to 2 more, done one after another ----------
const actOf = id => ACTS.find(z => z.id === id) || FESTS.find(z => z.id === id) || GEMS.find(z => z.id === id);
const kindOf = x => x.gem ? 'Hidden gem' : x.fest ? 'Festival · limited time' : KINDS[x.kind];
function planIds(){ return (N.act ? [N.act.id] : []).concat(N.queue); }
function planned(id){ return planIds().indexOf(id) >= 0; }
// A lesson that needs an earlier one can be lined up once the earlier one is done or already in the plan.
function unlocked(x){ return !x.needs || N.done[x.needs] || planned(x.needs); }
function begin(id){ const x = actOf(id); N.act = {id, prog:0, need:x.min, at:Date.now()}; }
function complete(){
  const x = actOf(N.act.id);
  N.done[x.id] = true; N.ready.push(x.id); N.polaroids.push(x.id);
  N.fin[todayKey()] = (N.fin[todayKey()] || 0) + 1;
  if (x.kind === 'meet') N.met[x.id] = todayKey();
  if (x.kind in N.keyp && !x.fest) N.keyp[x.kind] = Math.min(KEY_NEEDS[x.kind], N.keyp[x.kind] + 1);
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

// A real challenge (Matthew, 2026-11-20): if the phone was used during an activity (Blip's count rose by a 5-minute step),
// that activity doesn't count. No punishment: its Coins come back, and Blip offers a friendly try again.
// Anything that was already finished before the phone came out still counts (benefit of the doubt).
function interrupt(){
  const x = actOf(N.act.id);
  N.coins += x.cost; N.missed = x.id; N.act = null;
  if (N.queue.length) begin(N.queue.shift());
}
function showMissed(){
  const id = N.missed; if (!id) return;
  N.missed = null; nsave();
  const x = actOf(id), canRetry = !N.done[id] && !planned(id) && planIds().length < PLAN_MAX && N.coins >= x.cost;
  modal('<div class="mbig">'+x.emoji+'</div><h2 style="margin:4px 0">So close!</h2>'+
    '<p>Your phone came out during <b>'+esc(x.title)+'</b>, so '+esc(N.name)+' will have to go again another time. No harm done: your <b>'+x.cost+' '+CUR+'</b> are back.</p>'+
    '<p class="muted small">Next time, let '+esc(N.name)+' finish the adventure before you pick up your phone. Short checks under 5 minutes may not show up in Blip\'s count.</p>'+
    (canRetry ? '<button class="btn" id="nretry" data-close>Try again</button><button class="btn ghost" data-close style="margin-top:8px">Not now</button>' : '<button class="btn" data-close>OK</button>'));
  const r = document.getElementById('nretry');
  if (r) r.addEventListener('click', () => start(id));
}

// Phone-down progress: real time while Blip is closed, minus what the counter gained meanwhile.
// Opening Blip doesn't count either way. Using the phone (a 5-minute step on Blip's count) ends the activity in progress.
function advance(nowM, snapDayEnd){
  const now = Date.now(), t = todayKey();
  if (N.snap) {
    const mins = (now - N.snap.t) / 60000;
    const used = N.snap.day === t ? Math.max(0, nowM - N.snap.m) : nowM + Math.max(0, (snapDayEnd != null ? snapDayEnd : N.snap.m) - N.snap.m);
    if (N.act) { addDown(Math.max(0, mins - used)); if (N.act && used >= 5) interrupt(); }
    checkGem(N.snap.t, mins, used);
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
    if (firstOpen) liveSync();
    if (firstOpen && N.ready.length && !document.querySelector('.modal')) reveal();
    if (firstOpen && N.missed) showMissed();
    if (tip) showMorning(tip);   // added last, so it sits on top: the morning note first, then the Polaroids
  }));
}

// ---------- art ----------
// Drawings come from nomad-art.js (look 1A). The player's Blip keeps their Classic skin and hair, plus a travel kit.
const look = o => Object.assign({skin:N.skin, hair:N.hair, girl:N.girl}, o || {});
function sam(o){ return NART.blipSVG(look(o)); }
function polaroid(a){ return '<div class="npol">'+NART.photo(a.id, look())+'<div class="npcap">'+esc(a.title)+'</div></div>'; }
function bubbleLine(){
  const h = new Date().getHours(), a = N.act;
  if (a) return 'Off to '+actOf(a.id).title.replace(/^./, c => c.toLowerCase())+'! Put your phone down and I\'ll go.';
  if (live.over) return 'Shift\'s done for today. I keep everything I earned!';
  if (h >= SHIFT_FROM && h < SHIFT_TO) return 'Hola! I\'m crewing a sailboat in the old harbor until 10 PM.';
  return h >= 5 && h < SHIFT_FROM ? 'Bon dia! Back on the boat at 8 AM.' : 'Bona nit! Back on the boat at 8 AM.';
}

// ---------- screens ----------
const app = document.getElementById('app');
function bar(p, c){ return '<div class="nbar"><i style="width:'+Math.min(100, Math.round(p*100))+'%;background:'+(c || 'var(--accent2)')+'"></i></div>'; }
function keyLine(){ const k = N.keyp, row = (l, have, need) => '<div class="nkrow"><span>'+l+'</span><b>'+Math.min(have, need)+' / '+need+'</b></div>';
  return row('Small adventures', k.small, KEY_NEEDS.small)+row('Big adventure', k.big, KEY_NEEDS.big)+row('Spanish lessons', k.lesson, KEY_NEEDS.lesson)+row('Full shifts (a day under your goal)', k.shift, KEY_NEEDS.shift); }
function keyDone(){ return Object.keys(KEY_NEEDS).every(k => N.keyp[k] >= KEY_NEEDS[k]); }
function cityHTML(){
  const a = N.act, pay = live.pay, h = new Date().getHours(), onShift = h >= SHIFT_FROM && h < SHIFT_TO && !live.over;
  let s = '<div class="nhero1a">'+NART.scene({blip: look()})+'<div class="nhud"><div class="npill">'+NART.coin(26)+N.coins+' <small>'+CUR+'</small></div>'+
    '<div class="npill npay2"><small>Shift pay</small>+'+pay+' today</div></div>'+
    '<div class="nbanner">'+esc(N.city).toUpperCase()+'<small>'+esc(N.name)+' · Spain</small></div><div class="nsay">'+esc(bubbleLine())+'</div></div><div class="nsheet">';
  s += '<div class="card"><div class="npost">'+NART.tile('job')+'<div class="nbody"><small class="nk">Odd job</small><b>'+JOB.title+'</b><div class="muted small">'+esc(nm(JOB.line))+'</div></div></div>'+
    (FEAT.framing ? '<div class="npay">'+esc(N.name)+'\'s day: <b>'+pay+' '+CUR+'</b></div><div class="small" style="margin-bottom:4px">'+esc(dayLine(todayKey(), pay))+'</div>' :
      '<div class="npay">'+esc(N.name)+'\'s pay today: <b>'+pay+' '+CUR+'</b></div>')+
    '<div class="muted small">'+(live.over ? 'You reached your goal, so the shift is over for today. '+esc(N.name)+' keeps everything earned. Back on shift tomorrow at 8 AM.' :
      onShift ? 'On shift until 10 PM. Put your phone down and '+esc(N.name)+' earns 1 Coin every 5 minutes.' : 'The shift runs 8 AM to 10 PM.')+
    (live.today != null ? ' Blip\'s count today: '+fmtTime(live.today)+' of '+fmtTime(N.goal)+'.' : '')+'</div></div>';
  s += '<p class="muted small nrule">'+COIN_RULE+'</p>';
  s += tipCardHTML()+travelCardHTML()+festCardHTML();
  if (N.ready.length) s += '<div class="card nnow"><b>📸 '+N.ready.length+' new Polaroid'+(N.ready.length > 1 ? 's' : '')+'</b><button class="btn" id="nfin" style="margin-top:10px">See how it went ✨</button></div>';
  if (a) {
    const x = actOf(a.id);
    s += '<div class="card nnow"><h3 style="margin:0 0 8px">'+esc(N.name)+'\'s plan</h3><div class="nrow"><span class="nsm-tile">'+NART.tile(x.id, look())+'</span><div style="flex:1"><small class="nk">Now</small><b>'+esc(x.title)+'</b><div class="muted small">'+Math.floor(a.prog)+' of '+a.need+' min with your phone down</div></div></div>'+
      bar(a.prog / a.need);
    N.queue.forEach((id, i) => { const q = actOf(id);
      s += '<div class="nrow nq"><span class="nsm-tile">'+NART.tile(q.id, look())+'</span><div style="flex:1"><small class="nk">'+(i ? 'Then' : 'Next')+'</small><b>'+esc(q.title)+'</b></div>'+
        '<button class="btn ghost nsm" data-unq="'+i+'">Remove</button></div>'; });
    s += '<p class="muted small" style="margin:8px 0 0">Close Blip and put your phone down. '+esc(N.name)+' does these one after another. Let '+esc(N.name)+' finish each one before you pick up your phone. If your phone comes out early, that one won\'t count, but your Coins come back.</p></div>';
  }
  s += '<h3 class="nh3">Things to do in Barcelona</h3>';
  const full = planIds().length >= PLAN_MAX;
  for (const x of ACTS.concat(festsNow())) {
    const done = N.done[x.id], inPlan = planned(x.id), locked = !unlocked(x), afford = N.coins >= x.cost;
    const label = inPlan ? 'In the plan' : locked ? 'After lesson 1' : full ? 'Plan is full' : !afford ? 'Need '+(x.cost - N.coins) : a ? 'Add to plan' : 'Go';
    s += '<div class="card nact'+(done ? ' ndone' : '')+'">'+(done ? '<span class="nstamped">DONE</span>' : '')+'<div class="npost">'+NART.tile(x.id)+'<div class="nbody"><small class="nk">'+kindOf(x)+'</small><b>'+esc(x.title)+'</b>'+
      '<div class="ncost">'+NART.coin(16)+'<b>'+x.cost+'</b> · '+(x.min >= 60 ? '1 hour' : x.min+' min')+' phone down</div>'+
      (done ? '' : '<button class="btn nsm" data-go="'+x.id+'"'+(inPlan || locked || full || !afford ? ' disabled' : '')+' style="margin-top:8px">'+label+'</button>')+'</div></div></div>';
  }
  return s+'</div>';
}
function passportHTML(){
  const k = N.keyp, dots = (have, need) => '<span class="nkdots">'+Array.from({length: need}, (_, i) => '<i'+(i < have ? ' class="on"' : '')+'></i>').join('')+'</span>';
  const row = (l, have, need) => '<div class="nkrow"><span>'+l+'</span>'+dots(Math.min(have, need), need)+'</div>';
  const born = new Date(N.born || Date.now()), date = born.getDate()+' '+born.toLocaleString('en-US', {month:'short'})+' '+born.getFullYear();
  let s = '<div class="npassbook"><div class="pg"><h2>'+esc(N.name).toUpperCase()+'\'S PASSPORT</h2>'+
    '<div>'+NART.stamp('ESPAÑA', 'Barcelona', date)+'</div>'+
    '<div class="nslot'+(keyDone() ? ' open' : '')+'">NEXT STOP'+NART.keyIcon(keyDone() ? '#ffc84a' : '#e3e6f0', 34)+'<small>'+(keyDone() ? 'Key earned!' : 'Locked')+'</small></div>'+
    '<div class="nslot">MORE<small>Coming soon</small></div>'+
    '<div class="nslot" style="border-style:solid;border-color:#e4d8c4;color:#6d6787">'+N.polaroids.length+'<small>Polaroid'+(N.polaroids.length === 1 ? '' : 's')+'</small></div></div></div>';
  s += '<div class="card" style="margin-top:14px"><div class="nrow2">'+NART.keyIcon('#ffc84a', 36)+'<h3 style="margin:0">Next destination key</h3></div><p class="muted small">Finish Spain\'s goals to earn the key to your next destination.</p>'+
    row('Small adventures', k.small, KEY_NEEDS.small)+row('Big adventure', k.big, KEY_NEEDS.big)+row('Spanish lessons', k.lesson, KEY_NEEDS.lesson)+row('Full shifts (a day under your goal)', k.shift, KEY_NEEDS.shift)+
    (keyDone() ? '<p><b>Key earned! Your next destination opens in a later version of the prototype.</b></p>' : '')+'</div>';
  if (N.polaroids.length) s += '<h3 class="nh3">Photos</h3>'+N.polaroids.slice().reverse().map(id => { const x = actOf(id); return x ? '<div class="card">'+polaroid(x)+realHTML(x)+stampBtnHTML(x)+'</div>' : ''; }).join('');
  return s+passportExtrasHTML();
}
function settingsHTML(){
  return '<div class="card"><h2 style="margin-top:0">Settings</h2><div class="nrow" style="justify-content:space-between"><span>Daily goal</span><span><button class="btn nsm" id="gm">–</button> <b>'+fmtTime(N.goal)+'</b> <button class="btn nsm" id="gp">+</button></span></div>'+
    '<p class="muted small">You choose the goal, and Blip never changes it on its own. A new goal starts tomorrow in the full game. In the prototype it counts right away.</p></div>'+
    liveCardHTML()+
    (IS_APP ? '<div class="card"><h3 style="margin-top:0">⏰ Morning note</h3><div class="switch"><span>One note in the morning when '+esc(N.name)+'\'s news is ready. Never during the day.</span><input type="checkbox" id="rmon" '+(N.remind.on ? 'checked' : '')+'></div>'+
      (N.remind.on ? '<div class="switch"><span>Time</span><input type="time" id="rmtime" value="'+String(N.remind.h).padStart(2, '0')+':'+String(N.remind.m).padStart(2, '0')+'"></div>' : '')+
      (remindNote ? '<p class="muted small">'+esc(remindNote)+'</p>' : '')+'</div>' : '')+
    '<div class="card"><h3 style="margin-top:0">About this prototype</h3><p class="muted small">Blip Nomad, Barcelona only. Your Blip Classic save is kept as it is and doesn\'t age while you try this.</p>'+
    (TF ? '<p class="muted small"><b>Test tools</b> (TestFlight only)</p><button class="btn ghost" id="t30">Add 30 phone-down minutes to the activity</button><button class="btn ghost" id="tuse" style="margin-top:8px">Pretend I used my phone during the activity</button><button class="btn ghost" id="tday" style="margin-top:8px">Pretend a new day started</button><button class="btn ghost" id="treset" style="margin-top:8px">Start Nomad over</button>' : '')+'</div>';
}
function realHTML(x){ return '<div class="nreal"><div class="nrk">Do it for real</div>'+(x.phrase ? '<p class="nphr">"'+esc(nm(x.phrase))+'"<br><small>Say it: '+esc(nm(x.say))+'<br>Means: '+esc(nm(x.mean))+'</small></p>' : '')+'<ul>'+x.real.map(r => '<li>'+esc(r)+'</li>').join('')+'</ul></div>'; }

function draw(){
  const nav = '<div class="nnav1a">'+[['city','📍','Barcelona'],['passport','🛂','Passport'],['settings','⚙️','Settings']].map(t => '<button data-v="'+t[0]+'" class="'+(view === t[0] ? 'on' : '')+'"><b>'+t[1]+'</b>'+t[2]+'</button>').join('')+'</div>';
  app.innerHTML = (view === 'city' ? '' : '<div class="top"><div class="logo">Blip <small>Nomad prototype</small></div><div class="npill">'+NART.coin(24)+N.coins+' <small>'+CUR+'</small></div></div>')+
    (view === 'city' ? cityHTML() : view === 'passport' ? passportHTML() : settingsHTML())+nav;
  app.querySelectorAll('[data-v]').forEach(b => b.onclick = () => { view = b.dataset.v; draw(); window.scrollTo(0, 0); });
  app.querySelectorAll('[data-go]').forEach(b => b.onclick = () => start(b.dataset.go));
  const on = (id, f) => { const e = document.getElementById(id); if (e) e.onclick = f; };
  app.querySelectorAll('[data-unq]').forEach(b => b.onclick = () => unqueue(+b.dataset.unq));
  on('nfin', reveal);
  bindExtras(); bindLive();
  on('gm', () => { N.goal = Math.max(15, N.goal - 15); nsave(); refresh(false); });
  on('gp', () => { N.goal = Math.min(960, N.goal + 15); nsave(); refresh(false); });
  const rm = document.getElementById('rmon');
  if (rm) rm.onchange = () => { N.remind.on = rm.checked; remindNote = ''; nsave(); draw();
    nremindSync().then(ok => { if (!ok && N.remind.on) { N.remind.on = false; nsave(); remindNote = 'Notifications are off for Blip. You can turn them on in iPhone Settings > Notifications > Blip.'; draw(); } }); };
  const rt = document.getElementById('rmtime');
  if (rt) rt.onchange = () => { const [h, m] = rt.value.split(':').map(Number); if (isNaN(h)) return; N.remind.h = h; N.remind.m = m || 0; nsave(); nremindSync(); };
  on('t30', () => { if (N.act) { addDown(30); nsave(); refresh(false); if (N.ready.length) reveal(); } });
  on('tuse', () => { if (N.act) { interrupt(); nsave(); draw(); showMissed(); } });
  on('tday', () => { N.day = yestKey(); nsave(); refresh(false); });
  on('treset', () => { localStorage.removeItem(NKEY); location.reload(); });
}
// Go (nothing running) starts it now; Add to plan lines it up. Either way it is paid now, and then Blip heads off.
function start(id){
  const x = actOf(id); if (!x || N.done[id] || planned(id) || !unlocked(x) || planIds().length >= PLAN_MAX || N.coins < x.cost) return;
  N.coins -= x.cost;
  if (N.act) N.queue.push(id);
  else { begin(id); N.snap = {t: Date.now(), day: todayKey(), m: live.today || 0}; }
  nsave(); draw(); calm(); liveSync();
}
// Taking something out of the plan gives its Coins back. Anything lined up after it that needed it comes out too.
function unqueue(i){
  const id = N.queue[i]; if (id == null) return;
  N.queue.splice(i, 1); N.coins += actOf(id).cost;
  for (let j = N.queue.length - 1; j >= 0; j--) { const q = actOf(N.queue[j]); if (!unlocked(q)) { N.queue.splice(j, 1); N.coins += q.cost; } }
  nsave(); draw(); liveSync();
}
// The calm screen: nothing to tap but the screen itself. Its only job is to send you off.
function calm(){
  const ids = planIds(), now = actOf(ids[0]), later = ids.slice(1).map(actOf);
  const c = document.createElement('div');
  c.className = 'ncalm';
  c.innerHTML = '<div class="ncalmin"><div class="nsamw">'+sam()+'</div><h1>'+esc(N.name)+'\'s off!</h1><p class="ncbig">Put your phone down.</p>'+
    '<p>'+now.emoji+' '+esc(now.title)+(later.length ? '<br><span class="ncsoft">then '+later.map(q => q.emoji+' '+esc(q.title)).join(', then ')+'</span>' : '')+'</p>'+
    '<p class="ncsoft ncfoot">'+esc(N.name)+' is earning '+CUR+' on the boat the whole time. Tap anywhere to come back.</p></div>';
  c.onclick = () => c.remove();
  document.body.appendChild(c);
}
// Polaroids for everything finished while the phone was down, oldest on top.
function reveal(){
  const ids = N.ready.slice(); if (!ids.length) return;
  N.ready = []; nsave(); draw();
  ids.slice().reverse().forEach((id, i) => { const x = actOf(id), last = i === 0;
    modal('<div class="nrk" style="text-align:center">'+(x.gem ? 'Hidden gem found!' : kindOf(x)+' done!')+'</div>'+polaroid(x)+(x.line ? '<p>'+esc(nm(x.line))+'</p>' : '')+realHTML(x)+stampBtnHTML(x)+
      (last && keyDone() ? '<p><b>🔑 That\'s everything for your next destination key!</b></p>' : '')+'<button class="btn" data-close>'+(last ? 'Done' : 'Next photo')+'</button>'); });
  confetti([actOf(ids[0]).emoji, '✨', '📸']);
  bindExtras();
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
  const card = nextPostcard(), tr = t.travel;
  offerTip(); draw();
  modal('<div class="mbig">☀️</div><h2 style="margin:4px 0">Good morning</h2>'+
    (FEAT.framing ? '<p>'+esc(N.name)+'\'s day yesterday: <b>'+t.pay+' '+CUR+'</b>. '+esc(dayLine(t.y, t.pay))+'</p>' : '<p>Yesterday '+esc(N.name)+' earned <b>'+t.pay+' '+CUR+'</b> on the boat.</p>')+
    (t.under ? '<p>You finished '+fmtTime(N.goal - t.m)+' under your goal, so the passengers left <b>'+t.tips+' '+CUR+'</b> in tips. That\'s a full shift toward your next key.</p>' :
      '<p>The shift ended at your goal. '+esc(N.name)+' kept every Coin and is back on the boat at 8 AM.</p>')+
    (tr ? (tr.went ? '<p>🧳 That was travel day number '+N.travel.count+'.'+(tr.pin ? ' '+esc(N.name)+' earned a '+esc(tr.pin.name.toLowerCase())+' '+tr.pin.emoji+' for the backpack!' : '')+'</p>' :
      '<p>🧳 '+esc(N.name)+' took a slow day. That\'s part of travelling.</p>') : '')+
    (card ? postcardHTML(card) : '')+
    (raise ? '<div class="nraise"><p><b>What a week!</b> You were under your goal on 5 of the last 7 days. Want to try 15 minutes less? It\'s your call, and you can change it back any time in Settings.</p>'+
      '<button class="btn" id="nrup" data-close>Try '+fmtTime(N.goal - 15)+'</button><button class="btn ghost" data-close style="margin-top:8px">Keep '+fmtTime(N.goal)+'</button></div>' :
      '<button class="btn" data-close>Let\'s go</button>'));
  const up = document.getElementById('nrup');
  if (up) up.addEventListener('click', () => { N.goal = Math.max(15, N.goal - 15); nsave(); refresh(false); });
}
function welcome(){
  N.welcomed = true; nsave();
  modal('<div class="nwelcome">'+NART.scene({blip: look(), bx: 180})+'</div><div class="nribbon">'+(N.girl ? 'BENVINGUDA!' : 'BENVINGUT!')+'</div><h2 style="margin:4px 0">'+esc(N.name)+' lands in Barcelona!</h2><p>'+esc(N.name)+' arrives with a backpack and <b>150 '+CUR+'</b> saved from home.</p>'+
    '<p class="muted">While your phone is down, '+esc(N.name)+' crews a sailing boat in the old harbor and earns '+CUR+'. Spend them on lessons, friends and adventures. Every one is something you can really do.</p>'+
    '<p class="muted small">'+(N.girl ? 'Benvinguda' : 'Benvingut')+' is Catalan for "welcome". '+COIN_RULE+'</p><button class="btn" data-close id="nwel">Let\'s explore</button>');
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

// ======================= Build 30 extras (mechanics plan v1, Phase 2 and Monthly) =======================
// Each one can be switched off here.
const FEAT = {stamps:true, tips:true, framing:true, travel:true, postcards:true, festivals:true, gems:true};   // all four OK'd by the Lawyer 2026-11-19
N.fin = N.fin || {};          // day -> activities finished that day (for travel days; kept 14 days)
N.travel = N.travel || {count:0, days:{}};   // travel-day total, and day -> true/false for the last 14 days
N.pins = N.pins || [];        // cosmetic backpack pins
N.real = N.real || {};        // "I did it for real" gold stamps: activity id -> day
N.tip = N.tip || null;        // the tip card on offer: {id, day}
N.tipsDone = N.tipsDone || {};
N.met = N.met || {};          // friend id -> day met (for postcards)
N.cards = N.cards || [];      // postcards received: {from, text, day}
N.gems = N.gems || [];        // hidden gems found, by id
function daysBetween(a, b){ return Math.round((new Date(b) - new Date(a)) / 864e5); }
function trim14(o){ const d = new Date(); d.setDate(d.getDate() - 14); for (const k in o) if (k < key(d)) delete o[k]; }

// ---- Travel days instead of a streak: a low bar, rest days built in, nothing ever taken away ----
const TRAVEL_PINS = [{n:3, emoji:'🧭', name:'Compass pin'}, {n:7, emoji:'🎒', name:'Backpack patch'}, {n:14, emoji:'🗺️', name:'Map pin'}, {n:21, emoji:'⛰️', name:'Mountain pin'}, {n:30, emoji:'🌍', name:'Globe pin'}];
function travelToday(){ return (N.fin[todayKey()] || 0) > 0 || (N.credited[todayKey()] || 0) >= 12; }
// Called when a day is settled. Returns what the morning note says about it.
function settleTravel(y, pay){
  if (!FEAT.travel) return null;
  const went = (N.fin[y] || 0) > 0 || pay >= 12;
  N.travel.days[y] = went; trim14(N.travel.days); trim14(N.fin);
  let pin = null;
  if (went) { N.travel.count++; pin = TRAVEL_PINS.find(p => p.n === N.travel.count) || null; if (pin && N.pins.indexOf(pin.emoji) < 0) N.pins.push(pin.emoji); }
  return {went, pin};
}
function weekRowHTML(){
  const d = new Date(); d.setDate(d.getDate() - 6); let s = '';
  for (let i = 0; i < 7; i++) { const k = key(d), today = k === todayKey(), went = today ? travelToday() : N.travel.days[k];
    s += '<span class="ntd'+(went ? ' on' : '')+'">'+'SMTWTFS'[d.getDay()]+'</span>'; d.setDate(d.getDate() + 1); }
  return s;
}
function travelCardHTML(){
  if (!FEAT.travel) return '';
  const wk = Object.keys(N.travel.days).filter(k => daysBetween(k, todayKey()) < 7 && N.travel.days[k]).length + (travelToday() ? 1 : 0);
  return '<div class="card ntravel"><div class="nrow" style="justify-content:space-between"><b>🧳 Travel days: '+(N.travel.count + (travelToday() ? 1 : 0))+'</b><span class="muted small">'+Math.min(wk, 7)+' this week</span></div>'+
    '<div class="ntdrow">'+weekRowHTML()+'</div><p class="muted small" style="margin:6px 0 0">'+(travelToday() ? 'Today counts as a travel day. ✓' :
      'A day counts when '+esc(N.name)+' finishes something or works an hour of shift. Two slow days a week are part of travelling.')+'</p></div>';
}

// ---- "I did it for real": honor system, cosmetic gold stamp, no proof, no Coins ----
function stampable(x){ return FEAT.stamps && x && x.home; }
function stampBtnHTML(x){
  if (!stampable(x)) return '';
  return N.real[x.id] ? '<p class="nreal-ok">🏅 '+esc(x.home)+'</p>' : '<button class="btn ghost nsm nreal-btn" data-real="'+x.id+'">I did it for real</button>';
}
function markReal(id){ const x = actOf(id); if (!stampable(x) || N.real[id]) return; N.real[id] = todayKey(); nsave(); confetti(['🏅', '✨']); draw();
  document.querySelectorAll('[data-real="'+id+'"]').forEach(b => { b.outerHTML = '<p class="nreal-ok">🏅 '+esc(x.home)+'</p>'; }); }

// ---- Real-world tip cards: one every few days, invitations only (Lawyer wording), "I tried it" earns a pin ----
const TIPS = [
  {id:'gray', emoji:'⚫', text:'Try grayscale with a triple-click. Set it up once, then switch it on or off from anywhere.', yes:'I set it up', followup:'grayauto',
    steps:['Open Settings > Accessibility > Display & Text Size > Color Filters and pick Grayscale (leave the switch off).', 'Go back to Accessibility > Accessibility Shortcut and tick Color Filters.', 'Triple-click the side button to turn grayscale on. Triple-click again for color.'],
    pin:'🎞️', pinName:'Black-and-white film pin'},
  {id:'grayauto', emoji:'🌙', text:'Want it automatic? Your iPhone can switch to grayscale every evening and back to color in the morning.', yes:'I set it up', followup:true,
    steps:['Open the Shortcuts app and tap Automation, then +.', 'Pick Time of Day, set 9:00 PM, Daily, and choose Run Immediately.', 'Tap New Blank Automation, add the action Set Color Filters, and set it to On.', 'Make one more for 7:00 AM with Set Color Filters set to Off.'],
    pin:'🌙', pinName:'Moon pin'},
  {id:'charge', emoji:'🔌', text:'Tonight, charge your phone outside the bedroom. Use a clock for your alarm if you can.', pin:'⏰', pinName:'Alarm clock pin'},
  {id:'walk', emoji:'🚶', text:'Take a short walk with your phone in your pocket the whole way.', pin:'👟', pinName:'Walking shoe pin'},
  {id:'dinner', emoji:'🍽️', text:'Tonight, put your phone in another room while you eat.', pin:'🍴', pinName:'Fork and knife pin'},
  {id:'home', emoji:'📱', text:'Try moving your most-used app off your home screen for a day.', pin:'🏠', pinName:'Little house pin'},
  {id:'book', emoji:'📖', text:'Try reading a few pages of a paper book before bed.', pin:'📚', pinName:'Book pin'}
];
const TIP_EVERY = 3;   // days between tip cards
function tipOf(id){ return TIPS.find(t => t.id === id); }
function offerTip(){
  if (!FEAT.tips || (N.tip && !N.tip.done)) return;
  if (N.tip && daysBetween(N.tip.day, todayKey()) < TIP_EVERY) return;
  const next = TIPS.find(t => !N.tipsDone[t.id] && t.followup !== true); if (!next) return;
  N.tip = {id: next.id, day: todayKey()}; nsave();
}
function tipCardHTML(){
  if (!FEAT.tips || !N.tip || N.tip.done) return '';
  const t = tipOf(N.tip.id); if (!t) return '';
  return '<div class="card ntip"><small class="nk">An idea from '+esc(N.name)+'</small><p class="ntiptext">'+t.emoji+' '+esc(t.text)+'</p>'+
    (t.steps ? '<ol class="ntipsteps">'+t.steps.map(x => '<li>'+esc(x)+'</li>').join('')+'</ol>' : '')+(t.note ? '<p class="muted small">'+esc(t.note)+'</p>' : '')+
    '<div class="nrow"><button class="btn nsm" id="ntipyes">'+esc(t.yes || 'I tried it')+'</button><button class="btn ghost nsm" id="ntipno">Not this time</button></div></div>';
}
function answerTip(tried){
  const t = N.tip && tipOf(N.tip.id); if (!t) return;
  N.tipsDone[t.id] = tried ? 'tried' : 'skipped'; N.tip.done = true;
  if (tried && N.pins.indexOf(t.pin) < 0) N.pins.push(t.pin);
  // A tip with a follow-up (grayscale -> automatic grayscale) offers it right away, only after "I set it up".
  if (tried && typeof t.followup === 'string' && !N.tipsDone[t.followup]) N.tip = {id: t.followup, day: todayKey()};
  nsave(); draw();
  if (tried) { modal('<div class="mbig">'+t.pin+'</div><h2 style="margin:4px 0">Nice one!</h2><p>'+esc(N.name)+' pins a '+esc(t.pinName.toLowerCase())+' to the backpack.</p><button class="btn" data-close>OK</button>'); confetti([t.pin, '✨']); }
}

// ---- Coins framing: Blip's day, not a pay slip ----
const DAY_LINES = [
  'Sailed {n} passengers from {c} countries past the beaches.', 'Coiled every rope on deck into a perfect spiral.', 'Learned to tie a bowline without looking.',
  'Helped hoist the mainsail as the boat left Port Vell.', 'Spotted the Sagrada Família towers from out at sea.', 'Learned the Catalan for "good morning" from the skipper: "Bon dia!"',
  'Scrubbed the deck until it shone.', 'Pointed out Montjuïc to {n} passengers as the sun went down.'
];
function dayLine(day, coins){
  if (!coins) return 'The boat leaves the harbor at 8 AM.';
  let h = 0; for (const ch of day) h = (h * 31 + ch.charCodeAt(0)) % 997;
  return DAY_LINES[h % DAY_LINES.length].replace('{n}', Math.min(12, Math.max(2, Math.floor(coins / 12)))).replace('{c}', 2 + h % 5);
}

// ---- Postcards from friends you met: at the morning note, at most one a morning ----
const POSTCARDS = {
  laia: [
    {after:1, text:'Everyone at the hostel asks how sailing is going! Next time, walk the Carretera de les Aigües: flat, quiet, and the whole city below you. Fins aviat! (See you soon!) Laia'},
    {after:4, text:'Rooftop evening at the hostel on Friday. Everyone brings one phrase in a new language. I\'m doing Italian. Laia'},
    {after:8, text:'The Christmas market by the Cathedral, the Fira de Santa Llúcia, has run since 1786. Come and see the tiny nativity figures with me in December! Laia'}
  ]
};
const FRIEND_NAMES = {laia:'Laia'};
function nextPostcard(){
  if (!FEAT.postcards) return null;
  for (const f in N.met) {
    const sent = N.cards.filter(c => c.from === f).length, card = (POSTCARDS[f] || [])[sent];
    if (card && daysBetween(N.met[f], todayKey()) >= card.after) { const c = {from: f, text: card.text, day: todayKey()}; N.cards.push(c); nsave(); return c; }
  }
  return null;
}
function postcardHTML(c){ return '<div class="npcard"><div class="npcardfrom">📮 A postcard from '+esc(FRIEND_NAMES[c.from] || c.from)+'</div><p>'+esc(nm(c.text))+'</p></div>'; }

// ---- Real festivals on their real dates: limited-time activities (not part of the key) ----
const FESTS = [
  {id:'castanyada', from:'10-25', to:'11-01', kind:'small', fest:true, emoji:'🌰', title:'La Castanyada: roast chestnuts', cost:150, min:30,
    line:'{name} helps a street stall roast chestnuts and sweet potatoes, and tries panellets, little almond sweets.',
    real:['La Castanyada is Catalonia\'s chestnut festival around All Saints\' Day (1 November).', 'Chestnut sellers set up street stalls in Barcelona from late October.', 'Tip: panellets are easy to make at home with ground almonds, sugar, egg and pine nuts.']},
  {id:'santallucia', from:'11-27', to:'12-23', kind:'small', fest:true, emoji:'🎄', title:'Fira de Santa Llúcia Christmas market', cost:150, min:30,
    line:'{name} wanders the stalls in front of Barcelona Cathedral, full of moss, little trees and hand-painted nativity figures.',
    real:['The Fira de Santa Llúcia has been held near Barcelona Cathedral since 1786.', 'It usually runs from late November to 23 December. Dates change a little each year, so check before you go.', 'Tip: go on a weekday evening when the lights are on and the crowds are smaller.']},
  {id:'reis', from:'01-02', to:'01-05', kind:'small', fest:true, emoji:'👑', title:'The Three Kings parade', cost:150, min:30,
    line:'{name} joins the crowds on the evening of 5 January as the Three Kings arrive by boat and parade through the city.',
    real:['The Cavalcada de Reis usually takes place on the evening of 5 January, the night before Epiphany.', 'In Barcelona the Kings traditionally arrive at the port by boat, then parade through the city.', 'Tip: find your spot early along the route. Families bring step stools for children to see.']},
  {id:'gracia', from:'08-14', to:'08-21', kind:'small', fest:true, emoji:'🎏', title:'Festa Major de Gràcia street decorations', cost:150, min:30,
    line:'{name} helps neighbors hang handmade decorations, turning a whole street into an underwater world.',
    real:['During the Festa Major de Gràcia, usually in mid-August, neighbors decorate their streets and compete for the best one.', 'The decorations are made by hand over months, often from recycled materials.', 'Tip: visit in the daytime to see the details, and come back at night for the lights and concerts.']},
  {id:'merce', from:'09-20', to:'09-24', kind:'small', fest:true, emoji:'🏰', title:'Human towers at La Mercè', cost:150, min:30,
    line:'{name} watches teams of castellers build human towers up to nine people high in Plaça de Sant Jaume.',
    real:['La Mercè is Barcelona\'s biggest festival, usually held around 24 September.', 'Castells (human towers) are on UNESCO\'s list of Intangible Cultural Heritage.', 'Tip: watch from the crowd and get to Plaça de Sant Jaume early. The square fills up long before the towers start.']}
];
function mmdd(d){ return String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0'); }
function festOn(f, d){ const t = mmdd(d || new Date()); return f.from <= f.to ? t >= f.from && t <= f.to : t >= f.from || t <= f.to; }
function festsNow(){ return FEAT.festivals ? FESTS.filter(f => festOn(f) || planned(f.id) || N.ready.indexOf(f.id) >= 0) : []; }
function festNext(){
  if (!FEAT.festivals) return null;
  const d = new Date();
  for (let i = 1; i <= 45; i++) { d.setDate(d.getDate() + 1); const f = FESTS.find(z => z.from === mmdd(d)); if (f) return {f, days: i}; }
  return null;
}
function festCardHTML(){
  const n = festNext(); if (!n || festsNow().length) return '';
  return '<div class="card nfest"><div class="npost">'+NART.tile(n.f.id, look())+'<div class="nbody"><small class="nk">Coming up in Barcelona</small><b>'+esc(n.f.title)+'</b><div class="muted small">Opens in '+n.days+' day'+(n.days > 1 ? 's' : '')+'. Here for a short time only, like the real thing.</div></div></div></div>';
}

// ---- Hidden gems: a long phone-down stretch (about 2 hours) lets Blip find a lesser-known spot ----
const GEMS = [
  {id:'aigues', kind:'small', gem:true, emoji:'🌲', title:'Hidden gem: Carretera de les Aigües', line:'{name} finds a flat old path along the hills, with the whole city and the sea below.',
    real:['The Carretera de les Aigües is an old service road along the Collserola hills, about 10 km long and almost flat.', 'The Vallvidrera funicular stops close to it.', 'Tip: go early in the morning or near sunset. It is popular with runners and cyclists, so keep to the side.']},
  {id:'cactus', kind:'small', gem:true, emoji:'🌵', title:'Hidden gem: the Montjuïc cactus garden', line:'{name} discovers a hillside garden of giant cacti looking out over the port.',
    real:['The Jardins de Mossèn Costa i Llobera on Montjuïc hold one of Europe\'s largest collections of cacti and succulents.', 'Entry is free.', 'Tip: wear proper shoes. The paths are steep, and some of the cacti are taller than you.']},
  {id:'santpau', kind:'small', gem:true, emoji:'🏛️', title:'Hidden gem: the Sant Pau Art Nouveau site', line:'{name} wanders through a former hospital built like a garden city, with tiled domes and mosaics.',
    real:['The Sant Pau Recinte Modernista was designed by Lluís Domènech i Montaner and is a UNESCO World Heritage site.', 'It worked as a hospital until 2009 and is now open to visitors.', 'Tip: it is a short walk from the Sagrada Família, so you can see both in one day.']}
];
const GEM_MIN = 120;   // minutes Blip was closed, between 8 AM and 10 PM, with Blip's count up less than 5 minutes
function checkGem(closedAt, mins, used){
  if (!FEAT.gems || mins < GEM_MIN || used >= 5) return;
  const a = new Date(closedAt), b = new Date();
  if (key(a) !== key(b) || a.getHours() < SHIFT_FROM || b.getHours() >= SHIFT_TO) return;
  if (N.gemDay === todayKey()) return;
  const g = GEMS.find(z => N.gems.indexOf(z.id) < 0); if (!g) return;
  N.gems.push(g.id); N.gemDay = todayKey(); N.ready.push(g.id); N.polaroids.push(g.id);
  N.fin[todayKey()] = (N.fin[todayKey()] || 0) + 1;
}

// ---- Passport extras: travel pins, gold stamps, postcards, hidden gems ----
function passportExtrasHTML(){
  let s = '';
  const pins = N.pins.slice();
  if (FEAT.travel || FEAT.tips) s += '<div class="card"><h3 style="margin-top:0">🎒 Backpack pins</h3>'+(pins.length ? '<div class="npins">'+pins.map(p => '<span>'+p+'</span>').join('')+'</div>' :
    '<p class="muted small">'+(FEAT.travel ? 'Travel days and tips you try add pins to '+esc(N.name)+'\'s backpack.' : 'Tips you try add pins to '+esc(N.name)+'\'s backpack.')+'</p>')+'</div>';
  const reals = Object.keys(N.real).map(actOf).filter(Boolean);
  if (FEAT.stamps) s += '<div class="card"><h3 style="margin-top:0">🏅 Made it for real</h3>'+(reals.length ? reals.map(x => '<div class="nkrow"><span>'+x.emoji+' '+esc(x.home)+'</span><b>🏅</b></div>').join('') :
    '<p class="muted small">Tried a phrase or a recipe in real life? Tap "I did it for real" on its photo for a gold stamp.</p>')+'</div>';
  if (FEAT.gems) s += '<div class="card"><h3 style="margin-top:0">💎 Hidden gems of Barcelona</h3><p class="muted small">Leave your phone alone for about 2 hours in the daytime and '+esc(N.name)+' may find one.</p>'+
    GEMS.map(g => '<div class="nkrow"><span>'+(N.gems.indexOf(g.id) >= 0 ? g.emoji+' '+esc(g.title.replace('Hidden gem: ', '')) : '❔ Not found yet')+'</span></div>').join('')+'</div>';
  if (FEAT.postcards && N.cards.length) s += '<h3 class="nh3">Postcards</h3>'+N.cards.slice().reverse().map(c => '<div class="card">'+postcardHTML(c)+'</div>').join('');
  return s;
}
function bindExtras(){
  document.querySelectorAll('[data-real]').forEach(b => b.onclick = ev => { ev.stopPropagation(); markReal(b.dataset.real); });
  const y = document.getElementById('ntipyes'), n = document.getElementById('ntipno');
  if (y) y.onclick = () => answerTip(true);
  if (n) n.onclick = () => answerTip(false);
}

// ======================= Lock-screen countdown (Live Activity) =======================
// Lawyer OK 2026-11-20: started only by the player's tap, game text only, status only (never shop items, prices or promotions),
// can be switched off in Settings. The countdown runs on real time; opening Blip corrects it, or ends it (an activity only counts if the phone stays down).
N.live = N.live == null ? true : N.live;
let liveIconSent = false;
const liveOK = () => { const p = P(); return !!(p && p.liveStart); };
function livePNG(){
  return new Promise((ok, no) => {
    const w = 120, h = 144, t = NART.blipSVG(look()).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" width="'+w+'" height="'+h+'" ');
    const img = new Image();
    img.onload = () => { const cv = document.createElement('canvas'); cv.width = w; cv.height = h; cv.getContext('2d').drawImage(img, 0, 0, w, h); ok(cv.toDataURL('image/png').split(',')[1]); };
    img.onerror = no; img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(t);
  });
}
// Shows (or updates) the countdown for the activity running now, or clears it when nothing is running.
function liveSync(){
  if (!liveOK()) return;
  const p = P();
  if (!N.live || !N.act) { p.liveEnd().catch(() => {}); return; }
  const x = actOf(N.act.id), left = Math.max(1, N.act.need - N.act.prog), nx = N.queue[0] ? actOf(N.queue[0]) : null;
  const send = icon => p.liveStart(Object.assign({name: N.name, title: x.title, emoji: x.emoji, next: nx ? nx.title : '', endsAt: Date.now() + left * 60000}, icon ? {icon} : {})).catch(() => {});
  if (liveIconSent) send();
  else livePNG().then(icon => { liveIconSent = true; send(icon); }).catch(() => send());
}
function liveCardHTML(){
  if (!liveOK()) return '';
  return '<div class="card"><h3 style="margin-top:0">🔒 Lock-screen countdown</h3><div class="switch"><span>When '+esc(N.name)+' heads off, show the countdown on your lock screen.</span><input type="checkbox" id="lvon" '+(N.live ? 'checked' : '')+'></div></div>';
}
function bindLive(){ const c = document.getElementById('lvon'); if (c) c.onchange = () => { N.live = c.checked; nsave(); liveSync(); }; }

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

// ---------- mechanics styles (Builder): plain classes for the new screens; the Designer may restyle these ----------
document.head.insertAdjacentHTML('beforeend', '<style>'+
  '.ntdrow{display:flex;gap:6px;margin-top:8px}.ntd{flex:1;text-align:center;font-size:12px;font-weight:700;padding:6px 0;border-radius:10px;background:#eee8dd;color:#9a92a8}.ntd.on{background:#ffc84a;color:#3b2a4a}'+
  '.ntipsteps{margin:0 0 8px;padding-left:20px;font-size:14px}.ntipsteps li{margin:3px 0}.ntip .ntiptext{font-size:16px;margin:6px 0 10px}.ntip .nrow{gap:8px}.nfest b{display:block}.npins{display:flex;flex-wrap:wrap;gap:10px;font-size:30px}'+
  '.npcard{background:#fffaf0;border:2px dashed #c9a46a;border-radius:12px;padding:10px 12px;margin:10px 0;text-align:left;transform:rotate(-1deg)}.npcardfrom{font-size:12px;font-weight:700;color:#a8402a;text-transform:uppercase;letter-spacing:.5px}.npcard p{margin:6px 0 0}'+
  '.nreal-btn{margin:6px 0 4px}.nreal-ok{font-weight:600;color:#a87b00;margin:6px 0}'+
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
