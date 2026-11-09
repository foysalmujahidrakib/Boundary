import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  BarChart3,
  Bolt,
  ListChecks,
  Radio,
  Volume2,
  Waves
} from "lucide-react";

import { subscribeLiveMatchesFeed } from "../livematches.js";
import { subscribePublicLiveFeed } from "../public-live.js";
import {
  subscribePublicScorecardByMatchId,
  toPublicScorecardViewModel
} from "../scorecard.js";

const MONO = "font-mono";

function overs(balls) {
  const legalBalls = Number(balls) || 0;
  return `${Math.floor(legalBalls / 6)}.${legalBalls % 6}`;
}

function teamScore(inn) {
  if (!inn) return "Yet to bat";
  return `${inn.total || 0}/${inn.wickets || 0}`;
}

function mergeFeeds(primary, secondary) {
  const map = new Map();
  for (const item of [...primary, ...secondary]) {
    const key = item.matchId || item.id;
    if (!key) continue;
    const prev = map.get(key);
    if (!prev) {
      map.set(key, item);
      continue;
    }

    const prevTime = prev.updatedAt?.toMillis?.() || 0;
    const nextTime = item.updatedAt?.toMillis?.() || 0;
    map.set(key, nextTime >= prevTime ? item : prev);
  }

  return [...map.values()].sort((a, b) => {
    const at = a.updatedAt?.toMillis?.() || 0;
    const bt = b.updatedAt?.toMillis?.() || 0;
    return bt - at;
  });
}

function statusBadge(match) {
  const innings = match.innings || [];
  const status = String(match.status || "").toLowerCase();

  if (status === "completed" || status === "abandoned" || status === "cancelled") {
    return "RESULT";
  }

  if (innings.length === 1 && innings[0]?.completed) {
    return "INNINGS BREAK";
  }

  return "LIVE";
}

function pillTone(label) {
  if (label === "LIVE") return "bg-emerald-500/20 text-emerald-300 border-emerald-400/30";
  if (label === "INNINGS BREAK") return "bg-amber-500/20 text-amber-300 border-amber-400/30";
  return "bg-slate-700/60 text-slate-200 border-slate-500/40";
}

function inningsOversLabel(innings, index) {
  const inn = innings[index];
  if (!inn) return "";
  return `${overs(inn.legalBalls)} ov`;
}

function tabClass(active) {
  if (active) {
    return "bg-[#00E599] text-slate-950 border-[#00FFA3] shadow-[0_0_20px_rgba(0,255,163,0.2)]";
  }

  return "bg-slate-900/80 text-slate-300 border-slate-700 hover:text-white hover:border-slate-500";
}

export default function BoundarySportsDashboard() {
  const [liveMatches, setLiveMatches] = useState([]);
  const [publicMatches, setPublicMatches] = useState([]);
  const [selectedMatchId, setSelectedMatchId] = useState(null);
  const [scorecardData, setScorecardData] = useState(null);
  const [inningIndex, setInningIndex] = useState(0);

  useEffect(() => {
    const unsubLive = subscribeLiveMatchesFeed((matches) => {
      setLiveMatches(matches || []);
    }, console.error);

    const unsubPublic = subscribePublicLiveFeed((matches) => {
      setPublicMatches(matches || []);
    }, console.error);

    return () => {
      unsubLive?.();
      unsubPublic?.();
    };
  }, []);

  const matches = useMemo(() => mergeFeeds(liveMatches, publicMatches), [liveMatches, publicMatches]);

  useEffect(() => {
    if (!matches.length) {
      setSelectedMatchId(null);
      return;
    }

    if (!selectedMatchId || !matches.some((m) => (m.matchId || m.id) === selectedMatchId)) {
      setSelectedMatchId(matches[0].matchId || matches[0].id);
    }
  }, [matches, selectedMatchId]);

  useEffect(() => {
    if (!selectedMatchId) {
      setScorecardData(null);
      return undefined;
    }

    const unsubscribe = subscribePublicScorecardByMatchId(selectedMatchId, (docData) => {
      setScorecardData(docData);
    }, console.error);

    return () => unsubscribe?.();
  }, [selectedMatchId]);

  const scorecard = useMemo(() => toPublicScorecardViewModel(scorecardData), [scorecardData]);

  useEffect(() => {
    setInningIndex(0);
  }, [selectedMatchId]);

  const activeMatch = useMemo(
    () => matches.find((match) => (match.matchId || match.id) === selectedMatchId) || null,
    [matches, selectedMatchId]
  );

  const activeInnings = scorecard?.inningsDetails?.[inningIndex] || null;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 selection:bg-[#00E599] selection:text-slate-950">
      <header className="sticky top-0 z-40 border-b border-slate-800 bg-slate-950/95 backdrop-blur-xl">
        <div className="flex items-center gap-3 overflow-x-auto border-b border-slate-800 px-4 py-2">
          <span className="inline-flex shrink-0 items-center gap-2 rounded-full border border-emerald-400/30 bg-emerald-500/10 px-3 py-1 text-[11px] font-bold tracking-[0.16em] text-emerald-300">
            <span className="relative flex h-2.5 w-2.5">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-80" />
              <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-300" />
            </span>
            LIVE MATCHES
          </span>

          {matches.map((match) => {
            const key = match.matchId || match.id;
            const innings = match.innings || [];
            const first = innings[0];
            const latest = innings[innings.length - 1] || first;
            const teams = match.teamNames || {};
            const firstName = first ? teams[first.battingTeamId] || "Team A" : teams[match.teamAId] || "Team A";
            const secondName = latest ? teams[latest.battingTeamId] || "Team B" : teams[match.teamBId] || "Team B";
            const label = statusBadge(match);

            return (
              <button
                key={key}
                type="button"
                onClick={() => setSelectedMatchId(key)}
                className={`shrink-0 rounded-full border px-3 py-1.5 text-left transition ${
                  selectedMatchId === key
                    ? "border-[#00FFA3] bg-[#00FFA3]/10"
                    : "border-slate-700 bg-slate-900/80 hover:border-slate-500"
                }`}
              >
                <div className="flex items-center gap-2 text-[12px]">
                  <span className="font-semibold text-white">{firstName} vs {secondName}</span>
                  <span className={`rounded-full border px-2 py-0.5 text-[10px] font-bold ${pillTone(label)}`}>{label}</span>
                </div>
                <div className={`mt-0.5 text-[11px] text-slate-300 ${MONO}`}>
                  {teamScore(first)} ({overs(first?.legalBalls)} ov){latest && latest !== first ? ` • ${teamScore(latest)} (${overs(latest?.legalBalls)} ov)` : ""}
                </div>
              </button>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center justify-between gap-4 px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-[#00FFA3] to-[#00C2FF] text-slate-950">
              <Bolt size={20} strokeWidth={2.8} />
            </div>
            <div>
              <p className="text-lg font-black tracking-tight">BOUNDARY <span className="ml-1 rounded-md bg-gradient-to-r from-teal-300 to-cyan-400 px-1.5 py-0.5 text-[10px] font-black text-slate-950">PRO</span></p>
              <p className="text-[11px] tracking-[0.15em] text-slate-400">ICC WORLD CUP CHAMPIONSHIP 2026</p>
            </div>
          </div>

          <nav className="flex items-center gap-2 rounded-xl border border-slate-800 bg-slate-900/70 p-1">
            <button type="button" className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-xs font-bold ${tabClass(false)}`}><Radio size={14} />Live Match</button>
            <button type="button" className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-xs font-bold ${tabClass(true)}`}><ListChecks size={14} />Full Scorecard</button>
            <button type="button" className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-xs font-bold ${tabClass(false)}`}><Waves size={14} />Overs Timeline</button>
            <button type="button" className={`inline-flex items-center gap-2 rounded-lg border px-3 py-2 text-xs font-bold ${tabClass(false)}`}><BarChart3 size={14} />Stats & Match Info</button>
          </nav>

          <div className="flex items-center gap-2">
            <button type="button" className="rounded-xl border border-slate-700 bg-slate-900 p-2.5 text-slate-300 hover:text-white" aria-label="Toggle audio">
              <Volume2 size={16} />
            </button>
            <span className="inline-flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-900/70 px-3 py-2 text-xs text-slate-300">
              <Activity size={13} className="text-[#00E599]" />
              Data Feed: <strong className="text-white">Realtime</strong>
            </span>
          </div>
        </div>
      </header>

      <main className="mx-auto grid w-full max-w-7xl gap-5 px-4 py-6 lg:grid-cols-[360px_1fr]">
        <aside className="rounded-2xl border border-slate-800 bg-[#111C2E] p-4">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="text-[11px] font-bold tracking-[0.18em] text-[#00E599]">PUBLIC LIVE FEED</p>
              <h2 className="mt-1 text-xl font-extrabold">All Live Matches</h2>
            </div>
            <button type="button" className="rounded-full border border-slate-700 bg-slate-900 px-3 py-1.5 text-[11px] font-bold tracking-wide text-slate-300 hover:border-[#00E599]/50 hover:text-white">
              BACK TO HOME
            </button>
          </div>

          {!matches.length && (
            <div className="rounded-xl border border-slate-700 bg-slate-900/70 p-4 text-sm text-slate-300">
              There are no live matches right now. Check back when scoring starts.
            </div>
          )}

          <div className="space-y-3">
            {matches.map((match) => {
              const key = match.matchId || match.id;
              const innings = match.innings || [];
              const first = innings[0];
              const latest = innings[innings.length - 1] || first;
              const teams = match.teamNames || {};
              const firstName = first ? teams[first.battingTeamId] || "Team A" : teams[match.teamAId] || "Team A";
              const secondName = latest ? teams[latest.battingTeamId] || "Team B" : teams[match.teamBId] || "Team B";
              const label = statusBadge(match);

              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => setSelectedMatchId(key)}
                  className={`w-full rounded-xl border p-3 text-left transition ${
                    selectedMatchId === key
                      ? "border-[#00FFA3]/60 bg-[#00FFA3]/10"
                      : "border-slate-700 bg-slate-900/65 hover:border-slate-500"
                  }`}
                >
                  <div className="mb-2 flex items-center justify-between text-[11px] uppercase tracking-wide">
                    <span className={`rounded-full border px-2 py-0.5 font-bold ${pillTone(label)}`}>{label}</span>
                    <span className="text-slate-400">{match.matchDate || ""}</span>
                  </div>
                  <p className="text-sm font-bold text-white">{match.title || `${firstName} vs ${secondName}`}</p>
                  <div className="mt-2 space-y-1 text-sm">
                    <div className="flex items-center justify-between"><span>{firstName}</span><span className={MONO}>{teamScore(first)}</span></div>
                    <div className="flex items-center justify-between text-slate-300"><span>{secondName}</span><span className={MONO}>{teamScore(latest)}</span></div>
                  </div>
                </button>
              );
            })}
          </div>
        </aside>

        <section className="rounded-2xl border border-slate-800 bg-[#111C2E] p-4 sm:p-5">
          {!selectedMatchId && (
            <div className="rounded-xl border border-slate-700 bg-slate-900/70 p-5 text-sm text-slate-300">
              Select a live match to load its detailed scorecard.
            </div>
          )}

          {selectedMatchId && !scorecard && (
            <div className="rounded-xl border border-slate-700 bg-slate-900/70 p-5 text-sm text-slate-300">
              Loading scorecard for match {selectedMatchId}...
            </div>
          )}

          {selectedMatchId && scorecard && (
            <>
              <div className="mb-4 flex flex-wrap items-start justify-between gap-3 border-b border-slate-800 pb-4">
                <div>
                  <p className="text-[11px] font-bold tracking-[0.16em] text-[#00E599]">MATCH SCORECARD</p>
                  <h3 className="mt-1 text-2xl font-extrabold text-white">{scorecard.title}</h3>
                  <p className="mt-1 text-sm text-slate-400">{scorecard.meta}</p>
                  {scorecard.result ? <p className="mt-2 text-sm font-semibold text-emerald-300">{scorecard.result}</p> : null}
                </div>
                <p className="rounded-full border border-slate-700 bg-slate-900/70 px-3 py-1.5 text-xs font-bold text-slate-300">{scorecard.formatLabel}</p>
              </div>

              <div className="mb-4 flex flex-wrap items-center gap-2">
                {scorecard.inningTabs.map((tab) => (
                  <button
                    key={tab.key}
                    type="button"
                    onClick={() => setInningIndex(tab.index)}
                    className={`rounded-lg border px-3 py-2 text-sm font-semibold transition ${
                      inningIndex === tab.index
                        ? "border-[#00FFA3]/50 bg-[#00FFA3]/12 text-[#8CFFD7]"
                        : "border-slate-700 bg-slate-900/70 text-slate-300 hover:text-white"
                    }`}
                  >
                    <span>{tab.label}</span>
                    <span className="ml-2 text-xs text-slate-400">{tab.status}</span>
                  </button>
                ))}
                <span className="ml-auto rounded-full border border-slate-700 bg-slate-900 px-3 py-1.5 text-[11px] font-bold text-slate-300">{scorecard.status}</span>
              </div>

              {!activeInnings && (
                <div className="rounded-xl border border-slate-700 bg-slate-900/70 p-5 text-sm text-slate-300">
                  No innings data available for this match.
                </div>
              )}

              {activeInnings && (
                <div className="space-y-4">
                  <div className="rounded-xl border border-slate-700 bg-slate-900/65 p-3">
                    <p className="text-sm font-bold text-white">{activeInnings.heading}</p>
                    <p className="text-xs text-slate-400">{activeInnings.summary} • {inningsOversLabel(scorecardData?.innings || [], inningIndex)}</p>
                  </div>

                  <div className="overflow-x-auto rounded-xl border border-slate-700">
                    <table className="min-w-full border-collapse text-sm">
                      <thead className="bg-slate-900/90 text-[11px] uppercase tracking-wide text-slate-400">
                        <tr>
                          <th className="px-3 py-2 text-left">Batter</th>
                          <th className="px-3 py-2 text-left">Dismissal</th>
                          <th className="px-3 py-2 text-right">R</th>
                          <th className="px-3 py-2 text-right">B</th>
                          <th className="px-3 py-2 text-right">4s</th>
                          <th className="px-3 py-2 text-right">6s</th>
                          <th className="px-3 py-2 text-right">SR</th>
                        </tr>
                      </thead>
                      <tbody>
                        {activeInnings.battingRows.length === 0 && (
                          <tr>
                            <td colSpan={7} className="px-3 py-4 text-center text-slate-400">No batting data yet.</td>
                          </tr>
                        )}
                        {activeInnings.battingRows.map((row) => (
                          <tr key={row.playerId} className={row.isActive ? "bg-[#00FFA3]/10" : "bg-transparent"}>
                            <td className={`px-3 py-2 font-semibold ${row.isActive ? "text-[#8CFFD7]" : "text-white"}`}>{row.name}{row.isActive ? " *" : ""}</td>
                            <td className="px-3 py-2 text-slate-300">{row.dismissal}</td>
                            <td className={`px-3 py-2 text-right ${MONO}`}>{row.runs}</td>
                            <td className={`px-3 py-2 text-right ${MONO}`}>{row.balls}</td>
                            <td className={`px-3 py-2 text-right ${MONO}`}>{row.fours}</td>
                            <td className={`px-3 py-2 text-right ${MONO}`}>{row.sixes}</td>
                            <td className={`px-3 py-2 text-right ${MONO}`}>{row.strikeRate}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  <div className="overflow-x-auto rounded-xl border border-slate-700">
                    <table className="min-w-full border-collapse text-sm">
                      <thead className="bg-slate-900/90 text-[11px] uppercase tracking-wide text-slate-400">
                        <tr>
                          <th className="px-3 py-2 text-left">Bowler</th>
                          <th className="px-3 py-2 text-right">O</th>
                          <th className="px-3 py-2 text-right">R</th>
                          <th className="px-3 py-2 text-right">W</th>
                          <th className="px-3 py-2 text-right">Econ</th>
                        </tr>
                      </thead>
                      <tbody>
                        {activeInnings.bowlingRows.length === 0 && (
                          <tr>
                            <td colSpan={5} className="px-3 py-4 text-center text-slate-400">No bowling data yet.</td>
                          </tr>
                        )}
                        {activeInnings.bowlingRows.map((row) => (
                          <tr key={row.playerId}>
                            <td className="px-3 py-2 text-white">{row.name}</td>
                            <td className={`px-3 py-2 text-right text-slate-300 ${MONO}`}>{row.overs}</td>
                            <td className={`px-3 py-2 text-right text-slate-300 ${MONO}`}>{row.runs}</td>
                            <td className={`px-3 py-2 text-right text-slate-300 ${MONO}`}>{row.wickets}</td>
                            <td className={`px-3 py-2 text-right text-slate-300 ${MONO}`}>{row.economy}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </>
          )}

          {activeMatch && (
            <p className="mt-4 text-xs text-slate-500">
              Selected match: <span className="text-slate-300">{activeMatch.title || activeMatch.matchId || activeMatch.id}</span>
            </p>
          )}
        </section>
      </main>
    </div>
  );
}
