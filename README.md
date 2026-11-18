# Boundary — Flutter app

A Flutter port of the **Boundary** cricket club web app (HTML/CSS/JS + Firebase).
It talks to the **same Firebase project, collections and security rules** as the
web app, so clubs, squads, tournaments and live scores are shared between the
two. A match can even be scored on the phone while spectators watch it on the
website.

| Web page | Flutter screen |
|---|---|
| `index.html` | `features/landing/landing_screen.dart` (+ auth sheet, public standings) |
| `dashboard.html` | `features/dashboard/dashboard_screen.dart` |
| `club.html` | `features/club/club_screen.dart` |
| `tournaments.html` | `features/tournaments/tournaments_screen.dart` |
| `matches.html` | `features/matches/matches_screen.dart` |
| `scoring.html` | `features/scoring/scoring_screen.dart` |
| `scorecard.html` | `features/scorecard/scorecard_screen.dart` |
| `public-scorecard.html` | `PublicScorecardScreen` (same file) |
| `Livematches.html` | `features/public/live_matches_screen.dart` |

See **[CONVERSION_GUIDE.md](CONVERSION_GUIDE.md)** for the HTML→widget, CSS→Flutter
and JavaScript→Dart mappings.

---

## Quick start

You need Flutter **3.44 or newer** (see "Material import" below for older versions).

```bash
# 1. Generate the android/ ios/ web/ platform folders around this code
flutter create . --project-name boundary --org com.boundary --platforms=android,ios,web

# 2. The generator adds a sample test that does not apply to this app. Remove it:
rm test/widget_test.dart

# 3. Install dependencies
flutter pub get

# 4. Connect the native apps to your Firebase project
dart pub global activate flutterfire_cli
flutterfire configure --project=boundary-4b4e8      # overwrites lib/firebase_options.dart

# 5. Run
flutter run
```

**Platform notes** (only if the build complains): Firebase needs Android
`minSdk 23` (`android/app/build.gradle(.kts)`) and a recent iOS deployment
target (`ios/Podfile`: `platform :ios, '15.0'`).

### Firebase checklist

* **Authentication → Email/Password** is enabled (already true for the web app).
* **Firestore rules** are published from `firebase/firestore.rules`
  (a verbatim copy of the web project's rules):
  `firebase deploy --only firestore:rules`. No index changes are needed; every
  query is a single-field equality.
* The first user who creates a club becomes its `club_admin`, exactly as on the
  web.

### Run the tests

```bash
flutter test
```

53 tests cover the cricket rules (delivery handling, overs/bowler limits,
strike rotation, wickets, undo, results), standings/net run rate, scorecards and
Firestore (de)serialization. They are pure Dart and need no Firebase.

---

## Architecture

```
lib/
├── main.dart                 Firebase init → runApp
├── app.dart                  MaterialApp, theme, route table
├── app_services.dart         AppServices (repositories) + AppScope (InheritedWidget)
├── firebase_options.dart     Firebase config (web filled in; run flutterfire for mobile)
│
├── core/
│   ├── ui.dart               ★ single import point for the Material library
│   ├── routes.dart           route names + typed arguments
│   └── theme/                design tokens (colors, fonts, ThemeData)
│
├── domain/                   PURE DART: no Flutter, no Firebase  (unit-tested)
│   ├── constants.dart        collection names, roles, statuses, dropdown options
│   ├── models/               Club, Team, Player, Tournament, CricketMatch,
│   │                         Innings, Delivery, MatchScore, Public* snapshots
│   └── scoring/
│       ├── scoring_engine.dart   the rules of the scorer (port of scoring.js)
│       ├── scorecard.dart        batting/bowling rows, extras, FOW, overs
│       ├── standings.dart        points + net run rate
│       └── formatters.dart       overs / strike rate / economy / NRR text
│
├── data/                     Firebase only; one repository per concern
│   └── repositories/         auth, club, roster, tournament, match, score, public
│
├── features/                 one folder per screen, with its own widgets
│   ├── landing/ auth/ dashboard/ club/ tournaments/ matches/
│   ├── scoring/              controller + run pad + dialogs
│   ├── scorecard/ public/
│
└── shared/widgets/           reusable UI: cards, form fields, scorecard tables…
```

**Layering rule:** `domain` imports nothing from Flutter or Firebase; `data`
imports `domain`; `features` import `data` + `domain`. That is what makes the
scoring engine testable and keeps the Firestore schema in one place.

**State management** uses only built-in Flutter tools (no extra packages):
`ChangeNotifier` controllers (`ClubWorkspaceController`, `ScoringController`)
with `ListenableBuilder`, `StreamBuilder` for Firestore streams, and an
`InheritedWidget` (`AppScope`) for dependency injection. Swapping in
Provider/Riverpod later only touches `app_services.dart` and the screens'
`build` methods.

**Material import:** every file imports `core/ui.dart`, which re-exports
`package:material_ui/material_ui.dart` (Flutter 3.44+ moved Material into a
standalone package and deprecated `package:flutter/material.dart`). On an older
Flutter, change that one line to
`export 'package:flutter/material.dart';` and remove `material_ui` from
`pubspec.yaml`. Both variants were analyzed (see below).

**Fonts:** `google_fonts` downloads DM Sans / Manrope / Anton on first use. For
fully offline builds, download the font files into `assets/fonts/`, declare
them in `pubspec.yaml`, and set `GoogleFonts.config.allowRuntimeFetching = false`.

---

## Behaviour changes from the web app

Most of the code is a faithful port. These are the deliberate differences
(mostly bug fixes found while reading the JavaScript):

| Area | Web app | Flutter app |
|---|---|---|
| Byes / leg-byes on the private scorecard | Always showed 0 (`scorecard.js` summed `batterRuns`, which is 0 for those balls) | Counted correctly, and penalty runs get their own figure |
| Fall of wickets | Named the **striker** even if the non-striker was run out | Names the batter actually dismissed |
| Next bowler after an over | Free-text `prompt()`; cancelling it still saved the ball and left the scorer stuck on the same bowler | Picker lists only eligible bowlers with their overs; cancelling **does not record the ball** |
| Second innings | Batting team freely selectable | Forced to the side that bowled first |
| Undo | Rebuilt from the scorer's local copy | Rebuilt inside a transaction from the latest server state (safe with two scorers) |
| Bowling style "None" | Stored `Left-arm medium` (several options shared a value) | Stored as empty; every style has its own value; legacy values still display |
| Dismissal picker | Any batter at the crease for any dismissal | Non-striker only for run-out / retired hurt |
| Penalty runs | `0` silently became `5` | UI requires 1–100 (engine keeps the web rule) |
| Standings query | Downloaded **all** `publicMatchScores` documents | Server-side filter `status == completed` (identical result, far fewer reads) |
| Data loading | One-shot reads, manual refresh | Live Firestore streams for teams, players, tournaments, matches and scores |
| Unknown fields | n/a | Fields written by other clients on an innings are preserved on write |

Quirks kept on purpose so both apps score identically: no striker change is
applied on wicket balls, an innings ends at 10 wickets, bowler over limits
(3 under 15 overs, 4 in T20, 10 in ODI, otherwise ⌈overs/5⌉), and
`c ? b Bowler` for catches (the fielder is not recorded).

Not ported: `js/react/BoundarySportsDashboard.jsx` (not part of the web build —
its tabbed live view and dismissal text are merged into the Live Match Centre),
the empty `Tournamentpage.js`, the `dist/` build output and Vite config, and
`scripts/bootstrap-admin.js` (a Node admin tool; keep using it from the web repo).

---

## How this was verified — and what was not

Verified in a sandbox with the real Dart SDK (3.14):

* **53 unit tests pass** (`test/`).
* **`dart analyze` reports 0 issues** on all of `lib/` and `test/`, including the main
  `flutter_lints` rules (enabled individually), against the **actual Flutter framework source** and the
  real `material_ui` package; also re-checked with `package:flutter/material.dart`.
* `dart format` is clean.

**Not verified** (no Flutter SDK, device, or pub.dev access in the sandbox):

* The app has **not been run** on an emulator/device, so layout and visual
  fidelity against the web app are untested. Expect small spacing tweaks.
* Calls into `firebase_auth`, `cloud_firestore`, `firebase_core` and
  `google_fonts` were checked against stubs of those packages' APIs, not the
  published packages. Run `flutter analyze` after `flutter pub get`; if a
  Firebase major version changed a signature, the fix will be local to
  `lib/data/`.
* Security rules were not re-tested; they are unchanged.
