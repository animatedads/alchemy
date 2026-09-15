(() => {
  "use strict";
  const state = { spheres: [], selectedKey: null, selected: null, contextEnvelope: null, filter: "" };
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

  async function api(url) {
    const r = await fetch(url, {headers: {"Accept":"application/json"}});
    const j = await r.json().catch(() => ({error: `HTTP ${r.status}`}));
    if (!r.ok) throw new Error(j.error || `HTTP ${r.status}`);
    return j;
  }

  function toast(message, error=false) {
    const el = $("toast"); el.textContent = message; el.className = "toast show" + (error ? " error" : "");
    clearTimeout(toast.timer); toast.timer = setTimeout(() => el.className = "toast", 2600);
  }

  function pretty(v) { return JSON.stringify(v, null, 2); }
  function shortFile(p) { return String(p || "").split(/[\\/]/).pop(); }

  function renderSphereList() {
    const q = state.filter.trim().toLowerCase();
    const list = state.spheres.filter(s => !q || [s.title, s.sphere, s.filename, s.version].join(" ").toLowerCase().includes(q));
    $("collection-count").textContent = `${state.spheres.length} sphere${state.spheres.length === 1 ? "" : "s"}`;
    $("sphere-list").innerHTML = list.map(s => {
      const available = s.status === "available";
      const label = s.title || s.sphere || s.filename;
      const sub = available ? `${s.sphere}${s.version ? " · " + s.version : ""}` : s.status.replaceAll("_", " ");
      return `<button class="sphere-item ${state.selectedKey === s.key ? "active" : ""} ${available ? "" : "unavailable"}" data-key="${esc(s.key)}" ${available ? "" : "title=\"Not loadable by current Gopher\""}>
        <span class="sphere-name">${esc(label)}</span><span class="sphere-id"><span>${esc(sub)}</span><span>${available ? "›" : "!"}</span></span>
      </button>`;
    }).join("") || `<div class="empty-state">No matching spheres.</div>`;
    document.querySelectorAll(".sphere-item").forEach(el => el.addEventListener("click", () => selectSphere(el.dataset.key)));
  }

  async function loadSpheres(force=false, quiet=false) {
    try {
      const j = await api(`/api/spheres${force ? "?refresh=1" : ""}`);
      const oldKeys = state.spheres.map(s => `${s.key}:${s.mtime_ns}:${s.size}`).join("|");
      state.spheres = j.spheres || [];
      renderSphereList();
      const newKeys = state.spheres.map(s => `${s.key}:${s.mtime_ns}:${s.size}`).join("|");
      if (!quiet && oldKeys && oldKeys !== newKeys) toast("Sphere collection changed; list refreshed.");
    } catch (e) { toast(e.message, true); }
  }

  async function selectSphere(key) {
    const entry = state.spheres.find(s => s.key === key);
    if (!entry) return;
    if (entry.status !== "available") { toast(entry.reason || "This archive is not loadable by current Gopher.", true); return; }
    state.selectedKey = key; state.selected = entry; renderSphereList();
    $("welcome").classList.add("hidden"); $("sphere-view").classList.remove("hidden");
    $("crumb").textContent = entry.sphere || "sphere"; $("page-title").textContent = entry.title || entry.sphere;
    $("panel-articles").innerHTML = `<div class="loading">Asking Gopher for sphere context…</div>`;
    $("panel-capabilities").innerHTML = `<div class="loading">Loading capability descriptions…</div>`;
    try {
      const j = await api(`/api/sphere?key=${encodeURIComponent(key)}`);
      if (state.selectedKey !== key) return;
      state.selected = j.entry; state.contextEnvelope = j.context;
      renderSphere(j);
    } catch (e) {
      $("panel-articles").innerHTML = `<div class="problem">${esc(e.message)}</div>`;
      toast(e.message, true);
    }
  }

  function renderSphere(j) {
    const entry = j.entry || {};
    const ctx = j.context?.result || {};
    const activation = j.activation?.result || {};
    const selected = activation.selected || {};
    const articles = ctx.articles || [];
    const caps = ctx.capabilities || [];
    $("sphere-summary").innerHTML = [
      ["Sphere", ctx.sphere || entry.sphere],
      ["Version", selected.version || entry.version || "—"],
      ["Articles", articles.length],
      ["Capabilities", caps.length],
      ["Source", entry.filename || "—"],
      ["SHA-256", selected.archive_sha256 || "—"],
    ].map(([k,v]) => `<div class="summary-card"><div class="summary-label">${esc(k)}</div><div class="summary-value">${esc(v)}</div></div>`).join("");
    $("crumb").textContent = `${ctx.sphere || entry.sphere} / ${shortFile(entry.filename)}`;
    $("page-title").textContent = selected.title || entry.title || ctx.sphere || "Sphere";
    const contextClass = j.context?.operation_status?.class || "UNKNOWN";
    $("panel-articles").innerHTML = contextClass !== "OPENED"
      ? `<div class="problem">Gopher returned <code>${esc(contextClass)}</code> for this sphere context. The exact envelope is available under “Gopher JSON”.</div>`
      : (articles.length ? `<div class="article-list">${articles.map(a => `<article class="article-card" data-article="${esc(a.id)}"><h3>${esc(a.title || a.id)}</h3><div class="id">${esc(a.id)}</div></article>`).join("")}</div>` : `<div class="empty-state">This context exposes no articles to role <code>${esc(ctx.role)}</code>.</div>`);
    document.querySelectorAll("[data-article]").forEach(el => el.addEventListener("click", () => openArticle(el.dataset.article)));
    $("panel-capabilities").innerHTML = caps.length ? `<div class="cap-list">${caps.map(renderCapability).join("")}</div>` : `<div class="empty-state">No capabilities exposed in this context.</div>`;
    $("context-json").textContent = pretty(j.context);
  }

  function renderCapability(c) {
    const tags = [...(c.required || []).map(x => `required: ${x}`), ...(c.supports || [])];
    const svc = (c.services || []).length;
    return `<article class="cap-card"><h3>${esc(c.id)}</h3><div class="id">${svc} service${svc === 1 ? "" : "s"}</div>${c.summary ? `<p>${esc(c.summary)}</p>` : ""}${tags.length ? `<div class="chips">${tags.map(x => `<span class="chip">${esc(x)}</span>`).join("")}</div>` : ""}</article>`;
  }

  async function openArticle(id) {
    if (!state.selectedKey) return;
    $("drawer-kind").textContent = "article"; $("drawer-title").textContent = id; $("drawer-body").innerHTML = `<div class="loading">Opening through Gopher…</div>`; $("drawer").classList.add("open");
    try {
      const j = await api(`/api/article?key=${encodeURIComponent(state.selectedKey)}&id=${encodeURIComponent(id)}`);
      const r = j.result || {};
      $("drawer-kind").textContent = `${r.kind || "article"}${r.version ? " · " + r.version : ""}`;
      $("drawer-title").textContent = r.title || r.id || id;
      $("drawer-body").innerHTML = renderObject(r, new Set(["kind","title"])) + `<div class="object-section"><div class="object-key">Gopher evidence</div><pre class="json-block">${esc(pretty(j.evidence || {}))}</pre></div>`;
    } catch (e) { $("drawer-body").innerHTML = `<div class="problem">${esc(e.message)}</div>`; }
  }

  function renderObject(obj, skip=new Set()) {
    if (!obj || typeof obj !== "object") return `<div class="object-value">${esc(obj)}</div>`;
    return Object.entries(obj).filter(([k]) => !skip.has(k)).map(([k,v]) => `<section class="object-section"><div class="object-key">${esc(k.replaceAll("_"," "))}</div>${renderValue(v)}</section>`).join("");
  }
  function renderValue(v) {
    if (Array.isArray(v)) {
      if (!v.length) return `<div class="object-value">—</div>`;
      if (v.every(x => ["string","number","boolean"].includes(typeof x) || x === null)) return `<ul class="object-value">${v.map(x => `<li>${esc(x)}</li>`).join("")}</ul>`;
      return `<div class="nested">${v.map((x,i) => `<div><div class="object-key">${i+1}</div>${renderValue(x)}</div>`).join("")}</div>`;
    }
    if (v && typeof v === "object") return `<div class="nested">${Object.entries(v).map(([k,x]) => `<div><div class="object-key">${esc(k.replaceAll("_"," "))}</div>${renderValue(x)}</div>`).join("")}</div>`;
    if (typeof v === "boolean") return `<div class="object-value">${v ? "true" : "false"}</div>`;
    return `<div class="object-value">${esc(v)}</div>`;
  }

  function renderSearchEnvelope(j) {
    const r = j.result || {};
    const hits = r.hits || [];
    if (!hits.length) return `<div class="empty-state">No corpus hits. Gopher returned <code>${esc(j.operation_status?.class || "—")}</code>.</div>`;
    return hits.map(h => `<article class="hit-card"><div class="hit-meta">${esc(h.corpus || "corpus")}${h.record !== undefined ? ` · record ${esc(h.record)}` : ""}</div>${renderValue(h.data ?? h)}</article>`).join("");
  }

  async function runSearch(ev) {
    ev.preventDefault(); if (!state.selectedKey) return;
    const q = $("search-query").value.trim(); if (!q) return;
    $("search-result").className = "result-area"; $("search-result").innerHTML = `<div class="loading">Searching through Gopher…</div>`;
    try { const j = await api(`/api/search?key=${encodeURIComponent(state.selectedKey)}&q=${encodeURIComponent(q)}`); $("search-result").innerHTML = renderSearchEnvelope(j); }
    catch (e) { $("search-result").innerHTML = `<div class="problem">${esc(e.message)}</div>`; }
  }

  async function runLookup(ev) {
    ev.preventDefault(); if (!state.selectedKey) return;
    const q = $("lookup-query").value.trim(); if (!q) return;
    $("lookup-result").className = "result-area"; $("lookup-result").innerHTML = `<div class="loading">Looking up exact fields through Gopher…</div>`;
    try { const j = await api(`/api/lookup?key=${encodeURIComponent(state.selectedKey)}&q=${encodeURIComponent(q)}`); $("lookup-result").innerHTML = renderSearchEnvelope(j); }
    catch (e) { $("lookup-result").innerHTML = `<div class="problem">${esc(e.message)}</div>`; }
  }

  function setTab(name) {
    document.querySelectorAll(".tab").forEach(x => x.classList.toggle("active", x.dataset.tab === name));
    document.querySelectorAll(".panel").forEach(x => x.classList.toggle("active", x.id === `panel-${name}`));
  }

  async function init() {
    try {
      const status = await api("/api/status");
      $("server-state").textContent = `${shortFile(status.sphere_dir)} · Gopher ready`;
      await loadSpheres(false, true);
    } catch (e) { $("server-state").textContent = "not ready"; toast(e.message, true); }
    $("refresh").addEventListener("click", () => loadSpheres(true));
    $("sphere-filter").addEventListener("input", e => { state.filter = e.target.value; renderSphereList(); });
    document.querySelectorAll(".tab").forEach(x => x.addEventListener("click", () => setTab(x.dataset.tab)));
    $("drawer-close").addEventListener("click", () => $("drawer").classList.remove("open"));
    $("search-form").addEventListener("submit", runSearch);
    $("lookup-form").addEventListener("submit", runLookup);
    setInterval(() => loadSpheres(false, true), 5000);
  }
  init();
})();
