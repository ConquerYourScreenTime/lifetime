# Blip friends game (build 1, 2026-11-25)

The phone app now runs `friends/index.html` (see `app/scripts/copy-web.js`). The website (`index.html` on main) and
Blip Classic (branch `blip-classic`) are unchanged.

- Points: everyone starts each day with 1,000. Every 15 minutes in a tier costs Red 40, Orange 20, Yellow 10, Free 0.
  Same for every player. Tiers are fixed Apple categories the player ticks in Apple's picker.
- Native: `ScreenTimePlugin.swift` (`tierPick`, `tierStatus`, `friendsStart`, `friendsResync`, `friendsMinutes`,
  `friendsSync`, `friendsWipe`) and `BlipMonitor/MonitorExtension.swift` (watchers `tier-red|orange|yellow` in
  15-minute steps; `fclock` wakes it just after midnight to send yesterday's points total). The `Friends` enum is
  copied in both files: keep them identical.
- Online: Firebase (anonymous sign-in + Firestore, REST, no SDK). Keys in `friends/config.js`, rules in
  `friends/firestore.rules`. Only `{uid, day, points, at}` per finished day leaves the phone. Totals deleted after 30 days.
- Morning notification at the player's chosen time (default 8 AM), never at midnight.

Before the App Store (Lawyer 2026-11-25): update privacy.html and the App Store privacy label (points total,
anonymous ID, Firebase), App Review note, age rating 13+, remove the "Practice against a pretend friend" button
(TestFlight only) and the BlipWidget/Nomad leftovers, no money bets anywhere.
