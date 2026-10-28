const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const outputDir=process.env.TEST_OUTPUT_DIR||path.resolve(__dirname,'../../test-results');
async function launch(){
 const channel=process.env.BROWSER_CHANNEL;
 const executablePath=process.env.BROWSER_PATH;
 const options={headless:true};
 if(executablePath)options.executablePath=executablePath;
 else if(channel)options.channel=channel;
 else if(fs.existsSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'))options.channel='chrome';
 return chromium.launch(options);
}
async function load(page){
 await page.addInitScript(()=>{
  let state=1;
  window.resetTestRandom=seed=>{state=seed>>>0};
  Math.random=()=>{state=(state+0x6D2B79F5)|0;let t=Math.imul(state^(state>>>15),1|state);t=(t+Math.imul(t^(t>>>7),61|t))^t;return ((t^(t>>>14))>>>0)/4294967296;};
 });
 await page.route('https://telegram.org/**',r=>r.abort());
 await page.goto(process.env.GAME_URL||require('node:url').pathToFileURL(path.resolve(__dirname,'../../index.html')).href);
}
function writeReport(name,data){fs.mkdirSync(outputDir,{recursive:true});fs.writeFileSync(path.join(outputDir,name),JSON.stringify(data,null,2)+'\n');}
module.exports={launch,load,writeReport};
