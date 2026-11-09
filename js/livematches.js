import { db, isConfigured } from "./firebase.js";
import { collection, onSnapshot, query, where } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const hasDocument = typeof document !== "undefined";
const list = hasDocument ? document.getElementById("liveMatchList") : null;

const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;"
}[c]));

const overs = (balls) => {
  const legalBalls = Number(balls) || 0;
  return `${Math.floor(legalBalls / 6)}.${legalBalls % 6}`;
};

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

export function subscribeLiveMatchesFeed(onMatches, onError) {
  if (!isConfigured || !db) {
    if (typeof onMatches === "function") onMatches([]);
    return () => {};
  }

  const liveQuery = query(collection(db, "publicMatchScores"), where("status", "==", "live"));

  return onSnapshot(liveQuery, (snapshot) => {
    const matches = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
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
    list.innerHTML = '<div class="rounded-xl border border-white/10 bg-petrol-900/70 p-4 text-sm text-gray-300 sm:col-span-2 xl:col-span-3">There are no live matches right now. Check back when scoring starts.</div>';
    return;
  }

  list.innerHTML = matches.map((match) => {
    const innings = match.innings || [];
    const firstInnings = innings[0];
    const latestInnings = innings[innings.length - 1];
    const teams = match.teamNames || {};

    const firstName = firstInnings
      ? teams[firstInnings.battingTeamId] || "Team A"
      : teams[match.teamAId] || "Team A";
    const secondName = latestInnings
      ? teams[latestInnings.battingTeamId] || "Team B"
      : teams[match.teamBId] || "Team B";

    const firstScore = firstInnings
      ? `${firstInnings.total || 0}/${firstInnings.wickets || 0}`
      : "Yet to bat";
    const secondScore = latestInnings && latestInnings !== firstInnings
      ? `${latestInnings.total || 0}/${latestInnings.wickets || 0}`
      : "Yet to bat";

    const firstOvers = firstInnings ? `${overs(firstInnings.legalBalls)} ov` : "";
    const secondOvers = latestInnings && latestInnings !== firstInnings
      ? `${overs(latestInnings.legalBalls)} ov`
      : "";

    const title = match.title || `${firstName} vs ${secondName}`;

    return `
      <a href="public-scorecard.html?matchId=${encodeURIComponent(match.matchId)}" class="group rounded-xl border border-white/10 bg-petrol-900/70 p-4 transition hover:border-mint-400/40 hover:bg-petrol-800/80">
        <div class="mb-3 flex items-center justify-between text-[11px] uppercase tracking-wide">
          <span class="rounded-full border border-blaze-500/40 bg-blaze-500/15 px-2 py-1 font-bold text-blaze-500">Live</span>
          <span class="text-gray-400">${esc(match.matchDate || "")}</span>
        </div>
        <h3 class="mb-3 text-sm font-extrabold text-white">${esc(title)}</h3>
        <div class="space-y-2 text-sm">
          <div class="flex items-center justify-between text-gray-200">
            <strong>${esc(firstName)}</strong>
            <span class="font-mono">${esc(firstScore)}</span>
          </div>
          <div class="flex items-center justify-between text-gray-300">
            <strong>${esc(secondName)}</strong>
            <span class="font-mono">${esc(secondScore)}</span>
          </div>
        </div>
        <p class="mt-3 text-xs text-gray-400">${esc(firstOvers)}${secondOvers ? ` • ${esc(secondOvers)}` : ""}${match.format ? ` • ${esc(match.format)}` : ""}</p>
        <p class="mt-3 text-xs font-bold text-mint-400">Open scorecard →</p>
      </a>`;
  }).join("");
}

if (list) {
  if (!isConfigured || !db) {
    list.innerHTML = '<div class="rounded-xl border border-white/10 bg-petrol-900/70 p-4 text-sm text-gray-300 sm:col-span-2 xl:col-span-3">Live scores will appear here after Firebase is configured.</div>';
  } else {
    subscribeLiveMatchesFeed((matches) => {
      render(matches);
    }, (error) => {
      console.error("Live score feed error:", error);
      list.innerHTML = '<div class="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-300 sm:col-span-2 xl:col-span-3">Could not load live matches. Check Firestore rules and published data.</div>';
    });
  }
}
