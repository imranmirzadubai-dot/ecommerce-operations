import { chromium } from 'playwright'
import { mkdir, writeFile } from 'node:fs/promises'

const baseUrl = process.env.E2E_BASE_URL
const cases = [{name:'orders-off',orders:'off'},{name:'orders-on',orders:'on'}]
const results=[]
for (const c of cases) {
  const result={...c,url:null,bodyText:'',readyState:null,marker:null,consoleErrors:[],pageErrors:[],failedRequests:[],navigationError:null,ordersVisible:false}
  let browser
  try {
    const u=new URL('/',baseUrl); u.searchParams.set('t227010','1'); u.searchParams.set('orders',c.orders); u.searchParams.set('cb',process.env.GITHUB_SHA ?? Date.now().toString()); result.url=u.toString()
    browser=await chromium.launch({headless:true,timeout:5000,args:['--no-sandbox','--disable-dev-shm-usage']})
    const page=await browser.newPage(); page.setDefaultNavigationTimeout(5000); page.setDefaultTimeout(1500)
    page.on('console',m=>{if(m.type()==='error') result.consoleErrors.push(m.text())})
    page.on('pageerror',e=>result.pageErrors.push(String(e)))
    page.on('requestfailed',r=>result.failedRequests.push({url:r.url(),error:r.failure()?.errorText??'unknown'}))
    await page.route('**/api/**',async route=>{
      const method=route.request().method()
      if(method==='GET') {
        const path=new URL(route.request().url()).pathname
        if(path==='/api/health') return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({status:'ok'})})
        return route.fulfill({status:200,contentType:'application/json',headers:{'X-Has-More':'false'},body:'[]'})
      }
      return route.fulfill({status:200,contentType:'application/json',body:'[]'})
    })
    try{await page.goto(result.url,{waitUntil:'domcontentloaded',timeout:5000})}catch(e){result.navigationError=String(e)}
    const deadline=Date.now()+7000
    while(Date.now()<deadline){
      try{
        const s=await page.evaluate(()=>({bodyText:document.body?.innerText??'',readyState:document.readyState}))
        result.bodyText=s.bodyText; result.readyState=s.readyState; result.ordersVisible=s.bodyText.includes('Orders') && s.bodyText.includes('Orders Workspace')
        if(s.bodyText.includes('Operations Dashboard')) break
      }catch{}
      await new Promise(r=>setTimeout(r,250))
    }
    await mkdir('artifacts',{recursive:true})
    await writeFile(`artifacts/T227-010-${c.name}.json`,JSON.stringify(result,null,2))
    try{await page.screenshot({path:`artifacts/T227-010-${c.name}.png`,fullPage:false,timeout:1500})}catch{}
  }catch(e){result.navigationError=String(e)}finally{try{await browser?.close()}catch{}}
  results.push(result)
}
const interpretation={ordersOffRenders:results.find(x=>x.orders==='off')?.bodyText.includes('Operations Dashboard')??false,ordersOnRenders:results.find(x=>x.orders==='on')?.bodyText.includes('Operations Dashboard')??false,ordersOnTimedOut:results.find(x=>x.orders==='on')?.bodyText.includes('Operations Dashboard')!==true}
console.log(JSON.stringify({test:'T227-010-app-composition-isolation',results,interpretation},null,2))
