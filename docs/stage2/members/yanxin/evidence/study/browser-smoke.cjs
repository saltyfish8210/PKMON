const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const {randomBytes}=require('node:crypto');
(async()=>{
const repo=process.cwd(),web=path.join(repo,'client/build/web')+path.sep;
const child=spawn(process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME,'bin',process.platform==='win32'?'java.exe':'java') : 'java',['-jar',process.env.STUDY_JAR || path.join(repo,'server/target/pkmon-server-0.1.0.jar'),'--server.address=127.0.0.1','--server.port=0','--spring.profiles.active=dev','--pkmon.capture.dev-user-header=false','--pkmon.study.rules.required-seconds=4','--spring.datasource.url=jdbc:h2:mem:studybrowser',...(process.env.STUDY_JAR?[]:['--spring.web.resources.static-locations='+pathToFileURL(web).href])],{windowsHide:true,stdio:['ignore','pipe','pipe']});
let browser, page;
const password=randomBytes(18).toString('hex'),user='demo_'+randomBytes(4).toString('hex');
try{
const port=await new Promise((res,rej)=>{const timeout=setTimeout(()=>rej(Error('Server readiness timeout')),45000);child.stdout.on('data',c=>{let m=c.toString().match(/Tomcat started on port (\d+)/);if(m){clearTimeout(timeout);res(m[1]);}});child.once('exit',code=>{clearTimeout(timeout);rej(Error('Server exited '+code));});});
browser=await chromium.launch({executablePath:process.env.CHROME_PATH || undefined,headless:true,args:['--enable-unsafe-swiftshader']});
page=await browser.newPage({viewport:{width:1080,height:920}});
page.setDefaultTimeout(13000);
const receipts=[];
page.on('response',async r=>{const path=new URL(r.url()).pathname;if(!/^\/api\/v1\/(study|capture|collection)\//.test(path))return;try{const j=await r.json();receipts.push({path,data:j.data,code:j.code});}catch{}});
await page.goto('http://127.0.0.1:'+port+'/');
const click=async(name)=>page.getByRole('button',{name,exact:true}).click();
const field=async(name,value)=>{await page.getByRole('textbox',{name,exact:true}).click();await page.keyboard.insertText(value);};
await click('注册新账号');await field('用户名',user);await field('昵称','同学');await field('密码',password);await click('创建账号');await page.getByText('注册成功，请登录',{exact:true}).waitFor();await click('登录');await click('任务模式');
if(await page.getByRole('button',{name:'进入自习任务'}).isVisible())await click('进入自习任务');
await click('使用模拟位置开始');await page.getByRole('button',{name:'前往答题',exact:true}).waitFor({timeout:35000});await click('前往答题');
await page.getByRole('button',{name:/^B\s/}).click();
await page.getByText('这次没有答对，可以再试一次。',{exact:true}).waitFor();
await page.getByRole('button',{name:/^A\s/}).click();
await page.getByText('成为伙伴了！',{exact:true}).waitFor();
const triggered=receipts.find(x=>x.data?.status==='TRIGGERED');
const question=receipts.find(x=>x.path.endsWith('/challenge'));
if(!triggered?.data.spawnId || triggered.data.spawnId!==question?.data.spawnId)throw Error('Encounter identifier mismatch');
if(question.data.sourceType!=='DEV_SIMULATED')throw Error('Simulated source not labelled');
if(!receipts.some(x=>x.data?.captureCount===1))throw Error('Expected one capture');
await click('返回自习');await click('结束任务');await page.getByText(/状态.*已结束/).waitFor();
console.log('PASS Chrome / Flutter release + Spring Boot: register, login, start, position samples, trigger, navigate with same spawnId, wrong answer and retry, one capture, end.');
console.log('Observed task states: '+[...new Set(receipts.map(x=>x.data?.status).filter(Boolean))].join(', '));
} catch(e){console.error(String(e).replaceAll(password,'[redacted]'));if(page){console.error((await page.locator('body').ariaSnapshot().catch(()=>'' )).replaceAll(password,'[redacted]').slice(0,3200));}process.exitCode=1;}
finally{await browser?.close();child.kill();}
})();
