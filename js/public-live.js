import { db, isConfigured } from "./firebase.js";
import { collection, onSnapshot, query, where } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const hasDocument = typeof document !== "undefined";
const list = hasDocument ? document.getElementById("publicLiveList") : null;
const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[c]));
const overs = (balls) => `${Math.floor((Number(balls) || 0) / 6)}.${(Number(balls) || 0) % 6}`;

const terminalStatuses = new Set(["completed", "abandoned", "cancelled"]);

const normalizeStatus = (value) => String(value || "").trim().toLowerCase();

function isGenuinelyLive(match) {
  if (normalizeStatus(match.status) !== "live") return false;

  const matchStatus = normalizeStatus(match.matchStatus);
  if (terminalStatuses.has(matchStatus)) return false;

  const innings = match.innings || [];
  const secondInnings = innings[1];

  if (secondInnings?.completed === true) return false;

  return true;
}

function sortByUpdatedAtDesc(matches) {
  return [...matches].sort((a, b) => {
    const at = a.updatedAt?.toMillis?.() || 0;
    const bt = b.updatedAt?.toMillis?.() || 0;
    return bt - at;
  });
}

export function subscribePublicLiveFeed(onMatches, onError) {
  if (!isConfigured || !db) {
    if (typeof onMatches === "function") onMatches([]);
    return () => {};
  }

  const liveQuery = query(collection(db, "publicMatchScores"), where("status", "==", "live"));

  return onSnapshot(liveQuery, (snapshot) => {
    const matches = snapshot.docs
      .map((item) => ({ id: item.id, ...item.data() }))
      .filter(isGenuinelyLive);

    if (typeof onMatches === "function") {
      onMatches(sortByUpdatedAtDesc(matches));
    }
  }, (error) => {
    if (typeof onError === "function") onError(error);
  });
}

function render(matches) {
  if (!matches.length) {
    list.innerHTML = '<div class="public-live-empty">There are no live matches right now. Check back when a club starts scoring.</div>';
    return;
  }

  list.innerHTML = matches.map((match) => {
    const innings = match.innings || [];
    const last = innings[innings.length - 1];
    const teams = match.teamNames || {};
    const first = innings[0];
    const firstName = first ? teams[first.battingTeamId] || "Team" : teams[match.teamAId] || "Team A";
    const secondName = last ? teams[last.battingTeamId] || "Team" : teams[match.teamBId] || "Team B";
    const firstScore = first ? `${first.total || 0}/${first.wickets || 0}` : "Yet to bat";
    const secondScore = last && last !== first ? `${last.total || 0}/${last.wickets || 0}` : "Yet to bat";
    const firstOvers = first ? `${overs(first.legalBalls)} ov` : "";
    const secondOvers = last && last !== first ? `${overs(last.legalBalls)} ov` : "";
    const title = match.title || `${firstName} vs ${secondName}`;
    return `
      <a class="public-live-card" href="public-scorecard.html?matchId=${encodeURIComponent(match.matchId)}">
        <div class="public-live-card-top"><span class="public-live-pill">● LIVE</span><span class="public-live-date">${esc(match.matchDate || "")}</span></div>
        <strong>${esc(title)}</strong>
        <div class="public-live-team"><strong>${esc(firstName)}</strong><b>${esc(firstScore)}</b></div>
        <div class="public-live-team"><strong>${esc(secondName)}</strong><b>${esc(secondScore)}</b></div>
        <div class="public-live-overs">${esc(firstOvers)}${secondOvers ? ` · ${esc(secondOvers)}` : ""} ${match.format ? `· ${esc(match.format)}` : ""}</div>
        <span class="text-action">View scorecard and summary →</span>
      </a>`;
  }).join("");
}

if (list) {
  if (!isConfigured || !db) {
    list.innerHTML = '<div class="public-live-empty">Live scores will appear here after Firebase is configured.</div>';
  } else {
    subscribePublicLiveFeed((matches) => {
      render(matches);
    }, (error) => {
      console.error("Live score feed error:", error);
      list.innerHTML = '<div class="public-live-empty">Could not load live scores. Check the published Firestore rules.</div>';
    });
  }
}
