import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE??'playwright');
const browser=await chromium.launch({executablePath:process.env.CHROMIUM??'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:1440,height:1000}}); let n=0;
function check(c,m){if(!c)throw Error(m);n++}
page.on('pageerror',e=>console.log('PAGE ERROR',e.message));
page.on('console',m=>{if(m.type()==='error')console.log('CONSOLE',m.text())});
async function click(s){await page.locator(s).click()}
async function feedback(s){await page.waitForFunction(text=>document.querySelector('#toast')?.textContent.includes(text),s,{timeout:10000});n++}
try{
 await page.goto(process.argv[2]); await page.waitForSelector('#connection[data-ready=true]',{timeout:20000});
 check(await page.getByText('The 1901 experiment',{exact:true}).count()===1,'game loaded');
 check(await page.getByText('I propose that we keep the Channel clear this spring.').count()===1,'reviewer delivered mail');
 await page.screenshot({path:process.env.SCREENSHOT??'/tmp/diplomacy-desktop.png'});
 await click('nav [data-page=prompts]');check(await page.locator('#prompt-text').inputValue()!== '', 'prompt shown only own');
 await page.locator('#prompt-text').fill('Test prompt with <script> literal text');
 await click('form[data-action="DIP.PROMPT"] button');await feedback('PROMPT SAVED');
 check((await page.locator('#prompt-text').inputValue()).includes('<script>'),'literal prompt round trip');
 await click('nav [data-page=credentials]');
 check(await page.locator('input[type=password]').isDisabled(),'real key disabled');
 await page.locator('input[name=label]').fill('Browser test');
 await page.locator('input[name=model]').fill('fixture-browser');
 await click('form[data-action="DIP.CREDENTIAL.FIXTURE"] button');await feedback('K');
 check(await page.getByText('Browser test',{exact:true}).count()===1,'credential added');
 await click('#account');await page.locator('input[name=display]').fill('Human tester');await click('form button');await feedback('REGISTERED');
 check(await page.locator('#account').textContent()==='Human tester','registration');
 await click('nav [data-page=lobby]');await page.locator('input[name=title]').fill('Human test table');await page.locator('select[name=mode]').selectOption('HUMAN');await click('form button');await feedback('G');
 check(await page.getByText('Human test table',{exact:true}).count()===1,'new game');
 await click('nav [data-page=setup]');await page.locator('select[name=power]').selectOption('ENG');await click('form button');await feedback('SEAT SAVED');
 check(await page.getByText('Human player',{exact:true}).count()===1,'human seat');
 await click('nav [data-page=prompts]');check(await page.locator('#prompt-text').count()===0,'human cannot see prompt');
 await click('nav [data-page=lobby]');await page.getByRole('article').filter({hasText:'The 1901 experiment'}).getByRole('button',{name:'Open'}).click();await feedback('GAME SELECTED');
 check(await page.getByText('I propose that we keep the Channel clear this spring.').count()===0,'other actor cannot see press');
 await click('nav [data-page=prompts]');check(await page.locator('#prompt-text').count()===0,'other actor cannot see prompt');
 await page.setViewportSize({width:390,height:844});await click('nav [data-page=review]');check(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'mobile horizontal overflow');
 await page.screenshot({path:process.env.MOBILE_SCREENSHOT??'/tmp/diplomacy-mobile.png'});
 console.log('PASS '+n+' Chromium checks');
}finally{await browser.close()}
