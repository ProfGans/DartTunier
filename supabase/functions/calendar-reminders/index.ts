import { createClient } from 'npm:@supabase/supabase-js@2.117.2';
import { importPKCS8, SignJWT } from 'npm:jose@5.10.0';

const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body),
  {status, headers: {'Content-Type':'application/json'}});

// Only the scoped database scheduler can invoke this worker, never an app account.
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return reply({error:'method'},405);
  const key = request.headers.get('x-calendar-worker-key');
  if (!key || key.length > 200) return reply({error:'unauthorized'},401);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    {auth:{persistSession:false}});
  try {
    const authorization = await db.rpc('calendar_worker_authorized', {p_token:key});
    if (authorization.error || authorization.data !== true) return reply({error:'unauthorized'},401);
    const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!raw) return reply({error:'push_not_configured'},503);
    const service = JSON.parse(raw);
    if (service.project_id !== 'darttunier-6f866') return reply({error:'wrong_firebase_project'},503);
    const assertion = await new SignJWT({scope:'https://www.googleapis.com/auth/firebase.messaging'})
      .setProtectedHeader({alg:'RS256'}).setIssuer(service.client_email)
      .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h')
      .sign(await importPKCS8(service.private_key,'RS256'));
    const auth = await fetch('https://oauth2.googleapis.com/token',{method:'POST',
      body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),
      signal:AbortSignal.timeout(10000)});
    if (!auth.ok) return reply({error:'provider_auth_failed'},502);
    const {access_token} = await auth.json();
    if (!access_token) return reply({error:'provider_auth_failed'},502);
    // Authenticate with FCM before claiming: missing configuration must not consume reminders.
    const {data:claims,error} = await db.rpc('claim_calendar_reminders');
    if (error) throw error;
    let accepted=0, failed=0, cancelled=0;
    for (let offset=0; offset<(claims?.length ?? 0); offset+=10) {
      await Promise.all(claims.slice(offset,offset+10).map(async (item: {
        delivery_id:string;event_id:string;community_id:string;user_id:string;device_id:string;
        token:string;title:string;location:string;starts_at:string;minutes_before:number;
      }) => {
        let status='failed';
        try {
          // Recheck cancellation, rescheduling, membership and token ownership immediately before dispatch.
          const [event,subscription,device,member] = await Promise.all([
            db.from('community_calendar_events').select('title,location,starts_at').eq('id',item.event_id).maybeSingle(),
            db.from('community_calendar_reminders').select('minutes_before').eq('event_id',item.event_id).eq('user_id',item.user_id).maybeSingle(),
            db.from('app_push_devices').select('token').eq('id',item.device_id).eq('owner_id',item.user_id).maybeSingle(),
            db.from('community_members').select('user_id').eq('community_id',item.community_id).eq('user_id',item.user_id).maybeSingle(),
          ]);
          if ([event,subscription,device,member].some(result=>result.error)) throw new Error('recheck_failed');
          if (!event.data || !subscription.data || !member.data || device.data?.token!==item.token ||
            Date.parse(event.data.starts_at)!==Date.parse(item.starts_at) || subscription.data.minutes_before!==item.minutes_before) {
            status='cancelled'; cancelled++; return;
          }
          const minutes = Math.max(0,Math.ceil((Date.parse(item.starts_at)-Date.now())/60000));
          const ttl = Math.max(0,Math.min(86400,Math.floor((Date.parse(item.starts_at)+15*60000-Date.now())/1000)));
          if (ttl===0) {status='cancelled';cancelled++;return;}
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${service.project_id}/messages:send`,{
            method:'POST',headers:{Authorization:`Bearer ${access_token}`,'Content-Type':'application/json'},
            body:JSON.stringify({message:{token:item.token,
              notification:{title:`Turniererinnerung: ${event.data.title}`,
                body:`${minutes===0?'Beginnt jetzt':`Beginnt in ca. ${minutes} Minuten`}${event.data.location?` · ${event.data.location}`:''}`},
              data:{calendar_event_id:item.event_id,community_id:item.community_id},
              android:{priority:'HIGH',ttl:`${ttl}s`,notification:{tag:`calendar-${item.event_id}`}}}}),
            signal:AbortSignal.timeout(10000)});
          if (response.ok) {status='accepted';accepted++;} else {
            failed++;
            const problem=await response.json();
            if(problem.error?.details?.some((detail:{errorCode?:string})=>detail.errorCode==='UNREGISTERED')) {
              await db.from('app_push_devices').delete().eq('id',item.device_id).eq('token',item.token);
            }
          }
        } catch { failed++; }
        finally {
          // No automatic retry after an ambiguous provider timeout: avoid duplicate pushes.
          await db.from('community_calendar_deliveries').update({status}).eq('id',item.delivery_id);
        }
      }));
    }
    return reply({accepted,failed,cancelled});
  } catch {return reply({error:'calendar_dispatch_failed'},500);}
});
