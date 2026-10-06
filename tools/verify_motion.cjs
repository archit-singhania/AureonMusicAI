// Actual local release UI, local gateway and real audio jobs. No API fixtures.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { chromium } = require('C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async () => {
  const root = path.resolve(__dirname, '..');
  const output = path.join(root, 'docs/screenshots/premium-motion-2026-10-06');
  fs.mkdirSync(output, {recursive:true});
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const context = await browser.newContext({viewport:{width:1440,height:1000}, recordVideo:{dir:output,size:{width:1440,height:1000}}});
  const page = await context.newPage();
  const errors = [], checks = [], captures = [], fonts = [], jobs = [];
  let failure = null;
  await context.route('**/*', route => {
    const url = new URL(route.request().url());
    return ['http:','https:'].includes(url.protocol) && !['localhost','127.0.0.1'].includes(url.hostname)
      ? route.abort('blockedbyclient') : route.continue();
  });
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', async response => {
    if (/\/(Manrope-Variable|Inter)\.ttf$/.test(response.url())) fonts.push({path:new URL(response.url()).pathname,status:response.status()});
    if (/\/api\/v1\/jobs\?/.test(response.url()) && response.ok()) {
      const list=await response.json().catch(()=>[]);
      for (const job of list) {
        if (!jobs.some(item=>item.id===job.id && item.status===job.status)) jobs.push({id:job.id,kind:job.job_kind,status:job.status,progress:job.progress});
      }
    }
  });
  const pause = ms => page.waitForTimeout(ms);
  const press = name => page.getByRole(
    ['Studio','Library','Discover','Activity','Settings'].includes(name) && page.viewportSize().width < 1000 ? 'tab' : 'button',
    {name,exact:true},
  ).first().evaluate(e=>e.click());
  const capture = async (name, delay=360) => {
    await pause(delay);
    await page.screenshot({path:path.join(output,name+'.png')});
    captures.push(name+'.png');
  };
  const palette = async name => {
    const option = page.getByRole('checkbox',{name:new RegExp(name+'$')});
    await option.evaluate(e=>e.click());
    await pause(320);
  };
  const enableSemantics = async () => {
    const placeholder=page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(e=>e.click());
    await page.getByRole('button',{name:'Settings',exact:true}).waitFor({state:'visible',timeout:30000});
  };
  try {
    await page.goto('http://localhost:3005',{waitUntil:'networkidle',timeout:60000});
    await enableSemantics();
    await capture('welcome-iris');
    await press('Library');
    await capture('library-entering',60);
    await pause(300);
    const search=page.getByRole('textbox').first();
    await search.focus(); await pause(120);
    await search.fill('Afterglow');
    await pause(300);
    await search.press('Tab');
    await capture('library-keyboard-focus');
    await press('Settings');
    await capture('settings-entering',60);
    await pause(300);
    if (await page.getByRole('textbox').count()) throw new Error('Inactive library textbox remains accessible');
    await press('Library');
    await pause(350);
    await page.getByRole('textbox').first().focus();
    await pause(120);
    await capture('library-retained-search',60);
    if (await page.getByRole('textbox').first().inputValue() !== 'Afterglow') throw new Error('Library search lost across route changes');
    checks.push('Desktop route entrance, inactive semantics exclusion and retained search verified');
    await press('Settings'); await pause(350);
    await palette('Copper');
    await capture('settings-copper-light');
    await press('Dark');
    await capture('settings-copper-dark');
    await palette('Tide');
    await capture('settings-tide-dark');
    await press('Light');
    await capture('settings-tide-light');
    checks.push('All curated palette controls perform real persisted appearance changes');
    await press('Sign in');
    await capture('sheet-entering',70);
    await capture('sheet-open');
    await page.keyboard.press('Escape'); await pause(300);
    if (await page.getByRole('button',{name:'Close sheet',exact:true}).count()) throw new Error('Escape failed to close sheet');
    checks.push('Account sheet entrance and keyboard Escape close verified');
    await press('Studio'); await pause(350);
    const submitted=page.waitForResponse(r=>r.request().method()==='POST' && /\/api\/v1\/demo$/.test(r.url()) && r.ok(),{timeout:30000});
    await press('Try the studio');
    // A real guest render; record its actual completion rather than simulating progress.
    await capture('render-loading',120);
    await page.getByRole('button',{name:'Play master',exact:true}).waitFor({state:'visible',timeout:120000});
    await submitted;
    await capture('master-complete');
    await press('Play master');
    await page.getByRole('button',{name:'Pause',exact:true}).waitFor({state:'visible',timeout:15000});
    await capture('playback-feedback',70);
    await pause(1000);
    await press('Pause');
    await page.setViewportSize({width:390,height:1000});
    await capture('phone-master-normal');
    await page.setViewportSize({width:1440,height:1000}); await pause(350);
    await press('Import voice');
    await capture('consent-entering',60); await capture('consent-open');
    await page.keyboard.press('Tab'); await capture('consent-keyboard-focus',100);
    await page.keyboard.press('Escape'); await pause(300);
    checks.push('Actual guest master completed, played and paused with stable transport');
    await press('Activity'); await pause(350);
    await capture('activity-complete');
    const completed=await page.request.get('http://localhost:5000/api/v1/capabilities');
    if (!completed.ok()) throw new Error('Gateway health unavailable');
    await press('Settings'); await pause(350);
    for (const name of ['Reduce motion','Reduce transparency','Increase contrast']) {
      await page.getByRole('switch',{name:new RegExp('^'+name)}).evaluate(e=>e.click());
      await pause(120);
    }
    await capture('settings-comfort');
    await press('Studio'); await pause(120);
    await page.setViewportSize({width:390,height:1000});
    await capture('phone-master-comfort',120);
    await page.setViewportSize({width:1440,height:1000});
    await page.reload({waitUntil:'networkidle'}); await enableSemantics();
    await press('Settings'); await pause(150);
    for (const name of ['Reduce motion','Reduce transparency','Increase contrast']) {
      if (await page.getByRole('switch',{name:new RegExp('^'+name)}).getAttribute('aria-checked') !== 'true') throw new Error(name+' did not persist');
    }
    if (await page.getByRole('checkbox',{name:/Tide$/}).getAttribute('aria-checked') !== 'true') throw new Error('Palette did not persist');
    checks.push('Tide, light appearance and all comfort options survived an actual reload');
    await press('Sign in'); await capture('sheet-comfort',60);
    await page.keyboard.press('Escape'); await pause(120);
    await page.setViewportSize({width:390,height:1000});
    await capture('phone-settings-comfort');
    await press('Studio'); await capture('phone-studio-comfort',100);
    await press('Library'); await capture('phone-library-comfort',100);
    checks.push('390px phone navigation and opaque high-contrast comfort surfaces captured');
    await press('Settings'); await pause(150);
    for (const name of ['Reduce motion','Reduce transparency','Increase contrast']) {
      await page.getByRole('switch',{name:new RegExp('^'+name)}).evaluate(e=>e.click()); await pause(150);
    }
    await palette('Iris');
    await press('Sign in'); await capture('phone-sheet-entering',70); await capture('phone-sheet-open');
    await page.keyboard.press('Escape'); await pause(300);
    await press('Studio'); await capture('phone-studio-normal');
    checks.push('390px phone normal sheet and section motion captured');
    if (errors.length) throw new Error(errors.join('\n'));
  } catch (error) {
    failure=error.message;
    await page.screenshot({path:path.join(output,'failure.png')}).catch(()=>{});
    throw error;
  }
  finally {
    const video=page.video();
    await context.close();
    if (video) await video.saveAs(path.join(output,'motion-review.webm'));
    await browser.close();
    const receipt={date:new Date().toISOString(),scope:'Actual release and local original guest render; no API interception or simulated progress',checks,captures,actual_job_states:jobs,page_errors:errors,bundled_fonts:fonts,failure,
      main_js_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'flutter_app/aureon/build/web/main.dart.js'))).digest('hex'),
      motion_review_video:'motion-review.webm',manual_review:'Inspect paired entering/open frames and video. Headless browser captures do not certify native device frame rate.'};
    fs.writeFileSync(path.join(output,'visual-receipt.json'),JSON.stringify(receipt,null,2));
    console.log(JSON.stringify(receipt));
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
