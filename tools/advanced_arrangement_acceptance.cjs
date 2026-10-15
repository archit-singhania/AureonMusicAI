/* Production browser + actual gateway/worker acceptance in isolated storage. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium, request } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'docs/screenshots/advanced-arrangement-2026-10-13');
fs.mkdirSync(output, { recursive: true });
const api = 'http://127.0.0.1:5084/api/v1';
const web = 'http://localhost:3006';
const password = 'Advanced-Local-Fixture-2026!';
const email = `advanced-${Date.now()}@example.test`;
const timeout = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  const http = await request.newContext();
  const registered = await http.post(api+'/auth/register', {data:{email,password,name:'Advanced QA · illustrative'}});
  assert.equal(registered.status(),201);
  const identity = await registered.json();
  const headers = {Authorization:'Bearer '+identity.token};
  async function get(route) { const r=await http.get(api+route,{headers});assert.equal(r.status(),200,await r.text());return r.json(); }
  const created = await http.post(api+'/projects',{headers,data:{title:'Arrangement QA · illustrative'}});
  assert.equal(created.status(),201); const project=await created.json();
  const queued=await http.post(api+`/projects/${project.id}/jobs`,{headers,data:{kind:'generate'}});assert.equal(queued.status(),202);
  async function done(jid) { const deadline=Date.now()+90000;while(Date.now()<deadline) { const j=await get('/jobs/'+jid); if(['done','failed','cancelled'].includes(j.status)) {assert.equal(j.status,'done',j.error);return j;}await timeout(300); }throw new Error('Actual worker job timed out'); }
  await done((await queued.json()).id);
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:1440,height:1100}});
  const page=await context.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  const press=async name => {const button=page.getByRole('button',{name,exact:true});await button.first().waitFor({state:'visible',timeout:60000});await button.first().evaluate(e=>e.click());};
  async function login() {
    await page.goto(web,{waitUntil:'networkidle',timeout:60000});
    const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count()) await placeholder.evaluate(e=>e.click());
    await press('Sign in');
    await page.getByRole('textbox',{name:'Email address',exact:true}).fill(email);
    await page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true}).fill(password);
    await page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true}).press('Tab');
    await page.getByRole('button',{name:'Sign in',exact:true}).last().evaluate(e=>e.click());
    await timeout(1200); await press('Library'); await press('Open');
    await page.getByRole('button',{name:'Render arrangement',exact:true}).waitFor({state:'visible',timeout:60000});
  }
  try {
    await login();
    let saved=await get('/projects/'+project.id);assert.ok(saved.arrangement);
    await page.getByRole('button',{name:/^Accessible track and clip list/}).evaluate(e=>e.click());
    await page.getByRole('button',{name:/^Clip /}).first().evaluate(e=>e.click());
    await press('Add volume point');
    await page.getByRole('textbox',{name:'Sample',exact:true}).fill('0');
    await page.getByRole('textbox',{name:'Value',exact:true}).fill('0.5');
    await page.getByRole('textbox',{name:'Value',exact:true}).press('Tab');await press('Apply edit');
    for(let i=0;i<60;i++) {
      saved=await get('/projects/'+project.id);
      if(saved.arrangement.tracks[0].automation[0]?.points[0]?.value===.5) break;
      await timeout(250);
    }
    assert.equal(saved.arrangement.tracks[0].automation[0].points[0].value,.5);
    await press('Render arrangement');
    let render;for(let i=0;i<40;i++) {render=(await get('/jobs?project_id='+project.id)).find(j=>j.job_kind==='arrangement_render');if(render)break;await timeout(250);}assert.ok(render);
    render=await done(render.id);const master=await get('/assets/'+render.master_asset_id);
    const media=await http.get('http://127.0.0.1:5084'+master.url);assert.equal(media.status(),200);
    const wav=await media.body();assert.equal(wav.subarray(0,4).toString(),'RIFF');fs.writeFileSync(path.join(output,'rendered-arrangement.wav'),wav);
    await press('Studio');await timeout(1200);
    await page.getByRole('button',{name:'Play rendered preview',exact:true}).click({force:true});
    await page.getByRole('button',{name:'Pause rendered preview',exact:true}).waitFor({state:'visible',timeout:15000});
    await timeout(1300);
    const moving=page.getByRole('button',{name:/^Cursor [1-9]\d* samples$/});
    await moving.waitFor({state:'visible',timeout:15000});
    await page.getByRole('button',{name:'Pause rendered preview',exact:true}).click({force:true});await timeout(400);
    await moving.waitFor({state:'visible',timeout:15000});
    await page.screenshot({path:path.join(output,'timeline-desktop-light.png')});
    await page.setViewportSize({width:390,height:1100});await timeout(600);await page.screenshot({path:path.join(output,'timeline-phone-light.png')});
    await page.setViewportSize({width:1440,height:1100});await press('Settings');await press('Dark');await press('Studio');await timeout(600);await page.screenshot({path:path.join(output,'timeline-desktop-dark.png')});
    await page.setViewportSize({width:390,height:1100});await timeout(600);await page.screenshot({path:path.join(output,'timeline-phone-dark.png')});
    await page.setViewportSize({width:1440,height:1100});
    await page.reload({waitUntil:'networkidle'});await login();
    const reopened=await get('/projects/'+project.id);assert.deepEqual(reopened.arrangement,saved.arrangement);
    assert.deepEqual(errors,[]);
    const receipt={checkedAtUtc:new Date().toISOString(),scope:'Actual named-account gateway/worker/browser timeline and curve workflow, reload and light/dark/phone captures',projectId:project.id,jobId:render.id,sampleCount:master.metrics.sample_count,sampleRate:master.metrics.sample_rate,pageErrors:errors,persistedArrangement:true,realAudio:true};
    fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt));
  } catch(e) {
    await page.screenshot({path:path.join(output,'acceptance-failure.png')});
    console.error((await page.getByRole('button').allTextContents()).slice(0,40));throw e;
  } finally {await browser.close();await http.dispose();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
