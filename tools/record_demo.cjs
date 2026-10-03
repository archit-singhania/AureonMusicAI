// Real guest-fixture browser journey; no API interception or simulated progress.
const fs = require('fs');
const path = require('path');
let chromium;
try { ({ chromium } = require(process.env.AUREON_PLAYWRIGHT || 'playwright')); }
catch (error) { if (process.env.AUREON_PLAYWRIGHT) throw error; ({ chromium } = require('C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')); }
(async () => {
 const output = path.resolve(__dirname, '../docs/demo');
 const screenshots = path.resolve(__dirname, '../docs/screenshots');
 fs.mkdirSync(screenshots,{recursive:true});
 const browser = await chromium.launch({channel:'chrome', headless:true});
 const context = await browser.newContext({viewport:{width:1440,height:1000}, recordVideo:{dir:output,size:{width:1440,height:1000}}, acceptDownloads:true});
 const page = await context.newPage();
 const errors=[]; const completed=[];
 page.on('pageerror', error => errors.push(error.message));
 const pause = ms => page.waitForTimeout(ms);
 try {
  await page.goto(process.env.AUREON_PREVIEW || 'http://localhost:3005',{waitUntil:'networkidle',timeout:60000});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await page.getByRole('button',{name:'Try the studio',exact:true}).waitFor({state:'visible',timeout:30000});
  await page.evaluate(() => { const note=document.createElement('div'); note.dataset.fixtureLabel='true'; note.textContent='Aureon · guest fixture · live local workspace'; Object.assign(note.style,{position:'fixed',right:'18px',bottom:'16px',zIndex:'999999',background:'#22242cee',color:'#fff',padding:'8px 12px',borderRadius:'12px',font:'12px sans-serif',pointerEvents:'none'});document.body.appendChild(note); });
  await pause(1500);
  await page.screenshot({path:path.join(screenshots,'welcome.png')});
  await page.getByRole('button',{name:'Try the studio',exact:true}).evaluate(e=>e.click());
  completed.push('Guest fixture created through UI');
  const play=page.getByRole('button',{name:'Play master',exact:true});
  await play.waitFor({state:'visible',timeout:120000});
  completed.push('Actual original instrumental render completed');
  await pause(1500);
  await play.evaluate(e=>e.click());
  await page.getByRole('button',{name:'Pause',exact:true}).waitFor({state:'visible',timeout:15000});
  await pause(3000);
  await page.getByRole('button',{name:'Pause',exact:true}).evaluate(e=>e.click());
  completed.push('Real master playback started and paused');
  
  const mute=page.getByRole('checkbox',{name:'M',exact:true}).nth(2);
  if (await mute.count()) {await mute.first().evaluate(e=>e.click());completed.push('Bass stem muted in saved mixer');}
  const render=page.getByRole('button',{name:'Render mix',exact:true});
  await render.scrollIntoViewIfNeeded(); await pause(700); await render.evaluate(e=>e.click());
  await pause(900); await page.getByRole('button',{name:'Studio',exact:true}).evaluate(e=>e.click()); await page.getByLabel('Previous mix',{exact:true}).waitFor({state:'visible',timeout:30000});
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
  await videoExport.scrollIntoViewIfNeeded(); await videoExport.evaluate(e=>e.click());
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
 } finally {
  const video=page.video();
  await context.close();
  await video.saveAs(path.join(output,'guest-workflow.webm'));
  await browser.close();
  fs.writeFileSync(path.join(output,'guest-workflow-evidence.json'),JSON.stringify({fixture:'Isolated guest workspace using original preset composition',url:'http://localhost:3005',completed,page_errors:errors,video_audio:'Silent browser screen recording; actual exported master is supplied separately.'},null,2));
  console.log(JSON.stringify({completed,page_errors:errors}));
 }
})().catch(error => {console.error(error.message); process.exitCode=1;});
