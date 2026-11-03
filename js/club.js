import { auth, db, isConfigured } from "./firebase.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { collection, doc, getDoc, getDocs, query, where, addDoc, updateDoc, deleteDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const params = new URLSearchParams(location.search);
const clubId = params.get("clubId");
let user = null, club = null, role = "member", teams = [], players = [];
const $ = id => document.getElementById(id);
const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const isAdmin = () => ["club_admin", "club_owner"].includes(role);

if (!isConfigured || !auth || !db) showFatal("Firebase is not configured. Update js/firebase.js first.");
else if (!clubId) showFatal("No club was selected. Return to your dashboard and open a club.");

if (auth) onAuthStateChanged(auth, async signedInUser => {
  if (!signedInUser) { location.href = "index.html"; return; }
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
    $("clubMeta").textContent = [data.location, data.description].filter(Boolean).join(" · ") || "Teams and player directory";
    $("sideClubName").textContent = data.name || "Cricket club";
    $("sideClubLocation").textContent = data.location || "Location not added";
    $("clubRole").textContent = role.replaceAll("_", " ").toUpperCase();
    if (!isAdmin()) document.querySelectorAll(".admin-only").forEach(el => el.classList.add("hidden"));
    await refreshData();
  } catch (err) { console.error(err); showFatal(err.code === "permission-denied" ? "Access denied by Firestore rules. Publish the Stage 3 rules." : "Could not open this club. Check your Firestore setup."); }
});

async function refreshData() {
  const [teamSnap, playerSnap] = await Promise.all([
    getDocs(query(collection(db, "teams"), where("clubId", "==", clubId))),
    getDocs(query(collection(db, "players"), where("clubId", "==", clubId)))
  ]);
  teams = teamSnap.docs.map(d => ({ id:d.id, ...d.data() })).sort((a,b)=>(a.name||"").localeCompare(b.name||""));
  players = playerSnap.docs.map(d => ({ id:d.id, ...d.data() })).sort((a,b)=>(a.fullName||"").localeCompare(b.fullName||""));
  renderTeams(); renderPlayers(); updateCounts(); updateTeamOptions();
}
function updateCounts() {
  $("teamCount").textContent = `${teams.length} TEAM${teams.length===1?"":"S"}`;
  $("playerCount").textContent = `${players.length} PLAYER${players.length===1?"":"S"}`;
  $("sideTeamCount").textContent = teams.length; $("sidePlayerCount").textContent = players.length;
}
function renderTeams() {
  $("teamList").innerHTML = teams.length ? teams.map(t => `<div class="management-item"><div class="club-avatar">${esc((t.name||"T").slice(0,2).toUpperCase())}</div><div class="management-item-info"><strong>${esc(t.name)}</strong><small>${esc(t.category||"Team")} · ${players.filter(p=>p.teamId===t.id).length} players${t.description?` · ${esc(t.description)}`:""}</small></div>${isAdmin()?`<div class="item-actions"><button class="text-action" data-edit-team="${esc(t.id)}">Edit</button><button class="text-action danger" data-delete-team="${esc(t.id)}">Delete</button></div>`:""}</div>`).join("") : '<div class="empty-state">No teams have been created yet.</div>';
}
function renderPlayers() {
  $("playerList").innerHTML = players.length ? players.map(p => { const team=teams.find(t=>t.id===p.teamId); return `<div class="management-item player-item"><div class="player-number">${p.jerseyNumber!==undefined && p.jerseyNumber!==""?`#${esc(p.jerseyNumber)}`:"—"}</div><div class="management-item-info"><strong>${esc(p.fullName)}</strong><small>${esc(p.role||"Player")} · ${esc(team?.name||"Unassigned")} · ${esc(p.battingStyle||"Batting style not set")}${p.bowlingStyle?` · ${esc(p.bowlingStyle)}`:""}</small></div>${isAdmin()?`<div class="item-actions"><button class="text-action" data-edit-player="${esc(p.id)}">Edit</button><button class="text-action danger" data-delete-player="${esc(p.id)}">Remove</button></div>`:""}</div>`; }).join("") : '<div class="empty-state">No players registered yet.</div>';
}
function updateTeamOptions(selected="") { $("playerTeam").innerHTML = '<option value="">Unassigned</option>'+teams.map(t=>`<option value="${esc(t.id)}" ${t.id===selected?"selected":""}>${esc(t.name)}</option>`).join(""); }

$("teamForm").addEventListener("submit", async e => {
  e.preventDefault(); if(!isAdmin()) return;
  const id=$("teamId").value, payload={clubId, name:$("teamName").value.trim(), category:$("teamCategory").value, description:$("teamDescription").value.trim(), updatedAt:serverTimestamp()};
  if(!payload.name) return; setBusy("saveTeamBtn",true,"Saving…");
  try { if(id) await updateDoc(doc(db,"teams",id),payload); else await addDoc(collection(db,"teams"),{...payload,createdAt:serverTimestamp(),createdBy:user.uid}); resetTeamForm(); await refreshData(); toast(id?"Team updated.":"Team created."); }
  catch(err){ console.error(err); $("teamMessage").textContent=err.code==="permission-denied"?"Permission denied. Publish the Stage 3 Firestore rules.":"Could not save team."; }
  finally { setBusy("saveTeamBtn",false,"Save team →"); }
});
$("playerForm").addEventListener("submit", async e => {
  e.preventDefault(); if(!isAdmin()) return;
  const id=$("playerId").value, number=$("jerseyNumber").value;
  const payload={clubId, fullName:$("playerName").value.trim(), jerseyNumber:number===""?null:Number(number), role:$("playerRole").value, teamId:$("playerTeam").value||null, battingStyle:$("battingStyle").value, bowlingStyle:$("bowlingStyle").value.trim(), updatedAt:serverTimestamp()};
  if(!payload.fullName) return; setBusy("savePlayerBtn",true,"Saving…");
  try { if(id) await updateDoc(doc(db,"players",id),payload); else await addDoc(collection(db,"players"),{...payload,createdAt:serverTimestamp(),createdBy:user.uid}); resetPlayerForm(); await refreshData(); toast(id?"Player updated.":"Player registered."); }
  catch(err){ console.error(err); $("playerMessage").textContent=err.code==="permission-denied"?"Permission denied. Publish the Stage 3 Firestore rules.":"Could not save player."; }
  finally { setBusy("savePlayerBtn",false,"Save player →"); }
});

document.addEventListener("click", async e => {
  const editTeam=e.target.closest("[data-edit-team]")?.dataset.editTeam;
  const deleteTeam=e.target.closest("[data-delete-team]")?.dataset.deleteTeam;
  const editPlayer=e.target.closest("[data-edit-player]")?.dataset.editPlayer;
  const deletePlayer=e.target.closest("[data-delete-player]")?.dataset.deletePlayer;
  if(editTeam){ const t=teams.find(x=>x.id===editTeam); if(!t)return; $("teamId").value=t.id; $("teamName").value=t.name||""; $("teamCategory").value=t.category||"Senior"; $("teamDescription").value=t.description||""; $("teamFormTitle").textContent="Edit team"; $("cancelTeamEdit").classList.remove("hidden"); $("teamFormCard").scrollIntoView({behavior:"smooth"}); }
  if(deleteTeam){ const t=teams.find(x=>x.id===deleteTeam); if(!t)return; if(players.some(p=>p.teamId===t.id)){alert("Move or unassign this team's players before deleting the team.");return;} if(confirm(`Delete ${t.name}?`)){try{await deleteDoc(doc(db,"teams",t.id));await refreshData();toast("Team deleted.");}catch(err){console.error(err);alert("Could not delete team. Check permissions.");}} }
  if(editPlayer){ const p=players.find(x=>x.id===editPlayer); if(!p)return; $("playerId").value=p.id; $("playerName").value=p.fullName||""; $("jerseyNumber").value=p.jerseyNumber??""; $("playerRole").value=p.role||"Batter"; updateTeamOptions(p.teamId||""); $("battingStyle").value=p.battingStyle||"Not specified"; $("bowlingStyle").value=p.bowlingStyle||""; $("playerFormTitle").textContent="Edit player"; $("cancelPlayerEdit").classList.remove("hidden"); $("playerFormCard").scrollIntoView({behavior:"smooth"}); }
  if(deletePlayer){ const p=players.find(x=>x.id===deletePlayer); if(p&&confirm(`Remove ${p.fullName} from this club?`)){try{await deleteDoc(doc(db,"players",p.id));await refreshData();toast("Player removed.");}catch(err){console.error(err);alert("Could not remove player. Check permissions.");}} }
});
function resetTeamForm(){ $("teamForm").reset(); $("teamId").value=""; $("teamFormTitle").textContent="Add a team"; $("cancelTeamEdit").classList.add("hidden"); }
function resetPlayerForm(){ $("playerForm").reset(); $("playerId").value=""; $("playerFormTitle").textContent="Register a player"; $("cancelPlayerEdit").classList.add("hidden"); updateTeamOptions(); }
$("cancelTeamEdit").addEventListener("click",resetTeamForm); $("cancelPlayerEdit").addEventListener("click",resetPlayerForm);
$("signOutBtn").addEventListener("click",async()=>{if(auth)await signOut(auth);location.href="index.html";});
function setBusy(id,busy,label){$(id).disabled=busy;$(id).textContent=label;}
function toast(msg){const el=$("toast");el.textContent=msg;el.classList.add("show");setTimeout(()=>el.classList.remove("show"),2400);}
function showFatal(msg){const el=$("pageNotice");el.textContent=msg;el.classList.remove("hidden");$("teamList").innerHTML='';$("playerList").innerHTML='';}
