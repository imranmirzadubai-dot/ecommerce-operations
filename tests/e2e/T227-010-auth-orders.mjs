import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl=process.env.E2E_BASE_URL
const result={url:null,readyState:null,authLoading:null,authenticated:null,authState:null,bodyText:'',consoleErrors:[],pageErrors:[],failedRequests:[],navigationError:null,ordersRequestCount:0,ordersApiStatus:null}
let browser
try{
 const url=new URL('/?t227010=1',baseUrl); url.searchParams.set('cb',process.env.GITHUB_SHA??Date.now().toString()); result.url=url.toString()
 browser=await chromium.launch({headless:true,timeout:5000,args:['--no-sandbox','--disable-dev-shm-usage']})
 const page=await browser.newPage(); page.setDefaultTimeout(2000); page.setDefaultNavigationTimeout(5000)
 page.on('console',m=>{if(m.type()==='error')result.consoleErrors.push(m.text())})
 page.on('pageerror',e=>result.pageErrors.push(String(e)))
 page.on('requestfailed',r=>result.failedRequests.push({url:r.url(),error:r.failure()?.errorText??'unknown'}))
 page.on('response',r=>{if(new URL(r.url()).pathname==='/api/orders'){result.ordersRequestCount++;result.ordersApiStatus=r.status()}})
 try{await page.goto(result.url,{waitUntil:'domcontentloaded',timeout:5000})}catch(e){result.navigationError=e instanceof Error?e.message:String(e)}
 const deadline=Date.now()+8000
 while(Date.now()<deadline){
  try{
   const s=await page.evaluate(()=>({readyState:document.readyState,bodyText:document.body?.innerText??'',token:document.querySelector('[data-t227010-token]')?.getAttribute('data-t227010-token')??null,authLoading:document.querySelector('[data-t227010-token]')?.getAttribute('data-auth-loading')??null,authenticated:document.querySelector('[data-t227010-token]')?.getAttribute('data-authenticated')??null,authState:document.querySelector('[data-t227010-state]')?.textContent??null}))
   Object.assign(result,s)
   if(s.authState==='AUTH_SIGNED_OUT' || s.authState==='AUTHENTICATED') break
  }catch{}
  await new Promise(r=>setTimeout(r,250))
 }
 await mkdir('artifacts',{recursive:true}); await writeFile('artifacts/T227-010-auth-orders.json',JSON.stringify(result,null,2))
 try{await page.screenshot({path:'artifacts/T227-010-auth-orders.png',fullPage:false,timeout:1500})}catch{}
}catch(e){result.navigationError=e instanceof Error?e.message:String(e)}
finally{try{await browser?.close()}catch{}}
console.log(JSON.stringify(result,null,2))
