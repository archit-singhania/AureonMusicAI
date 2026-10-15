/* Real gateway/worker/browser reference comparison in isolated acceptance storage. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium, request } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const output = path.resolve(__dirname, '../docs/screenshots/reference-2026-10-13');
fs.mkdirSync(output, { recursive: true });
const api='http://127.0.0.1:5084/api/v1';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
  const http=await request.newContext();
  const email=`reference-${Date.now()}@example.test`,password='Reference-Local-Fixture-2026!';
  const registration=await http.post(api+'/auth/register',{data:{email,password,name:'Reference QA · illustrative'}});
  assert.equal(registration.status(),201);const identity=await registration.json();
  const headers={Authorization:'Bearer '+identity.token};
  async function get(route){const r=await http.get(api+route,{headers});assert.equal(r.status(),200,await r.text());return r.json();}
  async function done(id){for(let i=0;i<300;i++){const j=await get('/jobs/'+id);if(['done','failed','cancelled'].includes(j.status)){assert.equal(j.status,'done',j.error);return j;}await wait(1000);}throw Error('Real audio job timed out');}
  const created=await http.post(api+'/projects',{headers,data:{title:'Reference QA · illustrative'}});assert.equal(created.status(),201);const project=await created.json();
  const generated=await http.post(api+`/projects/${project.id}/jobs`,{headers,data:{kind:'generate'}});assert.equal(generated.status(),202);
  const source=await done((await generated.json()).id), original=await get('/assets/'+source.master_asset_id);
  const originalResponse=await http.get('http://127.0.0.1:5084'+original.url);assert.equal(originalResponse.status(),200);const originalWav=await originalResponse.body();
  // An explicitly illustrative private reference derived from real generated audio.
  const upload=await http.post(api+'/assets?project_id='+project.id,{headers,multipart:{file:{name:'Private illustrative reference.wav',mimeType:'audio/wav',buffer:originalWav}}});assert.equal(upload.status(),201,await upload.text());const reference=await upload.json();
  const saved=await http.put(api+'/projects/'+project.id,{headers,data:{revision:project.revision,state:{...project,reference:{asset_id:reference.id,gain_db:0,width:1}}}});assert.equal(saved.status(),200,await saved.text());
  const browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:1100}});const page=await context.newPage();const errors=[],networkFailures=[];page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(new URL(r.url()).pathname==='/api/v1/auth/login'){const d=r.postDataJSON();console.log(JSON.stringify({typedEmailMatches:d.email===email,typedPasswordMatches:d.password===password}));}});
  page.on('requestfailed',r=>networkFailures.push({path:new URL(r.url()).pathname,error:r.failure()?.errorText}));
  page.on('console',m=>{if(m.text().startsWith('Studio request diagnostic:'))console.error(m.text());});
  async function press(name){const b=page.getByRole('button',{name,exact:true}).first();await b.waitFor({state:'visible',timeout:60000});await b.click({force:true});}
  async function login(){await page.goto('http://localhost:3006',{waitUntil:'networkidle'});const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(e=>e.click());await press('Sign in');const ef=page.getByRole('textbox',{name:'Email address',exact:true});await ef.click({force:true});await wait(350);await page.keyboard.type(email,{delay:20});await ef.press('Tab');const pf=page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true});await pf.click({force:true});await wait(350);await page.keyboard.type(password,{delay:20});await wait(250);await page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true}).press('Tab');const [signedIn]=await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/v1/auth/login'),page.getByRole('button',{name:'Sign in',exact:true}).last().click({force:true})]);assert.equal(signedIn.status(),200,'Real sign-in failed');await wait(1000);await press('Library');await press('Open');await page.getByRole('button',{name:'Compare reference',exact:true}).waitFor({state:'visible',timeout:60000});}
  try {
    await login();await press('Compare reference');
    let comparison;
    for(let i=0;i<100;i++){comparison=(await get('/jobs?project_id='+project.id)).find(j=>j.job_kind==='reference_analysis');if(comparison)break;await wait(1000);}assert.ok(comparison);comparison=await done(comparison.id);
    await page.getByRole('button',{name:'Review adjustment',exact:true}).waitFor({state:'visible',timeout:30000});
    await page.getByRole('button',{name:'Audition matched master',exact:true}).scrollIntoViewIfNeeded();
    await page.getByRole('button',{name:'Audition matched master',exact:true}).click({force:true});
    await page.getByRole('button',{name:'Pause audition',exact:true}).waitFor({state:'visible',timeout:15000});
    await page.getByRole('button',{name:'Audition matched reference',exact:true}).click({force:true});await wait(1000);await press('Pause audition');
    await press('Review adjustment');const gainInput=page.getByRole('textbox',{name:'Gain dB',exact:true});await gainInput.click({force:true});await wait(350);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.type('-3',{delay:40});await page.keyboard.press('Tab');await wait(250);await press('Confirm new render');
    let render;for(let i=0;i<100;i++){render=(await get('/jobs?project_id='+project.id)).find(j=>j.job_kind==='reference_render');if(render)break;await wait(1000);}assert.ok(render);render=await done(render.id);assert.equal(render.state.reference.gain_db,-3);assert.notEqual(render.master_asset_id,source.master_asset_id);
    for(const [index,aid] of [...comparison.audition_asset_ids,render.master_asset_id].entries()){const a=await get('/assets/'+aid);const r=await http.get('http://127.0.0.1:5084'+a.url);assert.equal(r.status(),200);fs.writeFileSync(path.join(output,`audio-${index}.wav`),await r.body());}
    await press('Studio');await page.getByRole('button',{name:'Compare reference',exact:true}).scrollIntoViewIfNeeded();await page.mouse.wheel(0,650);await wait(1000);await page.screenshot({path:path.join(output,'reference-desktop-light.png')});
    await page.setViewportSize({width:390,height:1100});await wait(700);await page.screenshot({path:path.join(output,'reference-phone-light.png')});
    await page.setViewportSize({width:1440,height:1100});await press('Settings');await press('Dark');await press('Studio');await page.getByRole('button',{name:'Compare reference',exact:true}).scrollIntoViewIfNeeded();await page.mouse.wheel(0,650);await wait(500);await page.screenshot({path:path.join(output,'reference-desktop-dark.png')});
    await page.reload({waitUntil:'networkidle'});await login();assert.equal((await get('/projects/'+project.id)).reference.gain_db,-3);assert.deepEqual(errors,[]);
    const receipt={checkedAtUtc:new Date().toISOString(),scope:'Real private reference comparison, actual matched A/B playback, confirmed new render, preserved original, persisted settings and responsive theme captures',comparisonJobId:comparison.id,renderJobId:render.id,originalAssetId:source.master_asset_id,newAssetId:render.master_asset_id,comparison:comparison.comparison,persisted:true,pageErrors:errors};
    fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt));
  }catch(error){await page.screenshot({path:path.join(output,'failure.png')});console.error(networkFailures);console.error(await page.getByRole('button').allTextContents());throw error;}
  finally{await browser.close();await http.dispose();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
