import { PGlite } from '../build/rbac_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
const owner='11111111-1111-1111-1111-111111111111', reader='22222222-2222-2222-2222-222222222222', outsider='33333333-3333-3333-3333-333333333333';
const group='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
await db.exec(`create role authenticated;create role anon;create role service_role;
create schema auth;create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon,service_role;
alter default privileges in schema public grant all on tables to authenticated;`);
for (const path of ['supabase/schema.sql','supabase/migrations/202609210001_manual_community_members.sql',
 'supabase/migrations/202609220001_account_devices.sql','supabase/migrations/202609230001_community_devices.sql',
 'supabase/migrations/202610020001_community_permissions.sql','supabase/migrations/202610020003_app_push.sql',
 'supabase/migrations/202610030003_community_calendar.sql']) await db.exec(await readFile(path,'utf8'));
await db.exec(`insert into auth.users values('${owner}'),('${reader}'),('${outsider}');
insert into public.player_profiles(id,user_id,display_name) values('${owner}','${owner}','Owner'),('${reader}','${reader}','Reader'),('${outsider}','${outsider}','Other');
insert into public.communities(id,owner_user_id,name,invite_code) values('${group}','${owner}','Test','TEST1234');
insert into public.community_members(community_id,user_id,role) values('${group}','${owner}','owner'),('${group}','${reader}','member');`);
async function as(user) {await db.exec(`reset role;select set_config('request.jwt.claim.sub','${user}',false);set role authenticated;`);}
const settings={version:1,boardCount:2,playerCount:8,gameFormat:{x01Score:501},rankingIds:['default']};
await as(owner);
const appointmentSettings={version:1,calendarVersion:2,eventType:'appointment'};
const appointment=(await db.query(`insert into community_calendar_events(community_id,title,starts_at,location,notes,settings)
 values($1,'Besprechung',now()+interval '2 days','Vereinsheim','Freier Termin',$2) returning id,settings`,[group,appointmentSettings])).rows[0];
assert.deepEqual(appointment.settings,appointmentSettings);
await as(reader);
assert.equal((await db.query('select settings from community_calendar_events where id=$1',[appointment.id])).rows[0].settings.eventType,'appointment');
await assert.rejects(db.query(`insert into community_calendar_events(community_id,title,starts_at,settings) values($1,'Denied',now(),$2)`,[group,appointmentSettings]));
assert.equal((await db.query(`update community_calendar_events set title='Denied' where id=$1 returning id`,[appointment.id])).rows.length,0);
await as(owner);
await db.query('delete from community_calendar_events where id=$1',[appointment.id]);
const event=(await db.query(`insert into community_calendar_events(community_id,title,starts_at,settings)
 values($1,'Freitag',now()+interval '10 minutes',$2) returning id`,[group,settings])).rows[0].id;
await db.query('insert into community_calendar_presets(community_id,name,settings) values($1,$2,$3)',[group,'Training',settings]);
await as(reader);
assert.equal((await db.query('select * from community_calendar_events')).rows.length,1);
await assert.rejects(db.query(`insert into community_calendar_events(community_id,title,starts_at,settings) values($1,'Denied',now(),$2)`,[group,settings]));
assert.equal((await db.query(`update community_calendar_events set title='Denied' where id=$1 returning id`,[event])).rows.length,0);
await db.query(`insert into community_calendar_reminders(event_id,community_id,user_id,minutes_before) values($1,$2,$3,15)`,[event,group,reader]);
await assert.rejects(db.query(`insert into community_calendar_reminders(event_id,community_id,user_id,minutes_before) values($1,$2,$3,15)`,[event,group,owner]));
await assert.rejects(db.query('select * from claim_calendar_reminders()'));
await db.query('select register_app_push_device($1,$2,$3)',['calendar-test-device-token','Handy','android']);
await as(outsider);
assert.equal((await db.query('select * from community_calendar_events')).rows.length,0);
assert.equal((await db.query('select * from community_calendar_presets')).rows.length,0);
await db.exec('reset role');
let claims=(await db.query('select * from claim_calendar_reminders()')).rows;
assert.equal(claims.length,1); assert.equal(claims[0].user_id,reader);
assert.equal((await db.query('select * from claim_calendar_reminders()')).rows.length,0);
// Rescheduling into the future cancels eligibility; the new date can remind later.
await db.query(`update community_calendar_events set starts_at=now()+interval '2 days' where id=$1`,[event]);
assert.equal((await db.query('select * from claim_calendar_reminders()')).rows.length,0);
await db.query(`update community_calendar_events set starts_at=now()+interval '5 minutes' where id=$1`,[event]);
assert.equal((await db.query('select * from claim_calendar_reminders()')).rows.length,1);
await db.query('delete from community_members where community_id=$1 and user_id=$2',[group,reader]);
assert.equal((await db.query('select * from community_calendar_reminders')).rows.length,0);
await db.query(`update community_calendar_events set starts_at=now()+interval '3 minutes' where id=$1`,[event]);
assert.equal((await db.query('select * from claim_calendar_reminders()')).rows.length,0);
await db.query('delete from community_calendar_events where id=$1',[event]);
assert.equal((await db.query('select * from community_calendar_deliveries')).rows.length,0);
await db.close();
console.log('PASS calendar: permissions, own opt-in, private tokens, due times, deduplication, rescheduling, removal and deletion.');
