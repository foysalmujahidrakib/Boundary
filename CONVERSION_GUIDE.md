# Conversion guide: web → Flutter

How each part of the Boundary web project maps to this Flutter project. Use it
to find where something moved, or as a pattern when you port the next page.

---

## 1. HTML structure → Flutter widgets

| HTML / web pattern | Flutter equivalent | Where |
|---|---|---|
| `<body>` page + `<main class="container">` | `Scaffold` + `ListView` + `ContentWidth` (centered, max 1120px) | `WorkspaceScaffold`, `ContentWidth` |
| `<header class="topbar">` with brand + links | `AppBar` with `BrandLogo` + `PopupMenuButton` | `landing_screen.dart`, `workspace_scaffold.dart` |
| `<div class="card">` | `AppCard` / `SectionCard` (`Material` + rounded border) | `shared/widgets/app_card.dart` |
| CSS grid / flex rows | `Row`, `Column`, `Wrap`, `Expanded` | everywhere |
| 2-column grid that collapses < 900px | `TwoColumn` (`LayoutBuilder` breakpoint) | `shared/widgets/responsive.dart` |
| `<ul>` / repeated `innerHTML` templates | `ListView` / `for` loops inside a `Column` | `club_screen.dart`, `matches_screen.dart` |
| Collapsible team + players | `ExpansionTile` | `club_screen.dart` |
| `<table>` | `Table` with a flexible first column and fixed numeric columns | `StatTable` in `scorecard_widgets.dart` |
| `<form>` + `<input>` + validation | `Form` + `TextFormField` + `validator` | `*_form_sheet.dart`, `auth_sheet.dart` |
| `<select>` | `DropdownButtonFormField` via `OptionDropdown` (keeps unknown legacy values) | `option_dropdown.dart` |
| `<input type="date">` / `type="time"` | `showDatePicker` / `showTimePicker` via `DateField` / `TimeField` | `date_time_fields.dart` |
| `<input type="checkbox">` list (tournament teams) | `CheckboxListTile` | `tournament_form_sheet.dart` |
| Modal overlay (`#authModal`, team/player/match forms) | `showModalBottomSheet` (keyboard-aware) | `form_sheet.dart`, `auth_sheet.dart` |
| `#wicketModal`, `#extrasModal` | `AlertDialog` | `scoring_dialogs.dart` |
| `window.confirm` / `alert` / `prompt` | `confirmDialog` / `alertDialog` / `showNextBowlerDialog` | `feedback.dart`, `scoring_dialogs.dart` |
| `#toast` | `SnackBar` via `showToast` | `feedback.dart` |
| `.notice`, `.empty-state` | `NoticeBanner`, `EmptyState` | `feedback.dart` |
| `.status-chip` | `StatusChip` | `feedback.dart` |
| Tabs in the live match centre | `DefaultTabController` + `TabBar` + `TabBarView` | `live_matches_screen.dart` |
| Ball chips (`.ball-chip`) | `BallChip` (circle, colour by delivery type) | `ball_chip.dart` |
| Scoring keypad (`.score-btn`) | `GridView.count` of `Material` + `InkWell` buttons | `run_pad.dart` |
| Page links (`<a href="club.html?clubId=…">`) | `Navigator.pushNamed(route, arguments: ClubArgs(id))` | `core/routes.dart`, `app.dart` |
| Auth redirect (`onAuthStateChanged` → `index.html`) | `RequireAuth` wrapper widget | `require_auth.dart` |

## 2. CSS → Flutter styling

Design tokens come from `:root` in `css/style.css` and live in
`core/theme/app_colors.dart`.

| CSS token | Value | Flutter |
|---|---|---|
| `--pale` (page background) | `#0b121e` | `AppColors.canvas` → `scaffoldBackgroundColor` |
| `--surface` (cards) | `#111c2d` | `AppColors.surface` → `ColorScheme.surface`, `cardTheme` |
| hero gradient end | `#1a293e` | `AppColors.surfaceRaised` |
| `--blue` / mint accent | `#00ffc2` | `AppColors.mint` → `ColorScheme.primary` |
| `--accent-orange` / alert | `#ff5e1e` | `AppColors.orange` → `ColorScheme.secondary` |
| `--muted` | `#64748b` | `AppColors.muted` |
| `--line` | `rgba(100,116,139,.38)` | `AppColors.line` (`0x6164748B`) |
| status chip colours | pastel pairs | `StatusColors.of(status)` |

| CSS concept | Flutter |
|---|---|
| `font-family: DM Sans` / `Manrope 800` / `Anton` | `AppText.body()` / `AppText.heading()` / `AppText.score()` (via `google_fonts`) |
| `.eyebrow` (small spaced caps) | `Eyebrow` widget + `AppText.eyebrow()` |
| `border-radius`, `border: 1px solid var(--line)` | `BoxDecoration(borderRadius:, border:)` / `RoundedRectangleBorder(side:)` |
| `padding` / `margin` / `gap` | `EdgeInsets`, `SizedBox`, `Row.spacing`/`Wrap.spacing` |
| `box-shadow` / gradients | `BoxDecoration(gradient: LinearGradient(...))` |
| `.btn-primary` / `.btn-ghost` | `FilledButton` / `OutlinedButton` (themed in `AppTheme`) |
| `input`, `select`, `textarea` styling | `InputDecorationTheme` in `AppTheme` |
| `@media (max-width: 900px)` | `LayoutBuilder` / `MediaQuery` (`kWideBreakpoint = 900`) |
| `:hover` states | not needed on touch; `InkWell` ripple instead |
| Global theme file | `ThemeData` built once in `AppTheme.dark()` |

The app is dark-only (`themeMode: ThemeMode.dark`), like the web CSS.

## 3. JavaScript logic → Dart

### File map

| JavaScript | Dart |
|---|---|
| `js/firebase.js` | `main.dart` + `firebase_options.dart` + `app_services.dart` |
| `js/app.js` (auth modal, sign-in/up) | `features/auth/auth_sheet.dart`, `data/repositories/auth_repository.dart` |
| `js/dashboard.js` | `features/dashboard/`, `data/repositories/club_repository.dart` |
| `js/club.js` | `features/club/`, `data/repositories/roster_repository.dart` |
| `js/matches.js` | `features/matches/`, `data/repositories/match_repository.dart` |
| `js/tournaments.js` | `features/tournaments/`, `data/repositories/tournament_repository.dart` |
| `js/scoring.js` — **rules** | `domain/scoring/scoring_engine.dart` |
| `js/scoring.js` — Firestore transactions | `data/repositories/score_repository.dart` |
| `js/scoring.js` — page state & handlers | `features/scoring/scoring_controller.dart`, `scoring_screen.dart` |
| `js/scorecard.js`, `public-scorecard.js` | `domain/scoring/scorecard.dart` + `shared/widgets/scorecard_widgets.dart` |
| `js/public-tournaments.js` | `domain/scoring/standings.dart` + `landing/public_standings_section.dart` |
| `js/public-live.js`, `livematches.js`, `live-match-centre.js` | `data/repositories/public_repository.dart` + `public/live_matches_screen.dart` |
| repeated membership check in 5 pages | `ClubRepository.loadAccess` + `ClubWorkspaceController` |

### Translation patterns

| JavaScript | Dart / Flutter |
|---|---|
| `onAuthStateChanged(auth, cb)` | `FirebaseAuth.userChanges()` stream → `StreamBuilder` in `RequireAuth` |
| `getDocs(query(...))` | `query.get()` (one-off) |
| `onSnapshot(query, cb)` | `query.snapshots()` → `Stream` → `StreamBuilder` / controller subscription |
| `runTransaction(db, async tx => …)` | `db.runTransaction((tx) async {…})`; the *rule logic inside* is a pure function in `ScoringEngine` |
| `addDoc`, `updateDoc`, `deleteDoc`, `setDoc(…,{merge:true})` | `add`, `update`, `delete`, `set(…, SetOptions(merge: true))` |
| `serverTimestamp()` | `FieldValue.serverTimestamp()` |
| `writeBatch` | `db.batch()` |
| module-level `let state` + `render()` | a `ChangeNotifier` controller + `ListenableBuilder` |
| `element.addEventListener("click", …)` | `onPressed` / `onTap` callbacks |
| `Number(x \|\| 0)`, `x ?? ""` coercion | `JsonRead` helpers (`integer`, `str`, …) in `domain/models/json_read.dart` |
| untyped Firestore objects | typed immutable models with `fromMap` / `toMap` |
| `innerHTML` templates | widget trees |
| `toFixed(2)` | `toStringAsFixed(2)` (identical rounding; checked on the classic edge cases) |
| `Date#toISOString()` | `DateTime.toUtc().toIso8601String()` (millisecond precision) |
| `localeCompare` | `compareNames` (case-insensitive) |

The key design move: **`scoring.js` mixed rules, DOM and Firestore in one 1,100-line
file.** In Dart they are separated:

```
ScoringEngine.planDelivery(...)   validate + build the ball           (pure)
  → UI asks for the next bowler if the over ends                       (dialog)
ScoreRepository.mutateInnings(...) transaction on the latest innings   (Firebase)
  → ScoringEngine.applyDelivery(...) mutate a copy                     (pure)
  → publish the public scorecard                                       (Firebase)
```

### Should anything use a WebView instead?

**No part of this app needs one.** The web app has no custom backend: every
page is plain JavaScript calling Firebase Auth and Firestore. Those have
first-class Flutter SDKs (`firebase_auth`, `cloud_firestore`), so porting the
logic natively gives you offline caching, a single shared session, native
keyboard/pickers and no JavaScript bridge to maintain. Embedding the old pages
in a WebView would mean a second login session, a clunky scoring keypad, and
two codebases to keep in sync.

A WebView (or `url_launcher`) would only make sense for genuinely web-only
content, e.g. opening a shareable public scorecard link in the browser, or a
future privacy-policy page.

## 4. Directory structure

```
lib/
  core/            app-wide: theme, routes, the Material import barrel
  domain/          business rules + models (pure Dart, unit-tested)
  data/            Firebase repositories (the only place that touches Firestore)
  features/<name>/ one folder per screen: screen, controller, widgets, sheets
  shared/widgets/  UI used by 2+ features
test/              domain tests (flutter test)
firebase/          firestore.rules (unchanged from the web project)
```

**Adding a feature:** model in `domain/models` → logic in `domain/` (with a
test) → repository method in `data/repositories` → screen in
`features/<name>/` → register the route in `core/routes.dart` and `app.dart`.
