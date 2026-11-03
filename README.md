# Boundary — Stage 7: Scorecards & Player Statistics

Stage 7 builds report pages on top of the Stage 6 `matchScores/{matchId}` innings and delivery data.

## Included
- `scorecard.html` and `js/scorecard.js`.
- Scorecard link beside every match in Match Centre.
- Shortcut from the live scoring page to the scorecard.
- Batting tables: runs, balls, fours, sixes and strike rate.
- Bowling tables: overs, runs, wickets and economy.
- Extras breakdown: wides, no-balls, byes and leg-byes.
- Fall-of-wickets list with wicket number, team score, over and recorded striker.
- Partnership sequence summaries showing team runs between wicket events.
- Match-level player aggregates across innings.
- Print / Save as PDF using the browser print dialog.

## Install
1. Extract Stage 7 into a new folder; keep Stage 6 as a backup.
2. Copy your working Stage 6 `js/firebase.js` into Stage 7's `js/firebase.js`.
3. No new Firestore collection or rules are required; Stage 7 reads existing `matchScores` documents using the Stage 6 read rules.
4. Run `npm install` and `npm start`.
5. Sign in, open your club → Matches → Scorecard. Or open a match's Live scoring page and click Scorecard.

## Data and reporting notes
- Reports are calculated from saved Stage 6 innings and deliveries; existing match data is retained.
- Stage 6 stores aggregate batting and bowling figures and delivery events. This report derives strike rate, economy, extras, wicket fall score/over, and player aggregates from those values.
- The current scorer does not record dismissal type, dismissed batter, fielder, or precise batter-end movement. Therefore fall-of-wickets identifies the striker recorded on that delivery, not a confirmed dismissed batter. Partnership sequence reports team runs between wicket events, not verified individual batter partnership totals.
- Penalty extras and official dismissal-credit rules are not represented in Stage 6 data.
- Print / Save PDF uses the browser's print dialog.

## Validation and production notes
- JavaScript syntax and ZIP integrity checks were checked locally.
- Live Firebase reads have not been tested against your Firebase project.
- This is a reporting layer for the prototype scorer, not an official scoring/competition compliance certification.
- For accurate official partnerships and dismissal details, Stage 8 / a later scoring-engine hardening pass should capture dismissed batter, dismissal type, fielder, completed runs, striker/non-striker end changes, and bowler wicket credit per delivery.


## Stage 8 — Testing, security and deployment readiness

Stage 8 preserves the complete Stage 7 website and adds `TESTING.md` and `.gitignore`. The testing guide covers authentication, club permissions, tournaments, matches, scoring, scorecards and Firebase Hosting deployment.

This package does not deploy your Firebase project or certify its security. Complete the production engineering checklist in `TESTING.md` before accepting real public tournament data.

Run locally:
```bash
npm install
npm start
```

Deploy after testing:
```bash
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
firebase deploy --only hosting
```


## Public live scores

The homepage now lists matches after the scorer starts the first innings. The scoring page publishes a curated, read-only document to `publicMatchScores/{matchId}`. Visitors can open `public-scorecard.html?matchId=...` without signing in. Publish the updated `firestore.rules` before testing. The public snapshot exposes match metadata, team/player display names, and scorecard data only; private club membership and management records remain behind the existing rules.
