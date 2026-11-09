import{initializeApp as e}from"https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";import{createUserWithEmailAndPassword as t,getAuth as n,onAuthStateChanged as r,signInWithEmailAndPassword as i,updateProfile as a}from"https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";import{collection as o,getFirestore as s,onSnapshot as c}from"https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";(function(){let e=document.createElement(`link`).relList;if(e&&e.supports&&e.supports(`modulepreload`))return;for(let e of document.querySelectorAll(`link[rel="modulepreload"]`))n(e);new MutationObserver(e=>{for(let t of e)if(t.type===`childList`)for(let e of t.addedNodes)e.tagName===`LINK`&&e.rel===`modulepreload`&&n(e)}).observe(document,{childList:!0,subtree:!0});function t(e){let t={};return e.integrity&&(t.integrity=e.integrity),e.referrerPolicy&&(t.referrerPolicy=e.referrerPolicy),t.credentials=e.crossOrigin===`use-credentials`?`include`:e.crossOrigin===`anonymous`?`omit`:`same-origin`,t}function n(e){if(e.ep)return;e.ep=!0;let n=t(e);fetch(e.href,n)}})();var l={apiKey:`AIzaSyDQcVhVxVj8JbDv3m8i0EBQ4zwV12B6Grs`,authDomain:`boundary-4b4e8.firebaseapp.com`,projectId:`boundary-4b4e8`,storageBucket:`boundary-4b4e8.firebasestorage.app`,messagingSenderId:`636164427849`,appId:`1:636164427849:web:d2ec68b5027b276f52ef98`,measurementId:`G-FS1M8TM786`},u=!!(l.apiKey&&l.projectId&&l.appId),d=e(l),f=n(d),p=s(d);console.log(`Firebase initialized successfully!`);var m=document.getElementById(`authModal`),h=document.getElementById(`authForm`),g=document.getElementById(`authTitle`),_=document.getElementById(`authIntro`),v=document.getElementById(`authSubmit`),y=document.getElementById(`nameField`),b=document.getElementById(`authMessage`),x=`login`;function S(e){x=e;let t=e===`register`;g.textContent=t?`Create your account.`:`Welcome back.`,_.textContent=t?`Start building your cricket community.`:`Log in to continue to your workspace.`,v.innerHTML=t?`Create account <span>→</span>`:`Log in <span>→</span>`,y.classList.toggle(`hidden`,!t),document.getElementById(`password`).autocomplete=t?`new-password`:`current-password`,document.querySelectorAll(`[data-auth-tab]`).forEach(t=>t.classList.toggle(`active`,t.dataset.authTab===e)),b.textContent=``,b.className=`form-message`}function C(e){S(e),m.classList.remove(`hidden`),document.body.style.overflow=`hidden`,setTimeout(()=>document.getElementById(e===`register`?`fullName`:`email`).focus(),50)}function w(){m.classList.add(`hidden`),document.body.style.overflow=``}document.querySelectorAll(`[data-open-auth]`).forEach(e=>e.addEventListener(`click`,()=>C(e.dataset.openAuth))),document.querySelectorAll(`[data-auth-tab]`).forEach(e=>e.addEventListener(`click`,()=>S(e.dataset.authTab))),document.getElementById(`closeAuth`).addEventListener(`click`,w),m.addEventListener(`click`,e=>{e.target===m&&w()}),document.addEventListener(`keydown`,e=>{e.key===`Escape`&&w()}),h.addEventListener(`submit`,async e=>{if(e.preventDefault(),b.textContent=``,!u||!f){b.textContent=`Firebase is not configured yet. Add your Firebase web app settings in js/firebase.js, then reload.`;return}let n=h.email.value.trim(),r=h.password.value,o=h.fullName.value.trim();if(x===`register`&&!o)b.textContent=`Please enter your full name.`;else{v.disabled=!0,v.textContent=x===`register`?`Creating account…`:`Logging in…`;try{if(x===`register`){let e=await t(f,n,r);await a(e.user,{displayName:o})}else await i(f,n,r);window.location.href=`dashboard.html`}catch(e){b.textContent=T(e.code),v.disabled=!1,v.innerHTML=x===`register`?`Create account <span>→</span>`:`Log in <span>→</span>`}}});function T(e){return{"auth/email-already-in-use":`An account already exists with this email. Try logging in.`,"auth/invalid-email":`Please enter a valid email address.`,"auth/weak-password":`Please choose a stronger password (at least 6 characters).`,"auth/invalid-credential":`Email or password is incorrect.`,"auth/user-disabled":`This account has been disabled. Contact the platform administrator.`,"auth/too-many-requests":`Too many attempts. Please wait and try again.`}[e]||`Something went wrong. Please try again.`}document.getElementById(`year`).textContent=new Date().getFullYear(),document.getElementById(`mobileMenu`).addEventListener(`click`,()=>{E(`Navigation links are available in the desktop menu.`)}),f&&r(f,e=>{if(e){let e=document.querySelector(`.top-actions`);e&&(e.innerHTML=`<a class="btn btn-primary" href="dashboard.html">Open workspace →</a>`)}});function E(e){let t=document.getElementById(`toast`);t.textContent=e,t.classList.add(`show`),setTimeout(()=>t.classList.remove(`show`),2500)}var D=document.getElementById(`publicTournamentList`),O=[],k=[],A=new Set,j=e=>String(e??``).replace(/[&<>"']/g,e=>({"&":`&amp;`,"<":`&lt;`,">":`&gt;`,'"':`&quot;`,"'":`&#39;`})[e]);function M(e){return String(e||`planned`).replaceAll(`_`,` `).toUpperCase()}function N(e,t){let n=Math.max(0,Number(e?.legalBalls||0));return Number(e?.wickets||0)>=10?t*6:n}function P(e){let t=Array.isArray(e.teamIds)?e.teamIds:[],n=new Map;t.forEach(t=>{n.set(t,{id:t,name:e.teamNames?.[t]||`Team`,mp:0,wins:0,losses:0,points:0,runsScored:0,ballsFaced:0,runsConceded:0,ballsBowled:0,nrr:0})}),k.filter(t=>{if(t.tournamentId!==e.id||t.status!==`completed`)return!1;let n=Array.isArray(t.innings)?t.innings:[];return n.length>=2&&n[0]?.completed===!0&&n[1]?.completed===!0}).forEach(e=>{let t=e.innings,r=t[0],i=t[1],a=r.battingTeamId,o=i.battingTeamId;if(!a||!o||a===o||!n.has(a)||!n.has(o))return;let s=Math.max(1,Number(e.overs||20)),c=N(r,s),l=N(i,s),u=Number(r.total||0),d=Number(i.total||0),f=n.get(a),p=n.get(o);f.mp+=1,p.mp+=1,f.runsScored+=u,f.ballsFaced+=c,p.runsConceded+=u,p.ballsBowled+=c,p.runsScored+=d,p.ballsFaced+=l,f.runsConceded+=d,f.ballsBowled+=l,u>d?(f.wins+=1,p.losses+=1):d>u&&(p.wins+=1,f.losses+=1)});let r=[...n.values()].map(e=>(e.points=e.wins*2,e.nrr=(e.ballsFaced>0?e.runsScored*6/e.ballsFaced:0)-(e.ballsBowled>0?e.runsConceded*6/e.ballsBowled:0),e));return r.sort((e,t)=>t.points-e.points||t.nrr-e.nrr||t.wins-e.wins||e.name.localeCompare(t.name)),r}function F(e){return e.length?e.map((e,t)=>{let n=e.nrr>=0?`nrr-positive`:`nrr-negative`,r=Object.is(e.nrr,-0)?0:e.nrr;return`
      <tr>
        <td class="standings-position">${t+1}</td>
        <td class="standings-team">${j(e.name)}</td>
        <td>${e.mp}</td>
        <td>${e.wins}</td>
        <td>${e.losses}</td>
        <td class="standings-points">${e.points}</td>
        <td class="${n}">${r>0?`+`:``}${r.toFixed(3)}</td>
      </tr>
    `}).join(``):`
      <tr>
        <td class="tournament-table-empty" colspan="7">
          No participating teams have been added to this tournament.
        </td>
      </tr>
    `}function I(e){let t=String(e.id),n=A.has(t),r=Array.isArray(e.teamIds)?e.teamIds.length:0,i=String(e.venue||``).trim(),a=P(e),o=`tournament-details-${t.replace(/[^a-zA-Z0-9_-]/g,`_`)}`;return`
    <article class="public-tournament-card">
      <button
        class="tournament-toggle"
        type="button"
        data-tournament-toggle="${j(t)}"
        aria-expanded="${n}"
        aria-controls="${o}"
      >
        <span class="tournament-card-info">
          <span class="tournament-icon" aria-hidden="true">🏆</span>
          <span class="tournament-card-copy">
            <strong>${j(e.name||`Untitled tournament`)}</strong>
            <span class="meta-chips">
              <span class="meta-chip" title="Participating teams">
                <span aria-hidden="true">👥</span>
                <b>${r}</b> ${r===1?`team`:`teams`}
              </span>
              <span class="meta-chip${i?``:` is-muted`}" title="Venue">
                <span aria-hidden="true">📍</span>
                ${i?j(i):`Venue TBC`}
              </span>
              <span class="tournament-status status-${j(e.status||`planned`)}">
                ${j(M(e.status))}
              </span>
            </span>
            ${e.season||e.format?`<small>${[e.season,e.format].filter(Boolean).map(j).join(` · `)}</small>`:``}
          </span>
        </span>
        <span class="tournament-expand-icon" aria-hidden="true">⌄</span>
      </button>

      <div class="tournament-details" id="${o}" ${n?``:`hidden`}>
        <div class="standings-scroll">
          <table class="standings-table">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col" class="standings-team">TEAM NAME</th>
                <th scope="col">MP</th>
                <th scope="col">W</th>
                <th scope="col">L</th>
                <th scope="col">PTS</th>
                <th scope="col">NRR</th>
              </tr>
            </thead>
            <tbody>${F(a)}</tbody>
          </table>
        </div>
        <p class="tournament-table-note">
          Points: 2 per win. NRR uses aggregate runs and legal-ball totals;
          an all-out innings is charged with the full allocated overs.
          Tied matches count as played, with no win/loss points.
        </p>
      </div>
    </article>
  `}function L(){if(!D)return;if(!O.length){D.innerHTML=`
      <div class="public-live-empty">
        No public tournaments are available right now.
      </div>
    `;return}let e={ongoing:0,planned:1,completed:2,cancelled:3};D.innerHTML=[...O].sort((t,n)=>(e[t.status]??4)-(e[n.status]??4)||String(t.startDate||``).localeCompare(String(n.startDate||``))).map(I).join(``)}D?!u||!p?D.innerHTML=`
    <div class="public-live-empty">
      Tournament standings are unavailable because Firebase is not configured.
    </div>
  `:(D.addEventListener(`click`,e=>{let t=e.target.closest(`[data-tournament-toggle]`);if(!t)return;let n=t.dataset.tournamentToggle;A.has(n)?A.delete(n):A.add(n),L()}),c(o(p,`publicTournaments`),e=>{O=e.docs.map(e=>({id:e.id,...e.data()})),L()},e=>{console.error(`Could not load public tournaments:`,e),D.innerHTML=`
        <div class="public-live-empty">
          Could not load tournament standings. Please try again later.
        </div>
      `}),c(o(p,`publicMatchScores`),e=>{k=e.docs.map(e=>({id:e.id,...e.data()})),L()},e=>{console.error(`Could not load public match scores for standings:`,e),D.innerHTML=`
        <div class="public-live-empty">
          Tournament scores could not be loaded. Please try again later.
        </div>
      `})):console.warn(`Tournament standings container was not found on this page.`);