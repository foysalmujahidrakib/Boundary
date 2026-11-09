import { auth, db, isConfigured } from "./firebase.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { collection, doc, getDoc, query, where, addDoc, updateDoc, deleteDoc, onSnapshot, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const params = new URLSearchParams(location.search);
const clubId = params.get("clubId");
let user = null, club = null, role = "member", teams = [], players = [];
let teamsLoaded = false, playersLoaded = false;
let unsubscribers = [];

// Teams start expanded so players are visible directly under their team.
// Set to false to start with every team card collapsed instead.
const DEFAULT_EXPANDED = true;
const toggledTeamIds = new Set();      // teams whose open/closed state differs from the default
const UNASSIGNED_ID = "unassigned";    // pseudo-card for legacy players saved without a team

const $ = id => document.getElementById(id);
const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const isAdmin = () => ["club_admin", "club_owner"].includes(role);
const isOpen = id => DEFAULT_EXPANDED ? !toggledTeamIds.has(id) : toggledTeamIds.has(id);

if (!isConfigured || !auth || !db) showFatal("Firebase is not configured. Update js/firebase.js first.");
else if (!clubId) showFatal("No club was selected. Return to your dashboard and open a club.");

if (auth) onAuthStateChanged(auth, async signedInUser => {
  if (!signedInUser) { stopRealtime(); location.href = "index.html"; return; }
  user = signedInUser; $("userEmail").textContent = user.email || "";
  if (!isConfigured || !clubId) return;
  try {
    const membership = await getDoc(doc(db, "memberships", `${user.uid}_${clubId}`));
    if (!membership.exists() || membership.data().status !== "active") { showFatal("You do not have access to this club workspace."); return; }
    role = membership.data().role || "member";
    club = await getDoc(doc(db, "clubs", clubId));
    if (!club.exists()) { showFatal("This club could not be found."); return; }
    const data = club.data();
    $("clubName").textContent = data.name || "Cricket club";
    $("clubMeta").textContent = [data.location, data.description].filter(Boolean).join(" · ") || "Teams and squads";
    $("sideClubName").textContent = data.name || "Cricket club";
    $("sideClubLocation").textContent = data.location || "Location not added";
    $("clubRole").textContent = role.replaceAll("_", " ").toUpperCase();
    if (!isAdmin()) document.querySelectorAll(".admin-only").forEach(el => el.classList.add("hidden"));
    startRealtime();
  } catch (err) { console.error(err); showFatal(err.code === "permission-denied" ? "Access denied by Firestore rules. Publish the Stage 3 rules." : "Could not open this club. Check your Firestore setup."); }
});

/* ---------- Real-time Firebase sync ---------- */
// Both listeners stay open, so every add / edit / assign / delete (from this
// browser or any other) re-renders the squads automatically. No manual refresh.
function startRealtime() {
  stopRealtime();
  teamsLoaded = playersLoaded = false;
  const forClub = name => query(collection(db, name), where("clubId", "==", clubId));
  unsubscribers.push(onSnapshot(forClub("teams"), snap => {
    teams = snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    teamsLoaded = true; onDataChanged();
  }, listenError));
  unsubscribers.push(onSnapshot(forClub("players"), snap => {
    players = snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => (a.fullName || "").localeCompare(b.fullName || ""));
    playersLoaded = true; onDataChanged();
  }, listenError));
}
function stopRealtime() { unsubscribers.forEach(unsub => unsub()); unsubscribers = []; }
function listenError(err) {
  console.error(err);
  showFatal(err.code === "permission-denied" ? "Access denied by Firestore rules. Publish the Stage 3 rules." : "Live updates stopped. Check your connection and reload.");
}
function onDataChanged() {
  if (!teamsLoaded || !playersLoaded) return;   // render once, with both datasets
  renderSquads(); updateCounts(); updateTeamOptions();
}

/* ---------- Rendering: teams with their players nested underneath ---------- */
function updateCounts() {
  $("teamCount").textContent = `${teams.length} TEAM${teams.length === 1 ? "" : "S"}`;
  $("playerCount").textContent = `${players.length} PLAYER${players.length === 1 ? "" : "S"}`;
  $("sideTeamCount").textContent = teams.length; $("sidePlayerCount").textContent = players.length;
}
const byJerseyThenName = (a, b) => {
  const an = a.jerseyNumber ?? Infinity, bn = b.jerseyNumber ?? Infinity;
  return an - bn || (a.fullName || "").localeCompare(b.fullName || "");
};
function renderSquads() {
  // Group once: teamId -> players. No global player list is ever rendered.
  const squads = new Map(teams.map(t => [t.id, []]));
  const orphans = [];
  players.forEach(p => (squads.get(p.teamId) || orphans).push(p));
  const cards = teams.map(t => teamCard({
    id: t.id, title: t.name || "Unnamed team",
    avatar: (t.name || "T").slice(0, 2).toUpperCase(),
    subtitle: [t.category || "Team", t.description].filter(Boolean).join(" · "),
    squad: squads.get(t.id).sort(byJerseyThenName), canManageTeam: true
  }));
  // Legacy players saved before teams were mandatory. Shown to admins only,
  // inside a normal team-style card, until each one is assigned to a team.
  if (isAdmin() && orphans.length) cards.push(teamCard({
    id: UNASSIGNED_ID, title: "Needs a team", avatar: "?",
    subtitle: "Edit each player to assign them to a team",
    squad: orphans.sort(byJerseyThenName), canManageTeam: false
  }));
  $("teamList").innerHTML = cards.length ? cards.join("") : '<div class="empty-state">No teams have been created yet.</div>';
}
function teamCard({ id, title, avatar, subtitle, squad, canManageTeam }) {
  const open = isOpen(id), safe = esc(id), rosterId = `roster-${safe}`;
  const count = `${squad.length} PLAYER${squad.length === 1 ? "" : "S"}`;
  const actions = isAdmin() && canManageTeam
    ? `<div class="item-actions team-card-actions"><button class="text-action" data-edit-team="${safe}">Edit</button><button class="text-action danger" data-delete-team="${safe}">Delete</button></div>` : "";
  const addBtn = isAdmin() && canManageTeam
    ? `<button class="text-action roster-add" type="button" data-add-player-to="${safe}">+ Add player</button>` : "";
  return `<article class="team-card${open ? " is-open" : ""}">
    <div class="team-card-head">
      <button class="team-toggle" type="button" data-team-toggle="${safe}" aria-expanded="${open}" aria-controls="${rosterId}">
        <span class="club-avatar">${esc(avatar)}</span>
        <span class="team-card-copy"><strong>${esc(title)}</strong><small>${esc(subtitle)}</small></span>
        <span class="team-count-chip">${count}</span>
        <span class="team-chevron" aria-hidden="true">⌄</span>
      </button>${actions}
    </div>
    <div class="team-roster" id="${rosterId}" ${open ? "" : "hidden"}>
      ${squad.length ? `<ul class="roster-list">${squad.map(playerRow).join("")}</ul>` : '<div class="roster-empty">No players registered to this team yet.</div>'}
      ${addBtn}
    </div>
  </article>`;
}
function playerRow(p) {
  const hasNo = p.jerseyNumber !== undefined && p.jerseyNumber !== null && p.jerseyNumber !== "";
  const actions = isAdmin()
    ? `<div class="item-actions"><button class="text-action" data-edit-player="${esc(p.id)}">Edit</button><button class="text-action danger" data-delete-player="${esc(p.id)}">Remove</button></div>` : "";
  return `<li class="roster-row">
    <span class="player-number" title="Jersey number">${hasNo ? `#${esc(p.jerseyNumber)}` : "—"}</span>
    <span class="roster-info"><strong>${esc(p.fullName)}</strong><small>${esc(p.role || "Player")}</small></span>
    ${actions}
  </li>`;
}
// Keeps whatever the admin has already picked, so a live update arriving
// while they are filling in the form does not reset the Team dropdown.
function updateTeamOptions(selected = $("playerTeam").value) {
  const placeholder = teams.length ? "Select a team…" : "Create a team first";
  $("playerTeam").innerHTML = `<option value="" disabled ${selected ? "" : "selected"}>${placeholder}</option>` +
    teams.map(t => `<option value="${esc(t.id)}" ${t.id === selected ? "selected" : ""}>${esc(t.name)}</option>`).join("");
}

/* ---------- Forms ---------- */
$("teamForm").addEventListener("submit", async e => {
  e.preventDefault(); if (!isAdmin()) return;
  const id = $("teamId").value, payload = { clubId, name: $("teamName").value.trim(), category: $("teamCategory").value, description: $("teamDescription").value.trim(), updatedAt: serverTimestamp() };
  if (!payload.name) return; setBusy("saveTeamBtn", true, "Saving…");
  try {
    if (id) await updateDoc(doc(db, "teams", id), payload);
    else await addDoc(collection(db, "teams"), { ...payload, createdAt: serverTimestamp(), createdBy: user.uid });
    resetTeamForm(); toast(id ? "Team updated." : "Team created.");   // the listener re-renders
  } catch (err) { console.error(err); $("teamMessage").textContent = err.code === "permission-denied" ? "Permission denied. Publish the Stage 3 Firestore rules." : "Could not save team."; }
  finally { setBusy("saveTeamBtn", false, "Save team →"); }
});
$("playerForm").addEventListener("submit", async e => {
  e.preventDefault(); if (!isAdmin()) return;
  const id = $("playerId").value, number = $("jerseyNumber").value;
  const payload = { clubId, fullName: $("playerName").value.trim(), jerseyNumber: number === "" ? null : Number(number), role: $("playerRole").value, teamId: $("playerTeam").value || null, battingStyle: $("battingStyle").value, bowlingStyle: $("bowlingStyle").value.trim(), updatedAt: serverTimestamp() };
  if (!payload.fullName) return;
  if (!payload.teamId) { $("playerMessage").textContent = "Choose a team for this player."; return; }
  $("playerMessage").textContent = ""; setBusy("savePlayerBtn", true, "Saving…");
  try {
    if (id) await updateDoc(doc(db, "players", id), payload);
    else await addDoc(collection(db, "players"), { ...payload, createdAt: serverTimestamp(), createdBy: user.uid });
    openTeam(payload.teamId);              // make sure the new/moved player is visible
    resetPlayerForm(); toast(id ? "Player updated." : "Player registered.");
  } catch (err) { console.error(err); $("playerMessage").textContent = err.code === "permission-denied" ? "Permission denied. Publish the Stage 3 Firestore rules." : "Could not save player."; }
  finally { setBusy("savePlayerBtn", false, "Save player →"); }
});

/* ---------- Clicks ---------- */
function openTeam(teamId) {
  if (DEFAULT_EXPANDED) toggledTeamIds.delete(teamId); else toggledTeamIds.add(teamId);
}
document.addEventListener("click", async e => {
  const toggle = e.target.closest("[data-team-toggle]");
  const addTo = e.target.closest("[data-add-player-to]")?.dataset.addPlayerTo;
  const editTeam = e.target.closest("[data-edit-team]")?.dataset.editTeam;
  const deleteTeam = e.target.closest("[data-delete-team]")?.dataset.deleteTeam;
  const editPlayer = e.target.closest("[data-edit-player]")?.dataset.editPlayer;
  const deletePlayer = e.target.closest("[data-delete-player]")?.dataset.deletePlayer;

  if (toggle) {   // expand / collapse in place (no re-render, so scroll position is kept)
    const id = toggle.dataset.teamToggle;
    toggledTeamIds.has(id) ? toggledTeamIds.delete(id) : toggledTeamIds.add(id);
    const open = isOpen(id);
    toggle.setAttribute("aria-expanded", open);
    toggle.closest(".team-card").classList.toggle("is-open", open);
    document.getElementById(toggle.getAttribute("aria-controls")).hidden = !open;
  }
  if (addTo) { resetPlayerForm(); updateTeamOptions(addTo); $("playerFormTitle").textContent = "Register a player"; $("playerFormCard").scrollIntoView({ behavior: "smooth" }); $("playerName").focus({ preventScroll: true }); }
  if (editTeam) { const t = teams.find(x => x.id === editTeam); if (!t) return; $("teamId").value = t.id; $("teamName").value = t.name || ""; $("teamCategory").value = t.category || "Senior"; $("teamDescription").value = t.description || ""; $("teamFormTitle").textContent = "Edit team"; $("cancelTeamEdit").classList.remove("hidden"); $("teamFormCard").scrollIntoView({ behavior: "smooth" }); }
  if (deleteTeam) { const t = teams.find(x => x.id === deleteTeam); if (!t) return; if (players.some(p => p.teamId === t.id)) { alert("Move or remove this team's players before deleting the team."); return; } if (confirm(`Delete ${t.name}?`)) { try { await deleteDoc(doc(db, "teams", t.id)); toast("Team deleted."); } catch (err) { console.error(err); alert("Could not delete team. Check permissions."); } } }
  if (editPlayer) { const p = players.find(x => x.id === editPlayer); if (!p) return; $("playerId").value = p.id; $("playerName").value = p.fullName || ""; $("jerseyNumber").value = p.jerseyNumber ?? ""; $("playerRole").value = p.role || "Batter"; updateTeamOptions(p.teamId || ""); $("battingStyle").value = p.battingStyle || "Not specified"; $("bowlingStyle").value = p.bowlingStyle || ""; $("playerFormTitle").textContent = "Edit player"; $("cancelPlayerEdit").classList.remove("hidden"); $("playerFormCard").scrollIntoView({ behavior: "smooth" }); }
  if (deletePlayer) { const p = players.find(x => x.id === deletePlayer); if (p && confirm(`Remove ${p.fullName} from this club?`)) { try { await deleteDoc(doc(db, "players", p.id)); toast("Player removed."); } catch (err) { console.error(err); alert("Could not remove player. Check permissions."); } } }
});
function resetTeamForm() { $("teamForm").reset(); $("teamId").value = ""; $("teamFormTitle").textContent = "Add a team"; $("cancelTeamEdit").classList.add("hidden"); }
function resetPlayerForm() { $("playerForm").reset(); $("playerId").value = ""; $("playerFormTitle").textContent = "Register a player"; $("cancelPlayerEdit").classList.add("hidden"); updateTeamOptions(""); }
$("cancelTeamEdit").addEventListener("click", resetTeamForm); $("cancelPlayerEdit").addEventListener("click", resetPlayerForm);
$("signOutBtn").addEventListener("click", async () => { stopRealtime(); if (auth) await signOut(auth); location.href = "index.html"; });
function setBusy(id, busy, label) { $(id).disabled = busy; $(id).textContent = label; }
function toast(msg) { const el = $("toast"); el.textContent = msg; el.classList.add("show"); setTimeout(() => el.classList.remove("show"), 2400); }
function showFatal(msg) { const el = $("pageNotice"); el.textContent = msg; el.classList.remove("hidden"); $("teamList").innerHTML = ""; }
