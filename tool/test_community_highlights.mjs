import { PGlite } from '../build/rbac_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
const owner='11111111-1111-1111-1111-111111111111', manager='22222222-2222-2222-2222-222222222222', reader='33333333-3333-3333-3333-333333333333';
const group='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', other='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
await db.exec(`create role authenticated;create role anon;create schema auth;create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon;
alter default privileges in schema public grant all on tables to authenticated;`);
for (const file of ['supabase/schema.sql','supabase/migrations/202609210001_manual_community_members.sql',
  'supabase/migrations/202609220001_account_devices.sql','supabase/migrations/202609230001_community_devices.sql',
  'supabase/migrations/202610020001_community_permissions.sql','supabase/migrations/202610030005_community_highlights.sql']) await db.exec(await readFile(file,'utf8'));
await db.exec(`insert into auth.users values('${owner}'),('${manager}'),('${reader}');
insert into player_profiles(id,user_id,display_name) values('${owner}','${owner}','Owner'),('${manager}','${manager}','Manager'),('${reader}','${reader}','Reader');
insert into communities(id,owner_user_id,name,invite_code) values('${group}','${owner}','Club','CODE123'),('${other}','${reader}','Other','OTHER12');
insert into community_members(community_id,user_id,role) values('${group}','${owner}','owner'),('${group}','${manager}','member'),('${group}','${reader}','member'),('${other}','${reader}','owner');`);
async function as(user) { await db.exec(`reset role;select set_config('request.jwt.claim.sub','${user}',false);set role authenticated;`); }
const insert=(community=group)=>db.query(`insert into community_highlights(community_id,highlight_key,category,title,value,occurred_at,updated_by)
 values($1,'manual:1','checkout','Finish','170',now(),$2) returning *`,[community,reader]);
await as(reader); await assert.rejects(insert());
await as(owner);
const rights=(await db.query('select community_permissions($1) as p',[group])).rows[0].p;
assert.ok(rights.includes('manage_highlights')); assert.ok(rights.includes('manage_rankings'));
const role=(await db.query(`insert into community_roles(community_id,name,permissions) values($1,'Highlights',array['manage_highlights']) returning id`,[group])).rows[0].id;
await db.query('select assign_community_role($1,$2,$3)',[group,manager,role]);
await as(manager);
const record=(await insert()).rows[0]; assert.equal(record.updated_by,manager);
await db.query(`update community_highlights set title='Korrektur',value='160' where community_id=$1`,[group]);
await db.query(`update community_highlights set deleted=true where community_id=$1`,[group]);
assert.equal((await db.query(`select deleted from community_highlights where community_id=$1`,[group])).rows[0].deleted,true);
await assert.rejects(insert(other));
await assert.rejects(db.query(`update community_highlights set community_id=$1`,[other]));
await assert.rejects(db.query(`update community_highlights set category='invalid'`));
await assert.rejects(db.query(`update community_highlights set title=''`));
await assert.rejects(db.query('delete from community_highlights'));
await as(reader);
assert.equal((await db.query('select * from community_highlights')).rows.length,1);
assert.equal((await db.query(`update community_highlights set title='Denied' returning *`)).rows.length,0);
await as(owner); await db.query('select assign_community_role($1,$2,$3)',[group,manager,null]);
await as(manager);
assert.equal((await db.query(`update community_highlights set deleted=false returning *`)).rows.length,0);
await db.exec('reset role'); await db.query('delete from community_members where community_id=$1 and user_id=$2',[group,manager]);
await as(manager); assert.equal((await db.query('select * from community_highlights')).rows.length,0);
await db.exec('reset role;set role anon'); await assert.rejects(db.query('select * from community_highlights'));
await db.close(); console.log('PASS highlights: dedicated rights, delegated edits/deletions, revocation, RLS, community isolation, field validation and unforgeable audit actor.');
