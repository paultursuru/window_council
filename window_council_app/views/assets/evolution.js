// Evolution charts and tables, drawn from #chart-data.
// Two charts rather than one with both °C and % axes.
(() => {
  const data = JSON.parse(document.getElementById('chart-data').textContent);
  const end = Date.parse(data.updated_at);
  const runs = data.history.map(e => Object.assign({ t: Date.parse(e.recorded_at) }, e)).sort((a, b) => a.t - b.t);
  // Hygrometer readings, at the time entered in the form
  const entries = data.readings.map(r => ({ t: Date.parse(r.at),
    v: { indoor_temp: r.temperature, indoor_rh: r.humidity, windows: r.windows || 'closed' } })).sort((a, b) => a.t - b.t);
  if (!runs.length && !entries.length) {
    document.getElementById('evolution').innerHTML = '<h2>Évolution</h2><p class="sub">L\'historique démarre ' +
      'au premier relevé réussi : les graphiques et les saisies apparaîtront ici.</p>';
    return;
  }
  const enteredAt = e => Date.parse(e.entered_at);
  const measuredAt = e => Date.parse(e.measured_at);
  // { t, v } points stamped by their real source, one per instant
  const series = (timeOf, valueOf) => {
    const pts = runs.map(e => ({ t: timeOf(e), v: valueOf(e) })).sort((a, b) => a.t - b.t);
    return pts.filter((p, i) => i === 0 || p.t !== pts[i - 1].t);
  };
  const S = {
    indoorTemp: entries.map(p => ({ t: p.t, v: p.v.indoor_temp })),
    indoorRh: entries.map(p => ({ t: p.t, v: p.v.indoor_rh })),
    outdoorTemp: series(measuredAt, e => e.outdoor_temp),
    projectedRh: series(e => Math.max(enteredAt(e), measuredAt(e)), e => e.projected_rh),
  };
  const CHARTS = [
    { el: document.getElementById('plot-temp'), unit: '°C', target: data.targets.temperature, ideal: data.ideals.temperature,
      series: [{ cls: 'indoor', pts: S.indoorTemp, entries: true }, { cls: 'outdoor', pts: S.outdoorTemp }] },
    { el: document.getElementById('plot-rh'), unit: '%', target: data.targets.humidity, ideal: data.ideals.humidity,
      series: [{ cls: 'indoor', pts: S.indoorRh, entries: true }, { cls: 'outdoor', pts: S.projectedRh }] },
  ];
  // Windows open from a reading until the next one
  const airings = entries.map((p, i) => ({ t0: p.t, t1: i + 1 < entries.length ? entries[i + 1].t : end, w: p.v.windows }))
    .filter(a => a.w !== 'closed');
  const GAP = 30 * 60e3; // longer gaps are not joined (Mac asleep…)
  const VERDICTS = { open: 'ouvrir', close: 'fermer', indifferent: 'indifférent', conflict: 'conflit' };
  const RANGES = { 3: '3h', 24: '24h', 168: '7d' };

  const hhmm = t => new Date(t).toLocaleTimeString('fr-CH', { hour: '2-digit', minute: '2-digit' });
  const day = t => new Date(t).toLocaleDateString('fr-CH', { weekday: 'short', day: 'numeric' });
  const when = t => (new Date(t).toDateString() === new Date(end).toDateString() ? '' : day(t) + ' ') + hhmm(t);
  const f1 = v => v.toFixed(1);
  const signed = v => { const r = +v.toFixed(1); return (r > 0 ? '+' : r < 0 ? '−' : '±') + Math.abs(r).toFixed(1); };
  const duration = ms => {
    const min = Math.round(ms / 60e3);
    return min < 60 ? `${min} min` : `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, '0')}`;
  };
  const lastBefore = (pts, t) => { let r = null; for (const p of pts) { if (p.t <= t) r = p; else break; } return r; };
  // Visible points, plus the last one before t0 so the line enters from the left
  const visible = (pts, t0) => {
    const i = pts.findIndex(p => p.t >= t0);
    return i === -1 ? pts.slice(-1) : pts.slice(Math.max(0, i - 1));
  };
  const niceStep = (lo, hi) => {
    const raw = (hi - lo) / 4 || 1;
    const p = 10 ** Math.floor(Math.log10(raw));
    return [1, 2, 2.5, 5, 10].map(k => k * p).find(s => s >= raw);
  };

  let hours = { '#3h': 3, '#24h': 24, '#7d': 168 }[location.hash] || 3;
  let instants = [];
  const W = () => CHARTS[0].el.clientWidth || 600;
  const M = { l: 34, r: 58, t: 10, b: 22 }, H = 190;
  const x = t => M.l + (t - (end - hours * 36e5)) / (hours * 36e5) * (W() - M.l - M.r);

  function draw(c, t0) {
    const w = W();
    const vis = c.series.map(s => visible(s.pts, t0));
    if (!vis.some(v => v.length)) { c.el.innerHTML = '<p class="sub empty">Pas encore de relevé sur cette période.</p>'; return; }
    const vals = [...c.target];
    if (c.ideal != null) vals.push(c.ideal);
    vis.forEach(v => v.forEach(p => vals.push(p.v)));
    const step = niceStep(Math.min(...vals), Math.max(...vals));
    const lo = Math.floor(Math.min(...vals) / step) * step;
    const hi = Math.max(Math.ceil(Math.max(...vals) / step) * step, lo + step);
    const y = v => M.t + (hi - v) / (hi - lo) * (H - M.t - M.b);
    const id = c.el.id;
    let svg = `<svg viewBox="0 0 ${w} ${H}" aria-hidden="true"><defs><clipPath id="clip-${id}">` +
      `<rect x="${M.l}" y="0" width="${w - M.l - M.r}" height="${H}"/></clipPath></defs>`;
    svg += `<rect class="target" x="${M.l}" y="${y(c.target[1])}" width="${w - M.l - M.r}" height="${y(c.target[0]) - y(c.target[1])}"/>`;
    for (let v = lo; v <= hi + 1e-9; v += step) {
      svg += `<line class="grid" x1="${M.l}" x2="${w - M.r}" y1="${y(v)}" y2="${y(v)}"/>` +
        `<text x="${M.l - 6}" y="${y(v) + 4}" text-anchor="end">${+v.toFixed(1)}</text>`;
    }
    const tickMin = hours <= 3 ? 30 : hours <= 24 ? 180 : 1440;
    const d = new Date(t0); d.setHours(0, 0, 0, 0);
    for (let t = d.getTime(); t <= end; t += tickMin * 60e3) {
      if (t < t0) continue;
      svg += `<text x="${x(t)}" y="${H - 6}" text-anchor="middle">${tickMin >= 1440 ? day(t) : hhmm(t)}</text>`;
    }
    svg += `<line class="axis" x1="${M.l}" x2="${w - M.r}" y1="${H - M.b}" y2="${H - M.b}"/>`;
    if (c.ideal != null) svg += `<line class="ideal" x1="${M.l}" x2="${w - M.r}" y1="${y(c.ideal)}" y2="${y(c.ideal)}"/>`;
    svg += `<g clip-path="url(#clip-${id})">`;
    airings.forEach(a => {
      if (a.t1 < t0) return;
      svg += `<rect class="airing ${a.w}" x="${x(a.t0)}" y="${M.t}" width="${Math.max(x(a.t1) - x(a.t0), 2)}" ` +
        `height="${H - M.t - M.b}"/>`;
    });
    const lasts = [];
    c.series.forEach((s, i) => {
      const pts = vis[i];
      if (!pts.length) return;
      const last = pts[pts.length - 1];
      const d = pts.map((p, j) => (j && (s.entries || p.t - pts[j - 1].t <= GAP) ? 'L' : 'M') +
        `${x(p.t).toFixed(1)} ${y(p.v).toFixed(1)}`).join('');
      svg += `<path class="line ${s.cls}" d="${d}"/>`;
      // An entered value holds until the next entry (faded line)
      if (s.entries) svg += `<path class="line ${s.cls} carry" d="M${x(last.t)} ${y(last.v)}H${x(end)}"/>`;
      (s.entries ? pts : [last]).forEach(p => { svg += `<circle class="dot ${s.cls}" cx="${x(p.t)}" cy="${y(p.v)}" r="4"/>`; });
      lasts.push({ cls: s.cls, v: last.v, y: y(last.v) });
    });
    svg += '</g>';
    // Last values in the right margin, skipped when they overlap
    lasts.forEach((f, i) => {
      if (i && Math.abs(f.y - lasts[0].y) < 13) return;
      svg += `<line class="line ${f.cls}" x1="${w - M.r + 4}" x2="${w - M.r + 12}" y1="${f.y}" y2="${f.y}"/>` +
        `<text class="last" x="${w - M.r + 15}" y="${f.y + 4}">${f1(f.v)}${c.unit === '%' ? ' %' : '°'}</text>`;
    });
    svg += `<line class="xhair" x1="0" x2="0" y1="${M.t}" y2="${H - M.b}" visibility="hidden"/></svg>`;
    c.el.innerHTML = svg;
  }

  const tip = document.getElementById('tip');
  const zone = document.getElementById('evolution');
  function tipRow(cls, value, label) {
    const row = document.createElement('div');
    row.className = 'row';
    const key = document.createElement('i');
    key.className = cls ? `key ${cls}` : 'key';
    const b = document.createElement('b');
    b.textContent = value;
    const n = document.createElement('span');
    n.textContent = label;
    row.append(key, b, n);
    tip.append(row);
  }
  function show(t, px, py) {
    CHARTS.forEach(c => {
      const l = c.el.querySelector('.xhair');
      if (l) { l.setAttribute('x1', x(t)); l.setAttribute('x2', x(t)); l.setAttribute('visibility', 'visible'); }
    });
    tip.textContent = '';
    const head = document.createElement('div');
    head.className = 'head';
    head.textContent = when(t);
    tip.append(head);
    const entry = lastBefore(entries, t), temp = lastBefore(S.outdoorTemp, t);
    const rh = lastBefore(S.projectedRh, t), run = lastBefore(runs, t);
    if (entry) tipRow('indoor', `${f1(entry.v.indoor_temp)} °C · ${f1(entry.v.indoor_rh)} %`,
      `intérieur, relevé ${when(entry.t)} · ${data.windows[entry.v.windows].toLowerCase()}`);
    if (temp) tipRow('outdoor', `${f1(temp.v)} °C`, 'extérieur');
    if (rh) tipRow('outdoor', `${f1(rh.v)} %`, 'air ext. à T int.');
    if (run) tipRow('', VERDICTS[run.verdict] || run.verdict, 'verdict');
    tip.hidden = false;
    const z = zone.getBoundingClientRect();
    const left = Math.min(px - z.left + 14, z.width - tip.offsetWidth);
    tip.style.left = `${Math.max(0, left)}px`;
    tip.style.top = `${py - z.top + 14}px`;
  }
  function hide() {
    tip.hidden = true;
    CHARTS.forEach(c => { const l = c.el.querySelector('.xhair'); if (l) l.setAttribute('visibility', 'hidden'); });
  }
  const nearest = px => {
    let best = null;
    instants.forEach(t => { if (best === null || Math.abs(x(t) - px) < Math.abs(x(best) - px)) best = t; });
    return best;
  };
  CHARTS.forEach(c => {
    let k = -1;
    c.el.addEventListener('pointermove', ev => {
      const t = nearest(ev.clientX - c.el.getBoundingClientRect().left);
      if (t !== null) show(t, ev.clientX, ev.clientY);
    });
    c.el.addEventListener('pointerleave', hide);
    c.el.addEventListener('blur', hide);
    const showAtKey = () => {
      if (!instants.length) return;
      const r = c.el.getBoundingClientRect();
      show(instants[k], r.left + x(instants[k]), r.top + 20);
    };
    c.el.addEventListener('focus', () => { k = instants.length - 1; showAtKey(); });
    c.el.addEventListener('keydown', ev => {
      if (ev.key === 'ArrowLeft') k = Math.max(0, k - 1);
      else if (ev.key === 'ArrowRight') k = Math.min(instants.length - 1, k + 1);
      else if (ev.key === 'Escape') return hide();
      else return;
      ev.preventDefault();
      showAtKey();
    });
  });

  function fillTable(id, headers, rows) {
    const table = document.getElementById(id);
    table.textContent = '';
    const tr = table.insertRow();
    headers.forEach(h => { const th = document.createElement('th'); th.textContent = h; tr.append(th); });
    rows.forEach(cells => {
      const row = table.insertRow();
      cells.forEach(v => { row.insertCell().textContent = v; });
    });
    if (!rows.length) table.insertRow().insertCell().textContent = 'Aucune sur cette période.';
  }

  function render() {
    const t0 = end - hours * 36e5;
    CHARTS.forEach(c => draw(c, t0));
    instants = [...new Set(CHARTS.flatMap(c => c.series.flatMap(s => s.pts.map(p => p.t))))]
      .filter(t => t >= t0 && t <= end).sort((a, b) => a - b);
    document.querySelectorAll('.ranges button').forEach(b => b.setAttribute('aria-pressed', +b.dataset.h === hours));
    const rows = [];
    entries.forEach((p, i) => {
      if (p.t < t0) return;
      const prev = entries[i - 1];
      let change = '—', rate = '—';
      if (prev) {
        const dT = p.v.indoor_temp - prev.v.indoor_temp, dH = p.v.indoor_rh - prev.v.indoor_rh, h = (p.t - prev.t) / 36e5;
        change = `${signed(dT)} °C, ${signed(dH)} pts en ${duration(p.t - prev.t)}`;
        rate = `${signed(dT / h)} °C/h, ${signed(dH / h)} pts/h`;
      }
      rows.unshift([when(p.t), `${f1(p.v.indoor_temp)} °C`, `${f1(p.v.indoor_rh)} %`, data.windows[p.v.windows],
        change, rate]);
    });
    fillTable('entries', ['Relevé', 'Température', 'Humidité', 'Fenêtres', 'Depuis le précédent', 'Vitesse'], rows);
    fillTable('runs', ['Passage', 'Intérieur', 'Extérieur', 'Air ext. à T int.', 'Verdict'],
      runs.filter(e => e.t >= t0).reverse().map(e => [when(e.t), `${f1(e.indoor_temp)} °C · ${f1(e.indoor_rh)} %`,
        `${f1(e.outdoor_temp)} °C · ${f1(e.outdoor_rh)} %`, `${f1(e.projected_rh)} %`, VERDICTS[e.verdict] || e.verdict]));
  }

  document.querySelectorAll('.ranges button').forEach(b => b.addEventListener('click', () => {
    hours = +b.dataset.h;
    history.replaceState(null, '', `#${RANGES[hours]}`); // keeps the range across auto-reloads
    hide();
    render();
  }));
  let frame;
  window.addEventListener('resize', () => { cancelAnimationFrame(frame); frame = requestAnimationFrame(render); });
  render();
})();
