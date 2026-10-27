/* Requires an isolated gateway on 5094 and a freshly built Flutter web app on 3094. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { chromium, request } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const output = path.resolve(process.env.AUREON_ACCEPTANCE_OUTPUT || '.tools/mastering-browser');
const api = 'http://127.0.0.1:5094/api/v1';
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  fs.mkdirSync(output, { recursive: true });
  const http = await request.newContext();
  let browser;
  try {
    const email = `mastering-${Date.now()}@example.test`, password = 'Mastering-Fixture-2026!';
    const registration = await http.post(api + '/auth/register', { data: { email, password, name: 'Mastering QA fixture' } });
    assert.equal(registration.status(), 201, await registration.text());
    const headers = { Authorization: 'Bearer ' + (await registration.json()).token };
    async function get(route) { const r = await http.get(api + route, { headers }); assert.equal(r.status(), 200, await r.text()); return r.json(); }
    async function done(id) { for (let i = 0; i < 300; i++) { const j = await get('/jobs/' + id); if (['done', 'failed', 'cancelled'].includes(j.status)) { assert.equal(j.status, 'done', j.error); return j; } await wait(1000); } throw Error('Job timed out'); }
    const created = await http.post(api + '/projects', { headers, data: { title: 'Mastering QA fixture' } });
    assert.equal(created.status(), 201); const project = await created.json();
    const generated = await http.post(api + `/projects/${project.id}/jobs`, { headers, data: { kind: 'generate' } });
    assert.equal(generated.status(), 202); const source = await done((await generated.json()).id);
    async function sourceHash() {
      const asset = await get('/assets/' + source.master_asset_id);
      const response = await http.get('http://127.0.0.1:5094' + asset.url);
      assert.equal(response.status(), 200);
      return createHash('sha256').update(await response.body()).digest('hex');
    }
    const originalHash = await sourceHash();
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 }, acceptDownloads: true });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    async function press(name) { const b = page.getByRole('button', { name, exact: true }).first(); await b.waitFor({ state: 'visible', timeout: 60000 }); await b.evaluate(e => e.click()); }
    await page.goto('http://localhost:3094', { waitUntil: 'networkidle' });
    const placeholder = page.locator('flt-semantics-placeholder'); if (await placeholder.count()) await placeholder.evaluate(e => e.click());
    await press('Sign in');
    for (const [label, value] of [['Email address', email], ['Password · at least 10 characters', password]]) {
      const field = page.getByRole('textbox', { name: label, exact: true });
      await field.click({ force: true }); await wait(300); await page.keyboard.type(value, { delay: 20 }); await field.press('Tab');
    }
    const [login] = await Promise.all([page.waitForResponse(r => new URL(r.url()).pathname === '/api/v1/auth/login'), page.getByRole('button', { name: 'Sign in', exact: true }).last().evaluate(e => e.click())]);
    assert.equal(login.status(), 200); await press('Library'); await press('Open');
    await press('Analyze saved master');
    let job;
    for (let i = 0; i < 90; i++) { job = (await get('/jobs?project_id=' + project.id)).find(j => j.job_kind === 'mastering_analysis'); if (job) break; await wait(1000); }
    assert.ok(job, 'UI must queue an actual analysis'); job = await done(job.id);
    assert.equal(job.source_master_asset_id, source.master_asset_id);
    const downloadButton = page.getByRole('button', { name: 'Download measured report', exact: true });
    await downloadButton.waitFor({ state: 'visible', timeout: 60000 });
    const [download] = await Promise.all([page.waitForEvent('download'), downloadButton.evaluate(e => e.click())]);
    const reportPath = path.join(output, 'mastering-report.json'); await download.saveAs(reportPath);
    assert.deepEqual(JSON.parse(fs.readFileSync(reportPath, 'utf8')), job.quality_report);
    await downloadButton.scrollIntoViewIfNeeded(); await page.screenshot({ path: path.join(output, 'desktop-light.png') });
    await page.setViewportSize({ width: 390, height: 1100 }); await wait(700); await downloadButton.scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(output, 'phone-light.png') });
    await page.setViewportSize({ width: 1440, height: 1100 }); await press('Settings'); await press('Dark'); await press('Studio');
    await downloadButton.scrollIntoViewIfNeeded(); await page.screenshot({ path: path.join(output, 'desktop-dark.png') });
    assert.deepEqual(errors, []);
    const receipt = { checked_at: new Date().toISOString(), job_id: job.id, source_unchanged: await sourceHash() === originalHash, source_sha256: originalHash, downloaded_report_matches: true, page_errors: errors };
    assert.equal(receipt.source_unchanged, true);
    fs.writeFileSync(path.join(output, 'acceptance.json'), JSON.stringify(receipt, null, 2)); console.log(JSON.stringify(receipt));
  } finally { if (browser) await browser.close(); await http.dispose(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
