/* Real gateway/worker/browser reference comparison in isolated acceptance storage. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { chromium, request } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const output = path.resolve(__dirname, '../docs/screenshots/production-2026-10-15');
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
  const wav=Buffer.alloc(44+44100*3*4);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(2,22);wav.writeUInt32LE(44100,24);wav.writeUInt32LE(176400,28);wav.writeUInt16LE(4,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(wav.length-44,40);for(let n=0;n<44100*3;n++){const v=Math.round(Math.sin(n*2*Math.PI*440/44100)*3000);wav.writeInt16LE(v,44+n*4);wav.writeInt16LE(v,46+n*4);}
  const upload=await http.post(api+'/assets?project_id='+project.id,{headers,multipart:{file:{name:'Illustrative take.wav',mimeType:'audio/wav',buffer:wav}}});assert.equal(upload.status(),201,await upload.text());const take=await upload.json();
  const state={...project,take_groups:[{id:'bank',name:'Illustrative performance',asset_ids:[take.id],phrases:[{id:'phrase',asset_id:take.id,start:0,source_start:22050,length:88200,fade_in:100,fade_out:100}]}],lyrics:'Original illustrative lyric\nRecorded locally',release_kit:{artist:'Illustrative QA',credits:'Original locally generated test recording',teaser_start:0,teaser_seconds:1}};
  const saved=await http.put(api+'/projects/'+project.id,{headers,data:{revision:project.revision,state}});assert.equal(saved.status(),200,await saved.text());
  const browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:1100}});const page=await context.newPage();const errors=[],networkFailures=[];page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(new URL(r.url()).pathname==='/api/v1/auth/login'){const d=r.postDataJSON();console.log(JSON.stringify({typedEmailMatches:d.email===email,typedPasswordMatches:d.password===password}));}});
  page.on('requestfailed',r=>networkFailures.push({path:new URL(r.url()).pathname,error:r.failure()?.errorText}));
  page.on('console',m=>{if(m.text().startsWith('Studio request diagnostic:'))console.error(m.text());});
  async function press(name){const b=page.getByRole('button',{name,exact:true}).first();await b.waitFor({state:'visible',timeout:60000});for(let i=0;i<60 && !(await b.isEnabled());i++)await wait(1000);assert.ok(await b.isEnabled(),'Disabled '+name);await b.evaluate(e=>e.click());}
  async function login(){await page.goto('http://localhost:3006',{waitUntil:'networkidle'});const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(e=>e.click());await press('Sign in');const ef=page.getByRole('textbox',{name:'Email address',exact:true});await ef.click({force:true});await wait(350);await page.keyboard.type(email,{delay:20});await ef.press('Tab');const pf=page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true});await pf.click({force:true});await wait(350);await page.keyboard.type(password,{delay:20});await wait(250);await page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true}).press('Tab');const [signedIn]=await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/api/v1/auth/login'),page.getByRole('button',{name:'Sign in',exact:true}).last().click({force:true})]);assert.equal(signedIn.status(),200,'Real sign-in failed');await wait(1000);await press('Library');await press('Open');await page.getByRole('button',{name:'Render composite',exact:true}).waitFor({state:'visible',timeout:60000});}
  try {
    await login();await press('Render composite');
    async function latest(kind){for(let i=0;i<120;i++){const j=(await get('/jobs?project_id='+project.id)).find(j=>j.job_kind===kind);if(j)return done(j.id);await wait(1000);}throw Error('Missing '+kind);}
    const comp=await latest('comp_render');assert.ok(comp.master_asset_id);
    await press('Edit release identity');const artist=page.getByRole('textbox',{name:'Artist',exact:true});await artist.click({force:true});await wait(350);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.type('Production browser QA',{delay:25});await page.keyboard.press('Tab');await press('Save edit');
    await press('Review release kit');await page.getByText('Confirm release credits and rights',{exact:true}).waitFor();await press('Confirm and build kit');const kit=await latest('release_kit');
    await page.getByRole('button',{name:'Download release ZIP',exact:true}).waitFor({timeout:60000});
    const download=page.waitForEvent('download');await press('Download release ZIP');await (await download).saveAs(path.join(output,'release-kit.zip'));
    await press('Preview square-teaser.mp4');await press('Play video');await page.getByRole('button',{name:'Pause video',exact:true}).waitFor({timeout:15000});await press('Pause video');await page.screenshot({path:path.join(output,'video-preview.png')});await press('Close preview');
    await page.mouse.move(1000,500);await page.mouse.wheel(0,850);await wait(500);await page.screenshot({path:path.join(output,'production-desktop.png')});
    await page.setViewportSize({width:390,height:1100});await page.mouse.move(200,650);await page.mouse.wheel(0,650);await wait(650);await page.screenshot({path:path.join(output,'production-phone.png')});await page.setViewportSize({width:1440,height:1100});await press('Settings');await press('Dark');await press('Studio');await press('Preview portrait-teaser.mp4');await press('Close preview');await wait(650);await page.mouse.move(1000,500);await page.mouse.wheel(0,850);await wait(650);await page.screenshot({path:path.join(output,'production-desktop-dark.png')});
    await page.reload({waitUntil:'networkidle'});await login();const reloaded=await get('/projects/'+project.id);assert.equal(reloaded.release_kit.artist,'Production browser QA');assert.equal(reloaded.take_groups[0].phrases[0].source_start,22050);assert.deepEqual(errors,[]);
    const receipt={checkedAtUtc:new Date().toISOString(),compJob:comp.id,kitJob:kit.id,persisted:true,actualBrowserVideoPlayback:true,zipDownloaded:true,pageErrors:errors};fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt));
  }catch(error){await page.screenshot({path:path.join(output,'failure.png')});console.error(networkFailures);console.error(await page.getByRole('button').allTextContents());throw error;}finally{await browser.close();await http.dispose();}
})().catch(e=>{console.error(e);process.exitCode=1;});
