// The example's self-check of the 1.5.0 calls (G15–G37) and the 1.5.5 taps, run on a device or simulator when
// SELF_CHECK_URL is set: each check's outcome is posted to that URL as JSON (JavaScript logs do not reach a console
// there).
import { PixelRatio, Platform } from 'react-native';
import { geo, type SMapHandle } from '@superrouteca/smap-react-native';

const PNG = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAASklEQVR4nO3NuwkAMAwDUe+/tNOkMoTIHxUC3wD3zDap/KYJeEgLiPNxhAq85mMIFfjN2wgVQOdlhApk52mEClTnMEIFunMI2WIHKJeFl7tO4Y0AAAAASUVORK5CYII=';
const wait = (ms: number) => new Promise<void>((r) => setTimeout(() => r(), ms));
const timeout = <T,>(p: Promise<T>, ms: number) => Promise.race([p, wait(ms).then(() => { throw new Error('timed out'); })]);

/**
 * The 1.5.5 tap checks' driver: real touches cannot be made from JavaScript, so a driver makes them at window points
 * — on the Android emulator tools/android_taps_driver.py on the computer sending them through adb and choosing the chooser's rows with
 * uiautomator (http://10.0.2.2:8765), on the iOS simulator the example app's debug driver (http://localhost:8766, see
 * ios/SMapExample/AppDelegate.swift). `origin` is the map's top-left corner in the window. The map is created with
 * `tapTolerance` 20.
 */
export interface TapsDriver { url: string; origin: () => Promise<{ x: number; y: number }> }

export async function selfCheck(m: SMapHandle, url: string, taps?: TapsDriver): Promise<string> {
  const results: { name: string; ok: boolean; detail?: string }[] = [];
  const check = async (name: string, run: () => Promise<string | boolean | void>, ms = 15000) => {
    try {
      const r = await timeout(Promise.resolve().then(run), ms);
      results.push({ name, ok: r !== false, detail: typeof r === 'string' ? r : undefined });
    } catch (e) {
      results.push({ name, ok: false, detail: e instanceof Error ? e.message : String(e) });
    }
  };
  await check('getCamera', async () => { const c = await m.getCamera(); return `${c.center.map((v) => v.toFixed(3))} z${c.zoom.toFixed(1)} bounds ${!!c.bounds}`; });
  await check('jumpTo then getCenter', async () => {
    m.jumpTo({ center: [-79.38, 43.65], zoom: 13, bearing: 0, pitch: 0 });
    await wait(600);
    const c = await m.getCenter();
    if (Math.abs(c[0] + 79.38) > 1e-3 || Math.abs(c[1] - 43.65) > 1e-3) { throw new Error(String(c)); }
    return String(await m.getZoom());
  });
  await check('project / unproject', async () => {
    const p = await m.project([-79.38, 43.65]);
    if (!p) { throw new Error('no point'); }
    const back = await m.unproject(p);
    if (!back || Math.abs(back[0] + 79.38) > 1e-4 || Math.abs(back[1] - 43.65) > 1e-4) { throw new Error(String(back)); }
    return `${p.x.toFixed(1)},${p.y.toFixed(1)}`;
  });
  await check('fitBounds and moveend', async () => {
    const moved = m.once('moveend');
    m.fitBounds([-79.45, 43.62, -79.30, 43.70], { duration: 0, padding: 20 });
    await timeout(moved, 5000);
    const b = await m.getBounds();
    if (!b || b[0][0] > -79.44 || b[1][0] < -79.31) { throw new Error(JSON.stringify(b)); }
    return JSON.stringify(b.map((x) => x.map((v) => +v.toFixed(3))));
  });
  await check('map events: listen and off', async () => {
    let n = 0;
    const l = () => { n++; };
    m.on('move', l);
    const done = m.once('moveend');
    m.easeTo({ center: [-79.39, 43.655], zoom: 12, duration: 600 });
    await timeout(done, 8000);
    await wait(500);
    m.off('move', l);
    return n > 0 ? `${n} moves` : false;
  });
  await check('addImage base64 / hasImage', async () => { await m.addImage('check-img', { base64: PNG }); return await m.hasImage('check-img'); });
  await check('addGlyphImage', async () => { await m.addGlyphImage('check-glyph', { glyph: '★', background: '#0ea5e9' }); return await m.hasImage('check-glyph'); });
  await check('removeImage', async () => { await m.removeImage('check-img'); return !(await m.hasImage('check-img')); });
  await check('circles, feature states', async () => {
    m.addCircles('check-circles', [{ id: 'c1', radius: 400, lng: -79.39, lat: 43.655 }], { idProperty: 'id', fill: '#f59e0b', states: { hover: { opacity: 0.6 } } });
    await m.setFeatureState('check-circles', 'c1', { hover: true });
    const s = await m.featureState('check-circles', 'c1');
    await m.removeFeatureState('check-circles', 'c1', 'hover');
    const after = await m.featureState('check-circles', 'c1');
    return s.hover === true && after.hover === undefined ? JSON.stringify(s) : false;
  });
  await check('featuresAt over a circle', async () => {
    m.jumpTo({ center: [-79.39, 43.655], zoom: 14 });
    await wait(1500);
    const p = await m.project([-79.39, 43.655]);
    const hits = await m.featuresAt(p!, { layers: ['check-circles'] });
    return hits.length > 0 ? hits.map((h) => h.layer + ':' + h.feature.key).join(' ') : false;
  });
  await check('openFeaturePopup calls the tap handler', async () => {
    let tapped = false;
    m.onTap('check-circles', () => { tapped = true; });
    const r = await m.openFeaturePopup('check-circles', 'c1');
    await wait(300);
    return r && tapped ? true : `answer ${r}, tapped ${tapped}`;
  });
  await check('moveFeature / updateFeature', async () => {
    m.addPoints('check-move', [{ id: 'p', n: 1, lng: -79.39, lat: 43.655 }], { idProperty: 'id', color: '#111827' });
    await m.moveFeature('check-move', 'p', [-79.385, 43.657], { duration: 0 });
    await m.updateFeature('check-move', 'p', { n: 2 });
    await wait(300);
    const fc = await m.toGeoJSON('check-move');
    const f = fc.features[0];
    const c = f.geometry.coordinates as number[];
    return Math.abs(c[0] + 79.385) < 1e-6 && f.properties?.n === 2 ? true : JSON.stringify(f);
  });
  await check('openTooltip / closeTooltip', async () => {
    m.addPoints('check-tip', [{ id: 't', name: 'Tip', lng: -79.39, lat: 43.655 }], { idProperty: 'id', tooltip: '{name}' });
    await m.openTooltip('check-tip', 't');
    await m.closeTooltip();
  });
  await check('export (PNG data URL)', async () => { const d = await m.export(); return d.startsWith('data:image/png;base64,') && d.length > 2000 ? `${d.length} chars` : false; });
  await check('export JPEG to a file', async () => { const f = await m.exportFile({ format: 'jpeg', quality: 0.8 }); return f.startsWith('file://') ? f : false; });
  await check('drawing tool: setProperties, styles', async () => {
    const t = m.drawTool({ toolbar: 'none', measure: true, style: (p) => (p.kind === 'x' ? { color: '#dc2626' } : null),
      features: { type: 'FeatureCollection', features: [{ type: 'Feature', id: 'f1', properties: {}, geometry: { type: 'Polygon', coordinates: [[[-79.40, 43.65], [-79.39, 43.65], [-79.39, 43.66], [-79.40, 43.65]]] } }] } });
    await wait(200);
    await t.setProperties('f1', { kind: 'x' });
    const got = await t.selection();
    await t.undo();
    await t.destroy();
    return got === null;
  });
  // Without a map key that names this app the service answers 403: the map reports `forbidden` and shows its notice.
  await check('getUnavailable', async () => `reason ${m.getUnavailable()}`);
  await check('geo.area of a 1° square', async () => Math.abs(geo.area({ type: 'Polygon', coordinates: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]] }) - 12391399902.07) < 1);
  if (taps) { await tapChecks(m, taps, check); }
  const ok = results.filter((r) => r.ok).length;
  const summary = `${Platform.OS}: ${ok}/${results.length} checks passed`;
  try {
    await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ platform: Platform.OS, summary, results }) });
  } catch { /* the listener is optional */ }
  return summary;
}

// 1.5.5 on the device: a tap beside a point answers it and not its neighbour, two piled points open the native chooser
// and the chosen row reaches the JavaScript handler, overlap off answers the top point, and tapTolerance (20) arrived.
async function tapChecks(m: SMapHandle, driver: TapsDriver, check: (name: string, run: () => Promise<string | boolean | void>, ms?: number) => Promise<void>) {
  const drive = async (op: string, args: Record<string, unknown> = {}) => {
    const r = await fetch(driver.url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ op, ...args }) });
    return (await r.json()) as { ok: boolean; rows?: string[] };
  };
  const answers: string[] = [];
  // Far from the example's own layers.
  const C: [number, number] = [-78.5, 44.5];
  m.jumpTo({ center: C, zoom: 15, bearing: 0, pitch: 0 });
  await wait(1500);
  const mid = (await m.project(C))!;
  const origin = await driver.origin();
  const at = async (dx: number, dy: number, name: string) => {
    const p = (await m.unproject({ x: mid.x + dx, y: mid.y + dy }))!;
    return { name, lng: p[0], lat: p[1] };
  };
  const tap = async (dx: number, dy: number) => {
    const k = Platform.OS === 'android' ? PixelRatio.get() : 1;
    await drive('tap', { x: (origin.x + mid.x + dx) * k, y: (origin.y + mid.y + dy) * k });
  };
  // Until n answers came (the map answers a tap after the double-tap time), then a while longer.
  const answered = async (n: number) => {
    const end = Date.now() + 5000;
    while (answers.length < n && Date.now() < end) { await wait(100); }
    await wait(1200);
    const out = answers.join(' ');
    answers.length = 0;
    return out;
  };
  // Two circles 40 px apart (centres), radius 10 + stroke 1.5.
  m.addPoints('check-near', [await at(-40, -80, 'A'), await at(0, -80, 'B')], { radius: 10, color: '#2563eb' });
  m.onTap('check-near', (p) => { answers.push(`near:${p.name}`); });
  // Two circles on one spot, rows named by the JavaScript label.
  m.addPoints('check-pile', [await at(0, 0, 'First'), await at(0, 0, 'Second')], { color: '#16a34a', overlap: { label: (f: { properties: Record<string, unknown> }) => `Row ${f.properties.name}` } });
  m.onTap('check-pile', (p) => { answers.push(`pile:${p.name}:${'__smap_overlapLabel' in p}`); });
  // Two circles on one spot of a layer that does not pile: the top one (drawn last) answers.
  m.addPoints('check-off', [await at(0, 80, 'Low'), await at(0, 80, 'High')], { color: '#e11d48', overlap: false });
  m.onTap('check-off', (p) => { answers.push(`off:${p.name}`); });
  // One circle, radius 6 + stroke 1.5, for the tolerance.
  m.addPoints('check-tol', [await at(80, 0, 'P')], { radius: 6, color: '#111827' });
  m.onTap('check-tol', (p) => { answers.push(`tol:${p.name}`); });
  await wait(2000);

  await check('1.5.5 a tap beside a point answers it, not its neighbour', async () => {
    // 1.5 px beside A's edge, 15.5 beside B's (both within 20): A. Then the other way round: B.
    await tap(-40 + 13, -80);
    const a = await answered(1);
    await tap(-40 + 27, -80);
    const b = await answered(1);
    return a === 'near:A' && b === 'near:B' ? `${a}, ${b}` : `got "${a}", "${b}"`;
  }, 45000);
  await check('1.5.5 piled points: the native chooser, the chosen row answers', async () => {
    await tap(0, 0);
    const r = await drive('choose', { text: 'Row Second', also: 'Row First' });
    const a = await answered(1);
    return r.ok && a === 'pile:Second:false' ? `rows ${JSON.stringify(r.rows)}` : `chooser ${JSON.stringify(r)}, got "${a}"`;
  }, 45000);
  await check('1.5.5 piled points: dismissing the chooser answers nothing', async () => {
    await tap(0, 0);
    const r = await drive('dismiss', { text: 'Row First' });
    const a = await answered(0);
    return r.ok && a === '' ? true : `chooser ${JSON.stringify(r)}, got "${a}"`;
  }, 45000);
  await check('1.5.5 overlap off answers the top point without a chooser', async () => {
    await tap(0, 80);
    const a = await answered(1);
    const rows = (await drive('rows')).rows ?? [];
    const listed = rows.filter((t) => t === 'Low' || t === 'High' || t === '1' || t === '2');
    return a === 'off:High' && listed.length === 0 ? true : `got "${a}", rows ${JSON.stringify(listed)}`;
  }, 45000);
  await check('1.5.5 tapTolerance 20 reached the native map', async () => {
    // 15 px beside the edge: within 20, not within the default 6; 28 px: nothing.
    await tap(80 + 7.5 + 15, 0);
    const a = await answered(1);
    await tap(80 + 7.5 + 28, 0);
    const b = await answered(0);
    return a === 'tol:P' && b === '' ? true : `got "${a}", "${b}"`;
  }, 45000);
  for (const id of ['check-near', 'check-pile', 'check-off', 'check-tol']) { m.removeLayer(id); }
}
