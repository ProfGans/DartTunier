import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import assert from 'node:assert/strict';
const source=stripTypeScriptTypes((await readFile('supabase/functions/send-app-push/index.ts','utf8')).replace(/^import .*;\r?\n/gm,''));
const id='11111111-1111-4111-8111-111111111111';
async function run(platforms,{allowed=true,raw,queueFailure=false}={}) {
  let handler,queued=0,sent=0,dispatches=0;
  const devices=platforms.map((platform,i)=>({id:id.slice(0,-1)+i,token:'token',platform}));
  const db={auth:{getUser:async()=>({data:{user:{id:'owner'}}})},from(table) {
    return {op:'select',select(){return this;},eq(){return this;},gt(){return this;},in(){return this;},limit(){this.recent=true;return this;},
      maybeSingle(){return Promise.resolve({data:table==='app_push_senders'?(allowed?{user_id:'owner'}:null):null});},
      insert(value){this.op='insert';this.value=value;return this;},update(){this.op='update';return this;},
      then(resolve,reject){
        if(this.op==='insert') {
          if(table==='linux_notification_queue') {queued++; assert.match(this.value.dedupe_key,/^dispatch:/);}
          if(table==='app_push_dispatches') dispatches++;
          return Promise.resolve({error:table==='linux_notification_queue'&&queueFailure?{code:'failure'}:null}).then(resolve,reject);
        }
        return Promise.resolve({data:table==='app_push_devices'?devices:[],error:null}).then(resolve,reject);
      }};
  }};
  class JWT {setProtectedHeader(){return this;}setIssuer(){return this;}setAudience(){return this;}setIssuedAt(){return this;}setExpirationTime(){return this;}async sign(){return 'test';}}
  runInNewContext(source,{Request,Response,URLSearchParams,AbortSignal,Date,JSON,Math,Promise,Error,Set,
    SignJWT:JWT,importPKCS8:async()=>({}),createClient:()=>db,
    Deno:{env:{get:name=>name==='FIREBASE_SERVICE_ACCOUNT_JSON'?raw:'test'},serve:fn=>handler=fn},
    fetch:async(url)=>{if(url.includes('oauth2')) return new Response(JSON.stringify({access_token:'access'}));sent++;return new Response('{}');},
  });
  const response=await handler(new Request('https://example.test',{method:'POST',headers:{authorization:'Bearer test'},
    body:JSON.stringify({requestId:id,title:'Title',body:'Body',deviceIds:devices.map(d=>d.id)})}));
  return {status:response.status,result:await response.json(),queued,sent,dispatches};
}
const linux=await run(['linux'],{raw:'malformed-unused-firebase'});
assert.equal(linux.status,200);assert.equal(linux.result.accepted,1);assert.equal(linux.queued,1);assert.equal(linux.sent,0);
const mixed=await run(['linux','android']);assert.equal(mixed.result.accepted,1);assert.equal(mixed.result.failed,1);
const android=await run(['android'],{raw:JSON.stringify({project_id:'darttunier-6f866',client_email:'test',private_key:'test'})});assert.equal(android.sent,1);assert.equal(android.result.accepted,1);
const denied=await run(['linux'],{allowed:false});assert.equal(denied.status,403);assert.equal(denied.queued,0);
const failed=await run(['linux'],{queueFailure:true});assert.equal(failed.result.failed,1);assert.equal(failed.result.accepted,0);
console.log('PASS push worker: Linux without Firebase, mixed recipients, Android regression, authorization and queue failure. No real messages sent.');
