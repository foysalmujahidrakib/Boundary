import { subscribeLiveMatchesFeed } from "./livematches.js";

const byId = (id) => document.getElementById(id);
const ticker = byId("ticker-matches-list");
const hero = byId("dynamic-hero-container");
const scorecard = byId("dynamic-scorecard-container");
const timeline = byId("dynamic-overs-container");
const stats = byId("dynamic-stats-container");

let matches = [];
let selectedMatchId = null;
let activeTab = "live";

const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
}[char]));

const ballsToOvers = (balls) => {
  const legalBalls = Number(balls) || 0;
  return `${Math.floor(legalBalls / 6)}.${legalBalls % 6}`;
};

function selectedMatch() {
  return matches.find((match) => (match.matchId || match.id) === selectedMatchId) || null;
}

function matchDetails(match) {
  const innings = match?.innings || [];
  const first = innings[0] || null;
  const latest = innings[innings.length - 1] || null;
  const names = match?.teamNames || {};
  const firstName = first ? names[first.battingTeamId] || "Team A" : names[match?.teamAId] || "Team A";
  const secondName = latest && latest !== first
    ? names[latest.battingTeamId] || "Team B"
    : names[match?.teamBId] || "Team B";
  return { innings, first, latest, firstName, secondName };
}

function score(innings) {
  return innings ? `${innings.total || 0}/${innings.wickets || 0}` : "Yet to bat";
}

function showEmpty(container, message) {
  container.innerHTML = `<div class="rounded-2xl border border-white/10 bg-petrol-900/70 p-6 text-center text-sm text-gray-300">${escapeHtml(message)}</div>`;
}

function renderTicker() {
  if (!matches.length) {
    ticker.innerHTML = '<span class="text-gray-400 text-xs italic">No live matches right now.</span>';
    return;
  }

  ticker.innerHTML = matches.map((match) => {
    const id = match.matchId || match.id;
    const { first, latest, firstName, secondName } = matchDetails(match);
    const isSelected = id === selectedMatchId;
    return `<button type="button" data-match-id="${escapeHtml(id)}" class="rounded-lg border px-3 py-1.5 text-left transition ${isSelected ? "border-mint-400/70 bg-mint-400/15" : "border-white/10 bg-petrol-900/60 hover:border-mint-400/40"}">
      <span class="font-semibold text-gray-100">${escapeHtml(firstName)} vs ${escapeHtml(secondName)}</span>
      <span class="ml-2 font-mono text-[11px] text-mint-400">${escapeHtml(score(first))}${latest && latest !== first ? ` · ${escapeHtml(score(latest))}` : ""}</span>
    </button>`;
  }).join("");

  ticker.querySelectorAll("[data-match-id]").forEach((button) => {
    button.addEventListener("click", () => selectMatch(button.dataset.matchId));
  });
}

function renderLiveMatch() {
  const match = selectedMatch();
  if (!match) return showEmpty(hero, "There are no live matches right now. Check back when scoring starts.");

  const { first, latest, firstName, secondName } = matchDetails(match);
  const title = match.title || `${firstName} vs ${secondName}`;
  hero.innerHTML = `
    <div class="absolute -right-12 -top-16 h-56 w-56 rounded-full bg-mint-400/10 blur-3xl"></div>
    <div class="relative">
      <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div><span class="rounded-full border border-blaze-500/40 bg-blaze-500/15 px-3 py-1 text-xs font-extrabold uppercase tracking-wider text-blaze-500">● Live</span><h1 class="mt-3 text-xl font-black text-white sm:text-2xl">${escapeHtml(title)}</h1></div>
        <div class="text-right text-xs text-gray-400"><p>${escapeHtml(match.venue || "Venue to be confirmed")}</p><p class="mt-1">${escapeHtml(match.matchDate || "")}${match.startTime ? ` · ${escapeHtml(match.startTime)}` : ""}</p></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div class="rounded-2xl border border-white/10 bg-petrol-900/75 p-5"><p class="text-sm font-bold text-gray-200">${escapeHtml(firstName)}</p><p class="mt-2 font-mono text-3xl font-black text-white">${escapeHtml(score(first))}</p><p class="mt-1 text-xs text-gray-400">${first ? `${ballsToOvers(first.legalBalls)} overs` : "Yet to bat"}</p></div>
        <div class="rounded-2xl border border-white/10 bg-petrol-900/75 p-5"><p class="text-sm font-bold text-gray-200">${escapeHtml(secondName)}</p><p class="mt-2 font-mono text-3xl font-black text-white">${escapeHtml(latest && latest !== first ? score(latest) : "Yet to bat")}</p><p class="mt-1 text-xs text-gray-400">${latest && latest !== first ? `${ballsToOvers(latest.legalBalls)} overs` : "Yet to bat"}</p></div>
      </div>
      <div class="mt-5 flex flex-wrap items-center justify-between gap-3 text-sm"><span class="text-gray-300">${escapeHtml(match.format || "Cricket match")}${match.overs ? ` · ${escapeHtml(match.overs)} overs` : ""}</span><a class="font-bold text-mint-400 hover:text-mint-300" href="public-scorecard.html?matchId=${encodeURIComponent(match.matchId || match.id)}">Open full scorecard →</a></div>
    </div>`;
}

function renderScorecard() {
  const match = selectedMatch();
  if (!match) return showEmpty(scorecard, "Select a live match to inspect its scorecard.");
  const { innings, firstName, secondName } = matchDetails(match);
  if (!innings.length) return showEmpty(scorecard, "This match has not recorded an innings yet.");
  scorecard.innerHTML = innings.map((inningsEntry, index) => {
    const name = match.teamNames?.[inningsEntry.battingTeamId] || (index === 0 ? firstName : secondName);
    return `<div class="${index ? "mt-4 border-t border-white/10 pt-4" : ""}"><div class="flex items-center justify-between gap-3"><h2 class="font-extrabold text-white">${escapeHtml(name)} innings</h2><span class="font-mono text-lg font-black text-mint-400">${escapeHtml(score(inningsEntry))}</span></div><p class="mt-1 text-sm text-gray-400">${ballsToOvers(inningsEntry.legalBalls)} overs · Extras ${Number(inningsEntry.extras) || 0}${inningsEntry.completed ? " · Innings complete" : ""}</p></div>`;
  }).join("");
}

function renderTimeline() {
  const match = selectedMatch();
  if (!match) return showEmpty(timeline, "Select a live match to view its innings timeline.");
  const { innings } = matchDetails(match);
  if (!innings.length) return showEmpty(timeline, "No innings events are available yet.");
  timeline.innerHTML = `<h2 class="mb-4 font-extrabold text-white">Innings progress</h2>${innings.map((entry, index) => `<div class="mb-3 rounded-xl border border-white/10 bg-petrol-900/60 p-4"><div class="flex justify-between gap-3"><span class="font-bold text-gray-100">Innings ${index + 1}</span><span class="font-mono text-mint-400">${escapeHtml(score(entry))}</span></div><p class="mt-1 text-sm text-gray-400">${ballsToOvers(entry.legalBalls)} overs · ${Number(entry.wickets) || 0} wickets</p></div>`).join("")}`;
}

function renderStats() {
  const match = selectedMatch();
  if (!match) return showEmpty(stats, "Select a live match to view match information.");
  const { firstName, secondName } = matchDetails(match);
  stats.innerHTML = `<h2 class="mb-4 font-extrabold text-white">Match information</h2><dl class="grid gap-3 text-sm sm:grid-cols-2"><div class="rounded-xl border border-white/10 bg-petrol-900/60 p-4"><dt class="text-gray-400">Teams</dt><dd class="mt-1 font-bold text-white">${escapeHtml(firstName)} vs ${escapeHtml(secondName)}</dd></div><div class="rounded-xl border border-white/10 bg-petrol-900/60 p-4"><dt class="text-gray-400">Format</dt><dd class="mt-1 font-bold text-white">${escapeHtml(match.format || "Not specified")}</dd></div><div class="rounded-xl border border-white/10 bg-petrol-900/60 p-4"><dt class="text-gray-400">Venue</dt><dd class="mt-1 font-bold text-white">${escapeHtml(match.venue || "Not specified")}</dd></div><div class="rounded-xl border border-white/10 bg-petrol-900/60 p-4"><dt class="text-gray-400">Match date</dt><dd class="mt-1 font-bold text-white">${escapeHtml(match.matchDate || "Not specified")}</dd></div></dl>`;
}

function render() {
  renderTicker();
  renderLiveMatch();
  renderScorecard();
  renderTimeline();
  renderStats();
}

function selectMatch(matchId) {
  selectedMatchId = matchId;
  render();
}

window.switchTab = (tab) => {
  activeTab = tab;
  document.querySelectorAll(".tab-view").forEach((view) => view.classList.toggle("hidden", view.id !== `view-${tab}`));
  document.querySelectorAll(".nav-tab").forEach((button) => {
    const active = button.id === `tab-btn-${tab}`;
    button.classList.toggle("bg-mint-400", active);
    button.classList.toggle("text-petrol-900", active);
    button.classList.toggle("text-gray-300", !active);
  });
};

window.toggleSound = () => {
  const icon = byId("sound-icon");
  icon?.classList.toggle("fa-volume-high");
  icon?.classList.toggle("fa-volume-xmark");
};

subscribeLiveMatchesFeed((nextMatches) => {
  matches = nextMatches;
  if (!matches.some((match) => (match.matchId || match.id) === selectedMatchId)) {
    selectedMatchId = matches[0]?.matchId || matches[0]?.id || null;
  }
  render();
}, (error) => {
  console.error("Could not load live matches:", error);
  const message = "Could not load live matches. Please try again shortly.";
  ticker.innerHTML = `<span class="text-red-300 text-xs">${message}</span>`;
  showEmpty(hero, message);
});

window.switchTab(activeTab);
