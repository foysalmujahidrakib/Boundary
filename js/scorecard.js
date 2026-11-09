import { auth, db, isConfigured } from "./firebase.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import { collection, doc, getDoc, getDocs, onSnapshot, query, where } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

const $ = id => document.getElementById(id);
const params = new URLSearchParams(location.search);
const clubId = params.get("clubId");
const matchId = params.get("matchId");

const esc = v => String(v ?? "").replace(/[&<>"']/g, c => ({ 
    "&": "&amp;", 
    "<": "&lt;", 
    ">": "&gt;", 
    '"': "&quot;", 
    "'": "&#39;" 
}[c]));

const overs = n => `${Math.floor((n || 0) / 6)}.${(n || 0) % 6}`;
const rate = (runs, balls) => balls ? ((runs / balls) * 100).toFixed(2) : "0.00";
const economy = (runs, balls) => balls ? ((runs / (balls / 6))).toFixed(2) : "0.00";

function statusLabelForInnings(innings, matchStatus) {
    const status = String(matchStatus || "").trim().toLowerCase();
    if (status === "completed" || status === "abandoned" || status === "cancelled") return "RESULT";
    if (!innings.length) return "LIVE";
    if (innings.length === 1 && innings[0]?.completed) return "INNINGS BREAK";
    return "LIVE";
}

function dismissalText(delivery, playerNames) {
    const type = String(delivery.dismissalType || "").trim();
    if (!type) {
        return `b ${playerNames[delivery.bowlerId] || "Unknown bowler"}`;
    }

    if (type === "run_out") return "run out";
    if (type === "retired_hurt") return "retired hurt";

    if (type === "caught") {
        return `c ? b ${playerNames[delivery.bowlerId] || "Unknown bowler"}`;
    }

    if (type === "bowled") {
        return `b ${playerNames[delivery.bowlerId] || "Unknown bowler"}`;
    }

    return type.replaceAll("_", " ");
}

function dismissalLookup(inn, playerNames) {
    const outByBatterId = {};

    for (const delivery of inn.deliveries || []) {
        if (!delivery.wicket) continue;

        const dismissedId = delivery.dismissedBatterId || delivery.strikerId;
        if (!dismissedId || outByBatterId[dismissedId]) continue;

        outByBatterId[dismissedId] = dismissalText(delivery, playerNames);
    }

    return outByBatterId;
}

function battingRowsForPublic(inn, playerNames) {
    const ids = [...new Set((inn.deliveries || []).map(d => d.strikerId))];
    const dismissalById = dismissalLookup(inn, playerNames);

    return ids.map((id) => {
        const values = inn.batters?.[id] || { runs: 0, balls: 0, fours: 0, sixes: 0 };
        const isActive = !inn.completed && (id === inn.strikerId || id === inn.nonStrikerId);

        return {
            playerId: id,
            name: playerNames[id] || "Unknown player",
            dismissal: dismissalById[id] || "not out",
            runs: values.runs || 0,
            balls: values.balls || 0,
            fours: values.fours || 0,
            sixes: values.sixes || 0,
            strikeRate: rate(values.runs || 0, values.balls || 0),
            isActive
        };
    });
}

function bowlingRowsForPublic(inn, playerNames) {
    const ids = [...new Set((inn.deliveries || []).map(d => d.bowlerId))];

    return ids.map((id) => {
        const values = inn.bowlers?.[id] || { runs: 0, wickets: 0, legalBalls: 0 };
        return {
            playerId: id,
            name: playerNames[id] || "Unknown player",
            overs: overs(values.legalBalls || 0),
            runs: values.runs || 0,
            wickets: values.wickets || 0,
            economy: economy(values.runs || 0, values.legalBalls || 0)
        };
    });
}

function teamNameFrom(teams, id) {
    return teams?.[id] || "Team";
}

function inningsSummaryLabel(inn, teams) {
    return `${teamNameFrom(teams, inn.battingTeamId)} ${inn.total || 0}/${inn.wickets || 0} (${overs(inn.legalBalls)} ov)`;
}

export function toPublicScorecardViewModel(publicData) {
    if (!publicData) return null;

    const innings = publicData.innings || [];
    const teams = publicData.teamNames || {};
    const players = publicData.playerNames || {};
    const formatOvers = Number(publicData.overs || 0);
    const formatText = publicData.format || "Match";

    const inningTabs = innings.map((inn, index) => ({
        index,
        key: `${publicData.matchId || "match"}-${index + 1}`,
        label: `${teamNameFrom(teams, inn.battingTeamId)} ${inn.total || 0}/${inn.wickets || 0}`,
        status: inn.completed ? "Complete" : "Batting"
    }));

    const inningsDetails = innings.map((inn, index) => ({
        index,
        key: `${publicData.matchId || "match"}-innings-${index + 1}`,
        heading: `${teamNameFrom(teams, inn.battingTeamId)} Innings`,
        summary: inningsSummaryLabel(inn, teams),
        battingRows: battingRowsForPublic(inn, players),
        bowlingRows: bowlingRowsForPublic(inn, players),
        completed: Boolean(inn.completed)
    }));

    return {
        matchId: publicData.matchId,
        title: publicData.title || "Live Match",
        meta: [publicData.matchDate, publicData.startTime, publicData.venue].filter(Boolean).join(" · "),
        status: statusLabelForInnings(innings, publicData.status),
        result: publicData.result || "",
        formatLabel: `Format: ${formatText}${formatOvers ? ` (${formatOvers} Overs)` : ""}`,
        inningTabs,
        inningsDetails
    };
}

export function subscribePublicScorecardByMatchId(matchIdValue, onData, onError) {
    if (!matchIdValue || !isConfigured || !db) {
        if (typeof onData === "function") onData(null);
        return () => {};
    }

    return onSnapshot(doc(db, "publicMatchScores", matchIdValue), (snapshot) => {
        const data = snapshot.exists() ? snapshot.data() : null;
        if (typeof onData === "function") onData(data);
    }, (error) => {
        if (typeof onError === "function") onError(error);
    });
}

let user = null;
let match = null;
let teams = [];
let players = [];
let score = null;

function fail(message) {
    $("pageNotice").textContent = message;
    $("pageNotice").hidden = false;
}

function namePlayer(id) {
    return players.find(p => p.id === id)?.fullName || "Unknown player";
}

function nameTeam(id) {
    return teams.find(t => t.id === id)?.name || "Unknown team";
}

function extrasFor(inn) {
    const x = { wides: 0, noBalls: 0, byes: 0, legByes: 0, penalties: 0 };
    for (const d of inn.deliveries || []) {
        if (d.kind === "wide") x.wides += Number(d.totalRuns || 0);
        else if (d.kind === "no_ball") x.noBalls += Number(d.extraRuns || 1);
        else if (d.kind === "bye") x.byes += Number(d.batterRuns || 0);
        else if (d.kind === "leg_bye") x.legByes += Number(d.batterRuns || 0);
    }
    return x;
}

function battingRows(inn) {
    const ids = [...new Set((inn.deliveries || []).map(d => d.strikerId))];
    return ids.map(id => {
        const v = inn.batters?.[id] || { runs: 0, balls: 0, fours: 0, sixes: 0 };
        return { id, ...v, sr: rate(v.runs, v.balls) };
    });
}

function bowlingRows(inn) {
    const ids = [...new Set((inn.deliveries || []).map(d => d.bowlerId))];
    return ids.map(id => {
        const v = inn.bowlers?.[id] || { runs: 0, wickets: 0, legalBalls: 0 };
        return { id, ...v, overs: overs(v.legalBalls), econ: economy(v.runs, v.legalBalls) };
    });
}

function fallOfWickets(inn) {
    let wickets = 0;
    const rows = [];
    for (let i = 0; i < (inn.deliveries || []).length; i++) {
        const d = inn.deliveries[i];
        if (d.wicket) {
            wickets++;
            rows.push({
                wicket: wickets,
                score: (inn.deliveries.slice(0, i + 1).reduce((s, x) => s + Number(x.totalRuns || 0), 0)),
                over: overs(inn.deliveries.slice(0, i + 1).filter(x => x.legal).length),
                batter: namePlayer(d.strikerId)
            });
        }
    }
    return rows;
}

function partnershipSummary(inn) {
    let total = 0;
    let partnership = 0;
    let wicketNo = 0;
    const rows = [];
    
    for (const d of inn.deliveries || []) {
        total += Number(d.totalRuns || 0);
        partnership += Number(d.totalRuns || 0);
        if (d.wicket) {
            wicketNo++;
            rows.push({ label: `Wicket ${wicketNo}`, runs: partnership, score: total });
            partnership = 0;
        }
    }
    rows.push({ label: wicketNo ? "Current stand" : "Opening stand", runs: partnership, score: total });
    return rows;
}

function renderInnings(inn) {
    const ex = extrasFor(inn);
    const bat = battingRows(inn);
    const bowl = bowlingRows(inn);
    const fow = fallOfWickets(inn);
    const stands = partnershipSummary(inn);

    const batHtml = bat.length ? `
        <div class="report-table-wrap">
            <table class="report-table">
                <thead>
                    <tr><th>Batter</th><th>R</th><th>B</th><th>4s</th><th>6s</th><th>SR</th></tr>
                </thead>
                <tbody>
                    ${bat.map(b => `<tr><td>${esc(namePlayer(b.id))}</td><td>${b.runs}</td><td>${b.balls}</td><td>${b.fours}</td><td>${b.sixes}</td><td>${b.sr}</td></tr>`).join("")}
                </tbody>
                <tfoot>
                    <tr><td>Extras</td><td colspan="5">${ex.wides + ex.noBalls + ex.byes + ex.legByes} (Wd ${ex.wides}, NB ${ex.noBalls}, B ${ex.byes}, LB ${ex.legByes})</td></tr>
                    <tr><td>Total</td><td colspan="5">${inn.total}/${inn.wickets} in ${overs(inn.legalBalls)} overs</td></tr>
                </tfoot>
            </table>
        </div>` : '<p class="report-muted">No batting deliveries recorded.</p>';

    const bowlHtml = bowl.length ? `
        <div class="report-table-wrap">
            <table class="report-table">
                <thead>
                    <tr><th>Bowler</th><th>O</th><th>R</th><th>W</th><th>Econ</th></tr>
                </thead>
                <tbody>
                    ${bowl.map(b => `<tr><td>${esc(namePlayer(b.id))}</td><td>${b.overs}</td><td>${b.runs}</td><td>${b.wickets}</td><td>${b.econ}</td></tr>`).join("")}
                </tbody>
            </table>
        </div>` : '<p class="report-muted">No bowling figures recorded.</p>';

    const fowHtml = fow.length ? `<div class="report-list">${fow.map(f => `<span class="report-chip">${f.wicket}-${f.score} (${f.over} ov) · ${esc(f.batter)}</span>`).join("")}</div>` : '<p class="report-muted">No wickets have fallen.</p>';
    
    // This scorer version does not persist dismissed-batter/partner identities, so stands are accurately labelled as team runs between wicket events.
    const standHtml = `<div class="report-list">${stands.map(x => `<span class="report-chip">${esc(x.label)}: ${x.runs} runs · team ${x.score}</span>`).join("")}</div><p class="report-muted" style="margin-top:8px">Stand totals are team runs between wicket events; individual batter partnership attribution requires dismissal and end-change tracking in the scoring engine.</p>`;

    return `
        <section class="report-card">
            <div style="display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap">
                <h2>${esc(nameTeam(inn.battingTeamId))} innings</h2>
                <strong>${inn.total}/${inn.wickets} (${overs(inn.legalBalls)} ov)</strong>
            </div>
            <h3>Batting</h3>
            ${batHtml}
            <h3>Bowling</h3>
            ${bowlHtml}
            <div class="report-grid">
                <div>
                    <h3>Fall of wickets</h3>
                    ${fowHtml}
                </div>
                <div>
                    <h3>Partnership sequence</h3>
                    ${standHtml}
                </div>
            </div>
        </section>`;
}

function render() {
    const innings = score?.innings || [];
    if (!innings.length) {
        $("headlineScores").innerHTML = '<div class="report-team">No innings started<strong>—</strong></div>';
        $("inningsReports").innerHTML = '<div class="empty-report">This match has no recorded innings yet. Start scoring to generate a scorecard.</div>';
        $("playerStats").innerHTML = '<p class="report-muted">No player statistics yet.</p>';
        $("matchSummary").innerHTML = '<p class="report-muted">No score data yet.</p>';
        return;
    }

    $("headlineScores").innerHTML = innings.map(i => `
        <div class="report-team">
            <span>${esc(nameTeam(i.battingTeamId))}</span>
            <strong>${i.total}/${i.wickets}</strong>
            <small>${overs(i.legalBalls)} overs${i.completed ? " · Innings complete" : ""}</small>
        </div>`).join("");

    $("inningsReports").innerHTML = innings.map(renderInnings).join("");

    const stats = {};
    for (const inn of innings) {
        for (const [id, v] of Object.entries(inn.batters || {})) {
            const p = stats[id] || { runs: 0, balls: 0, fours: 0, sixes: 0, wickets: 0, overs: 0, runsConceded: 0 };
            p.runs += v.runs || 0;
            p.balls += v.balls || 0;
            p.fours += v.fours || 0;
            p.sixes += v.sixes || 0;
            stats[id] = p;
        }
        for (const [id, v] of Object.entries(inn.bowlers || {})) {
            const p = stats[id] || { runs: 0, balls: 0, fours: 0, sixes: 0, wickets: 0, overs: 0, runsConceded: 0 };
            p.wickets += v.wickets || 0;
            p.overs += v.legalBalls || 0;
            p.runsConceded += v.runs || 0;
            stats[id] = p;
        }
    }

    const statRows = Object.entries(stats);
    $("playerStats").innerHTML = statRows.length ? `
        <table class="report-table">
            <thead>
                <tr><th>Player</th><th>Bat R</th><th>Balls</th><th>4s</th><th>6s</th><th>Bat SR</th><th>Bow W</th><th>Bow O</th><th>Bow Econ</th></tr>
            </thead>
            <tbody>
                ${statRows.map(([id, v]) => `<tr><td>${esc(namePlayer(id))}</td><td>${v.runs}</td><td>${v.balls}</td><td>${v.fours}</td><td>${v.sixes}</td><td>${rate(v.runs, v.balls)}</td><td>${v.wickets}</td><td>${overs(v.overs)}</td><td>${economy(v.runsConceded, v.overs)}</td></tr>`).join("")}
            </tbody>
        </table>` : '<p class="report-muted">No player figures yet.</p>';

    $("matchSummary").innerHTML = innings.map(i => `
        <div class="report-stat">
            <small>${esc(nameTeam(i.battingTeamId))} · ${i.completed ? "Completed" : "In progress"}</small>
            <strong>${i.total}/${i.wickets}</strong>
            <small>${overs(i.legalBalls)} overs · Extras ${Object.values(extrasFor(i)).reduce((a, b) => a + b, 0)}</small>
        </div>`).join("");
}

if (typeof document !== "undefined" && $("matchTitle")) {
    $("printBtn")?.addEventListener("click", () => window.print());
    $("printBottom")?.addEventListener("click", () => window.print());

    $("signOutBtn")?.addEventListener("click", async () => {
        if (auth) await signOut(auth);
        location.href = "index.html";
    });

    if (!isConfigured || !auth || !db) {
        fail("Firebase is not configured. Copy your working Stage 6 js/firebase.js into this project.");
    } else if (!clubId || !matchId) {
        fail("No match was selected. Open Scorecard from your club's Match Centre.");
    } else {
        onAuthStateChanged(auth, async u => {
            if (!u) {
                location.href = "index.html";
                return;
            }
            user = u;
            $("userEmail").textContent = u.email || "";
            $("backMatches").href = `matches.html?clubId=${encodeURIComponent(clubId)}`;
            $("matchesLink").href = $("backMatches").href;
            $("liveScoringLink").href = `scoring.html?clubId=${encodeURIComponent(clubId)}&matchId=${encodeURIComponent(matchId)}`;

            try {
                const membership = await getDoc(doc(db, "memberships", `${u.uid}_${clubId}`));
                if (!membership.exists() || membership.data().status !== "active") {
                    fail("You do not have access to this club.");
                    return;
                }

                const [m, t, p, s] = await Promise.all([
                    getDoc(doc(db, "matches", matchId)),
                    getDocs(query(collection(db, "teams"), where("clubId", "==", clubId))),
                    getDocs(query(collection(db, "players"), where("clubId", "==", clubId))),
                    getDoc(doc(db, "matchScores", matchId))
                ]);

                if (!m.exists() || m.data().clubId !== clubId) {
                    fail("This match could not be found in the selected club.");
                    return;
                }

                match = m.data();
                teams = t.docs.map(d => ({ id: d.id, ...d.data() }));
                players = p.docs.map(d => ({ id: d.id, ...d.data() }));
                score = s.exists() ? s.data() : null;

                const a = nameTeam(match.teamAId);
                const b = nameTeam(match.teamBId);
                $("matchTitle").textContent = match.title || `${a} vs ${b}`;
                $("matchMeta").textContent = [match.matchDate, match.startTime, match.venue, match.format].filter(Boolean).join(" · ");

                render();
            } catch (e) {
                console.error(e);
                fail(e.code === "permission-denied" ? "Access denied. Publish the Stage 6 Firestore rules." : "Could not load scorecard data. Check your Firebase setup.");
            }
        });
    }
}