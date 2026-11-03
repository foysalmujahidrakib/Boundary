import { auth, db, isConfigured } from "./firebase.js";
import {
  onAuthStateChanged, signOut
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  collection, doc, getDoc, getDocs, query, where, serverTimestamp, writeBatch
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const userEmail = document.getElementById("userEmail");
const clubList = document.getElementById("clubList");
const createClubForm = document.getElementById("createClubForm");
const createClubBtn = document.getElementById("createClubBtn");
const clubMessage = document.getElementById("clubMessage");
let currentUser = null;

if (!isConfigured || !auth || !db) {
  clubList.innerHTML = '<div class="empty-state">Firebase is not configured. Add your Firebase web app settings in <strong>js/firebase.js</strong> to enable account and club features.</div>';
  createClubBtn.disabled = true;
  createClubBtn.title = "Configure Firebase first";
}

if (auth) onAuthStateChanged(auth, async user => {
  if (!user) {
    window.location.href = "index.html";
    return;
  }
  currentUser = user;
  userEmail.textContent = user.email || "";
  document.getElementById("accountEmail").textContent = user.email || "";
  document.getElementById("userName").textContent = user.displayName || "Cricket organizer";
  document.getElementById("userInitial").textContent = (user.displayName || user.email || "U").charAt(0).toUpperCase();
  if (isConfigured) await loadMemberships();
});

document.getElementById("signOutBtn").addEventListener("click", async () => {
  if (auth) await signOut(auth);
  window.location.href = "index.html";
});

async function loadMemberships() {
  clubList.innerHTML = '<div class="empty-state">Loading your club memberships…</div>';
  try {
    const membershipQuery = query(collection(db, "memberships"), where("userId", "==", currentUser.uid));
    const snapshot = await getDocs(membershipQuery);
    document.getElementById("clubCount").textContent = `${snapshot.size} CLUB${snapshot.size === 1 ? "" : "S"}`;
    document.getElementById("membershipCount").textContent = snapshot.size;
    document.getElementById("rolePill").textContent = snapshot.empty ? "NEW ORGANIZER" : "CLUB MEMBER";
    if (snapshot.empty) {
      clubList.innerHTML = '<div class="empty-state">You are not a member of a club yet. Create your first club below.</div>';
      return;
    }
    const rows = await Promise.all(snapshot.docs.map(async membershipDoc => {
      const membership = membershipDoc.data();
      const clubSnap = await getDoc(doc(db, "clubs", membership.clubId));
      if (!clubSnap.exists()) return "";
      const club = clubSnap.data();
      return `<a class="club-item club-item-link" href="club.html?clubId=${encodeURIComponent(membership.clubId)}"><div class="club-avatar">${escapeHtml((club.name || "C").slice(0,2).toUpperCase())}</div><div class="club-info"><strong>${escapeHtml(club.name || "Cricket club")}</strong><small>${escapeHtml(club.location || "Location not added")}</small></div><span class="club-role">${escapeHtml((membership.role || "member").toUpperCase())} · OPEN →</span></a>`;
    }));
    clubList.innerHTML = rows.filter(Boolean).join("") || '<div class="empty-state">No club details found.</div>';
  } catch (error) {
    console.error(error);
    clubList.innerHTML = '<div class="empty-state">Could not load memberships. Check your Firestore setup and security rules.</div>';
  }
}

createClubForm.addEventListener("submit", async event => {
  event.preventDefault();
  if (!currentUser || !db) return;
  const name = document.getElementById("clubName").value.trim();
  const location = document.getElementById("clubLocation").value.trim();
  const description = document.getElementById("clubDescription").value.trim();
  if (!name) return;
  createClubBtn.disabled = true;
  createClubBtn.textContent = "Creating workspace…";
  clubMessage.textContent = "";
  try {
    const clubRef = doc(collection(db, "clubs"));
    const membershipRef = doc(db, "memberships", `${currentUser.uid}_${clubRef.id}`);
    const batch = writeBatch(db);
    batch.set(clubRef, {
      name, location, description,
      ownerUid: currentUser.uid,
      createdAt: serverTimestamp(),
      status: "active",
      visibility: "public"
    });
    batch.set(membershipRef, {
      clubId: clubRef.id,
      userId: currentUser.uid,
      role: "club_admin",
      status: "active",
      createdAt: serverTimestamp()
    });
    batch.set(doc(db, "users", currentUser.uid), {
      displayName: currentUser.displayName || "",
      email: currentUser.email || "",
      updatedAt: serverTimestamp()
    }, { merge: true });
    await batch.commit();
    createClubForm.reset();
    clubMessage.textContent = "Your club workspace has been created.";
    clubMessage.className = "form-message success";
    await loadMemberships();
    showToast("Club created successfully.");
  } catch (error) {
    console.error(error);
    clubMessage.textContent = error.code === "permission-denied"
      ? "Firestore blocked this action. Publish the supplied security rules and try again."
      : "Could not create the club. Check Firebase setup and try again.";
    clubMessage.className = "form-message";
  } finally {
    createClubBtn.disabled = false;
    createClubBtn.innerHTML = 'Create club workspace <span>→</span>';
  }
});

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[char]));
}
function showToast(text) {
  const toast = document.getElementById("toast");
  toast.textContent = text;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 2600);
}
