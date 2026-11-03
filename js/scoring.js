
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
  $("oversText").textContent =
    `${ballsToOvers(inn.legalBalls)} overs`;

  $("inningsHeading").textContent =
    `${ordinal(inn.number)} innings`;

  $("inningsTeams").textContent =
    `${teamName(inn.battingTeamId)} batting · ${teamName(inn.bowlingTeamId)} bowling`;

  $("inningsStatus").textContent =
    inn.completed ? "COMPLETED" : "IN PROGRESS";

  const dismissed = new Set(inn.dismissedBatterIds || []);

  const batting = players.filter((p) =>
    p.teamId === inn.battingTeamId &&
    !dismissed.has(p.id)
  );

  const bowling = players.filter((p) =>
    p.teamId === inn.bowlingTeamId
  );

  populate("strikerSelect", batting, inn.strikerId);
  populate("nonStrikerSelect", batting, inn.nonStrikerId);
  populate("bowlerSelect", bowling, inn.bowlerId);

  $("strikerSelect").disabled =
    $("nonStrikerSelect").disabled =
    $("bowlerSelect").disabled =
      inn.completed || !canScore();

  const controlsDisabled =
    inn.completed || !canScore() || scoringBusy;

  document.querySelectorAll(
    "[data-run],#wicketBtn,#wideBtn,#noBallBtn,#byeBtn,#legByeBtn"
  ).forEach((b) => {
    b.disabled = controlsDisabled;
  });

  $("undoBtn").disabled =
    !inn.deliveries.length || !canScore() || scoringBusy;

  $("endInningsBtn").disabled =
    inn.completed || !canScore() || scoringBusy;

  $("nextInningsBtn").classList.toggle(
    "hidden",
    !inn.completed || score.innings.length >= 2
  );

  // BALL LOG

  $("ballLog").innerHTML = inn.deliveries.length
    ? inn.deliveries.slice(-18).map((d) =>
        `<span class="ball-chip ${
          d.wicket ? "wicket" :
          d.batterRuns === 4 || d.batterRuns === 6 ? "boundary" : ""
        }">${esc(d.label)}</span>`
      ).join("")
    : '<span class="muted">No deliveries yet.</span>';

  // BATTING TABLE

  const batRows = Object.entries(inn.batters || {})
    .filter(([id]) => !dismissed.has(id))
    .map(([id, v]) => ({ id, ...v }));

  $("battingTable").innerHTML = batRows.length
    ? `<table class="score-table">
        <thead>
          <tr>
            <th>Batter</th>
            <th>R</th>
            <th>B</th>
            <th>4s</th>
            <th>6s</th>
          </tr>
        </thead>
        <tbody>
          ${batRows.map((p) =>
            `<tr>
              <td>${esc(playerName(p.id))}${p.id === inn.strikerId ? " *" : ""}</td>
              <td>${p.runs}</td>
              <td>${p.balls}</td>
              <td>${p.fours}</td>
              <td>${p.sixes}</td>
            </tr>`
          ).join("")}
        </tbody>
      </table>`
    : "No active batting figures.";

  // BOWLING TABLE

  const bowlRows = Object.entries(inn.bowlers || {})
    .map(([id, v]) => ({ id, ...v }));

  $("bowlingTable").innerHTML = bowlRows.length
    ? `<table class="score-table">
        <thead>
          <tr>
            <th>Bowler</th>
            <th>O</th>
            <th>R</th>
            <th>W</th>
          </tr>
        </thead>
        <tbody>
          ${bowlRows.map((p) =>
            `<tr>
              <td>${esc(playerName(p.id))}${p.id === inn.bowlerId ? " *" : ""}</td>
              <td>${ballsToOvers(p.legalBalls)}</td>
              <td>${p.runs}</td>
              <td>${p.wickets}</td>
            </tr>`
          ).join("")}
        </tbody>
      </table>`
    : "No bowling figures.";

  // INNINGS SUMMARY

  $("inningsSummary").innerHTML = score.innings.map((i) =>
    `<p>
      <strong>${ordinal(i.number)}:</strong>
      ${esc(teamName(i.battingTeamId))}
      ${i.total}/${i.wickets}
      (${ballsToOvers(i.legalBalls)} ov)
    </p>`
  ).join("");

  const result = matchResult();

  if (result) {
    $("inningsSummary").innerHTML +=
      `<p class="match-result"><strong>${esc(result)}</strong></p>`;
  }
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

async function saveDelivery(kind, requestedRuns = 0, wicket = false) {
  const inn = current();

  if (!inn || inn.completed || !canScore() || scoringBusy) return;

  const striker = $("strikerSelect").value;
  const nonStriker = $("nonStrikerSelect").value;
  const bowler = $("bowlerSelect").value;

  if (
    !striker ||
    !nonStriker ||
    !bowler ||
    striker === nonStriker
  ) {
    $("scoreMessage").textContent =
      "Select two different batters and a bowler.";
    return;
  }

  // FIXED BOWLER VALIDATION

  const bowlerLimit = maxOversPerBowler();

  const atOverStart =
    inn.legalBalls > 0 &&
    inn.legalBalls % 6 === 0;

  const previousBowlerId = previousOverBowlerId(inn);

  // Check against the actual previous over bowler,
  // NOT the currently selected bowler.

  if (atOverStart && bowler === previousBowlerId) {
    $("scoreMessage").textContent =
      "A different bowler must bowl the next over. Select another bowler.";
    return;
  }

  if (bowlerOvers(inn, bowler) >= bowlerLimit) {
    $("scoreMessage").textContent =
      `This bowler has reached the ${bowlerLimit}-over limit. Select another bowler.`;
    return;
  }

  let batterRuns = requestedRuns;
  let extraRuns = 0;

  // WIDE

  if (kind === "wide") {
    const additional = askRuns(
      "Additional wide runs (excluding the automatic 1 wide)?",
      "0"
    );

    if (additional === null) return;

    batterRuns = 0;
    extraRuns = 1 + additional;
  }

  // NO BALL

  else if (kind === "no_ball") {
    const offBat = askRuns(
      "Runs scored off the bat on this no-ball (excluding the automatic 1 no-ball)?",
      "0"
    );

    if (offBat === null) return;

    batterRuns = offBat;
    extraRuns = 1;
  }

  // BYE / LEG BYE

  else if (kind === "bye" || kind === "leg_bye") {
    batterRuns = 0;

    const extras = askRuns(
      `How many ${kind === "bye" ? "byes" : "leg-byes"}?`,
      "1"
    );

    if (extras === null || extras === 0) return;

    extraRuns = extras;
  }

  const totalRuns = batterRuns + extraRuns;

  const legal = legalBall(kind);

  const overWillEnd =
    legal && (inn.legalBalls + 1) % 6 === 0;

  let incomingBatterId = null;

  // WICKET

  if (wicket) {
    incomingBatterId = chooseNewBatter(inn);

    if (!incomingBatterId) {
      const dismissedCount =
        (inn.dismissedBatterIds || []).length + 1;

      if (dismissedCount < 10) {
        alert("Select a valid incoming batter to record this wicket.");
        return;
      }
    }
  }

  // CALCULATE INNINGS COMPLETION

  let nextBowlerId = null;

  const projectedMaxBalls =
    Number(match.overs || 20) * 6;

  const projectedWickets =
    inn.wickets + (wicket ? 1 : 0);

  const projectedTotal =
    inn.total + totalRuns;

  const projectedBalls =
    inn.legalBalls + (legal ? 1 : 0);

  const projectedTargetReached =
    inn.number === 2 &&
    projectedTotal > (score.innings[0]?.total ?? Infinity);

  const projectedInningsComplete =
    projectedWickets >= 10 ||
    projectedBalls >= projectedMaxBalls ||
    projectedTargetReached;

  // ASK FOR NEXT BOWLER WHEN AN OVER ENDS

  if (overWillEnd && !projectedInningsComplete) {
    nextBowlerId = chooseNextBowler({
      ...inn,
      legalBalls: inn.legalBalls + 1,
      bowlerId: bowler
    });
  }

  // DELIVERY OBJECT

  const delivery = {
    kind,
    batterRuns,
    extraRuns,
    totalRuns,
    wicket,

    label: wicket ? "W" :
      kind === "wide" ? `Wd${extraRuns}` :
      kind === "no_ball" ? `Nb${totalRuns}` :
      kind === "bye" ? `B${extraRuns}` :
      kind === "leg_bye" ? `Lb${extraRuns}` :
      String(batterRuns),

    legal,
    strikerId: striker,
    nonStrikerId: nonStriker,
    bowlerId: bowler,
    at: new Date().toISOString()
  };

  scoringBusy = true;
  render();

  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(scoreRef());

      if (!snap.exists()) {
        throw new Error("Score record missing.");
      }

      const data = snap.data();

      const innings = data.innings.map((x) => ({
        ...x,
        deliveries: [...(x.deliveries || [])],
        batters: { ...(x.batters || {}) },
        bowlers: { ...(x.bowlers || {}) },
        dismissedBatterIds: [...(x.dismissedBatterIds || [])]
      }));

      const i = innings[activeIndex];

      if (!i || i.completed) {
        throw new Error("This innings is already complete.");
      }

      const batter = i.batters[striker] || {
        runs: 0,
        balls: 0,
        fours: 0,
        sixes: 0
      };

      // BATTER STATS

      if (kind !== "wide") {
        if (legal) batter.balls++;

        batter.runs += batterRuns;

        if (batterRuns === 4) batter.fours++;
        if (batterRuns === 6) batter.sixes++;
      }

      i.batters[striker] = batter;

      // BOWLER STATS

      const bowlerStats = i.bowlers[bowler] || {
        runs: 0,
        wickets: 0,
        legalBalls: 0
      };

      bowlerStats.runs +=
        kind === "bye" || kind === "leg_bye"
          ? 0
          : totalRuns;

      if (legal) bowlerStats.legalBalls++;

      if (wicket) bowlerStats.wickets++;

      i.bowlers[bowler] = bowlerStats;

      // UPDATE SCORE

      i.total += totalRuns;
      i.extras = (i.extras || 0) + extraRuns;
      i.legalBalls += legal ? 1 : 0;

      i.deliveries.push(delivery);

      // WICKET AND BATTER ROTATION

      if (wicket) {
        i.wickets++;

        i.dismissedBatterIds.push(striker);

        if (incomingBatterId) {
          i.strikerId = incomingBatterId;
        }

      } else if (batterRuns % 2 === 1) {
        [i.strikerId, i.nonStrikerId] =
          [i.nonStrikerId, i.strikerId];
      }

      // CHANGE ENDS AFTER COMPLETED OVER

      if (overWillEnd) {
        [i.strikerId, i.nonStrikerId] =
          [i.nonStrikerId, i.strikerId];
      }

      // CHECK INNINGS COMPLETION

      const maxBalls =
        Number(match.overs || 20) * 6;

      const targetReached =
        i.number === 2 &&
        i.total > (data.innings[0]?.total ?? Infinity);

      const allOut = i.wickets >= 10;

      const oversFinished =
        i.legalBalls >= maxBalls;

      if (allOut || oversFinished || targetReached) {
        i.completed = true;
      }

      // SAVE THE NEXT BOWLER

      if (overWillEnd && !i.completed && nextBowlerId) {
        i.bowlerId = nextBowlerId;
      }

      tx.update(scoreRef(), {
        innings,
        updatedAt: serverTimestamp(),
        updatedBy: user.uid
      });
    });

    await loadScore();

    $("scoreMessage").textContent = "Delivery saved.";

    if (overWillEnd && !current()?.completed && !nextBowlerId) {
      $("scoreMessage").textContent =
        "Over completed. Please select the next bowler.";
    }

    if (current()?.completed) {
      toast("Innings completed.");
    }

  } catch (e) {
    console.error(e);

    $("scoreMessage").textContent =
      e.code === "permission-denied"
        ? "Scoring permission denied. Check your published Firestore rules."
        : e.message || "Could not save delivery.";

  } finally {
    scoringBusy = false;
    render();
  }
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
// SCORING BUTTONS
// ========================================

document.querySelectorAll("[data-run]").forEach((button) => {

  button.addEventListener("click", () =>
    saveDelivery(
      "normal",
      Number(button.dataset.run)
    )
  );

});

$("wicketBtn").addEventListener("click", () =>
  saveDelivery("normal", 0, true)
);

$("wideBtn").addEventListener("click", () =>
  saveDelivery("wide", 0)
);

$("noBallBtn").addEventListener("click", () =>
  saveDelivery("no_ball", 0)
);

$("byeBtn").addEventListener("click", () =>
  saveDelivery("bye", 0)
);

$("legByeBtn").addEventListener("click", () =>
  saveDelivery("leg_bye", 0)
);


// ========================================
// UNDO LAST DELIVERY
// ========================================

$("undoBtn").addEventListener("click", async () => {
  const inn = current();

  if (
    !inn?.deliveries?.length ||
    !canScore() ||
    scoringBusy ||
    !confirm("Undo the most recent delivery?")
  ) {
    return;
  }

  const events = inn.deliveries.slice(0, -1);

  try {
    const rebuilt = {
      ...inn,

      total: 0,
      wickets: 0,
      legalBalls: 0,
      extras: 0,

      batters: {},
      bowlers: {},

      deliveries: events,
      dismissedBatterIds: [],
      completed: false
    };

    // REBUILD SCORE FROM DELIVERY HISTORY

    for (const d of events) {
      rebuilt.total += d.totalRuns;
      rebuilt.extras += d.extraRuns || 0;

      if (d.legal) {
        rebuilt.legalBalls++;
      }

      const batter = rebuilt.batters[d.strikerId] || {
        runs: 0,
        balls: 0,
        fours: 0,
        sixes: 0
      };

      if (d.kind !== "wide") {
        if (d.legal) batter.balls++;

        batter.runs += d.batterRuns;

        if (d.batterRuns === 4) batter.fours++;
        if (d.batterRuns === 6) batter.sixes++;
      }

      rebuilt.batters[d.strikerId] = batter;

      const bowler = rebuilt.bowlers[d.bowlerId] || {
        runs: 0,
        wickets: 0,
        legalBalls: 0
      };

      bowler.runs +=
        d.kind === "bye" || d.kind === "leg_bye"
          ? 0
          : d.totalRuns;

      if (d.legal) {
        bowler.legalBalls++;
      }

      if (d.wicket) {
        rebuilt.wickets++;
        bowler.wickets++;

        rebuilt.dismissedBatterIds.push(d.strikerId);
      }

      rebuilt.bowlers[d.bowlerId] = bowler;
    }

    // RECONSTRUCT BATTERS

    const last = events[events.length - 1];

    if (last) {
      rebuilt.strikerId = last.strikerId;
      rebuilt.nonStrikerId = last.nonStrikerId;
    }

    const innings = score.innings.map((x, i) =>
      i === activeIndex ? rebuilt : x
    );

    await runTransaction(db, async (tx) => {
      tx.update(scoreRef(), {
        innings,
        updatedAt: serverTimestamp()
      });
    });

    await loadScore();

    toast(
      "Last delivery undone. Please verify the batters at the crease."
    );

  } catch (e) {
    console.error(e);

    alert("Could not undo delivery.");
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
