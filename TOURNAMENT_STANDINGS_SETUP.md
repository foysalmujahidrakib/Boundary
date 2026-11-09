# Tournament Standings — Stage 8 Integration

This update adds an expandable tournament standings section to the public homepage.

## What changed

- `index.html`: adds the Tournament Standings section immediately below Live Matches and loads the new module.
- `css/style.css`: adds responsive tournament cards and horizontally scrollable standings tables.
- `js/public-tournaments.js`: listens to public tournament and public match-score documents, calculates MP/W/L/PTS/NRR, sorts standings, and handles expand/collapse.
- `js/tournaments.js`: publishes a public-safe tournament summary when a tournament is created/edited and backfills missing summaries when a club admin opens the tournament page.
- `js/scoring.js`: includes `tournamentId` in public match-score snapshots.
- `firestore.rules`: allows public reads of tournament summaries and restricts writes/deletes to administrators of the owning club.

## Firestore deployment

Publish the updated rules from the project directory:

```bash
firebase deploy --only firestore:rules
```

The homepage reads only:
- `publicTournaments`
- `publicMatchScores`

It does not read private `tournaments`, `matches`, `teams`, or `matchScores` collections.

## Existing data migration

1. Deploy the updated Firestore rules.
2. Sign in as a club administrator and open the club's Tournaments page once. Existing tournaments without a public summary are published automatically.
3. For previously completed matches, open each match's scoring page once after deploying this code. The scorer republishes its public score snapshot with the match's `tournamentId`.
4. Refresh the public homepage and expand the tournament card.

New tournaments and match score updates publish automatically.

## Standings rules

- Only public match snapshots with `status: "completed"` and two completed innings are counted.
- Each participating team receives one MP per completed match.
- A win gives 2 points; a loss gives 0 points. A tied match counts as played but gives neither side a win or loss, so both receive 0 points under the requested `Points = Wins × 2` rule.
- Teams are sorted by points, then NRR, then wins, then team name.
- NRR uses aggregate runs divided by aggregate legal-ball overs, less the equivalent conceded/bowled rate.
- An innings ending all out is charged with the full allocated overs for NRR. A chase ending after reaching the target uses the actual legal balls faced.
- NRR is displayed to three decimal places.

## Important limitations

This version follows the requested MP/W/L/PTS/NRR columns. It does not add separate Tie or No Result columns, bonus points, DLS adjustments, or super-over handling. Those rules should be added if the tournament regulations require them.
