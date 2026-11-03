// Optional future use: assign platform super-admin custom claims from a trusted machine.
// NEVER run this in the browser. Requires Firebase Admin SDK credentials set up securely.
// Install: npm install firebase-admin
// Run: node scripts/bootstrap-admin.js USER_UID
const admin = require("firebase-admin");

async function main() {
  const uid = process.argv[2];
  if (!uid) throw new Error("Usage: node scripts/bootstrap-admin.js USER_UID");
  // Configure Application Default Credentials before running this script.
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  await admin.auth().setCustomUserClaims(uid, { platformRole: "super_admin" });
  console.log(`Granted super_admin claim to ${uid}`);
}
main().catch(error => {
  console.error(error);
  process.exit(1);
});
