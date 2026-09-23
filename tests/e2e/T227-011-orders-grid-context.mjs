import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'
const baseUrl=process.env.E2E_BASE_URL
const u=new URL('/',baseUrl); u.searchParams.set('t227011','1'); u.searchParams.set('cb',process.env.GITHUB_SHA ?? Date.now().toString())
const result={url:u.toString(),bodyText:'',readyState:null,consoleErrors:[],pageErrors:[],failedRequests:[],navigationError:null}
let browser
try{
 browser=await chromium.launch({headless:true,timeout:5000,args:['--no-sandbox','--disable-dev-shm-usage']})
 const page=await browser.newPage(); page.setDefaultNavigationTimeout(5000)
 page.on('console',m=>{if(m.type()==='error')result.consoleErrors.push(m.text())})
 page.on('pageerror',e=>result.pageErrors.push(String(e)))
 page.on('requestfailed',r=>result.failedRequests.push({url:r.url(),error:r.failure()?.errorText??'unknown'}))
 await page.route('**/api/**',async route=>route.fulfill({status:200,contentType:'application/json',headers:{'X-Has-More':'false'},body:'[]'}))
 try{await page.goto(result.url,{waitUntil:'domcontentloaded',timeout:5000})}catch(e){result.navigationError=String(e)}
 const deadline=Date.now()+7000
 while(Date.now()<deadline){
  try{const s=await page.evaluate(()=>({bodyText:document.body?.innerText??'',readyState:document.readyState}));result.bodyText=s.bodyText;result.readyState=s.readyState;if(s.bodyText.includes('Create Draft Order'))break}catch{}
  await new Promise(r=>setTimeout(r,250))
 }
 await mkdir('artifacts',{recursive:true}); await writeFile('artifacts/T227-011-orders-grid.json',JSON.stringify(result,null,2))
 try{await page.screenshot({path:'artifacts/T227-011-orders-grid.png',fullPage:false,timeout:1500})}catch{}
}finally{try{await browser?.close()}catch{}}
console.log(JSON.stringify(result,null,2))
