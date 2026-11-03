# Boundary — Stage 8 Testing & Deployment Readiness

This stage packages the complete Stage 7 project with a practical test plan and deployment safeguards. Run tests against your own Firebase project; this package does not claim that a live Firebase deployment or security audit has occurred.

## 1. Install and run
- Install a current Node.js LTS release.
- Run `npm install`.
- Confirm `js/firebase.js` contains your Firebase web-app configuration.
- Confirm Firebase Authentication and Cloud Firestore are enabled.
- Run `npm start`, then open the local URL shown in the terminal.
- Check the browser developer console and terminal for errors.

## 2. Authentication
- [ ] Register a new account.
- [ ] Sign out and sign back in.
- [ ] Try invalid credentials and verify a safe error message.
- [ ] Open protected pages while signed out and verify redirect behavior.
- [ ] Verify profile/display-name behavior.

## 3. Club, team and player management
- [ ] Create a club and open it from the dashboard.
- [ ] Add, edit and remove teams and players.
- [ ] Test using a second account.
- [ ] Confirm one club's users cannot read or change another club's private data.
- [ ] Test empty, long and special-character inputs.

## 4. Tournaments and matches
- [ ] Create and edit a tournament.
- [ ] Add teams to a tournament.
- [ ] Create a match and verify teams, venue, date and toss details.
- [ ] Test missing or invalid fields.
- [ ] Confirm club-level access boundaries.

## 5. Live scoring and scorecards
- [ ] Test dot balls and 1–6 runs.
- [ ] Test wides, no-balls, byes and leg-byes.
- [ ] Test wickets, undo, innings end and second innings.
- [ ] Refresh during a match and verify saved data reloads.
- [ ] Compare scorecard totals with the delivery log.
- [ ] Verify batting, bowling, extras, fall-of-wickets and partnership summaries.
- [ ] Test print / Save PDF.
- [ ] Test two browser sessions scoring the same match.

## 6. Firestore rules and security
- [ ] Use a separate Firebase test project before production.
- [ ] Test access while signed out.
- [ ] Test owner/admin, scorer, captain and ordinary-member permissions.
- [ ] Test cross-club reads and writes.
- [ ] Confirm users cannot assign themselves elevated roles.
- [ ] Review whether publicly readable club documents contain private information.
- [ ] Use Firebase Emulator Suite to automate Firestore rules tests.
- [ ] Configure billing alerts, backups and monitoring.

## 7. Required production engineering
The current app is a browser-based prototype and is not a fully audited production scoring system. Before public tournament use:
- Move authoritative scoring and privileged operations to trusted server code (for example, Cloud Functions).
- Validate every delivery and score transition on the server.
- Complete dismissal types, dismissed batter, fielder, bowler-credit, strike-change, penalty-run and cricket-law edge-case handling.
- Avoid placing an unlimited delivery history in one Firestore document; use a scalable per-delivery or chunked data model.
- Add automated Firestore rules tests, abuse controls, monitoring, backups and a recovery plan.
- Review privacy, data retention and applicable legal obligations.

## 8. Firebase Hosting deployment
1. Install the CLI: `npm install -g firebase-tools`
2. Sign in: `firebase login`
3. Select your project: `firebase use --add`
4. Review `firebase.json` and `firestore.rules`.
5. Deploy rules: `firebase deploy --only firestore:rules`
6. Deploy hosting: `firebase deploy --only hosting`
7. Repeat the full checklist on the deployed Hosting URL.

Never commit service-account keys or private credentials.

## 9. Release sign-off
- [ ] Critical manual tests pass.
- [ ] Firestore rules are reviewed and emulator-tested.
- [ ] No secrets are committed.
- [ ] Backups and recovery are configured.
- [ ] Server-authoritative scoring is implemented and tested.
- [ ] Public launch approval is recorded.
