/* Production browser + actual gateway/worker acceptance in isolated storage. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const { chromium, request } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname, '..');
const output = process.env.AUREON_ACCEPTANCE_OUTPUT || path.join(root, '.runtime', 'arrangement-acceptance-'+Date.now());
fs.mkdirSync(output, { recursive: true });
const gateway = process.env.AUREON_GATEWAY_URL || 'http://127.0.0.1:5084';
const api = gateway+'/api/v1';
const web = process.env.AUREON_WEB_URL || 'http://localhost:3006';
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
  const wav=Buffer.alloc(44+44100*4*4);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length-8,4); wav.write('WAVEfmt ',8);
  wav.writeUInt32LE(16,16); wav.writeUInt16LE(1,20); wav.writeUInt16LE(2,22);
  wav.writeUInt32LE(44100,24); wav.writeUInt32LE(176400,28); wav.writeUInt16LE(4,32);
  wav.writeUInt16LE(16,34); wav.write('data',36); wav.writeUInt32LE(wav.length-44,40);
  for(let frame=0;frame<44100*4;frame++){
    const sample=Math.round(Math.sin(frame*2*Math.PI*440/44100)*5000);
    wav.writeInt16LE(sample,44+frame*4);
    wav.writeInt16LE(sample,46+frame*4);
  }
  const imported=await http.post(api+'/assets?project_id='+project.id,{headers,multipart:{
    file:{name:'Imported fixture.wav',mimeType:'audio/wav',buffer:wav},
  }});
  assert.equal(imported.status(),201,await imported.text());
  const importedBeat=await imported.json();
  const configured=await http.put(api+'/projects/'+project.id,{headers,data:{
    revision:project.revision,state:{...project,beat_asset_id:importedBeat.id,
      release_kit:{artist:'Arrangement fixture',credits:'Locally synthesized source audio',teaser_seconds:1}},
  }});
  assert.equal(configured.status(),200,await configured.text());
  const queued=await http.post(api+`/projects/${project.id}/jobs`,{headers,data:{kind:'generate'}});assert.equal(queued.status(),202);
  async function done(jid) { const deadline=Date.now()+90000;while(Date.now()<deadline) { const j=await get('/jobs/'+jid); if(['done','failed','cancelled'].includes(j.status)) {assert.equal(j.status,'done',j.error);return j;}await timeout(300); }throw new Error('Actual worker job timed out'); }
  const generated=await done((await queued.json()).id);
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const context=await browser.newContext({viewport:{width:1440,height:1100}});
  await context.addInitScript(()=>{
    const source=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src');
    Object.defineProperty(HTMLMediaElement.prototype,'src',{
      ...source,
      set(value){
        if(this instanceof HTMLAudioElement){
          (window.acceptanceAudioPlayers ||= new Set()).add(this);
          (window.acceptanceSourcePaths ||= []).push(new URL(value,location.href).pathname);
        }
        return source.set.call(this,value);
      },
    });
    const play=HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play=function(){
      if(this instanceof HTMLAudioElement) {
        window.acceptanceAudio=this;
        (window.acceptanceAudioPlayers ||= new Set()).add(this);
        window.acceptancePlayCount=(window.acceptancePlayCount||0)+1;
      }
      return play.call(this);
    };
  });
  let page=await context.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  async function press(name){
    const button=page.getByRole('button',{name,exact:true}).first();
    await button.waitFor({state:'visible',timeout:60000});
    for(let i=0;i<50&&!await button.isEnabled();i++) await timeout(200);
    assert.ok(await button.isEnabled(),name+' remained disabled');
    await button.evaluate(element=>element.click());
  }
  async function submitFeedback(action) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const feedback = page.waitForResponse(response =>
        response.url().endsWith('/feedback') && response.request().method() === 'POST');
      await press(action);
      if (action === 'revoke') await press('Confirm');
      const response = await feedback;
      if (response.status() === 429 && attempt === 0) {
        const seconds = Number(response.headers()['retry-after'] || 60);
        await timeout(Math.max(1, Math.min(60, seconds)) * 1000 + 250);
        continue;
      }
      assert.equal(response.status(), 200, await response.text());
      return response.json();
    }
  }
  async function login(address=email, openProject=true, retry=true) {
    await page.bringToFront();
    await page.goto(web,{waitUntil:'networkidle',timeout:60000});
    const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count()) await placeholder.evaluate(e=>e.click());
    await press('Sign in');
    const emailField=page.getByRole('textbox',{name:'Email address',exact:true});
    await emailField.click();
    await page.keyboard.insertText(address);
    const passwordField=page.getByRole('textbox',{name:'Password · at least 10 characters',exact:true});
    await passwordField.click();
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.insertText(password);
    assert.equal((await passwordField.inputValue()).length,password.length);
    await passwordField.press('Tab');
    const signedIn=page.waitForResponse(response=>response.url().endsWith('/auth/login') && response.request().method()==='POST');
    await page.getByRole('button',{name:'Sign in',exact:true}).last().evaluate(e=>e.click());
    const loginResponse=await signedIn;
    if(loginResponse.status()===429 && retry){
      const seconds=Number(loginResponse.headers()['retry-after']||60);
      await timeout(Math.max(1,Math.min(60,seconds))*1000+250);
      return login(address,openProject,false);
    }
    if(loginResponse.status()!==200){
      const result=await loginResponse.json().catch(()=>({}));
      const fields=Array.isArray(result.detail)?result.detail.map(issue=>issue.loc.join('.')+': '+issue.type):[];
      const submitted=loginResponse.request().postDataJSON();
      const inputs={emailMatches:submitted?.email===address,passwordMatches:submitted?.password===password};
      throw new Error('Fixture sign-in rejected ('+loginResponse.status()+') '+fields.join(', ')+' '+JSON.stringify(inputs));
    }
    await timeout(1200); await press('Library');
    if(openProject){
      await press('Open');
      await page.getByRole('button',{name:'Render arrangement',exact:true}).waitFor({state:'visible',timeout:60000});
    }
  }
  try {
    await login();
    let saved=await get('/projects/'+project.id);assert.ok(saved.arrangement);
    await page.getByRole('button',{name:/^Accessible track and clip list/}).evaluate(e=>e.click());
    await page.getByRole('button',{name:/^Clip /}).first().evaluate(e=>e.click());
    await press('Add volume point');
    for(const [label,value] of [['Sample','0'],['Value','0.5']]){
      const field=page.getByRole('textbox',{name:label,exact:true});
      await field.click();
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.insertText(value);
      assert.equal(await field.inputValue(),value);
      await field.press('Tab');
    }
    await press('Apply edit');
    for(let i=0;i<60;i++) {
      saved=await get('/projects/'+project.id);
      if(saved.arrangement.tracks[0].automation[0]?.points[0]?.value===.5) break;
      await timeout(250);
    }
    assert.equal(saved.arrangement.tracks[0].automation[0].points[0].value,.5);
    await press('Render arrangement');
    let render;for(let i=0;i<40;i++) {render=(await get('/jobs?project_id='+project.id)).find(j=>j.job_kind==='arrangement_render');if(render)break;await timeout(250);}assert.ok(render);
    render=await done(render.id);const master=await get('/assets/'+render.master_asset_id);
    const media=await http.get(gateway+master.url);assert.equal(media.status(),200);
    const wav=await media.body();assert.equal(wav.subarray(0,4).toString(),'RIFF');fs.writeFileSync(path.join(output,'rendered-arrangement.wav'),wav);
    await press('Studio');await timeout(1200);
    await page.getByRole('button',{name:'Play rendered preview',exact:true}).click({force:true});
    await page.getByRole('button',{name:'Pause rendered preview',exact:true}).waitFor({state:'visible',timeout:15000});
    await timeout(1300);
    const moving=page.getByRole('button',{name:/^Cursor [1-9]\d* samples$/});
    await moving.waitFor({state:'visible',timeout:15000});
    await press('Pause rendered preview');
    await page.getByRole('button',{name:'Play rendered preview',exact:true}).waitFor();
    await moving.waitFor({state:'visible',timeout:15000});
    const versions=api+`/projects/${project.id}/mix-versions`;
    for(const [job,name] of [[generated,'Generated source'],[render,'Edited arrangement']]){
      const savedMix=await http.post(versions,{headers,data:{job_id:job.id,name}});
      assert.equal(savedMix.status(),201,await savedMix.text());
    }
    await press('Load saved mix versions');
    const comparisonResponse=page.waitForResponse(response=>
      response.url().endsWith('/mix-versions/compare') && response.request().method()==='POST');
    await press('Compare selected versions');
    const comparisonResult=await comparisonResponse;
    assert.equal(comparisonResult.status(),200,await comparisonResult.text());
    const comparisonAudio=(await comparisonResult.json()).audio;
    const compare=await get(`/projects/${project.id}/mix-versions`);
    assert.equal(compare.length,2);
    await page.getByRole('button',{name:'Play original A',exact:true}).waitFor({state:'visible'});
    await page.getByRole('button',{name:'Play original B',exact:true}).waitFor({state:'visible'});
    const auditioned=[], sources=[];
    await page.setViewportSize({width:1440,height:4200});
    for(const [index,mix] of ['A','B'].entries()){
      const before=await page.evaluate(()=>window.acceptancePlayCount||0);
      const expected=new URL(comparisonAudio[index].url,gateway).pathname;
      const button=page.getByRole('button',{name:'Play original '+mix,exact:true});
      for(let pass=0;pass<50&&!await button.isEnabled();pass++) await timeout(200);
      assert.ok(await button.isEnabled(),'Mix '+mix+' remained disabled');
      const requested=[];
      const observe=response=>{
        if(new URL(response.url()).pathname===expected) requested.push(response.status());
      };
      page.on('response',observe);
      await button.click({force:true});
      await page.waitForFunction(({previous,expectedPath})=>{
        return window.acceptancePlayCount>previous && [...(window.acceptanceAudioPlayers||[])].some(audio=>
          audio.currentSrc && new URL(audio.currentSrc).pathname===expectedPath &&
          !audio.paused && audio.currentTime>0.15);
      },{previous:before,expectedPath:expected},{timeout:15000}).catch(async error=>{
        const actual=await page.evaluate(()=>{
          const media=window.acceptanceAudio;
          return media?.currentSrc?{path:new URL(media.currentSrc).pathname,time:media.currentTime,paused:media.paused}:null;
        });
        const assigned=await page.evaluate(()=>window.acceptanceSourcePaths||[]);
        throw new Error('Mix '+mix+' expected '+expected+', observed '+JSON.stringify(actual)+', assignments '+JSON.stringify(assigned)+', media HTTP '+JSON.stringify(requested),{cause:error});
      }).finally(()=>page.off('response',observe));
      sources.push(expected);
      auditioned.push(mix);
    }
    assert.deepEqual(auditioned,['A','B']);
    assert.notEqual(sources[0],sources[1]);
    await press('Play or pause preview');
    await page.setViewportSize({width:1440,height:1100});
    assert.equal(comparisonAudio.length,2);
    const sourceHashes=[];
    for(const mix of comparisonAudio){
      const media=await http.get(new URL(mix.url,gateway).href);
      assert.equal(media.status(),200);
      const pcm=await media.body();
      assert.equal(pcm.subarray(0,4).toString(),'RIFF');
      sourceHashes.push(createHash('sha256').update(pcm).digest('hex'));
    }
    assert.notEqual(sourceHashes[0],sourceHashes[1]);
    await page.screenshot({path:path.join(output,'mix-listening-room.png')});
    await press('Review release kit');
    await press('Confirm and build kit');
    let kit;
    for(let i=0;i<50;i++){
      kit=(await get('/jobs?project_id='+project.id)).find(job=>job.job_kind==='release_kit');
      if(kit) break;
      await timeout(350);
    }
    assert.ok(kit);
    kit=await done(kit.id);
    async function downloadRelease() {
      const button=page.getByRole('button',{name:'Download release ZIP',exact:true});
      for(let attempt=0;attempt<2;attempt++){
        await button.waitFor({state:'visible'});
        for(let i=0;i<50&&!await button.isEnabled();i++) await timeout(200);
        assert.ok(await button.isEnabled(),'Release download control is disabled');
        const assetResponse=page.waitForResponse(response=>response.url().endsWith('/assets/'+kit.bundle_asset_id));
        const download=page.waitForEvent('download',{timeout:20000}).catch(()=>null);
        await button.evaluate(element=>element.click());
        const asset=await assetResponse;
        if(asset.status()===429&&attempt===0){
          await download;
          const seconds=Number(asset.headers()['retry-after']||60);
          await timeout(Math.max(1,Math.min(60,seconds))*1000+250);
          continue;
        }
        assert.ok(asset.ok(),await asset.text());
        const file=await download;
        assert.ok(file,'Browser did not download the ready release kit');
        await file.saveAs(path.join(output,'release-kit.zip'));
        return;
      }
    }
    await downloadRelease();
    const exportReceipt={
      checkedAtUtc:new Date().toISOString(),projectId:project.id,importedAssetId:importedBeat.id,
      renderJobId:render.id,releaseJobId:kit.id,comparisonVersions:compare.length,auditioned,sourceHashes,
      renderedMasterSha256:createHash('sha256').update(wav).digest('hex'),
    };
    fs.writeFileSync(path.join(output,'integrated-export.json'),JSON.stringify(exportReceipt,null,2));
    if(process.env.AUREON_EXPORT_ONLY==='1'){
      assert.deepEqual(errors,[]);
      console.log(JSON.stringify(exportReceipt));
      return;
    }
    await page.screenshot({path:path.join(output,'timeline-desktop-light.png')});
    await page.setViewportSize({width:390,height:1100});await timeout(600);await page.screenshot({path:path.join(output,'timeline-phone-light.png')});
    await page.setViewportSize({width:1440,height:1100});await press('Settings');await press('Dark');await press('Studio');await timeout(600);await page.screenshot({path:path.join(output,'timeline-desktop-dark.png')});
    await page.setViewportSize({width:390,height:1100});await timeout(600);await page.screenshot({path:path.join(output,'timeline-phone-dark.png')});
    await page.setViewportSize({width:1440,height:1100});
    await page.reload({waitUntil:'networkidle'});await login();
    const reopened=await get('/projects/'+project.id);assert.deepEqual(reopened.arrangement,saved.arrangement);
    const reviewerEmail='reviewer-'+email;
    const reviewer=await http.post(api+'/auth/register',{data:{email:reviewerEmail,password,name:'Independent reviewer'}});
    assert.equal(reviewer.status(),201,await reviewer.text());
    await press('Load saved mix versions');
    const invitation=page.getByRole('textbox',{name:'Reviewer account email for version A'});
    await invitation.fill(reviewerEmail);
    await invitation.press('Tab');
    await press('Share version A for review');
    await page.getByText(/Independent reviewer can review/).waitFor({state:'visible'});
    const ownerPage=page;
    const reviewContext=await browser.newContext({viewport:{width:1440,height:1100}});
    page=await reviewContext.newPage();
    page.on('pageerror',error=>errors.push(error.message));
    await login(reviewerEmail,false);
    await press('Load review inbox');
    const review=page.locator('[aria-label*=" · Independent reviewer"]').first();
    await review.waitFor({state:'visible'});
    await review.evaluate(element=>element.click());
    const audition=page.waitForResponse(response=>/\/mix-reviews\/[^/]+\/audition$/.test(response.url()) && response.status()===200);
    await press('Audition shared version');
    const link=await (await audition).json();
    const mediaResponse=await http.get(new URL(link.url,gateway).href);
    assert.equal(mediaResponse.status(),200);
    assert.equal((await mediaResponse.body()).subarray(0,4).toString(),'RIFF');
    assert.equal((await submitFeedback('approve')).decision,'approved');
    await page.screenshot({path:path.join(output,'independent-review.png')});
    const reviewerPage=page;
    page=ownerPage;
    await page.bringToFront();
    await press('Library');
    await press('Load review inbox');
    const ownerReview=page.locator('[aria-label*=" · Independent reviewer"]').first();
    await ownerReview.waitFor({state:'visible'});
    await ownerReview.evaluate(element=>element.click());
    assert.equal((await submitFeedback('revoke')).revoked,true);
    const revokedMedia=await http.get(new URL(link.url,gateway).href);
    assert.equal(revokedMedia.status(),404);
    page=reviewerPage;
    await page.bringToFront();
    await press('Load review inbox');
    await review.waitFor({state:'hidden'});
    await reviewContext.close();
    assert.deepEqual(errors,[]);
    const receipt={checkedAtUtc:new Date().toISOString(),scope:'Actual gateway, audio worker and browser arrangement, comparison and independent review lifecycle',projectId:project.id,jobId:render.id,sampleCount:master.metrics.sample_count,sampleRate:master.metrics.sample_rate,pageErrors:errors,persistedArrangement:true,realAudio:true,independentReviewerAccess:true,reviewApproved:true,reviewRevoked:true,revokedAuditionStatus:revokedMedia.status()};
    fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt));
  } catch(e) {
    await page.screenshot({path:path.join(output,'acceptance-failure.png')});
    console.error((await page.getByRole('button').allTextContents()).slice(0,40));throw e;
  } finally {await browser.close();await http.dispose();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
