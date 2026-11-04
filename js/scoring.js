
import { auth, db, isConfigured } from "./firebase.js";
import {
  onAuthStateChanged,
  signOut
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";

import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  runTransaction,
  serverTimestamp,
  setDoc
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const $ = (id) => document.getElementById(id);

const params = new URLSearchParams(location.search);
const clubId = params.get("clubId");
const matchId = params.get("matchId");

const esc = (v) =>
  String(v ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  }[c]));

let user = null;
let role = "member";
let match = null;
let teams = [];
let players = [];
let score = null;
let activeIndex = -1;
let scoringBusy = false;

const canScore = () => ["club_admin", "club_owner"].includes(role);

const scoreRef = () => doc(db, "matchScores", matchId);

const ballsToOvers = (n) => `${Math.floor(n / 6)}.${n % 6}`;

const ordinal = (n) =>
  n === 1 ? "1st" :
  n === 2 ? "2nd" :
  n === 3 ? "3rd" : `${n}th`;

const current = () => score?.innings?.[activeIndex] || null;

const legalBall = (kind) => !["wide", "no_ball"].includes(kind);


// ========================================
// GENERAL FUNCTIONS
// ========================================

function fatal(message) {
  $("pageNotice").textContent = message;
  $("pageNotice").classList.remove("hidden");
}

function toast(message) {
  const el = $("toast");
  el.textContent = message;
  el.classList.add("show");

  setTimeout(() => el.classList.remove("show"), 2400);
}

function playerName(id) {
  return players.find((p) => p.id === id)?.fullName || "Unknown player";
}

function teamName(id) {
  return teams.find((t) => t.id === id)?.name || "Unknown team";
}

function populate(selectId, list, selected = "") {
  const el = $(selectId);

  el.innerHTML = list.map((p) =>
    `<option value="${esc(p.id)}">${esc(p.fullName || p.name)}</option>`
  ).join("");

  if (selected && list.some((p) => p.id === selected)) {
    el.value = selected;
  }
}


// ========================================
// BOWLING RULES
// ========================================

function maxOversPerBowler() {
  const format = String(match?.format || "").toLowerCase();
  const overs = Number(match?.overs || 20);

  if (overs < 15) return 3;

  if (format.includes("t20") || overs === 20) return 4;

  if (format.includes("odi") || overs >= 50) return 10;

  return Math.max(1, Math.ceil(overs / 5));
}

function bowlerOvers(inn, bowlerId) {
  return Math.floor(
    (inn.bowlers?.[bowlerId]?.legalBalls || 0) / 6
  );
}


// IMPORTANT FIX:
// Find the bowler who actually bowled the previous completed over.
// Do not compare against inn.bowlerId because that value may already
// contain the newly selected bowler.

function previousOverBowlerId(inn) {
  const lastLegalDelivery = [...(inn.deliveries || [])]
    .reverse()
    .find((delivery) => delivery.legal === true);

  return lastLegalDelivery?.bowlerId || null;
}


function availableBowlers(inn, excludeCurrent = false) {
  const limit = maxOversPerBowler();

  return players.filter((p) =>
    p.teamId === inn.bowlingTeamId &&
    (!excludeCurrent || p.id !== inn.bowlerId) &&
    bowlerOvers(inn, p.id) < limit
  );
}


// ========================================
// MATCH RESULT
// ========================================

function matchResult() {
  if (!score || score.innings?.length < 2) return "";

  const first = score.innings[0];
  const second = score.innings[1];

  if (!first || !second || !second.completed) return "";

  if (second.total > first.total) {
    const wicketsLeft = Math.max(0, 10 - second.wickets);

    return `${teamName(second.battingTeamId)} wins by ${wicketsLeft} wicket${wicketsLeft === 1 ? "" : "s"}.`;
  }

  if (second.total < first.total) {
    return `${teamName(first.battingTeamId)} wins by ${first.total - second.total} run${first.total - second.total === 1 ? "" : "s"}.`;
  }

  return "Match tied.";
}


// ========================================
// RENDER LIVE SCORE
// ========================================

function render() {
  if (!score || activeIndex < 0) {
    $("setupCard").classList.remove("hidden");
    $("liveCard").classList.add("hidden");
    $("heroScore").textContent = "0/0";
    $("oversText").textContent = "0.0 overs";
    $("inningsSummary").textContent = "No innings recorded.";
    return;
  }

  const inn = current();
  $("setupCard").classList.add("hidden");
  $("liveCard").classList.remove("hidden");
  $("heroScore").textContent = `${inn.total}/${inn.wickets}`;
  $("oversText").textContent = `${ballsToOvers(inn.legalBalls)} overs`;
  $("inningsHeading").textContent = `${ordinal(inn.number)} innings`;
  $("inningsTeams").textContent = `${teamName(inn.battingTeamId)} batting · ${teamName(inn.bowlingTeamId)} bowling`;
  $("inningsStatus").textContent = inn.completed ? "INNINGS COMPLETED" : "● LIVE";
  $("battingTeamName").textContent = teamName(inn.battingTeamId);
  $("summaryRuns").textContent = inn.total;
  $("summaryWickets").textContent = inn.wickets;
  $("summaryOvers").textContent = `${ballsToOvers(inn.legalBalls)} OVERS`;
  $("summaryExtras").textContent = `Extras: ${inn.extras || 0}`;
  const oversDecimal = inn.legalBalls / 6;
  $("runRate").textContent = `RR ${(oversDecimal ? inn.total / oversDecimal : 0).toFixed(2)}`;

  const dismissed = new Set(inn.dismissedBatterIds || []);
  const batting = players.filter(p => p.teamId === inn.battingTeamId && !dismissed.has(p.id));
  const bowling = players.filter(p => p.teamId === inn.bowlingTeamId);
  populate("strikerSelect", batting, inn.strikerId);
  populate("nonStrikerSelect", batting, inn.nonStrikerId);
  populate("bowlerSelect", bowling, inn.bowlerId);

  $("strikerSelect").disabled = $("nonStrikerSelect").disabled =
    $("bowlerSelect").disabled = inn.completed || !canScore();

  const controlsDisabled = inn.completed || !canScore() || scoringBusy;
  document.querySelectorAll("[data-run],#wicketBtn,#wideBtn,#noBallBtn,#byeBtn,#legByeBtn,#penaltyBtn")
    .forEach(b => b.disabled = controlsDisabled);
  $("undoBtn").disabled = !inn.deliveries.length || !canScore() || scoringBusy;
  $("endInningsBtn").disabled = inn.completed || !canScore() || scoringBusy;
  $("nextInningsBtn").classList.toggle("hidden", !inn.completed || score.innings.length >= 2);

  const activeIds = [...new Set([inn.strikerId, inn.nonStrikerId, ...Object.keys(inn.batters || {})])]
    .filter(id => id && !dismissed.has(id));
  $("batterHighlights").innerHTML = activeIds.map(id => {
    const b = inn.batters?.[id] || {runs:0,balls:0,fours:0,sixes:0};
    const sr = b.balls ? (b.runs / b.balls * 100).toFixed(2) : "0.00";
    const active = id === inn.strikerId ? "active" : "";
    return `<div class="player-highlight ${active}">
      <span class="player-name">${esc(playerName(id))}${id === inn.strikerId ? " *" : ""}${id === inn.nonStrikerId ? " (NS)" : ""}</span>
      <span class="value">${b.runs}<small>RUNS</small></span><span class="value">${b.balls}<small>BALLS</small></span>
      <span class="value">${sr}<small>SR</small></span><span class="value">${b.fours}<small>4s</small></span><span class="value">${b.sixes}<small>6s</small></span>
    </div>`;
  }).join("") || '<p class="muted">No batter figures yet.</p>';

  const bowler = inn.bowlers?.[inn.bowlerId] || {legalBalls:0,runs:0,wickets:0};
  const eco = bowler.legalBalls ? (bowler.runs / (bowler.legalBalls / 6)).toFixed(2) : "0.00";
  $("bowlerHighlight").innerHTML = `<span class="player-name">${esc(playerName(inn.bowlerId))} *</span>
    <span>${ballsToOvers(bowler.legalBalls)}<small>OVERS</small></span><span>${bowler.runs}<small>RUNS</small></span>
    <span>${bowler.wickets}<small>WKT</small></span><span>${eco}<small>ECO</small></span>`;

  $("ballLog").innerHTML = inn.deliveries.length
    ? inn.deliveries.slice(-18).map(d => {
        const cls = d.wicket ? "wicket" : d.kind === "penalty" ? "penalty" :
          ["wide","no_ball","bye","leg_bye"].includes(d.kind) ? "extra" :
          (d.batterRuns === 4 || d.batterRuns === 6) ? "boundary" : "";
        return `<span class="ball-chip ${cls}" title="${esc(d.kind)}">${esc(d.label)}</span>`;
      }).join("")
    : '<span class="muted">No deliveries yet.</span>';

  const batRows = Object.entries(inn.batters || {}).map(([id,v]) => ({id,...v}));
  $("battingTable").innerHTML = batRows.length ? `<table class="score-table"><thead><tr>
    <th>Batter</th><th>R</th><th>B</th><th>4s</th><th>6s</th><th>SR</th></tr></thead><tbody>
    ${batRows.map(p => `<tr><td>${esc(playerName(p.id))}${p.id===inn.strikerId?" *":""}</td><td>${p.runs}</td><td>${p.balls}</td><td>${p.fours}</td><td>${p.sixes}</td><td>${p.balls?(p.runs/p.balls*100).toFixed(2):"0.00"}</td></tr>`).join("")}
    </tbody></table>` : "No batting figures.";
  const bowlRows = Object.entries(inn.bowlers || {}).map(([id,v]) => ({id,...v}));
  $("bowlingTable").innerHTML = bowlRows.length ? `<table class="score-table"><thead><tr>
    <th>Bowler</th><th>O</th><th>R</th><th>W</th><th>Eco</th></tr></thead><tbody>
    ${bowlRows.map(p => `<tr><td>${esc(playerName(p.id))}${p.id===inn.bowlerId?" *":""}</td><td>${ballsToOvers(p.legalBalls)}</td><td>${p.runs}</td><td>${p.wickets}</td><td>${p.legalBalls?(p.runs/(p.legalBalls/6)).toFixed(2):"0.00"}</td></tr>`).join("")}
    </tbody></table>` : "No bowling figures.";
  $("inningsSummary").innerHTML = score.innings.map(i =>
    `<p><strong>${ordinal(i.number)}:</strong> ${esc(teamName(i.battingTeamId))} ${i.total}/${i.wickets} (${ballsToOvers(i.legalBalls)} ov) · Extras ${i.extras||0}</p>`
  ).join("");
  const result = matchResult();
  if (result) $("inningsSummary").innerHTML += `<p class="match-result"><strong>${esc(result)}</strong></p>`;
}

// ========================================
// RUN INPUT
// ========================================

function askRuns(message, defaultValue = "0") {
  const answer = prompt(message, defaultValue);

  if (answer === null) return null;

  if (!/^\d+$/.test(answer.trim())) {
    alert("Please enter a whole number of runs.");
    return null;
  }

  const value = Number(answer);

  if (value > 6) {
    alert("Please enter a value from 0 to 6 for one delivery.");
    return null;
  }

  return value;
}


// ========================================
// SELECT INCOMING BATTER
// ========================================

function chooseNewBatter(inn) {
  const dismissed = new Set(inn.dismissedBatterIds || []);

  const eligible = players.filter((p) =>
    p.teamId === inn.battingTeamId &&
    p.id !== inn.strikerId &&
    p.id !== inn.nonStrikerId &&
    !dismissed.has(p.id)
  );

  if (!eligible.length) return null;

  const choices = eligible.map((p, i) =>
    `${i + 1}. ${p.fullName || p.name}`
  ).join("\n");

  const answer = prompt(
    `Wicket! Select the incoming batter by number:\n${choices}`,
    "1"
  );

  if (answer === null) return null;

  const index = Number(answer) - 1;

  return Number.isInteger(index) &&
    index >= 0 &&
    index < eligible.length
      ? eligible[index].id
      : null;
}


// ========================================
// SELECT NEXT BOWLER
// ========================================

function chooseNextBowler(inn) {
  const eligible = availableBowlers(inn, true);

  if (!eligible.length) {
    alert(
      "No eligible bowler is available. Check the bowling limits and player list."
    );
    return null;
  }

  const limit = maxOversPerBowler();

  const choices = eligible.map((p, i) =>
    `${i + 1}. ${p.fullName || p.name} (${bowlerOvers(inn, p.id)}/${limit} overs)`
  ).join("\n");

  const answer = prompt(
    `Over completed. Select the next bowler:\n${choices}`,
    "1"
  );

  if (answer === null) return null;

  const index = Number(answer) - 1;

  return Number.isInteger(index) &&
    index >= 0 &&
    index < eligible.length
      ? eligible[index].id
      : null;
}


// ========================================
// SAVE DELIVERY
// ========================================

async function saveDelivery(kind, requestedRuns = 0, wicket = false, options = {}) {
  const inn = current();
  if (!inn || inn.completed || !canScore() || scoringBusy) return;
  const striker = $("strikerSelect").value;
  const nonStriker = $("nonStrikerSelect").value;
  const bowler = $("bowlerSelect").value;
  if (!striker || !nonStriker || !bowler || striker === nonStriker) {
    $("scoreMessage").textContent = "Select two different batters and a bowler.";
    return;
  }

  const bowlerLimit = maxOversPerBowler();
  const atOverStart = inn.legalBalls > 0 && inn.legalBalls % 6 === 0;
  if (kind !== "penalty" && atOverStart && bowler === previousOverBowlerId(inn)) {
    $("scoreMessage").textContent = "A different bowler must bowl the next over.";
    return;
  }
  if (kind !== "penalty" && bowlerOvers(inn, bowler) >= bowlerLimit) {
    $("scoreMessage").textContent = `This bowler has reached the ${bowlerLimit}-over limit.`;
    return;
  }

  let batterRuns = Number(requestedRuns) || 0;
  let extraRuns = 0;
  if (kind === "wide") { batterRuns = 0; extraRuns = 1 + Number(options.runs || 0); }
  else if (kind === "no_ball") { extraRuns = 1; }
  else if (kind === "bye" || kind === "leg_bye") { batterRuns = 0; extraRuns = Number(options.runs || 0); }
  else if (kind === "penalty") { batterRuns = 0; extraRuns = Number(options.runs || 5); }
  if (!Number.isInteger(batterRuns) || !Number.isInteger(extraRuns) || batterRuns < 0 || extraRuns < 0) {
    $("scoreMessage").textContent = "Enter valid whole-number runs."; return;
  }

  const totalRuns = batterRuns + extraRuns;
  const legal = kind !== "wide" && kind !== "no_ball" && kind !== "penalty";
  const overWillEnd = legal && (inn.legalBalls + 1) % 6 === 0;
  const dismissedBatterId = wicket ? (options.dismissedBatterId || striker) : null;
  const incomingBatterId = wicket ? options.incomingBatterId : null;
  if (wicket && (!dismissedBatterId || ![striker,nonStriker].includes(dismissedBatterId))) {
    $("scoreMessage").textContent = "Choose a batter currently at the crease."; return;
  }
  if (wicket && inn.wickets < 9 && !incomingBatterId) {
    $("scoreMessage").textContent = "Choose the incoming batter."; return;
  }

  const projectedTotal = inn.total + totalRuns;
  const projectedWickets = inn.wickets + (wicket ? 1 : 0);
  const projectedBalls = inn.legalBalls + (legal ? 1 : 0);
  const targetReached = inn.number === 2 && projectedTotal > (score.innings[0]?.total ?? Infinity);
  const inningsComplete = projectedWickets >= 10 || projectedBalls >= Number(match.overs || 20)*6 || targetReached;
  let nextBowlerId = null;
  if (overWillEnd && !inningsComplete) {
    nextBowlerId = chooseNextBowler({...inn, legalBalls:inn.legalBalls+1, bowlerId:bowler});
  }

  const delivery = {
    kind, batterRuns, extraRuns, totalRuns, wicket, legal,
    label: wicket ? "W" : kind === "wide" ? `Wd${extraRuns}` :
      kind === "no_ball" ? `Nb${totalRuns}` : kind === "bye" ? `B${extraRuns}` :
      kind === "leg_bye" ? `Lb${extraRuns}` : kind === "penalty" ? `P${extraRuns}` : String(batterRuns),
    strikerId:striker, nonStrikerId:nonStriker, bowlerId:bowler,
    dismissedBatterId, incomingBatterId, dismissalType:options.dismissalType || "",
    at:new Date().toISOString()
  };

  scoringBusy = true; render();
  try {
    await runTransaction(db, async tx => {
      const snap = await tx.get(scoreRef());
      if (!snap.exists()) throw new Error("Score record missing.");
      const innings = snap.data().innings.map(x => ({
        ...x, deliveries:[...(x.deliveries||[])], batters:{...(x.batters||{})},
        bowlers:{...(x.bowlers||{})}, dismissedBatterIds:[...(x.dismissedBatterIds||[])]
      }));
      const i = innings[activeIndex];
      if (!i || i.completed) throw new Error("This innings is already complete.");

      if (kind !== "penalty" && kind !== "wide") {
        const batter = i.batters[striker] || {runs:0,balls:0,fours:0,sixes:0};
        if (legal) batter.balls++;
        batter.runs += batterRuns;
        if (batterRuns === 4) batter.fours++;
        if (batterRuns === 6) batter.sixes++;
        i.batters[striker] = batter;
      }

      if (kind !== "penalty") {
        const bs = i.bowlers[bowler] || {runs:0,wickets:0,legalBalls:0};
        if (!["bye","leg_bye"].includes(kind)) bs.runs += totalRuns;
        if (legal) bs.legalBalls++;
        const wicketCredited = wicket && !["run_out","retired_hurt"].includes(options.dismissalType);
        if (wicketCredited) bs.wickets++;
        i.bowlers[bowler] = bs;
      }

      i.total += totalRuns;
      i.extras = (i.extras || 0) + extraRuns;
      i.extrasByType = {...(i.extrasByType||{}), [kind]:(i.extrasByType?.[kind]||0)+extraRuns};
      i.legalBalls += legal ? 1 : 0;
      i.deliveries.push(delivery);

      if (wicket) {
        i.wickets++;
        i.dismissedBatterIds.push(dismissedBatterId);
        if (dismissedBatterId === i.strikerId) i.strikerId = incomingBatterId || null;
        else i.nonStrikerId = incomingBatterId || null;
      } else {
        const runsForRotation = ["bye","leg_bye"].includes(kind) ? extraRuns :
          kind === "wide" ? Math.max(0, extraRuns - 1) : batterRuns;
        if (runsForRotation % 2 === 1) [i.strikerId,i.nonStrikerId] = [i.nonStrikerId,i.strikerId];
      }

      if (overWillEnd) [i.strikerId,i.nonStrikerId] = [i.nonStrikerId,i.strikerId];
      const maxBalls = Number(match.overs || 20)*6;
      const reached = i.number === 2 && i.total > (snap.data().innings[0]?.total ?? Infinity);
      if (i.wickets >= 10 || i.legalBalls >= maxBalls || reached) i.completed = true;
      if (overWillEnd && !i.completed && nextBowlerId) i.bowlerId = nextBowlerId;
      tx.update(scoreRef(), {innings,updatedAt:serverTimestamp(),updatedBy:user.uid});
    });
    await loadScore();
    $("scoreMessage").textContent = "Delivery saved.";
    if (current()?.completed) toast("Innings completed.");
  } catch(e) {
    console.error(e);
    $("scoreMessage").textContent = e.code === "permission-denied"
      ? "Scoring permission denied. Check your published Firestore rules."
      : e.message || "Could not save delivery.";
  } finally { scoringBusy = false; render(); }
}

// ========================================
// PUBLISH PUBLIC LIVE SCORE
// ========================================

async function publishPublicScore() {
  if (!canScore() || !match || !score?.innings?.length) return;

  const lastInnings =
    score.innings[score.innings.length - 1];

  const isCompleted =
    score.innings.length >= 2 &&
    lastInnings.completed === true;

  const teamNames = Object.fromEntries(
    teams.map((team) => [
      team.id,
      team.name || "Team"
    ])
  );

  const playerNames = Object.fromEntries(
    players.map((player) => [
      player.id,
      player.fullName || "Player"
    ])
  );

  const publicData = {
    matchId,
    clubId,

    title: match.title ||
      `${teamName(match.teamAId)} vs ${teamName(match.teamBId)}`,

    matchDate: match.matchDate || "",
    startTime: match.startTime || "",
    venue: match.venue || "",
    format: match.format || "",
    overs: Number(match.overs || 20),

    teamAId: match.teamAId,
    teamBId: match.teamBId,

    teamNames,
    playerNames,

    innings: score.innings,
    result: matchResult(),

    status: isCompleted ? "completed" : "live",

    updatedAt: serverTimestamp()
  };

  await setDoc(
    doc(db, "publicMatchScores", matchId),
    publicData,
    { merge: true }
  );
}


// ========================================
// LOAD SCORE
// ========================================

async function loadScore() {
  const snap = await getDoc(scoreRef());

  score = snap.exists() ? snap.data() : null;

  activeIndex = score?.innings?.length
    ? score.innings.length - 1
    : -1;

  render();

  try {
    await publishPublicScore();

  } catch (error) {
    console.error(
      "Could not publish public live score:",
      error
    );

    if (canScore()) {
      $("scoreMessage").textContent =
        "Score saved, but public live-score publishing failed. Check Firestore rules.";
    }
  }
}


// ========================================
// START INNINGS
// ========================================

async function startInnings(number) {
  if (!canScore()) return;

  const battingTeamId = $("battingTeam").value;
  const bowlingTeamId = $("bowlingTeam").value;

  const strikerId = $("openingStriker").value;
  const nonStrikerId = $("openingNonStriker").value;
  const bowlerId = $("openingBowler").value;

  if (
    !battingTeamId ||
    !bowlingTeamId ||
    battingTeamId === bowlingTeamId ||
    !strikerId ||
    !nonStrikerId ||
    strikerId === nonStrikerId ||
    !bowlerId
  ) {
    alert(
      "Choose valid teams, two different opening batters and a bowler."
    );
    return;
  }

  const innings = [
    ...(score?.innings || []),
    {
      number,

      battingTeamId,
      bowlingTeamId,

      strikerId,
      nonStrikerId,
      openingStrikerId: strikerId,
      openingNonStrikerId: nonStrikerId,
      bowlerId,

      total: 0,
      wickets: 0,
      legalBalls: 0,
      extras: 0,

      batters: {},
      bowlers: {},
      deliveries: [],

      dismissedBatterIds: [],
      completed: false
    }
  ];

  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(scoreRef());

      if (number === 1 && snap.exists()) {
        throw new Error("An innings already exists.");
      }

      if (
        number === 2 &&
        (
          !snap.exists() ||
          snap.data().innings.length !== 1 ||
          !snap.data().innings[0].completed
        )
      ) {
        throw new Error(
          "Complete the first innings before starting the second."
        );
      }

      if (snap.exists()) {
        tx.update(scoreRef(), {
          innings,
          updatedAt: serverTimestamp()
        });

      } else {
        tx.set(scoreRef(), {
          clubId,
          matchId,
          innings,

          createdAt: serverTimestamp(),
          createdBy: user.uid,

          updatedAt: serverTimestamp()
        });
      }
    });

    await loadScore();

    toast(`${ordinal(number)} innings started.`);

  } catch (e) {
    console.error(e);

    alert(
      e.message || "Could not start innings. Check Firestore rules."
    );
  }
}


// ========================================
// UPDATE PLAYER CHOICES
// ========================================

function updatePlayerChoices() {
  const batting = players.filter(
    (p) => p.teamId === $("battingTeam").value
  );

  const bowling = players.filter(
    (p) => p.teamId === $("bowlingTeam").value
  );

  populate("openingStriker", batting);
  populate("openingNonStriker", batting);
  populate("openingBowler", bowling);
}


// ========================================
// EVENT LISTENERS
// ========================================

// START INNINGS FORM

$("inningsForm").addEventListener("submit", (e) => {
  e.preventDefault();

  startInnings(
    score?.innings?.length ? 2 : 1
  );
});


// NEXT INNINGS

$("nextInningsBtn").addEventListener("click", () => {
  const first = score.innings[0];

  $("battingTeam").value = first.bowlingTeamId;
  $("bowlingTeam").value = first.battingTeamId;

  updatePlayerChoices();

  $("setupCard").classList.remove("hidden");
  $("liveCard").classList.add("hidden");
});


// TEAM SELECTION

$("battingTeam").addEventListener("change", () => {
  const selected = $("battingTeam").value;

  $("bowlingTeam").value =
    teams.find((x) => x.id !== selected)?.id || "";

  updatePlayerChoices();
});

$("bowlingTeam").addEventListener(
  "change",
  updatePlayerChoices
);


// ========================================
// BATTER AND BOWLER SELECTION
// ========================================

[
  "strikerSelect",
  "nonStrikerSelect",
  "bowlerSelect"
].forEach((id) => {

  $(id).addEventListener("change", async () => {
    const inn = current();

    if (!inn || !canScore() || scoringBusy) return;

    const selectedId = $(id).value;

    const field =
      id === "strikerSelect"
        ? "strikerId"
        : id === "nonStrikerSelect"
          ? "nonStrikerId"
          : "bowlerId";

    // FIXED BOWLER DROPDOWN VALIDATION

    if (field === "bowlerId") {
      const limit = maxOversPerBowler();

      if (bowlerOvers(inn, selectedId) >= limit) {
        alert(
          `${playerName(selectedId)} has reached the ${limit}-over limit.`
        );

        render();
        return;
      }

      const atOverStart =
        inn.legalBalls > 0 &&
        inn.legalBalls % 6 === 0;

      const previousBowlerId =
        previousOverBowlerId(inn);

      // Compare against the actual previous over bowler.

      if (
        atOverStart &&
        selectedId === previousBowlerId
      ) {
        alert(
          "The same bowler cannot bowl consecutive overs."
        );

        render();
        return;
      }
    }

    try {
      await runTransaction(db, async (tx) => {
        const snap = await tx.get(scoreRef());

        if (!snap.exists()) {
          throw new Error("Score record missing.");
        }

        const innings = snap.data().innings;

        innings[activeIndex] = {
          ...innings[activeIndex],
          [field]: selectedId
        };

        tx.update(scoreRef(), {
          innings,
          updatedAt: serverTimestamp()
        });
      });

      await loadScore();

    } catch (e) {
      console.error(e);

      alert("Could not update the selected player.");
    }
  });

});


// ========================================
// SCORING BUTTONS AND MODALS
// ========================================
document.querySelectorAll("[data-run]").forEach(button => {
  button.addEventListener("click", () => saveDelivery("normal", Number(button.dataset.run)));
});

const openModal = id => $(id).classList.add("open");
const closeModal = id => $(id).classList.remove("open");
let pendingExtrasKind = null;

$("wicketBtn").addEventListener("click", () => {
  const inn = current();
  if (!inn || inn.completed) return;
  const dismissed = new Set(inn.dismissedBatterIds || []);
  const eligible = players.filter(p => p.teamId === inn.battingTeamId &&
    !dismissed.has(p.id) && (p.id === inn.strikerId || p.id === inn.nonStrikerId));
  $("dismissedBatter").innerHTML = eligible.map(p =>
    `<option value="${esc(p.id)}">${esc(p.fullName || p.name)}</option>`).join("");
  const incoming = players.filter(p => p.teamId === inn.battingTeamId &&
    !dismissed.has(p.id) && p.id !== inn.strikerId && p.id !== inn.nonStrikerId);
  $("incomingBatter").innerHTML = `<option value="">Select incoming batter</option>` +
    incoming.map(p => `<option value="${esc(p.id)}">${esc(p.fullName || p.name)}</option>`).join("");
  $("incomingBatter").disabled = inn.wickets >= 9;
  openModal("wicketModal");
});
$("cancelWicket").addEventListener("click", () => closeModal("wicketModal"));
$("confirmWicket").addEventListener("click", async () => {
  const incoming = $("incomingBatter").value;
  if (current()?.wickets < 9 && !incoming) { alert("Select the incoming batter."); return; }
  closeModal("wicketModal");
  await saveDelivery("normal", 0, true, {
    dismissedBatterId:$("dismissedBatter").value,
    incomingBatterId:incoming,
    dismissalType:$("wicketType").value
  });
});

function requestExtras(kind) {
  if (!current() || current().completed) return;
  pendingExtrasKind = kind;
  const config = {
    wide:["Wide runs","Enter additional runs. One automatic wide is added.",0],
    no_ball:["No-ball","Enter runs scored off the bat. One automatic no-ball is added.",0],
    bye:["Byes","Enter the number of byes.",1],
    leg_bye:["Leg-byes","Enter the number of leg-byes.",1],
    penalty:["Penalty runs","Penalty runs are added to the team total and are not charged to the bowler.",5]
  }[kind];
  $("extrasModalTitle").textContent = config[0];
  $("extrasHelp").textContent = config[1];
  $("extrasRuns").value = config[2];
  $("extrasRuns").max = kind === "penalty" ? "100" : "6";
  openModal("extrasModal");
}
$("wideBtn").addEventListener("click", () => requestExtras("wide"));
$("noBallBtn").addEventListener("click", () => requestExtras("no_ball"));
$("byeBtn").addEventListener("click", () => requestExtras("bye"));
$("legByeBtn").addEventListener("click", () => requestExtras("leg_bye"));
$("penaltyBtn").addEventListener("click", () => requestExtras("penalty"));
$("cancelExtras").addEventListener("click", () => closeModal("extrasModal"));
$("confirmExtras").addEventListener("click", async () => {
  const value = Number($("extrasRuns").value);
  const kind = pendingExtrasKind;
  const max = kind === "penalty" ? 100 : 6;
  if (!Number.isInteger(value) || value < 0 || value > max || (["bye","leg_bye"].includes(kind) && value === 0)) {
    alert(`Enter a whole number from ${kind === "bye" || kind === "leg_bye" ? 1 : 0} to ${max}.`);
    return;
  }
  closeModal("extrasModal");
  await saveDelivery(kind, kind === "no_ball" ? value : 0, false, {runs:value});
});

// ========================================
// UNDO LAST DELIVERY
// ========================================
$("undoBtn").addEventListener("click", async () => {
  const inn = current();
  if (!inn?.deliveries?.length || !canScore() || scoringBusy || !confirm("Undo the most recent delivery?")) return;
  const events = inn.deliveries.slice(0,-1);
  const last = inn.deliveries[inn.deliveries.length-1];
  try {
    const rebuilt = {
      ...inn, total:0,wickets:0,legalBalls:0,extras:0,extrasByType:{},
      batters:{},bowlers:{},deliveries:events,dismissedBatterIds:[],completed:false
    };
    for (const d of events) {
      rebuilt.total += Number(d.totalRuns||0);
      rebuilt.extras += Number(d.extraRuns||0);
      rebuilt.extrasByType[d.kind] = (rebuilt.extrasByType[d.kind]||0) + Number(d.extraRuns||0);
      if (d.legal) rebuilt.legalBalls++;
      if (d.kind !== "wide" && d.kind !== "penalty") {
        const b = rebuilt.batters[d.strikerId] || {runs:0,balls:0,fours:0,sixes:0};
        if (d.legal) b.balls++;
        b.runs += Number(d.batterRuns||0);
        if (d.batterRuns===4) b.fours++;
        if (d.batterRuns===6) b.sixes++;
        rebuilt.batters[d.strikerId] = b;
      }
      if (d.kind !== "penalty") {
        const b = rebuilt.bowlers[d.bowlerId] || {runs:0,wickets:0,legalBalls:0};
        if (!["bye","leg_bye"].includes(d.kind)) b.runs += Number(d.totalRuns||0);
        if (d.legal) b.legalBalls++;
        if (d.wicket && !["run_out","retired_hurt"].includes(d.dismissalType)) b.wickets++;
        rebuilt.bowlers[d.bowlerId] = b;
      }
      if (d.wicket) {
        rebuilt.wickets++;
        rebuilt.dismissedBatterIds.push(d.dismissedBatterId || d.strikerId);
      }
    }
    rebuilt.strikerId = last.strikerId || inn.openingStrikerId || inn.strikerId;
    rebuilt.nonStrikerId = last.nonStrikerId || inn.openingNonStrikerId || inn.nonStrikerId;
    rebuilt.bowlerId = last.bowlerId || inn.bowlerId;
    const maxBalls = Number(match.overs || 20)*6;
    rebuilt.completed = rebuilt.wickets >= 10 || rebuilt.legalBalls >= maxBalls ||
      (rebuilt.number === 2 && rebuilt.total > (score.innings[0]?.total ?? Infinity));
    const innings = score.innings.map((x,i) => i===activeIndex ? rebuilt : x);
    await runTransaction(db, async tx => {
      const snap = await tx.get(scoreRef());
      if (!snap.exists()) throw new Error("Score record missing.");
      tx.update(scoreRef(), {innings,updatedAt:serverTimestamp(),updatedBy:user.uid});
    });
    await loadScore();
    toast("Last delivery undone.");
  } catch(e) {
    console.error(e);
    alert(e.message || "Could not undo delivery.");
  }
});

// ========================================
// END INNINGS
// ========================================

$("endInningsBtn").addEventListener("click", async () => {
  if (
    !canScore() ||
    scoringBusy ||
    !confirm("End this innings now?")
  ) {
    return;
  }

  try {
    const innings = score.innings.map((x, i) =>
      i === activeIndex
        ? { ...x, completed: true }
        : x
    );

    await runTransaction(db, async (tx) => {
      tx.update(scoreRef(), {
        innings,
        updatedAt: serverTimestamp()
      });
    });

    await loadScore();

  } catch (e) {
    console.error(e);

    alert("Could not end innings.");
  }
});


// ========================================
// SIGN OUT
// ========================================

$("signOutBtn").addEventListener("click", async () => {
  if (auth) {
    await signOut(auth);
  }

  location.href = "index.html";
});


// ========================================
// FIREBASE INITIALIZATION
// ========================================

if (!isConfigured || !auth || !db) {

  fatal(
    "Firebase is not configured. Check js/firebase.js."
  );

} else if (!clubId || !matchId) {

  fatal(
    "No match was selected. Open Live scoring from your club's Match Centre."
  );

} else {

  onAuthStateChanged(auth, async (u) => {

    if (!u) {
      location.href = "index.html";
      return;
    }

    user = u;

    $("userEmail").textContent = u.email || "";

    $("backMatches").href =
      `matches.html?clubId=${encodeURIComponent(clubId)}`;

    $("scorecardLink").href =
      `scorecard.html?clubId=${encodeURIComponent(clubId)}&matchId=${encodeURIComponent(matchId)}`;

    try {

      // CHECK MEMBERSHIP

      const membership = await getDoc(
        doc(db, "memberships", `${u.uid}_${clubId}`)
      );

      if (
        !membership.exists() ||
        membership.data().status !== "active"
      ) {
        fatal(
          "You do not have access to this club."
        );

        return;
      }

      role = membership.data().role || "member";

      // LOAD MATCH, TEAMS AND PLAYERS

      const [
        matchSnap,
        teamSnap,
        playerSnap
      ] = await Promise.all([

        getDoc(doc(db, "matches", matchId)),

        getDocs(
          query(
            collection(db, "teams"),
            where("clubId", "==", clubId)
          )
        ),

        getDocs(
          query(
            collection(db, "players"),
            where("clubId", "==", clubId)
          )
        )

      ]);

      if (
        !matchSnap.exists() ||
        matchSnap.data().clubId !== clubId
      ) {
        fatal(
          "This match could not be found in the selected club."
        );

        return;
      }

      match = {
        id: matchSnap.id,
        ...matchSnap.data()
      };

      teams = teamSnap.docs.map((d) => ({
        id: d.id,
        ...d.data()
      }));

      players = playerSnap.docs.map((d) => ({
        id: d.id,
        ...d.data()
      }));

      // CHECK MATCH TEAMS

      if (
        !teams.some((x) => x.id === match.teamAId) ||
        !teams.some((x) => x.id === match.teamBId)
      ) {
        fatal(
          "The match teams are missing. Check the club team records."
        );

        return;
      }

      // MATCH INFORMATION

      $("matchTitle").textContent =
        match.title ||
        `${teamName(match.teamAId)} vs ${teamName(match.teamBId)}`;

      $("matchMeta").textContent =
        `${match.matchDate || ""} · ${match.startTime || ""} · ${match.venue || ""} · ${match.format || ""}`;

      // TEAM DROPDOWNS

      $("battingTeam").innerHTML =
        `<option value="${esc(match.teamAId)}">${esc(teamName(match.teamAId))}</option>
         <option value="${esc(match.teamBId)}">${esc(teamName(match.teamBId))}</option>`;

      $("bowlingTeam").innerHTML =
        `<option value="${esc(match.teamBId)}">${esc(teamName(match.teamBId))}</option>
         <option value="${esc(match.teamAId)}">${esc(teamName(match.teamAId))}</option>`;

      updatePlayerChoices();

      // VIEW-ONLY PERMISSION

      if (!canScore()) {
        $("setupCard").classList.add("hidden");

        $("scoreMessage").textContent =
          "You can view this match score, but only club admins or owners can record deliveries.";
      }

      await loadScore();

    } catch (e) {

      console.error(e);

      fatal(
        e.code === "permission-denied"
          ? "Access denied. Check your published Firestore rules."
          : "Could not load match scoring data."
      );

    }

  });

}
