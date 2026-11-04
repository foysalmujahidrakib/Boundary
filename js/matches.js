import { auth, db, isConfigured } from "./firebase.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { 
    collection, 
    doc, 
    getDoc, 
    getDocs, 
    query, 
    where, 
    addDoc, 
    updateDoc, 
    deleteDoc, 
    serverTimestamp 
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const $ = id => document.getElementById(id);
const params = new URLSearchParams(location.search);
const clubId = params.get("clubId");

const esc = v => String(v ?? "").replace(/[&<>"']/g, c => ({ 
    "&": "&amp;", 
    "<": "&lt;", 
    ">": "&gt;", 
    '"': "&quot;", 
    "'": "&#39;" 
}[c]));

let user = null;
let role = "member";
let teams = [];
let tournaments = [];
let matches = [];

const admin = () => ["club_admin", "club_owner"].includes(role);

function fatal(s) {
    const n = $("pageNotice");
    if (n) {
        n.textContent = s; 
        n.classList.remove("hidden");
        $("matchList").innerHTML = "";
    }
}

$("backClub").href = clubId ? `club.html?clubId=${encodeURIComponent(clubId)}` : "dashboard.html";

if (!isConfigured || !auth || !db) {
    fatal("Firebase is not configured. Copy your working Stage 4 js/firebase.js into this project.");
} else if (!clubId) {
    fatal("No club was selected. Return to your dashboard and open a club before choosing Matches.");
}

if (auth) {
    onAuthStateChanged(auth, async u => {
        if (!u) { 
            location.href = "index.html"; 
            return; 
        }
        user = u;
        $("userEmail").textContent = u.email || "";

        if (!isConfigured || !clubId) return;

        try {
            const m = await getDoc(doc(db, "memberships", `${u.uid}_${clubId}`));
            if (!m.exists() || m.data().status !== "active") {
                fatal("You do not have access to this club workspace.");
                return;
            }
            
            role = m.data().role || "member";
            const c = await getDoc(doc(db, "clubs", clubId));
            
            if (!c.exists()) {
                fatal("This club could not be found.");
                return;
            }

            $("clubName").textContent = c.data().name || "Cricket club";
            $("sideClubName").textContent = c.data().name || "Cricket club";
            $("clubRole").textContent = role.replaceAll("_", " ").toUpperCase();
            
            if (!admin()) $("matchFormCard").classList.add("hidden");
            
            await refresh();
        } catch (e) {
            console.error(e);
            fatal(e.code === "permission-denied" ? "Access denied. Publish the Stage 5 Firestore rules." : "Could not load this club. Check your Firebase setup.");
        }
    });
}

async function refresh() {
    const [a, b, c] = await Promise.all([
        getDocs(query(collection(db, "teams"), where("clubId", "==", clubId))),
        getDocs(query(collection(db, "tournaments"), where("clubId", "==", clubId))),
        getDocs(query(collection(db, "matches"), where("clubId", "==", clubId)))
    ]);

    teams = a.docs.map(d => ({ id: d.id, ...d.data() })).sort((x, y) => (x.name || "").localeCompare(y.name || ""));
    tournaments = b.docs.map(d => ({ id: d.id, ...d.data() }));
    matches = c.docs.map(d => ({ id: d.id, ...d.data() })).sort((x, y) => (x.matchDate || "").localeCompare(y.matchDate || "") || (x.startTime || "").localeCompare(y.startTime || ""));
    
    fillSelects();
    render();
    
    $("matchCount").textContent = `${matches.length} MATCH${matches.length === 1 ? "" : "ES"}`;
    $("sideMatchCount").textContent = matches.length;
    $("sideTeamCount").textContent = teams.length;
    $("sideTournamentCount").textContent = tournaments.length;
}

function fillSelects() {
    const options = teams.map(t => `<option value="${esc(t.id)}">${esc(t.name)}</option>`).join("");
    
    for (const id of ["teamA", "teamB"]) {
        const old = $(id).value;
        $(id).innerHTML = '<option value="">Choose team</option>' + options;
        $(id).value = old;
    }
    
    const oldT = $("tossWinnerId").value;
    $("tossWinnerId").innerHTML = '<option value="">Not decided</option>' + options;
    $("tossWinnerId").value = oldT;

    const oldTour = $("tournamentId").value;
    $("tournamentId").innerHTML = '<option value="">Friendly / standalone match</option>' + tournaments.map(t => `<option value="${esc(t.id)}">${esc(t.name)}</option>`).join("");
    $("tournamentId").value = oldTour;
}

function render() {
    const box = $("matchList");
    if (!matches.length) {
        box.innerHTML = '<div class="empty-state">No matches scheduled yet. Create your first fixture below.</div>';
        return;
    }

    box.innerHTML = matches.map(m => {
        const a = teams.find(t => t.id === m.teamAId)?.name || "Unknown team";
        const b = teams.find(t => t.id === m.teamBId)?.name || "Unknown team";
        const tour = tournaments.find(t => t.id === m.tournamentId)?.name;

        return `<article class="management-item">
            <div class="trophy-mark">🏏</div>
            <div class="management-item-info">
                <strong>${esc(m.title || `${a} vs ${b}`)}</strong>
                <small>${esc(a)} <b>vs</b> ${esc(b)} · ${esc(m.format || "Format")} (${esc(m.overs || "?")} overs)</small>
                <small>${esc(m.matchDate || "Date TBC")} · ${esc(m.startTime || "Time TBC")} · ${esc(m.venue || "Venue TBC")}</small>
                <small>${tour ? `🏆 ${esc(tour)} · ` : ""}${m.tossWinnerId ? `Toss: ${esc(teams.find(t => t.id === m.tossWinnerId)?.name || "Team")} elected to ${esc(m.tossDecision || "decide")}` : "Toss not decided"}</small>
                <span class="status-chip status-${esc(m.status || "scheduled")}">${esc((m.status || "scheduled").replaceAll("_", " ").toUpperCase())}</span>
            </div>
            <div class="item-actions">
                <a class="text-action" href="scoring.html?clubId=${encodeURIComponent(clubId)}&matchId=${encodeURIComponent(m.id)}">Live scoring</a>
                <a class="text-action" href="scorecard.html?clubId=${encodeURIComponent(clubId)}&matchId=${encodeURIComponent(m.id)}">Scorecard</a>
                ${admin() ? `<button class="text-action" data-edit="${esc(m.id)}">Edit</button><button class="text-action danger" data-delete="${esc(m.id)}">Delete</button>` : ""}
            </div>
        </article>`;
    }).join("");
}

$("matchForm").addEventListener("submit", async e => {
    e.preventDefault();
    if (!admin()) return;

    const id = $("matchId").value;
    const teamAId = $("teamA").value;
    const teamBId = $("teamB").value;
    const tossWinnerId = $("tossWinnerId").value;

    const payload = {
        clubId,
        title: $("matchTitle").value.trim(),
        tournamentId: $("tournamentId").value || null,
        teamAId,
        teamBId,
        matchDate: $("matchDate").value,
        startTime: $("startTime").value,
        venue: $("venue").value.trim(),
        format: $("format").value,
        overs: Number($("overs").value),
        status: $("status").value,
        tossWinnerId: tossWinnerId || null,
        tossDecision: $("tossDecision").value || null,
        notes: $("notes").value.trim(),
        updatedAt: serverTimestamp()
    };

    if (!teamAId || !teamBId || teamAId === teamBId) {
        message("Choose two different teams.");
        return;
    }
    if (!teams.some(t => t.id === teamAId) || !teams.some(t => t.id === teamBId)) {
        message("Selected teams must belong to this club. Refresh and try again.");
        return;
    }
    if (!payload.matchDate || !payload.startTime || !payload.venue || !Number.isInteger(payload.overs) || payload.overs < 1 || payload.overs > 100) {
        message("Complete the date, time, venue and a valid overs value (1–100).");
        return;
    }
    if (tossWinnerId && ![teamAId, teamBId].includes(tossWinnerId)) {
        message("The toss winner must be one of the two playing teams.");
        return;
    }
    if (payload.tournamentId && !tournaments.some(t => t.id === payload.tournamentId)) {
        message("Choose a tournament belonging to this club.");
        return;
    }

    busy(true);
    try {
        if (id) {
            await updateDoc(doc(db, "matches", id), payload);
        } else {
            await addDoc(collection(db, "matches"), { 
                ...payload, 
                createdAt: serverTimestamp(), 
                createdBy: user.uid 
            });
        }
        reset();
        await refresh();
        toast(id ? "Match updated." : "Match scheduled.");
    } catch (err) {
        console.error(err);
        message(err.code === "permission-denied" ? "Permission denied. Publish the Stage 5 Firestore rules." : "Could not save the match. Check Firebase and try again.");
    } finally {
        busy(false);
    }
});

document.addEventListener("click", async e => {
    const edit = e.target.closest("[data-edit]")?.dataset.edit;
    const del = e.target.closest("[data-delete]")?.dataset.delete;

    if (edit) {
        const m = matches.find(x => x.id === edit);
        if (!m) return;

        $("matchId").value = m.id;
        $("matchTitle").value = m.title || "";
        $("tournamentId").value = m.tournamentId || "";
        $("teamA").value = m.teamAId;
        $("teamB").value = m.teamBId;
        $("matchDate").value = m.matchDate || "";
        $("startTime").value = m.startTime || "";
        $("venue").value = m.venue || "";
        $("format").value = m.format || "T20";
        $("overs").value = m.overs || 20;
        $("status").value = m.status || "scheduled";
        $("tossWinnerId").value = m.tossWinnerId || "";
        $("tossDecision").value = m.tossDecision || "";
        $("notes").value = m.notes || "";
        
        $("formTitle").textContent = "Edit match";
        $("saveMatchBtn").textContent = "Save changes →";
        $("cancelEditBtn").classList.remove("hidden");
        $("matchFormCard").scrollIntoView({ behavior: "smooth" });
    }

    if (del) {
    const m = matches.find(x => x.id === del);

    if (m && confirm(`Delete match “${m.title || "fixture"}”?`)) {
        try {
            // Step 1: Delete the public live-score document.
            await deleteDoc(
                doc(db, "publicMatchScores", m.id)
            );

            // Step 2: Delete the original match document.
            await deleteDoc(
                doc(db, "matches", m.id)
            );

            // Step 3: Refresh the match list.
            await refresh();

            toast("Match and public live score deleted.");

        } catch (err) {
            console.error("Match deletion error:", err);

            alert(
                "Could not completely delete the match. " +
                "Check Firebase permissions and try again."
            );
        }
    }
}
});

function reset() {
    $("matchForm").reset();
    $("matchId").value = "";
    $("overs").value = 20;
    $("formTitle").textContent = "Schedule a match";
    $("saveMatchBtn").textContent = "Schedule match →";
    $("cancelEditBtn").classList.add("hidden");
    $("formMessage").textContent = "";
}

function message(s) {
    $("formMessage").textContent = s;
}

function busy(v) {
    $("saveMatchBtn").disabled = v;
    $("saveMatchBtn").textContent = v ? "Saving…" : ($("matchId").value ? "Save changes →" : "Schedule match →");
}

function toast(s) {
    const el = $("toast");
    el.textContent = s;
    el.classList.add("show");
    setTimeout(() => el.classList.remove("show"), 2500);
}

$("cancelEditBtn").addEventListener("click", reset);

$("signOutBtn").addEventListener("click", async () => {
    if (auth) await signOut(auth);
    location.href = "index.html";
});
