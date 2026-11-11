// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: deep-gray; icon-glyph: tachometer-alt;

// Token Gauge for iPhone (Scriptable). Draws the usage that Token Gauge on your Mac
// publishes to Scriptable's iCloud Drive folder as "Token Gauge.json". The file holds only
// usage percentages, reset times and capture times; this script makes no network requests.
// Logo paths come from CodexBar's MIT-licensed provider assets; see Assets/NOTICE.md in Token Gauge.

const FILE = 'Token Gauge.json';
const CACHE = 'token-gauge-last.json'; // phone-only copy of the last good data, kept outside iCloud
const STALE_SECONDS = 900;
const LOGOS = {
  claude: "M 25.7146 63.2153 L 41.4393 54.3917 L 41.7025 53.6226 L 41.4393 53.1976 L 40.6705 53.1976 L 38.0394 53.0359 L 29.054 52.7929 L 21.2624 52.4691 L 13.7134 52.0644 L 11.8111 51.6594 L 10.0303 49.3118 L 10.2123 48.138 L 11.8111 47.0657 L 14.0981 47.2681 L 19.1574 47.6119 L 26.7467 48.138 L 32.2516 48.4618 L 40.4073 49.3118 L 41.7025 49.3118 L 41.8846 48.7857 L 41.4393 48.4618 L 41.0955 48.138 L 33.243 42.8155 L 24.7432 37.1894 L 20.2909 33.9513 L 17.8824 32.3119 L 16.6684 30.774 L 16.1422 27.4147 L 18.328 25.0062 L 21.2624 25.2088 L 22.0112 25.4112 L 24.9861 27.6979 L 31.3407 32.616 L 39.6381 38.7273 L 40.8525 39.7391 L 41.3381 39.395 L 41.399 39.1523 L 40.8525 38.2415 L 36.3394 30.0858 L 31.5227 21.7883 L 29.3775 18.3478 L 28.811 16.2837 C 28.4669 13.8549 28.6087 15.4334 28.4669 14.7252 L 30.9563 10.4753 L 32.3321 10.0303 L 35.6515 10.4756 L 37.0479 11.6897 L 39.112 16.4052 L 42.4513 23.8327 L 47.6321 33.9313 L 49.15 36.9265 L 49.9594 39.6991 L 50.2632 40.5491 L 50.7894 40.5491 L 50.7894 40.0632 L 51.2141 34.3766 L 52.0035 27.3944 L 52.7726 18.4087 L 53.0358 15.8793 L 54.2905 12.8435 L 56.7795 11.2041 L 58.7224 12.135 L 60.3212 14.422 L 60.0986 15.899 L 59.1474 22.0718 L 57.2857 31.7458 L 56.0713 38.2218 L 56.7795 38.2218 L 57.5892 37.4121 L 60.8677 33.061 L 66.3723 26.18 L 68.801 23.448 L 71.6342 20.4325 L 73.4556 18.9957 L 76.8962 18.9957 L 79.4255 22.7601 L 78.2926 26.6456 L 74.7509 31.1384 L 71.8163 34.943 L 67.607 40.6097 L 64.9758 45.1431 L 65.2188 45.5072 L 65.8464 45.4466 L 75.358 43.4228 L 80.4984 42.4917 L 86.6304 41.4393 L 89.4033 42.7346 L 89.7065 44.0502 L 88.6135 46.7419 L 82.0566 48.3607 L 74.3662 49.8989 L 62.9118 52.6109 L 62.77 52.7121 L 62.9321 52.9144 L 68.0925 53.4 L 70.2987 53.5214 L 75.7021 53.5214 L 85.7601 54.2702 L 88.3912 56.0108 L 89.9697 58.1358 L 89.7065 59.7545 L 85.6589 61.8189 L 80.1949 60.5236 L 67.4452 57.4881 L 63.0735 56.3952 L 62.4665 56.3952 L 62.4665 56.7596 L 66.1093 60.3213 L 72.7877 66.3523 L 81.1461 74.1236 L 81.5707 76.0462 L 80.4984 77.5638 L 79.3649 77.4021 L 72.0186 71.8772 L 69.1854 69.3879 L 62.77 63.9844 L 62.3453 63.9844 L 62.3453 64.5509 L 63.8223 66.7164 L 71.6342 78.4544 L 72.0389 82.0567 L 71.4725 83.2308 L 69.4487 83.939 L 67.2222 83.534 L 62.6485 77.1189 L 57.9333 69.8937 L 54.1284 63.4177 L 53.6631 63.6809 L 51.4167 87.8651 L 50.3644 89.0995 L 47.9356 90.0303 L 45.9121 88.4924 L 44.8392 86.0031 L 45.9118 81.0852 L 47.2071 74.6701 L 48.2594 69.5699 L 49.2106 63.2356 L 49.7773 61.131 L 49.7367 60.9892 L 49.2715 61.0498 L 44.4954 67.607 L 37.23 77.4224 L 31.4825 83.5746 L 30.1063 84.1211 L 27.7181 82.8864 L 27.9408 80.6805 L 29.2763 78.7177 L 37.2297 68.5988 L 42.026 62.3248 L 45.1227 58.7025 L 45.1024 58.176 L 44.9204 58.176 L 23.7917 71.8975 L 20.0274 72.3831 L 18.4083 70.8655 L 18.6106 68.3761 L 19.3798 67.5664 L 25.7343 63.195 L 25.7146 63.2153 Z",
  grok: "M 38.625 63.7083 L 71.8667 39.1375 C 76.6042 40.2708 73.4958 37.9292 75.825 38.4 C 70.7292 70.1417 80.6875 50.1417 78.8625 62.0 C 40.9417 76.0 62.6 78.2833 51.2833 80.0667 L 29.6458 81.2375 C 77.8208 77.2667 45.85 92.325 65.525 89.5833 C 87.7708 42.1833 87.575 67.5 90.5958 54.1875 L 87.7958 42.2125 C 99.2542 3.1167 83.7 24.5792 88.8042 17.5292 C 100.0 2.0833 99.5042 2.775 99.7542 2.4333 L 86.2458 15.8542 L 86.2458 15.8125 L 38.6125 63.7167 M 31.7625 69.6792 C 32.0583 31.4125 20.1292 58.5542 22.1375 41.3417 C 61.9167 25.475 39.3958 24.0667 51.4208 21.0667 L 73.1875 20.2667 C 65.5667 16.1 70.8449 18.5434 68.2818 17.142 C 24.9333 24.2917 51.6095 10.3875 35.587 13.6176 C 16.7583 64.975 14.3792 34.8583 11.0583 51.1083 C 7.0083 90.0667 21.0167 75.3375 14.0375 82.6667 C 0.0 98.0875 4.5125 92.6917 2.0125 95.3125 L 31.75 69.6917",
  codex: "M 83.7733 42.8087 C 84.6807 34.4385 84.6678 40.1149 84.9771 37.2613 C 82.0544 26.4394 84.3843 31.6156 83.489 28.8885 C 60.3548 16.7725 77.6908 18.8436 68.9203 14.9365 C 51.5864 11.0673 57.9831 14.1344 54.9591 12.1668 C 41.1402 10.5084 48.2137 9.96772 44.611 9.77498 C 31.8132 15.2455 37.6694 11.2418 34.4527 12.8755 C 26.1024 24.0103 29.1736 17.6155 27.204 20.6383 C 18.3958 27.405 23.3212 24.5806 20.6938 25.738 C 12.7765 33.6772 16.0977 29.0721 14.1819 31.2104 C 15.2527 57.3327 8.36538 41.2609 9.3669 50.8267 C 14.3361 65.7012 14.3549 60.0251 14.0424 62.8782 C 16.9558 73.7017 14.6298 68.5241 15.523 71.2518 C 38.6712 83.3686 21.325 81.3002 30.1011 85.207 C 45.4623 88.3416 40.5554 85.4904 42.8707 87.1858 C 53.6999 90.0713 48.0539 89.4975 50.8622 90.0871 C 72.9393 76.0515 62.4793 90.079 70.2575 84.4114 C 80.6449 72.6555 75.7201 75.4802 78.347 74.3225 C 86.2649 66.3846 82.9427 70.9886 84.8587 68.8507 C 83.7733 42.8087 90.6227 58.8145 89.6172 49.3005 Z M 53.6999 84.8356 C 44.1116 81.3661 50.1955 84.8411 46.801 83.6129 L 44.5848 81.098 L 60.5123 71.9043 C 61.4674 70.942 60.9087 71.6718 61.2379 71.3402 C 61.8215 69.6333 61.6969 70.5439 61.8189 70.0929 L 61.8215 47.1769 L 68.5553 51.072 C 68.6814 51.2456 68.6225 51.1063 68.6694 51.1707 L 68.6814 69.854 C 53.6999 84.8356 68.6641 78.1208 61.9667 84.8183 Z M 21.4977 71.0843 C 19.7156 61.0386 19.7402 68.0497 19.1092 64.4925 L 20.1885 61.3225 L 36.1321 70.5165 C 37.4331 70.87 36.5266 70.748 36.9757 70.87 C 38.7341 70.5165 37.8905 70.87 38.3396 70.748 L 58.21 59.2883 L 58.21 67.0628 C 58.1782 67.1779 58.2081 67.1031 58.1973 67.1424 C 58.0996 67.2678 58.1591 67.2134 58.1322 67.2441 L 41.9671 76.5722 C 21.4977 71.0843 34.798 80.7022 25.6388 78.2463 Z M 17.3026 36.3898 C 25.1878 29.8138 19.0723 33.3357 21.8655 31.0062 L 25.1878 48.7376 C 25.5261 50.042 25.1818 49.1949 25.2986 49.6453 C 26.4809 50.9928 25.7535 50.4387 26.0833 50.7671 L 45.8622 62.1739 L 39.1283 66.069 C 39.0101 66.0984 39.0919 66.0883 39.0513 66.0984 C 38.8919 66.069 38.9689 66.0984 38.9283 66.0883 L 22.7908 56.7809 C 17.3026 36.3112 15.6359 52.6337 13.1822 43.4816 L 17.3026 36.3898 Z M 72.624 49.2426 L 53.1792 37.9512 L 59.8976 34.0718 C 60.016 34.0423 59.9341 34.0524 59.9747 34.0423 C 60.1344 34.0718 60.0573 34.0423 60.0979 34.0524 L 76.2355 43.3761 C 82.0221 49.4065 78.6973 44.7966 80.7043 46.8882 C 83.6775 57.5985 83.3398 51.9249 83.914 54.7661 C 80.6867 65.4027 83.4411 60.431 82.4038 63.1377 C 73.9803 70.3901 78.9696 67.6677 76.6436 69.3975 L 73.9803 51.466 C 73.5962 50.1749 73.9663 51.0096 73.834 50.5647 C 72.624 49.2426 73.3584 49.7851 73.0234 49.4638 Z M 79.3261 39.1657 L 78.8529 38.8815 L 62.9411 29.6089 C 61.6322 29.2532 62.5442 29.376 62.0924 29.2532 C 60.3233 29.6089 61.172 29.2532 60.7202 29.376 L 40.8629 40.8374 L 40.8629 33.0628 C 40.882 32.9473 40.8587 33.0233 40.8654 32.9834 C 40.9575 32.8579 40.8987 32.9113 40.9248 32.8803 L 57.0586 23.5692 C 65.193 21.5811 59.5263 22.1476 62.3478 21.458 C 73.1253 24.2642 68.0382 21.7042 70.7896 22.6348 C 78.3825 30.782 75.461 25.8936 77.2845 28.1543 C 79.3257 39.1025 79.4806 33.4097 79.8077 36.2957 L 79.3257 39.1657 L 79.3261 39.1657 Z M 37.1888 52.9484 L 30.455 49.069 C 30.3707 48.9884 30.4213 49.0487 30.3925 49.0212 C 30.3286 48.8797 30.3488 48.9557 30.3345 48.9186 L 30.3286 30.3188 C 32.6761 22.2822 30.3323 27.4714 31.1466 24.6839 C 38.9661 16.7564 34.2057 19.8805 36.3874 17.9639 C 47.2381 15.4636 41.5448 15.549 44.4139 15.1005 C 54.9141 18.8067 50.0622 15.8267 52.7247 16.9862 L 54.4409 19.0748 L 38.5134 28.2686 C 37.5584 29.2308 38.117 28.5011 37.7879 28.8327 C 37.2045 30.5395 37.329 29.629 37.207 30.0799 L 37.1888 52.9487 L 37.1888 52.9484 Z M 40.8472 45.0632 L 49.5209 40.0643 L 58.21 45.0635 L 58.21 55.0615 L 49.5523 60.0608 L 40.8632 55.0615 L 40.8472 45.0632 Z",
};

// Gauge sizes, matching the Mac widget's small / medium / large gauges (points).
const SPECS = {
  small: { d: 48, lw: 4.5, value: 11, label: 8, reset: 8.5, gap: 7, inner: 1.6, f: 5.5, sec: 7, secOff: 11, fOff: 7, logo: 16, cellGap: 6, logoGap: 5 },
  medium: { d: 64, lw: 6, value: 16, label: 10, reset: 10.5, gap: 13, inner: 2.2, f: 7, sec: 9, secOff: 14, fOff: 10, logo: 19.2, cellGap: 10, logoGap: 5 },
  large: { d: 88, lw: 8, value: 22, label: 12, reset: 12, gap: 15, inner: 3, f: 8, sec: 11, secOff: 20, fOff: 12, logo: 22.4, cellGap: 22, logoGap: 8 },
};
// Canvas sizes in points; the widget scales the image to the device's real tile size.
const CANVAS = { small: [170, 170], medium: [364, 170], large: [364, 382] };

function validUsage(q, now) { return q && q.used != null && !(q.reset != null && q.reset <= now) ? q.used : null; }
function isStale(g, now) { return !g.observedAt || g.stale || now - g.observedAt >= STALE_SECONDS; }
function percent(q, now) { const v = validUsage(q, now); return v == null ? '—' : `${Math.round(v)}%`; }
// Same format as the Mac: "11:59pm", weekly windows "Thu 11:59pm", in the phone's time zone.
function resetText(epoch, weekly) {
  if (epoch == null || !isFinite(epoch)) return '—';
  const d = new Date(Math.round(epoch) * 1000);
  const h = d.getHours(), m = String(d.getMinutes()).padStart(2, '0');
  const time = `${h % 12 || 12}:${m}${h < 12 ? 'am' : 'pm'}`;
  return weekly ? `${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()]} ${time}` : time;
}
// When the Mac stops publishing, say when its last report was; the numbers stay as of that time.
function offlineLabel(generatedAt, now) {
  if (!generatedAt || now - generatedAt <= STALE_SECONDS) return null;
  const sameDay = new Date(generatedAt * 1000).toDateString() === new Date(now * 1000).toDateString();
  return `Mac offline · ${resetText(generatedAt, !sameDay)}`;
}
// Prefer whichever copy is newer: iCloud's, or the phone's own last good copy.
function newer(a, b) {
  const ok = v => v && Array.isArray(v.groups) && v.groups.length && typeof v.generatedAt === 'number';
  if (!ok(a)) return ok(b) ? b : null;
  if (!ok(b)) return a;
  return b.generatedAt > a.generatedAt ? b : a;
}
function gaugeColors(provider, weekly, dark) {
  if (provider === 'claude') return weekly ? ['#D97757', '#E38D70'] : ['#E28B6D', '#EBA085'];
  if (provider === 'grok') return dark ? ['#BDBDBD', '#FFFFFF'] : ['#4A4A4A', '#111111'];
  return weekly ? ['#3285F5', '#5098FA'] : ['#5BA4FA', '#7BB9FF'];
}
function mix(a, b, t) {
  const p = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const x = p(a), y = p(b);
  return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('');
}

// Panels: Grok's single gauge, or a 5H gauge plus a 7D gauge (Claude's carries Fable inside).
function cells(group) {
  const w = group.windows || [];
  if (w.length === 1) return [{ quota: w[0] }];
  const fable = group.id === 'claude' ? w.find(x => String(x.label).toUpperCase() === 'FABLE') : null;
  return [{ quota: w[0] }, { quota: w[1], secondary: fable }];
}
function cellHeight(s, showReset) { return s.d + (showReset ? s.gap + s.reset * 1.25 : 0); }
function panelSize(p) {
  const s = SPECS[p.size], n = cells(p.group).length;
  const cw = n * s.d + (n - 1) * s.cellGap, ch = cellHeight(s, p.reset);
  return p.beside ? [s.logo + 10 + cw, ch] : [Math.max(cw, s.logo), s.logo + s.logoGap + ch];
}
// Layouts mirror the Mac widget: Grok on the left; Claude above Codex on the right in small and large.
function layout(family, groups) {
  const grok = groups.filter(g => g.id === 'grok'), others = groups.filter(g => g.id !== 'grok');
  const panel = (group, size, beside, reset) => ({ group, size, beside, reset });
  if (family === 'small') {
    if (!grok.length) return [others.map(g => panel(g, 'small', true, true))];
    return [grok.map(g => panel(g, 'medium', false, false)), others.map(g => panel(g, 'small', true, false))];
  }
  if (family === 'large') {
    if (!grok.length) return [others.map(g => panel(g, 'large', false, true))];
    return [grok.map(g => panel(g, 'medium', false, true)), others.map(g => panel(g, 'medium', true, true))];
  }
  return [...grok, ...others].map(g => [panel(g, 'medium', false, true)]);
}
const ROW_GAP = 16, COL_GAP = 12, PAD = 12;
function measure(cols) {
  const sizes = cols.map(col => {
    const ps = col.map(panelSize);
    return { ps, w: Math.max(...ps.map(p => p[0])), h: ps.reduce((a, p) => a + p[1], 0) + (col.length - 1) * ROW_GAP };
  });
  return { sizes, w: sizes.reduce((a, c) => a + c.w, 0) + (cols.length - 1) * COL_GAP * 2, h: Math.max(...sizes.map(c => c.h)) };
}

function render(snapshot, family, dark, now) {
  const [W, H] = CANVAS[family] || CANVAS.medium;
  const ctx = new DrawContext();
  ctx.size = new Size(W, H);
  ctx.respectScreenScale = true;
  ctx.opaque = true;
  const fg = dark ? '#FFFFFF' : '#000000';
  const col = (hex, a = 1) => new Color(hex, a);
  // Solid track colour (14% foreground over the background) so overlapping round caps don't darken.
  const track = col(mix(dark ? '#000000' : '#FFFFFF', fg, 0.14));
  ctx.setFillColor(col(dark ? '#000000' : '#FFFFFF'));
  ctx.fillRect(new Rect(0, 0, W, H));
  const text = (s, cx, cy, size, weight, color, width, k, ox, oy) => {
    ctx.setFont(weight === 'semibold' ? Font.semiboldSystemFont(size * k) : weight === 'regular' ? Font.systemFont(size * k) : Font.mediumSystemFont(size * k));
    ctx.setTextColor(color);
    ctx.setTextAlignedCenter();
    ctx.drawTextInRect(s, new Rect(ox + (cx - width / 2) * k, oy + (cy - size * 0.62) * k, width * k, size * 1.4 * k));
  };
  if (!snapshot || !Array.isArray(snapshot.groups) || !snapshot.groups.length) {
    // No data yet: the Mac has not published, or iCloud has not synced the file to this phone.
    text('Waiting for', W / 2, H / 2 - 8, 12, 'medium', col(fg, 0.6), W - 20, 1, 0, 0);
    text('your Mac', W / 2, H / 2 + 8, 12, 'medium', col(fg, 0.6), W - 20, 1, 0, 0);
    return ctx.getImage();
  }
  const cols = layout(family, snapshot.groups), m = measure(cols);
  const k = Math.min(1.4, (W - 2 * PAD) / m.w, (H - 2 * PAD) / m.h);
  const ox = (W - m.w * k) / 2, oy = (H - m.h * k) / 2;
  const X = x => ox + x * k, Y = y => oy + y * k;
  const arcPath = (cx, cy, r, a0, a1) => {
    const path = new Path(), n = Math.max(2, Math.ceil(Math.abs(a1 - a0) / 3)), pts = [];
    for (let i = 0; i <= n; i++) { const a = (a0 + (a1 - a0) * i / n) * Math.PI / 180; pts.push(new Point(X(cx + r * Math.cos(a)), Y(cy + r * Math.sin(a)))); }
    path.addLines(pts);
    return path;
  };
  const dot = (cx, cy, r, a, w, color) => {
    const rad = a * Math.PI / 180, x = cx + r * Math.cos(rad), y = cy + r * Math.sin(rad);
    ctx.setFillColor(color); ctx.fillEllipse(new Rect(X(x - w / 2), Y(y - w / 2), w * k, w * k));
  };
  const stroke = (path, w, color) => { ctx.addPath(path); ctx.setStrokeColor(color); ctx.setLineWidth(w * k); ctx.strokePath(); };
  // A 300° ring open at the top, filled clockwise from just right of 12 o'clock with a linear colour blend.
  const ring = (cx, cy, d, w, value, colors) => {
    const r = (d - w) / 2;
    stroke(arcPath(cx, cy, r, -60, 240), w, track);
    dot(cx, cy, r, -60, w, track); dot(cx, cy, r, 240, w, track);
    if (!(value > 0)) return;
    const sweep = Math.min(1, value / 100) * 300, n = Math.max(1, Math.ceil(sweep / 4));
    for (let i = 0; i < n; i++) {
      const a0 = -60 + sweep * i / n, a1 = -60 + sweep * (i + 1) / n;
      stroke(arcPath(cx, cy, r, a0, Math.min(-60 + sweep, a1 + 0.6)), w, col(mix(colors[0], colors[1], (i + 0.5) / n)));
    }
    dot(cx, cy, r, -60, w, col(colors[0])); dot(cx, cy, r, -60 + sweep, w, col(colors[1]));
  };
  const logo = (id, x, y, size) => {
    const tokens = (LOGOS[id] || '').split(' '), path = new Path(), s = size / 100;
    const pt = (i) => new Point(X(x + Number(tokens[i]) * s), Y(y + Number(tokens[i + 1]) * s));
    for (let i = 0; i < tokens.length;) {
      const c = tokens[i];
      if (c === 'M') { path.move(pt(i + 1)); i += 3; }
      else if (c === 'L') { path.addLine(pt(i + 1)); i += 3; }
      else if (c === 'C') { path.addCurve(pt(i + 1), pt(i + 3), pt(i + 5)); i += 7; }
      else if (c === 'Z') { path.closeSubpath(); i += 1; }
      else i += 1;
    }
    ctx.addPath(path);
    ctx.setFillColor(id === 'claude' ? col('#D97757') : col(fg, dark ? 0.9 : 0.8));
    ctx.fillPath();
  };
  const clock = (x, y) => {
    // Small clock badge: this provider's report is over 15 minutes old.
    ctx.setFillColor(col(fg, 0.55)); ctx.fillEllipse(new Rect(X(x - 3.2), Y(y - 3.2), 6.4 * k, 6.4 * k));
    const hand = new Path(); hand.addLines([new Point(X(x), Y(y - 2)), new Point(X(x), Y(y)), new Point(X(x + 1.6), Y(y + 0.9))]);
    stroke(hand, 0.8, col(dark ? '#000000' : '#FFFFFF'));
  };
  const cell = (c, provider, x, y, s, showReset) => {
    const q = c.quota, cx = x + s.d / 2, cy = y + s.d / 2, weekly = q.duration >= 86400;
    ring(cx, cy, s.d, s.lw, validUsage(q, now) || 0, gaugeColors(provider, weekly, dark));
    if (c.secondary) ring(cx, cy, s.d - 2 * (s.lw + 0.5), s.inner, validUsage(c.secondary, now) || 0, ['#E4B55D', '#F0CA80']);
    if (q.reset != null && q.duration > 0 && validUsage(q, now) != null) {
      // Pace marker: how much of the window has elapsed.
      const f = Math.min(1, Math.max(0, 1 - (q.reset - now) / q.duration)), a = (-60 + f * 300) * Math.PI / 180;
      const len = s.lw + (c.secondary ? 0.5 + s.inner : 0), r0 = s.d / 2, r1 = s.d / 2 - len;
      const marker = new Path(); marker.addLines([new Point(X(cx + r0 * Math.cos(a)), Y(cy + r0 * Math.sin(a))), new Point(X(cx + r1 * Math.cos(a)), Y(cy + r1 * Math.sin(a)))]);
      stroke(marker, s === SPECS.small ? 1.6 : 2, col('#FF4558'));
    }
    text(String(q.label), cx, y + s.lw / 2, s.label, 'semibold', col(fg), s.d, k, ox, oy);
    if (c.secondary) text('F', cx, y + s.lw / 2 + s.fOff, s.f, 'medium', col(fg), s.d, k, ox, oy);
    text(percent(q, now), cx, cy, s.value, 'medium', col(fg), s.d + 10, k, ox, oy);
    if (c.secondary) text(percent(c.secondary, now), cx, cy + s.secOff, s.sec, 'regular', col(dark ? '#F0CA80' : '#704508'), s.d, k, ox, oy);
    if (showReset) text(validUsage(q, now) == null ? '—' : resetText(q.reset, weekly), cx, y + s.d + s.gap + s.reset * 0.6, s.reset, 'medium', col(fg, 0.9), s.d + 24, k, ox, oy);
  };
  const panel = (p, x, y, w) => {
    const s = SPECS[p.size], list = cells(p.group), n = list.length;
    const cw = n * s.d + (n - 1) * s.cellGap, [pw] = panelSize(p);
    let cx0, cy0, lx, ly;
    if (p.beside) { lx = x + (w - pw) / 2; ly = y + s.d / 2 - s.logo / 2; cx0 = lx + s.logo + 10; cy0 = y; }
    else { lx = x + (w - s.logo) / 2; ly = y; cx0 = x + (w - cw) / 2; cy0 = y + s.logo + s.logoGap; }
    logo(p.group.id, lx, ly, s.logo);
    if (isStale(p.group, now)) clock(lx + s.logo + 1, ly + 1);
    list.forEach((c, i) => cell(c, p.group.id, cx0 + i * (s.d + s.cellGap), cy0, s, p.reset));
  };
  const hairline = (x0, y0, x1, y1) => { const l = new Path(); l.addLines([new Point(X(x0), Y(y0)), new Point(X(x1), Y(y1))]); stroke(l, 0.5 / k, col(fg, 0.14)); };
  let x = 0;
  cols.forEach((column, ci) => {
    const size = m.sizes[ci];
    if (ci > 0) { hairline(x + COL_GAP, m.h / 2 - Math.min(m.h, 100) / 2, x + COL_GAP, m.h / 2 + Math.min(m.h, 100) / 2); x += 2 * COL_GAP; }
    let y = (m.h - size.h) / 2;
    column.forEach((p, pi) => {
      if (pi > 0) { hairline(x + 4, y + ROW_GAP / 2, x + size.w - 4, y + ROW_GAP / 2); y += ROW_GAP; }
      panel(p, x, y, size.w);
      y += size.ps[pi][1];
    });
    x += size.w;
  });
  const note = offlineLabel(snapshot.generatedAt, now);
  if (note) {
    ctx.setFont(Font.mediumSystemFont(8)); ctx.setTextColor(col(fg, 0.55)); ctx.setTextAlignedRight();
    ctx.drawTextInRect(note, new Rect(W - 130, 5, 124, 12));
  }
  return ctx.getImage();
}

async function loadSnapshot() {
  // The phone keeps its own copy of the last good data, so the widget still shows the latest
  // numbers if iCloud has not downloaded the file, is unavailable, or the Mac is off.
  const local = FileManager.local();
  const cachePath = local.joinPath(local.documentsDirectory(), CACHE);
  let cached = null, fresh = null;
  try { if (local.fileExists(cachePath)) cached = JSON.parse(local.readString(cachePath)); } catch { cached = null; }
  try {
    const fm = FileManager.iCloud();
    const path = fm.joinPath(fm.documentsDirectory(), FILE);
    await fm.downloadFileFromiCloud(path); // also fetches a file iCloud has not downloaded yet
    fresh = JSON.parse(fm.readString(path));
  } catch { fresh = null; }
  const best = newer(fresh, cached);
  if (best && best === fresh) { try { local.writeString(cachePath, JSON.stringify(fresh)); } catch { /* cache is best-effort */ } }
  return best;
}

// --- run (Scriptable) ---
const snapshot = await loadSnapshot();
const family = config.runsInWidget ? (config.widgetFamily || 'medium') : 'medium';
const widget = new ListWidget();
// Always dark by default. Set the widget's Parameter to "auto" to follow the phone's appearance, or "light".
const mode = String(args.widgetParameter || '').trim().toLowerCase();
const dark = mode === 'auto' ? Device.isUsingDarkAppearance() : mode !== 'light';
widget.backgroundImage = render(snapshot, CANVAS[family] ? family : 'medium', dark, Date.now() / 1000);
widget.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000);
if (config.runsInWidget) Script.setWidget(widget);
else await widget.presentMedium();
Script.complete();
