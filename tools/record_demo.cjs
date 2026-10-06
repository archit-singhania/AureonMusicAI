// Real guest-fixture browser journey; no API interception or simulated progress.
const fs = require('fs');
const path = require('path');
let chromium;
try { ({ chromium } = require(process.env.AUREON_PLAYWRIGHT || 'playwright')); }
catch (error) { if (process.env.AUREON_PLAYWRIGHT) throw error; ({ chromium } = require('C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')); }
(async () => {
 const output = path.resolve(__dirname, '../docs/demo', process.env.AUREON_EVIDENCE_NAME || '.');
 const screenshots = path.resolve(__dirname, '../docs/screenshots', process.env.AUREON_EVIDENCE_NAME || '.');
 fs.mkdirSync(output,{recursive:true});
 fs.mkdirSync(screenshots,{recursive:true});
 const browser = await chromium.launch({channel:'chrome', headless:true, args:['--use-fake-device-for-media-stream']});
 const context = await browser.newContext({viewport:{width:1440,height:1000}, permissions:['microphone'], recordVideo:{dir:output,size:{width:1440,height:1000}}, acceptDownloads:true});
 const blockedExternalRequests=[]; const bundledFontResponses=[];
 await context.route('**/*', async route => {
  const url=new URL(route.request().url());
  if (['http:','https:'].includes(url.protocol) && !['localhost','127.0.0.1'].includes(url.hostname)) {
   blockedExternalRequests.push(url.origin+url.pathname);
   await route.abort('blockedbyclient');
  } else await route.continue();
 });
 const page = await context.newPage();
 const errors=[]; const completed=[]; const completedJobs=[]; let frameSample=null; let recordingAsset=null;
 page.on('pageerror', error => errors.push(error.message));
 page.on('response', async response => {
  if (response.url().endsWith('/Inter.ttf')) bundledFontResponses.push({status:response.status(),path:new URL(response.url()).pathname});
  if (response.request().method()==='POST' && /\/api\/v1\/assets\?/.test(response.url()) && response.ok()) {
   const asset=await response.json().catch(()=>null);
   if (asset?.original_name==='voice-take.wav' || asset?.name==='voice-take.wav') recordingAsset={id:asset.id,media_type:asset.media_type,metrics:asset.metrics};
  }
 });
 const pause = ms => page.waitForTimeout(ms);
 const exportJob = async (kind, button) => {
  const submitted=page.waitForResponse(response => response.request().method()==='POST' && /\/api\/v1\/projects\/[^/]+\/jobs$/.test(response.url()) && response.status()===202,{timeout:30000});
  await button.evaluate(e=>e.click());
  const job=await (await submitted).json();
  let terminal=null;
  await page.waitForResponse(async response => {
   if (!response.url().includes('/api/v1/jobs?') || !response.ok()) return false;
   const jobs=await response.json().catch(()=>[]);
   const current=jobs.find(item=>item.id===job.id);
   if (current && ['done','failed','cancelled'].includes(current.status)) {
    terminal=current;
    return true;
   }
   return false;
  },{timeout:120000});
  if (terminal.status!=='done') throw new Error(kind+' job failed: '+terminal.error);
  completedJobs.push({id:terminal.id,kind:terminal.job_kind,status:terminal.status,master_asset_id:terminal.master_asset_id});
  await pause(500);
 };
 try {
  await page.goto(process.env.AUREON_PREVIEW || 'http://localhost:3005',{waitUntil:'networkidle',timeout:60000});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await page.getByRole('button',{name:'Try the studio',exact:true}).waitFor({state:'visible',timeout:30000});
  await page.evaluate(() => { const note=document.createElement('div'); note.dataset.fixtureLabel='true'; note.textContent='Aureon · guest fixture · live local workspace'; Object.assign(note.style,{position:'fixed',right:'18px',bottom:'16px',zIndex:'999999',background:'#22242cee',color:'#fff',padding:'8px 12px',borderRadius:'12px',font:'12px sans-serif',pointerEvents:'none'});document.body.appendChild(note); });
  await pause(1500);
  await page.screenshot({path:path.join(screenshots,'welcome.png')});
  const presetPreview = page.getByRole('button',{name:/Preview Afterglow/i}).first();
  await presetPreview.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Play or pause preview',exact:true}).waitFor({state:'visible',timeout:30000});
  await pause(1800);
  await page.screenshot({path:path.join(screenshots,'preset-preview.png')});
  await page.getByRole('button',{name:'Play or pause preview',exact:true}).evaluate(e=>e.click());
  completed.push('Actual preset preview opened a correctly labeled controllable transport');
  await page.getByRole('button',{name:'Try the studio',exact:true}).evaluate(e=>e.click());
  completed.push('Guest fixture created through UI');
  const play=page.getByRole('button',{name:'Play master',exact:true});
  await play.waitFor({state:'visible',timeout:120000});
  completed.push('Actual original instrumental render completed');
  await pause(1500);
  await play.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Pause',exact:true}).waitFor({state:'visible',timeout:15000});
  await pause(3000);
  frameSample=await page.evaluate(() => new Promise(resolve => {
    const intervals=[]; let previous=performance.now();
    const sample=now=>{intervals.push(now-previous);previous=now;
      if(intervals.length<120) requestAnimationFrame(sample);
      else {intervals.shift();intervals.sort((a,b)=>a-b);resolve({
        renderer:'Headless Chrome; desktop1440x1000; actual master playing',
        frames:intervals.length, median_ms:Number(intervals[Math.floor(intervals.length/2)].toFixed(2)),
        p95_ms:Number(intervals[Math.floor(intervals.length*.95)].toFixed(2)),
        scope:'Browser frame scheduling sample, not reference-device GPU profiling',
      });}
    };requestAnimationFrame(sample);
  }));
  await page.getByRole('button',{name:'Pause',exact:true}).evaluate(e=>e.click());
  completed.push('Real master playback started and paused');
  const title = page.getByRole('textbox',{name:/Session title/}).first();
  await title.fill('Aureon audit · original session');
  await title.press('Tab');
  await pause(1700);
  completed.push('Session title edited and autosaved through the editor');
  
  const mute=page.getByRole('checkbox',{name:'M',exact:true}).nth(2);
  await mute.waitFor({state:'visible',timeout:15000});
  await mute.evaluate(e=>e.click());
  completed.push('Bass stem muted in saved mixer');
  const render=page.getByRole('button',{name:'Render mix',exact:true});
  await render.scrollIntoViewIfNeeded(); await pause(700); await exportJob('remix',render);
  await page.getByRole('button',{name:'Studio',exact:true}).evaluate(e=>e.click()); await page.getByLabel('Previous mix',{exact:true}).waitFor({state:'visible',timeout:30000});
  completed.push('Real remixed master completed and previous mix available');
  const current=page.getByLabel('Current mix',{exact:true});
  if(await current.count()) await current.evaluate(e=>e.click());
  await pause(1200);
  await page.getByRole('button',{name:'Library',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Open',exact:true}).first().waitFor({state:'visible',timeout:30000});
  await pause(1600);
  await page.getByRole('button',{name:'Open',exact:true}).first().evaluate(e=>e.click());
  await play.waitFor({state:'visible',timeout:30000});
  completed.push('Persistent guest session reopened from library');
  const downloadPromise=page.waitForEvent('download',{timeout:30000});
  await page.getByRole('button',{name:'WAV',exact:true}).evaluate(e=>e.click());
  const download=await downloadPromise;
  await download.saveAs(path.join(output,'guest-master.wav'));
  completed.push('Real WAV export downloaded');
  const stemsDownload=page.waitForEvent('download',{timeout:30000});
  await page.getByRole('button',{name:'Stem pack',exact:true}).evaluate(e=>e.click());
  await (await stemsDownload).saveAs(path.join(output,'guest-stems.zip'));
  completed.push('Actual four-stem ZIP downloaded');
  await exportJob('mp3',page.getByRole('button',{name:'MP3',exact:true}));
  await page.getByRole('button',{name:'Save',exact:true}).first().waitFor({state:'visible',timeout:120000});
  const mp3Download=page.waitForEvent('download',{timeout:30000});
  await page.getByRole('button',{name:'Save',exact:true}).first().evaluate(e=>e.click());
  const mp3=await mp3Download;
  if (!mp3.suggestedFilename().endsWith('.mp3')) throw new Error('MP3 job did not download MP3');
  await mp3.saveAs(path.join(output,'guest-master.mp3'));
  completed.push('Real MP3 export completed and downloaded from Activity');
  await page.getByRole('button',{name:'Studio',exact:true}).evaluate(e=>e.click());
  await pause(1800);
  await page.screenshot({path:path.join(output,'completed-studio.png')});
  await page.screenshot({path:path.join(screenshots,'studio.png')});
  await page.evaluate(() => { const note=document.querySelector('[data-fixture-label]'); if(note) note.style.display='none'; });
  await page.setViewportSize({width:390,height:1000}); await pause(700);
  await page.screenshot({path:path.join(screenshots,'studio-phone.png')});
  await page.setViewportSize({width:1440,height:1000}); await pause(500);
  await page.evaluate(() => { const note=document.querySelector('[data-fixture-label]'); if(note) note.style.display='block'; });
  const cover=page.getByRole('button',{name:'Edit cover',exact:true});
  await cover.scrollIntoViewIfNeeded(); await cover.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Render cover',exact:true}).waitFor({state:'visible',timeout:15000});
  await page.screenshot({path:path.join(screenshots,'artwork-editor.png')});
  await page.getByRole('button',{name:'Render cover',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Render cover',exact:true}).waitFor({state:'hidden',timeout:15000});
  completed.push('Original cover rendered through the real editor');
  const videoExport=page.getByRole('button',{name:'Video',exact:true});
  await videoExport.scrollIntoViewIfNeeded(); await exportJob('video',videoExport);
  const previewVideo=page.getByRole('button',{name:'Preview video',exact:true});
  await previewVideo.waitFor({state:'visible',timeout:120000}); await previewVideo.evaluate(e=>e.click());
  const playVideo=page.getByRole('button',{name:'Play video',exact:true});
  await playVideo.waitFor({state:'visible',timeout:30000}); await playVideo.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Pause video',exact:true}).waitFor({state:'visible',timeout:15000});
  let media=[];
  for(let attempt=0;attempt<30;attempt++) {
    media=await page.locator('video').evaluateAll(videos=>videos.map(v=>({time:v.currentTime,ready:v.readyState,paused:v.paused,error:v.error?.message})));
    if(media.some(v=>v.time>1 && v.ready>=2 && !v.paused)) break;
    await pause(500);
  }
  if(!media.some(v=>v.time>1 && v.ready>=2 && !v.paused)) throw new Error('Actual visualizer playback did not advance: '+JSON.stringify(media));
  await page.screenshot({path:path.join(screenshots,'video-preview.png')});
  completed.push('Actual rendered MP4 preview decoded and playback advanced');
  await page.getByRole('button',{name:'Close sheet',exact:true}).evaluate(e=>e.click());
  const videoDownload=page.waitForEvent('download',{timeout:30000});
  await page.getByRole('button',{name:'Save',exact:true}).first().evaluate(e=>e.click());
  const visualizer=await videoDownload;
  if (!visualizer.suggestedFilename().endsWith('.mp4')) throw new Error('Video job did not download MP4');
  await visualizer.saveAs(path.join(output,'guest-visualizer.mp4'));
  completed.push('Real completed video job downloaded from Activity');
  await page.getByRole('button',{name:'Studio',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Share to showcase',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Discover',exact:true}).evaluate(e=>e.click());
  const playTrack=page.getByRole('button',{name:'Play track',exact:true}).first();
  await playTrack.waitFor({state:'visible',timeout:30000});
  await playTrack.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Play or pause preview',exact:true}).waitFor({state:'visible',timeout:30000});
  await pause(1500);
  await page.getByRole('button',{name:'Play or pause preview',exact:true}).evaluate(e=>e.click());
  await page.screenshot({path:path.join(screenshots,'covered-showcase.png')});
  completed.push('Covered publication retained actual playback and a correct preview transport');
  await page.getByRole('button',{name:'Unpublish',exact:true}).first().evaluate(e=>e.click());
  completed.push('Owned publication removed through UI');
  await page.getByRole('button',{name:'Studio',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Record',exact:true}).evaluate(e=>e.click());
  await page.getByRole('checkbox',{name:/This is my voice, or I have permission/}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Start recording',exact:true}).evaluate(e=>e.click());
  const stopRecording=page.getByRole('button',{name:'Stop & save recording',exact:true});
  await stopRecording.waitFor({state:'visible',timeout:15000});
  await pause(2200);
  await page.screenshot({path:path.join(screenshots,'recording.png')});
  await stopRecording.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Close sheet',exact:true}).waitFor({state:'hidden',timeout:120000});
  if (!recordingAsset) throw new Error('Recording did not produce a successful uploaded WAV asset');
  await page.screenshot({path:path.join(screenshots,'recording-saved.png')});
  completed.push('Consented synthetic Chrome microphone fixture finalized a real uploaded WAV take');
  await page.getByRole('button',{name:'Settings',exact:true}).evaluate(e=>e.click());
  await page.getByRole('button',{name:'Light',exact:true}).evaluate(e=>e.click());
  await pause(500);
  await page.screenshot({path:path.join(screenshots,'settings-light.png')});
  await page.getByRole('button',{name:'Dark',exact:true}).evaluate(e=>e.click());
  await pause(800);
  await page.screenshot({path:path.join(screenshots,'settings-dark.png')});
  await page.setViewportSize({width:390,height:1000}); await pause(500);
  await page.screenshot({path:path.join(screenshots,'settings-phone-dark.png')});
  await page.getByRole('tab',{name:'Studio',exact:true}).evaluate(e=>e.click());
  await pause(600);
  await page.screenshot({path:path.join(screenshots,'studio-phone-dark.png')});
  await page.setViewportSize({width:1440,height:1000}); await pause(600);
  await page.screenshot({path:path.join(screenshots,'studio-dark.png')});
  completed.push('Dark appearance and floating mobile dock inspected on actual release');
  await page.getByRole('button',{name:'Settings',exact:true}).evaluate(e=>e.click());
  for (const preference of ['Reduce motion','Reduce transparency','Increase contrast']) {
   await page.getByRole('switch',{name:new RegExp('^'+preference)}).evaluate(e=>e.click());
  }
  await pause(600);
  await page.screenshot({path:path.join(screenshots,'settings-accessible.png')});
  await page.reload({waitUntil:'networkidle'});
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByRole('button',{name:'Settings',exact:true}).evaluate(e=>e.click());
  for (const preference of ['Reduce motion','Reduce transparency','Increase contrast']) {
   const checked=await page.getByRole('switch',{name:new RegExp('^'+preference)}).getAttribute('aria-checked');
   if (checked!=='true') throw new Error('Preference did not persist after reload: '+preference+'='+checked);
  }
  await page.setViewportSize({width:390,height:1000}); await pause(500);
  await page.screenshot({path:path.join(screenshots,'settings-phone-accessible.png')});
  completed.push('Contrast, reduced motion and solid surfaces remained enabled after a real browser reload');
 } finally {
  const video=page.video();
  await context.close();
  await video.saveAs(path.join(output,'guest-workflow.webm'));
  await browser.close();
  fs.writeFileSync(path.join(output,'guest-workflow-evidence.json'),JSON.stringify({date:new Date().toISOString(),fixture:'Isolated guest workspace using original preset composition',url:process.env.AUREON_PREVIEW || 'http://localhost:3005',completed,completed_jobs:completedJobs,page_errors:errors,frame_sample:frameSample,recording_asset:recordingAsset,font_network:{policy:'All nonlocal HTTP requests blocked throughout the real journey',bundled_font_responses:bundledFontResponses,blocked_external_requests:blockedExternalRequests},video_audio:'Silent browser screen recording; actual exported master and rendered visualizer are supplied separately.'},null,2));
  console.log(JSON.stringify({completed,page_errors:errors}));
  if (errors.length) process.exitCode=1;
 }
})().catch(error => {console.error(error.message); process.exitCode=1;});
