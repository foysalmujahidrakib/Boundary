import { auth, db, isConfigured } from "./firebase.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { collection, doc, getDoc, getDocs, query, where, addDoc, updateDoc, deleteDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";
const $=id=>document.getElementById(id), params=new URLSearchParams(location.search), clubId=params.get("clubId");
const esc=v=>String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
let user=null, role="member", teams=[], tournaments=[];
const admin=()=>["club_admin","club_owner"].includes(role);
if(!isConfigured||!auth||!db) fatal("Firebase is not configured. Add your working Firebase web configuration to js/firebase.js.");
else if(!clubId) fatal("No club was selected. Return to your dashboard and open a club before choosing Tournaments.");
$("backClub").href=clubId?`club.html?clubId=${encodeURIComponent(clubId)}`:"dashboard.html";
if(auth) onAuthStateChanged(auth,async signedUser=>{
 if(!signedUser){location.href="index.html";return;} user=signedUser; $("userEmail").textContent=user.email||"";
 if(!isConfigured||!clubId)return;
 try{
  const ms=await getDoc(doc(db,"memberships",`${user.uid}_${clubId}`));
  if(!ms.exists()||ms.data().status!=="active"){fatal("You do not have access to this club workspace.");return;}
  role=ms.data().role||"member"; const cs=await getDoc(doc(db,"clubs",clubId));
  if(!cs.exists()){fatal("This club could not be found.");return;}
  const c=cs.data(); $("clubName").textContent=c.name||"Cricket club"; $("sideClubName").textContent=c.name||"Cricket club"; $("clubRole").textContent=role.replaceAll("_"," ").toUpperCase();
  if(!admin())$("tournamentFormCard").classList.add("hidden");
  await refresh();
 }catch(e){console.error(e);fatal(e.code==="permission-denied"?"Access denied. Publish the Stage 4 Firestore rules.":"Could not load this club. Check your Firebase setup.");}
});
async function refresh(){
 const [ts,rs]=await Promise.all([getDocs(query(collection(db,"teams"),where("clubId","==",clubId))),getDocs(query(collection(db,"tournaments"),where("clubId","==",clubId)))]);
 teams=ts.docs.map(d=>({id:d.id,...d.data()})).sort((a,b)=>(a.name||"").localeCompare(b.name||""));
 tournaments=rs.docs.map(d=>({id:d.id,...d.data()})).sort((a,b)=>(a.startDate||"").localeCompare(b.startDate||""));
 $("sideTeamCount").textContent=teams.length; $("tournamentCount").textContent=`${tournaments.length} TOURNAMENT${tournaments.length===1?"":"S"}`; $("sideTournamentCount").textContent=tournaments.length; renderTeams(); renderTournaments();
}
function renderTeams(selected=[]){const box=$("teamChoices");if(!teams.length){box.innerHTML='<div class="empty-state">No teams found. Add teams in your club workspace first.</div>';return;}box.innerHTML=teams.map(t=>`<label class="team-check"><input type="checkbox" name="teamIds" value="${esc(t.id)}" ${selected.includes(t.id)?"checked":""}><span>${esc(t.name)}</span><small>${esc(t.category||"Team")}</small></label>`).join("");}
function renderTournaments(){const box=$("tournamentList");if(!tournaments.length){box.innerHTML='<div class="empty-state">No tournaments yet. Create your first competition below.</div>';return;}box.innerHTML=tournaments.map(t=>{const names=(t.teamIds||[]).map(id=>teams.find(x=>x.id===id)?.name).filter(Boolean);return `<article class="management-item tournament-item"><div class="trophy-mark">🏆</div><div class="management-item-info"><strong>${esc(t.name)}</strong><small>${esc(t.format||"Format not set")} · ${esc(t.season||"Season not set")} · ${esc(t.startDate||"Date TBC")} to ${esc(t.endDate||"TBC")}</small><small>${names.length?esc(names.join(" · ")):"No participating teams listed"}${t.venue?` · ${esc(t.venue)}`:""}</small><span class="status-chip status-${esc(t.status||"planned")}">${esc((t.status||"planned").toUpperCase())}</span></div>${admin()?`<div class="item-actions"><button class="text-action" data-edit="${esc(t.id)}">Edit</button><button class="text-action danger" data-delete="${esc(t.id)}">Delete</button></div>`:""}</article>`;}).join("");}
$("tournamentForm").addEventListener("submit",async e=>{e.preventDefault();if(!admin())return;const id=$("tournamentId").value, teamIds=[...document.querySelectorAll('input[name="teamIds"]:checked')].map(x=>x.value);const payload={clubId,name:$("tournamentName").value.trim(),season:$("season").value.trim(),format:$("format").value,startDate:$("startDate").value,endDate:$("endDate").value,venue:$("venue").value.trim(),status:$("status").value,teamIds,updatedAt:serverTimestamp()};
 if(!payload.name){msg("Enter a tournament name.");return;}if(!payload.startDate||!payload.endDate||payload.endDate<payload.startDate){msg("Enter valid dates. The end date cannot be before the start date.");return;}if(teamIds.length<2){msg("Select at least two participating teams.");return;}if(teamIds.some(tid=>!teams.some(t=>t.id===tid))){msg("One or more selected teams do not belong to this club. Refresh and try again.");return;}
 setBusy(true);try{if(id)await updateDoc(doc(db,"tournaments",id),payload);else await addDoc(collection(db,"tournaments"),{...payload,createdAt:serverTimestamp(),createdBy:user.uid});resetForm();await refresh();toast(id?"Tournament updated.":"Tournament created.");}catch(err){console.error(err);msg(err.code==="permission-denied"?"Permission denied. Publish the Stage 4 Firestore rules.":"Could not save tournament. Check your Firebase connection.");}finally{setBusy(false);}});
document.addEventListener("click",async e=>{const edit=e.target.closest("[data-edit]")?.dataset.edit,del=e.target.closest("[data-delete]")?.dataset.delete;if(edit){const t=tournaments.find(x=>x.id===edit);if(!t)return;$("tournamentId").value=t.id;$("tournamentName").value=t.name||"";$("season").value=t.season||"";$("format").value=t.format||"T20";$("startDate").value=t.startDate||"";$("endDate").value=t.endDate||"";$("venue").value=t.venue||"";$("status").value=t.status||"planned";$("formTitle").textContent="Edit tournament";$("saveTournamentBtn").textContent="Save changes →";$("cancelEditBtn").classList.remove("hidden");renderTeams(t.teamIds||[]);$("tournamentFormCard").scrollIntoView({behavior:"smooth"});}if(del){const t=tournaments.find(x=>x.id===del);if(t&&confirm(`Delete tournament “${t.name}”?`)){try{await deleteDoc(doc(db,"tournaments",t.id));await refresh();toast("Tournament deleted.");}catch(err){console.error(err);alert("Could not delete tournament. Check Firestore rules.");}}}});
function resetForm(){$("tournamentForm").reset();$("tournamentId").value="";$("formTitle").textContent="Create a tournament";$("saveTournamentBtn").textContent="Create tournament →";$("cancelEditBtn").classList.add("hidden");renderTeams();$("formMessage").textContent="";}
$("cancelEditBtn").addEventListener("click",resetForm);$("signOutBtn").addEventListener("click",async()=>{if(auth)await signOut(auth);location.href="index.html";});
function msg(s){$("formMessage").textContent=s;}function setBusy(b){$("saveTournamentBtn").disabled=b;$("saveTournamentBtn").textContent=b?"Saving…":($("tournamentId").value?"Save changes →":"Create tournament →");}
function toast(s){const el=$("toast");el.textContent=s;el.classList.add("show");setTimeout(()=>el.classList.remove("show"),2500);}function fatal(s){const n=$("pageNotice");if(n){n.textContent=s;n.classList.remove("hidden");$("tournamentList").innerHTML="";}}
