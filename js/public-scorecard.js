import { db, isConfigured } from "./firebase.js";
import { doc, onSnapshot } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const $ = (id) => document.getElementById(id);
const matchId = new URLSearchParams(location.search).get("matchId");
const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[c]));
const overs = (balls) => `${Math.floor((Number(balls) || 0) / 6)}.${(Number(balls) || 0) % 6}`;
const rate = (runs, balls) => balls ? (runs / balls * 100).toFixed(2) : "0.00";
const economy = (runs, balls) => balls ? (runs / (balls / 6)).toFixed(2) : "0.00";

function playerName(data, id) { return data.playerNames?.[id] || "Player"; }
function teamName(data, id) { return data.teamNames?.[id] || "Team"; }

function extrasFor(inn) {
  const extras = { wides: 0, noBalls: 0, byes: 0, legByes: 0 };
  for (const delivery of inn.deliveries || []) {
    if (delivery.kind === "wide") extras.wides += Number(delivery.extraRuns || delivery.totalRuns || 0);
    if (delivery.kind === "no_ball") extras.noBalls += Number(delivery.extraRuns || 1);
    if (delivery.kind === "bye") extras.byes += Number(delivery.extraRuns || 0);
    if (delivery.kind === "leg_bye") extras.legByes += Number(delivery.extraRuns || 0);
  }
  return extras;
}

function renderInnings(data, inn) {
  const batterIds = [...new Set((inn.deliveries || []).map((d) => d.strikerId))];
  const batters = batterIds.map((id) => ({ id, ...(inn.batters?.[id] || {}) }));
  const bowlerIds = [...new Set((inn.deliveries || []).map((d) => d.bowlerId))];
  const bowlers = bowlerIds.map((id) => ({ id, ...(inn.bowlers?.[id] || {}) }));
  const extras = extrasFor(inn);
  const extraTotal = extras.wides + extras.noBalls + extras.byes + extras.legByes;

  const battingHtml = batters.length ? `
    <div class="public-table-wrap"><table class="public-table">
      <thead><tr><th>Batter</th><th>R</th><th>B</th><th>4s</th><th>6s</th><th>SR</th></tr></thead>
      <tbody>${batters.map((b) => `<tr><td>${esc(playerName(data, b.id))}</td><td>${b.runs || 0}</td><td>${b.balls || 0}</td><td>${b.fours || 0}</td><td>${b.sixes || 0}</td><td>${rate(b.runs || 0, b.balls || 0)}</td></tr>`).join("")}</tbody>
      <tfoot><tr><td>Extras</td><td colspan="5">${extraTotal} (Wd ${extras.wides}, Nb ${extras.noBalls}, B ${extras.byes}, Lb ${extras.legByes})</td></tr>
      <tr><td>Total</td><td colspan="5">${inn.total || 0}/${inn.wickets || 0} in ${overs(inn.legalBalls)} overs</td></tr></tfoot>
    </table></div>` : '<p class="public-muted">Batting figures will appear when deliveries are recorded.</p>';

  const bowlingHtml = bowlers.length ? `
    <div class="public-table-wrap"><table class="public-table">
      <thead><tr><th>Bowler</th><th>O</th><th>R</th><th>W</th><th>Economy</th></tr></thead>
      <tbody>${bowlers.map((b) => `<tr><td>${esc(playerName(data, b.id))}</td><td>${overs(b.legalBalls)}</td><td>${b.runs || 0}</td><td>${b.wickets || 0}</td><td>${economy(b.runs || 0, b.legalBalls || 0)}</td></tr>`).join("")}</tbody>
    </table></div>` : '<p class="public-muted">Bowling figures will appear when deliveries are recorded.</p>';

  let running = 0;
  let wicketNo = 0;
  const fall = [];
  for (const delivery of inn.deliveries || []) {
    running += Number(delivery.totalRuns || 0);
    if (delivery.wicket) {
      wicketNo++;
      fall.push(`${wicketNo}-${running} (${esc(playerName(data, delivery.strikerId))})`);
    }
  }

  return `<section class="public-report-card">
    <h2>${esc(teamName(data, inn.battingTeamId))} innings — ${inn.total || 0}/${inn.wickets || 0}</h2>
    <p class="public-muted">${overs(inn.legalBalls)} overs · ${inn.completed ? "Innings completed" : "Currently batting"}</p>
    <h3>Batting</h3>${battingHtml}
    <h3>Bowling</h3>${bowlingHtml}
    <h3>Fall of wickets</h3><p>${fall.length ? fall.join(" · ") : "No wickets yet."}</p>
  </section>`;
}

function render(data) {
  $("publicNotice").hidden = true;
  $("publicMatchHero").hidden = false;
  const innings = data.innings || [];
  $("publicMatchTitle").textContent = data.title || "Cricket match";
  $("publicMatchMeta").textContent = [data.matchDate, data.startTime, data.venue, data.format].filter(Boolean).join(" · ");
  $("publicStatus").textContent = data.status === "completed" ? "MATCH COMPLETED" : "LIVE SCORE";
  $("publicResult").textContent = data.result || "";

  $("publicHeadlineScores").innerHTML = innings.map((inn) => `
    <div class="public-report-team"><span>${esc(teamName(data, inn.battingTeamId))}</span>
      <strong>${inn.total || 0}/${inn.wickets || 0}</strong>
      <small>${overs(inn.legalBalls)} overs${inn.completed ? " · Complete" : " · Batting"}</small>
    </div>`).join("");

  $("publicInningsReports").innerHTML = innings.length
    ? innings.map((inn) => renderInnings(data, inn)).join("")
    : '<div class="public-empty">Scoring has not started yet.</div>';

  $("publicMatchSummary").innerHTML = innings.map((inn) => `
    <div class="public-summary-item"><small>${esc(teamName(data, inn.battingTeamId))} · ${inn.completed ? "Completed" : "In progress"}</small>
      <strong>${inn.total || 0}/${inn.wickets || 0}</strong><small>${overs(inn.legalBalls)} overs</small></div>`).join("");
}

if (!isConfigured || !db) {
  $("publicNotice").textContent = "Firebase is not configured.";
} else if (!matchId) {
  $("publicNotice").textContent = "No match was selected. Open a match from the homepage live-score list.";
} else {
  onSnapshot(doc(db, "publicMatchScores", matchId), (snapshot) => {
    if (!snapshot.exists()) {
      $("publicNotice").hidden = false;
      $("publicNotice").textContent = "This match has not published a public score yet.";
      $("publicMatchHero").hidden = true;
      return;
    }
    render(snapshot.data());
  }, (error) => {
    console.error(error);
    $("publicNotice").hidden = false;
    $("publicNotice").textContent = "Could not load this public scorecard.";
  });
}
