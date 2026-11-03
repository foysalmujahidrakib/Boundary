import { auth, isConfigured } from "./firebase.js";
import {
  createUserWithEmailAndPassword, signInWithEmailAndPassword,
  updateProfile, onAuthStateChanged
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";

const modal = document.getElementById("authModal");
const form = document.getElementById("authForm");
const title = document.getElementById("authTitle");
const intro = document.getElementById("authIntro");
const submit = document.getElementById("authSubmit");
const nameField = document.getElementById("nameField");
const message = document.getElementById("authMessage");
let authMode = "login";

function setMode(mode) {
  authMode = mode;
  const registering = mode === "register";
  title.textContent = registering ? "Create your account." : "Welcome back.";
  intro.textContent = registering ? "Start building your cricket community." : "Log in to continue to your workspace.";
  submit.innerHTML = registering ? "Create account <span>→</span>" : "Log in <span>→</span>";
  nameField.classList.toggle("hidden", !registering);
  document.getElementById("password").autocomplete = registering ? "new-password" : "current-password";
  document.querySelectorAll("[data-auth-tab]").forEach(tab => tab.classList.toggle("active", tab.dataset.authTab === mode));
  message.textContent = "";
  message.className = "form-message";
}
function openModal(mode) {
  setMode(mode);
  modal.classList.remove("hidden");
  document.body.style.overflow = "hidden";
  setTimeout(() => document.getElementById(mode === "register" ? "fullName" : "email").focus(), 50);
}
function closeModal() {
  modal.classList.add("hidden");
  document.body.style.overflow = "";
}
document.querySelectorAll("[data-open-auth]").forEach(button => button.addEventListener("click", () => openModal(button.dataset.openAuth)));
document.querySelectorAll("[data-auth-tab]").forEach(button => button.addEventListener("click", () => setMode(button.dataset.authTab)));
document.getElementById("closeAuth").addEventListener("click", closeModal);
modal.addEventListener("click", event => { if (event.target === modal) closeModal(); });
document.addEventListener("keydown", event => { if (event.key === "Escape") closeModal(); });

form.addEventListener("submit", async event => {
  event.preventDefault();
  message.textContent = "";
  if (!isConfigured || !auth) {
    message.textContent = "Firebase is not configured yet. Add your Firebase web app settings in js/firebase.js, then reload.";
    return;
  }
  const email = form.email.value.trim();
  const password = form.password.value;
  const fullName = form.fullName.value.trim();
  if (authMode === "register" && !fullName) {
    message.textContent = "Please enter your full name.";
    return;
  }
  submit.disabled = true;
  submit.textContent = authMode === "register" ? "Creating account…" : "Logging in…";
  try {
    if (authMode === "register") {
      const credential = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(credential.user, { displayName: fullName });
    } else {
      await signInWithEmailAndPassword(auth, email, password);
    }
    window.location.href = "dashboard.html";
  } catch (error) {
    message.textContent = friendlyAuthError(error.code);
    submit.disabled = false;
    submit.innerHTML = authMode === "register" ? "Create account <span>→</span>" : "Log in <span>→</span>";
  }
});

function friendlyAuthError(code) {
  const messages = {
    "auth/email-already-in-use": "An account already exists with this email. Try logging in.",
    "auth/invalid-email": "Please enter a valid email address.",
    "auth/weak-password": "Please choose a stronger password (at least 6 characters).",
    "auth/invalid-credential": "Email or password is incorrect.",
    "auth/user-disabled": "This account has been disabled. Contact the platform administrator.",
    "auth/too-many-requests": "Too many attempts. Please wait and try again."
  };
  return messages[code] || "Something went wrong. Please try again.";
}

document.getElementById("year").textContent = new Date().getFullYear();
document.getElementById("mobileMenu").addEventListener("click", () => {
  showToast("Navigation links are available in the desktop menu.");
});
if (auth) onAuthStateChanged(auth, user => {
  if (user) {
    // Keep the public homepage accessible; signed-in users can open their workspace.
    const actions = document.querySelector(".top-actions");
    if (actions) actions.innerHTML = '<a class="btn btn-primary" href="dashboard.html">Open workspace →</a>';
  }
});

function showToast(text) {
  const toast = document.getElementById("toast");
  toast.textContent = text;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 2500);
}
