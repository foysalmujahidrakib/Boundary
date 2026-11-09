import { db, isConfigured } from "./firebase.js";
import {
  collection,
  onSnapshot
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const list = document.getElementById("publicTournamentList");

let tournaments = [];
let publicMatches = [];
const expandedTournamentIds = new Set();

const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  }[character]));

function statusLabel(status) {
  return String(status || "planned").replaceAll("_", " ").toUpperCase();
}

function ballsForNetRunRate(innings, allocatedOvers) {
  const legalBalls = Math.max(0, Number(innings?.legalBalls || 0));

  // Under standard limited-overs NRR rules, an all-out innings is
  // charged with the full allocated quota, not the actual balls used.
  if (Number(innings?.wickets || 0) >= 10) {
    return allocatedOvers * 6;
  }

  return legalBalls;
}

function calculateStandings(tournament) {
  const teamIds = Array.isArray(tournament.teamIds)
    ? tournament.teamIds
    : [];

  const stats = new Map();

  teamIds.forEach((teamId) => {
    stats.set(teamId, {
      id: teamId,
      name: tournament.teamNames?.[teamId] || "Team",
      mp: 0,
      wins: 0,
      losses: 0,
      points: 0,
      runsScored: 0,
      ballsFaced: 0,
      runsConceded: 0,
      ballsBowled: 0,
      nrr: 0
    });
  });

  const completedMatches = publicMatches.filter((match) => {
    if (match.tournamentId !== tournament.id || match.status !== "completed") {
      return false;
    }

    const innings = Array.isArray(match.innings) ? match.innings : [];
    return innings.length >= 2 &&
      innings[0]?.completed === true &&
      innings[1]?.completed === true;
  });

  completedMatches.forEach((match) => {
    const innings = match.innings;
    const first = innings[0];
    const second = innings[1];

    const firstTeamId = first.battingTeamId;
    const secondTeamId = second.battingTeamId;

    if (
      !firstTeamId ||
      !secondTeamId ||
      firstTeamId === secondTeamId ||
      !stats.has(firstTeamId) ||
      !stats.has(secondTeamId)
    ) {
      return;
    }

    const allocatedOvers = Math.max(1, Number(match.overs || 20));
    const firstBalls = ballsForNetRunRate(first, allocatedOvers);
    const secondBalls = ballsForNetRunRate(second, allocatedOvers);
    const firstRuns = Number(first.total || 0);
    const secondRuns = Number(second.total || 0);

    const firstTeam = stats.get(firstTeamId);
    const secondTeam = stats.get(secondTeamId);

    firstTeam.mp += 1;
    secondTeam.mp += 1;

    // Each innings contributes runs/overs to the batting side and
    // runs/overs conceded/bowled to the opposing side.
    firstTeam.runsScored += firstRuns;
    firstTeam.ballsFaced += firstBalls;
    secondTeam.runsConceded += firstRuns;
    secondTeam.ballsBowled += firstBalls;

    secondTeam.runsScored += secondRuns;
    secondTeam.ballsFaced += secondBalls;
    firstTeam.runsConceded += secondRuns;
    firstTeam.ballsBowled += secondBalls;

    if (firstRuns > secondRuns) {
      firstTeam.wins += 1;
      secondTeam.losses += 1;
    } else if (secondRuns > firstRuns) {
      secondTeam.wins += 1;
      firstTeam.losses += 1;
    }
    // A tied match counts as played, but adds no win/loss points.
  });

  const standings = [...stats.values()].map((team) => {
    team.points = team.wins * 2;

    const runRateFor = team.ballsFaced > 0
      ? team.runsScored * 6 / team.ballsFaced
      : 0;

    const runRateAgainst = team.ballsBowled > 0
      ? team.runsConceded * 6 / team.ballsBowled
      : 0;

    team.nrr = runRateFor - runRateAgainst;
    return team;
  });

  standings.sort((a, b) =>
    b.points - a.points ||
    b.nrr - a.nrr ||
    b.wins - a.wins ||
    a.name.localeCompare(b.name)
  );

  return standings;
}

function renderStandingsRows(standings) {
  if (!standings.length) {
    return `
      <tr>
        <td class="tournament-table-empty" colspan="7">
          No participating teams have been added to this tournament.
        </td>
      </tr>
    `;
  }

  return standings.map((team, index) => {
    const nrrClass = team.nrr >= 0 ? "nrr-positive" : "nrr-negative";
    const nrr = Object.is(team.nrr, -0) ? 0 : team.nrr;

    return `
      <tr>
        <td class="standings-position">${index + 1}</td>
        <td class="standings-team">${escapeHtml(team.name)}</td>
        <td>${team.mp}</td>
        <td>${team.wins}</td>
        <td>${team.losses}</td>
        <td class="standings-points">${team.points}</td>
        <td class="${nrrClass}">${nrr > 0 ? "+" : ""}${nrr.toFixed(3)}</td>
      </tr>
    `;
  }).join("");
}

function renderTournament(tournament) {
  const id = String(tournament.id);
  const expanded = expandedTournamentIds.has(id);
  const teamCount = Array.isArray(tournament.teamIds)
    ? tournament.teamIds.length
    : 0;
  const venue = String(tournament.venue || "").trim();
  const standings = calculateStandings(tournament);
  const detailId = `tournament-details-${id.replace(/[^a-zA-Z0-9_-]/g, "_")}`;

  return `
    <article class="public-tournament-card">
      <button
        class="tournament-toggle"
        type="button"
        data-tournament-toggle="${escapeHtml(id)}"
        aria-expanded="${expanded}"
        aria-controls="${detailId}"
      >
        <span class="tournament-card-info">
          <span class="tournament-icon" aria-hidden="true">🏆</span>
          <span class="tournament-card-copy">
            <strong>${escapeHtml(tournament.name || "Untitled tournament")}</strong>
            <span class="meta-chips">
              <span class="meta-chip" title="Participating teams">
                <span aria-hidden="true">👥</span>
                <b>${teamCount}</b> ${teamCount === 1 ? "team" : "teams"}
              </span>
              <span class="meta-chip${venue ? "" : " is-muted"}" title="Venue">
                <span aria-hidden="true">📍</span>
                ${venue ? escapeHtml(venue) : "Venue TBC"}
              </span>
              <span class="tournament-status status-${escapeHtml(tournament.status || "planned")}">
                ${escapeHtml(statusLabel(tournament.status))}
              </span>
            </span>
            ${(tournament.season || tournament.format) ? `<small>${[tournament.season, tournament.format].filter(Boolean).map(escapeHtml).join(" · ")}</small>` : ""}
          </span>
        </span>
        <span class="tournament-expand-icon" aria-hidden="true">⌄</span>
      </button>

      <div class="tournament-details" id="${detailId}" ${expanded ? "" : "hidden"}>
        <div class="standings-scroll">
          <table class="standings-table">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col" class="standings-team">TEAM NAME</th>
                <th scope="col">MP</th>
                <th scope="col">W</th>
                <th scope="col">L</th>
                <th scope="col">PTS</th>
                <th scope="col">NRR</th>
              </tr>
            </thead>
            <tbody>${renderStandingsRows(standings)}</tbody>
          </table>
        </div>
        <p class="tournament-table-note">
          Points: 2 per win. NRR uses aggregate runs and legal-ball totals;
          an all-out innings is charged with the full allocated overs.
          Tied matches count as played, with no win/loss points.
        </p>
      </div>
    </article>
  `;
}

function render() {
  if (!list) return;

  if (!tournaments.length) {
    list.innerHTML = `
      <div class="public-live-empty">
        No public tournaments are available right now.
      </div>
    `;
    return;
  }

  // Keep active tournaments near the top, then order by start date.
  const statusOrder = { ongoing: 0, planned: 1, completed: 2, cancelled: 3 };
  const ordered = [...tournaments].sort((a, b) => {
    const statusDifference =
      (statusOrder[a.status] ?? 4) - (statusOrder[b.status] ?? 4);

    if (statusDifference) return statusDifference;
    return String(a.startDate || "").localeCompare(String(b.startDate || ""));
  });

  list.innerHTML = ordered.map(renderTournament).join("");
}

if (!list) {
  console.warn("Tournament standings container was not found on this page.");
} else if (!isConfigured || !db) {
  list.innerHTML = `
    <div class="public-live-empty">
      Tournament standings are unavailable because Firebase is not configured.
    </div>
  `;
} else {
  list.addEventListener("click", (event) => {
    const button = event.target.closest("[data-tournament-toggle]");
    if (!button) return;

    const tournamentId = button.dataset.tournamentToggle;
    if (expandedTournamentIds.has(tournamentId)) {
      expandedTournamentIds.delete(tournamentId);
    } else {
      expandedTournamentIds.add(tournamentId);
    }
    render();
  });

  onSnapshot(
    collection(db, "publicTournaments"),
    (snapshot) => {
      tournaments = snapshot.docs.map((document) => ({
        id: document.id,
        ...document.data()
      }));
      render();
    },
    (error) => {
      console.error("Could not load public tournaments:", error);
      list.innerHTML = `
        <div class="public-live-empty">
          Could not load tournament standings. Please try again later.
        </div>
      `;
    }
  );

  onSnapshot(
    collection(db, "publicMatchScores"),
    (snapshot) => {
      publicMatches = snapshot.docs.map((document) => ({
        id: document.id,
        ...document.data()
      }));
      render();
    },
    (error) => {
      console.error("Could not load public match scores for standings:", error);
      list.innerHTML = `
        <div class="public-live-empty">
          Tournament scores could not be loaded. Please try again later.
        </div>
      `;
    }
  );
}
