import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'
const baseUrl=process.env.E2E_BASE_URL
const u=new URL('/',baseUrl); u.searchParams.set('t227011','1'); u.searchParams.set('cb',process.env.GITHUB_SHA ?? Date.now().toString())
const result={url:u.toString(),bodyText:'',readyState:null,consoleErrors:[],pageErrors:[],failedRequests:[],navigationError:null,rendererEvaluateTimedOut:false}
let browser
try{
 browser=await chromium.launch({headless:true,timeout:5000,args:['--no-sandbox','--disable-dev-shm-usage']})
 const page=await browser.newPage(); page.setDefaultNavigationTimeout(5000)
 page.on('console',m=>{if(m.type()==='error')result.consoleErrors.push(m.text())})
 page.on('pageerror',e=>result.pageErrors.push(String(e)))
 page.on('requestfailed',r=>result.failedRequests.push({url:r.url(),error:r.failure()?.errorText??'unknown'}))
 await page.route('**/api/**',async route=>route.fulfill({status:200,contentType:'application/json',headers:{'X-Has-More':'false'},body:'[]'}))
 try{await page.goto(result.url,{waitUntil:'domcontentloaded',timeout:5000})}catch(e){result.navigationError=String(e)}
 try {
   const snapshot=await Promise.race([
     page.evaluate(()=>({bodyText:document.body?.innerText??'',readyState:document.readyState})),
     new Promise((_,reject)=>setTimeout(()=>reject(new Error('renderer snapshot timeout')),2500))
   ])
   result.bodyText=snapshot.bodyText; result.readyState=snapshot.readyState
 } catch (error) {
   result.rendererEvaluateTimedOut=true
   result.navigationError=result.navigationError ?? String(error)
 }
 await mkdir('artifacts',{recursive:true}); await writeFile('artifacts/T227-011-orders-grid.json',JSON.stringify(result,null,2))
 try{await page.screenshot({path:'artifacts/T227-011-orders-grid.png',fullPage:false,timeout:1500})}catch{}
}finally{try{await Promise.race([browser?.close(),new Promise(r=>setTimeout(r,1500))])}catch{}}
console.log(JSON.stringify(result,null,2))
