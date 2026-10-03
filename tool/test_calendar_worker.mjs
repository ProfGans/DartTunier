import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import assert from 'node:assert/strict';
const source=stripTypeScriptTypes((await readFile('supabase/functions/calendar-reminders/index.ts','utf8')).replace(/^import .*;\r?\n/gm,''));
async function run(mode) {
  let handler,claimed=0,sent=0,status;
  const starts=new Date(Date.now()+600000).toISOString();
  const item={delivery_id:'d',event_id:'e',community_id:'c',user_id:'u',device_id:'device',token:'token',title:'Cup',location:'Club',starts_at:starts,minutes_before:15};
  const db={
    async rpc(name) {if(name==='calendar_worker_authorized') return {data:mode!=='unauthorized'};
      claimed++; return {data:[item]};},
    from(table) {return {
      select(){return this;},eq(){return this;},delete(){return this;},
      update(value){status=value.status;return this;},
      async maybeSingle() {return {data:table==='community_calendar_events'
        ? (mode==='cancelled'?null:{title:'Cup',location:'Club',starts_at:starts})
        :table==='community_calendar_reminders'?{minutes_before:15}:table==='app_push_devices'?{token:'token'}:{user_id:'u'}};},
    };},
  };
  class JWT {setProtectedHeader(){return this;}setIssuer(){return this;}setAudience(){return this;}setIssuedAt(){return this;}setExpirationTime(){return this;}async sign(){return 'assertion';}}
  runInNewContext(source,{
    Request,Response,URLSearchParams,AbortSignal,Date,JSON,Math,Promise,Error,
    SignJWT:JWT,importPKCS8:async()=>({}),createClient:()=>db,
    Deno:{env:{get:name=>name==='FIREBASE_SERVICE_ACCOUNT_JSON'?(mode==='no_config'?undefined:JSON.stringify({project_id:'darttunier-6f866',client_email:'test',private_key:'test'})):'test'},serve:fn=>handler=fn},
    fetch:async(url,options)=>{
      if(url.includes('oauth2')) return new Response(JSON.stringify({access_token:'access'}),{status:mode==='provider_failure'?503:200});
      sent++; const payload=JSON.parse(options.body);assert.equal(payload.message.token,'token');
      assert.equal(payload.message.data.calendar_event_id,'e');assert.equal(payload.message.android.notification.tag,'calendar-e');
      return new Response('{}',{status:200});
    },
  });
  const response=await handler(new Request('https://example.test',{method:'POST',headers:mode==='no_key'?{}:{'x-calendar-worker-key':'key'}}));
  return {statusCode:response.status,body:await response.json(),claimed,sent,status};
}
for(const mode of ['no_key','unauthorized']) {const r=await run(mode);assert.equal(r.statusCode,401);assert.equal(r.claimed,0);assert.equal(r.sent,0);}
for(const mode of ['no_config','provider_failure']) {const r=await run(mode);assert.ok(r.statusCode>=500);assert.equal(r.claimed,0);assert.equal(r.sent,0);}
const success=await run('success');assert.equal(success.sent,1);assert.equal(success.status,'accepted');
const cancelled=await run('cancelled');assert.equal(cancelled.sent,0);assert.equal(cancelled.status,'cancelled');
console.log('PASS calendar worker: authorization, missing configuration, provider failure, dispatch and cancellation; no real messages sent.');
