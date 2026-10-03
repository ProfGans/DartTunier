import { createClient } from 'npm:@supabase/supabase-js@2.117.2';
import { importPKCS8, SignJWT } from 'npm:jose@5.10.0';

const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), {status, headers});

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers});
  if (request.method !== 'POST') return reply({error:'method'},405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {auth:{persistSession:false}});
  try {
    const jwt = request.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
    if (!jwt) return reply({error:'unauthorized'},401);
    const {data:{user},error:authError} = await db.auth.getUser(jwt);
    if (authError || !user) return reply({error:'unauthorized'},401);
    const {data:sender,error:roleError} = await db.from('app_push_senders').select('user_id').eq('user_id',user.id).maybeSingle();
    if (roleError || !sender) return reply({error:'forbidden'},403);
    const input = await request.text();
    if (input.length > 20000) return reply({error:'too_large'},413);
    const {requestId,title,body,deviceIds} = JSON.parse(input);
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (typeof requestId !== 'string' || !uuid.test(requestId) || typeof title !== 'string' ||
        !title.trim() || title.length>80 || typeof body !== 'string' || !body.trim() || body.length>1000 ||
        !Array.isArray(deviceIds) || deviceIds.length<1 || deviceIds.length>100 ||
        deviceIds.some(id=>typeof id!=='string'||!uuid.test(id))) return reply({error:'invalid_input'},400);
    // Secrets stay on the server; never trust service-account material from a client.
    const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    let service: {project_id:string;client_email:string;private_key:string} | null = null;
    const {data:previous,error:previousError} = await db.from('app_push_dispatches').select('sender_id,result').eq('id',requestId).maybeSingle();
    if (previousError) throw previousError;
    if(previous) return previous.sender_id===user.id ? reply(previous.result) : reply({error:'conflict'},409);
    const {data:recent,error:recentError} = await db.from('app_push_dispatches').select('id').eq('sender_id',user.id).gt('created_at',new Date(Date.now()-10000).toISOString()).limit(1);
    if (recentError) throw recentError;
    if (recent?.length) return reply({error:'Bitte 10 Sekunden zwischen Sendungen warten.'},429);
    const {data:devices,error:deviceError} = await db.from('app_push_devices').select('id,token,platform').in('id',[...new Set(deviceIds)]).gt('updated_at',new Date(Date.now()-90*86400000).toISOString());
    if (deviceError) throw deviceError;
    if (!devices?.length) return reply({error:'no_devices'},400);
    let access_token: string | undefined;
    if (devices.some(device=>['android','ios','web'].includes(device.platform))) {
      try {
        service = raw ? JSON.parse(raw) : null;
        if (service?.project_id !== 'darttunier-6f866') throw new Error('push_not_configured');
    const assertion = await new SignJWT({scope:'https://www.googleapis.com/auth/firebase.messaging'})
      .setProtectedHeader({alg:'RS256'}).setIssuer(service.client_email)
      .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h')
      .sign(await importPKCS8(service.private_key,'RS256'));
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {method:'POST',
      body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(10000)});
    if (!tokenResponse.ok) throw new Error('provider_auth_failed');
    access_token = (await tokenResponse.json()).access_token;
    if (!access_token) throw new Error('No access token');
      } catch {
        if (!devices.some(device=>device.platform==='linux')) return reply({error:'provider_auth_failed'},502);
      }
    }
    // Atomic insert prevents duplicate sends when clients retry an uncertain request.
    const {error:insertError} = await db.from('app_push_dispatches').insert({id:requestId,sender_id:user.id});
    if (insertError?.code==='23505') return reply({status:'processing'});
    if (insertError) throw insertError;
    let accepted=0, failed=new Set(deviceIds).size-devices.length;
    for(let offset=0;offset<devices.length;offset+=10) {
      await Promise.all(devices.slice(offset,offset+10).map(async device=>{
        try {
          if(device.platform==='linux') {
            const {error:queueError}=await db.from('linux_notification_queue').insert({
              device_id:device.id,dedupe_key:`dispatch:${requestId}`,title:title.trim(),body:body.trim(),
            });
            if(queueError) {failed++;} else {accepted++;}
            return;
          }
          if(device.platform==='windows') {failed++;return;}
          if(!access_token) {failed++;return;}
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${service.project_id}/messages:send`,{
            method:'POST', headers:{Authorization:`Bearer ${access_token}`,'Content-Type':'application/json'},
            body:JSON.stringify({message:{token:device.token,notification:{title:title.trim(),body:body.trim()},
              data:{dispatch_id:requestId}, android:{priority:'HIGH',ttl:'86400s'}}}),signal:AbortSignal.timeout(10000)});
          if(response.ok) {accepted++;return;}
          failed++;
          const problem=await response.json();
          if(problem.error?.details?.some((detail:{errorCode?:string})=>detail.errorCode==='UNREGISTERED')) {
            await db.from('app_push_devices').delete().eq('id',device.id).eq('token',device.token);
          }
        } catch {failed++;}
      }));
    }
    const result={status:'complete',accepted,failed};
    const {error:saveError}=await db.from('app_push_dispatches').update({result}).eq('id',requestId);
    if(saveError) return reply({status:'processing'});
    return reply(result);
  } catch { return reply({error:'Versand konnte nicht abgeschlossen werden.'},500); }
});
