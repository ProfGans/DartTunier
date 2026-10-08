import { PGlite } from '../build/rbac_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
const [owner,creator,director,reporter,viewer,outsider] = [1,2,3,4,5,6].map(i=>`${i}`.repeat(8)+'-'+`${i}`.repeat(4)+'-'+`${i}`.repeat(4)+'-'+`${i}`.repeat(4)+'-'+`${i}`.repeat(12));
const group='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
await db.exec(`create role authenticated; create role anon; create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon;
grant execute on function auth.uid() to authenticated,anon;
alter default privileges in schema public grant all on tables to authenticated;`);
for (const path of ['supabase/schema.sql','supabase/migrations/202609210001_manual_community_members.sql',
 'supabase/migrations/202609220001_account_devices.sql','supabase/migrations/202609230001_community_devices.sql',
 'supabase/migrations/202610020001_community_permissions.sql','supabase/migrations/20261008120000_tournament_access.sql']) {
 await db.exec(await readFile(path,'utf8'));
}
for (const user of [owner,creator,director,reporter,viewer,outsider]) {
 await db.query('insert into auth.users values($1)',[user]);
 await db.query('insert into public.player_profiles(id,user_id,display_name) values($1,$1,$2)',[user,user]);
}
await db.query(`insert into public.communities(id,owner_user_id,name,invite_code) values($1,$2,'Club','ABCD1234')`,[group,owner]);
for (const user of [owner,creator,director,reporter,viewer]) await db.query(`insert into public.community_members(community_id,user_id,role) values($1,$2,$3)`,[group,user,user===owner?'owner':'member']);
async function as(user) { await db.exec(`reset role; select set_config('request.jwt.claim.sub','${user}',false); set role authenticated;`); }
async function read() { return (await db.query(`select payload from public.tournaments where client_tournament_id='access-test'`)).rows[0].payload; }
async function save(p) { return db.query('select public.save_community_tournament_v2($1)',[p]); }
async function rejected(action) { await assert.rejects(action); }
await as(owner);
const role=(await db.query(`insert into public.community_roles(community_id,name,permissions) values($1,'Erstellen',array['create_tournaments']) returning id`,[group])).rows[0].id;
await db.query('select public.assign_community_role($1,$2,$3)',[group,creator,role]);
await as(creator);
const match = {homePlayer:{name:'Anna'},awayPlayer:{name:'Ben'},round:1,homeLegs:null,awayLegs:null,homeSets:null,awaySets:null,isAnnulled:false,startedAt:null,finishedAt:null};
const payload={id:'access-test',name:'Test',communityId:group,players:[],stages:[{gameFormat:{bestOfLegs:3,bestOfSets:1}}],
 runStages:[{groups:[{matches:[match,{...match,round:2}]}]}],boardCount:1,activeStageIndex:0,completedStageIndexes:[],
 access:{creatorUserId:creator,directorUserIds:[director],resultEntryMode:'selected',resultUserIds:[reporter]}};
await save(payload);
let p=await read();
assert.equal(p.access.creatorUserId,creator); assert.equal(p.syncRevision,1);
await save({...p,blockedBoards:[1]}); // creator has no community lead/edit right
await as(director); p=await read();
await save({...p,blockedBoards:[]});
await rejected(()=>save({...p,name:'Not allowed'}));
p=await read();
await rejected(()=>save({...p,access:{...p.access,directorUserIds:[director,viewer]}}));
await rejected(()=>save({...p,access:{...p.access,creatorUserId:director}}));
await as(viewer); p=await read();
await rejected(()=>save({...p,activeStageIndex:1}));
const path=['runStages','0','groups','0','matches','0'];
async function report(score,which=path,home=match.homePlayer) { return db.query('select public.submit_tournament_result($1,$2,$3,$4,$5,$6) as p',['access-test',which,home,match.awayPlayer,null,score]); }
await rejected(()=>report({homeLegs:2,awayLegs:0}));
await as(outsider); await rejected(()=>report({homeLegs:2,awayLegs:0}));
await as(reporter);
assert.equal((await db.query(`update public.tournaments set payload=$1 where client_tournament_id='access-test' returning id`,[p])).rows.length,0);
await rejected(()=>report({homeLegs:99,awayLegs:0}));
await rejected(()=>report({homeLegs:2,awayLegs:0},['access','directorUserIds']));
await rejected(()=>report({homeLegs:2,awayLegs:0},path,{name:'Changed'}));
const result=(await report({homeLegs:2,awayLegs:0})).rows[0].p;
assert.equal(result.runStages[0].groups[0].matches[0].homeLegs,2);
assert.equal(result.runStages[0].groups[0].matches[1].homeLegs,null);
assert.equal(result.activeStageIndex,0);
await rejected(()=>report({homeLegs:2,awayLegs:1})); // no corrections
await as(director); await rejected(()=>save(p)); // stale snapshot cannot erase reported result
await as(creator); p=await read();
await save({...p,access:{...p.access,resultEntryMode:'directors'}});
await as(reporter); await rejected(()=>report({homeLegs:2,awayLegs:0},[...path.slice(0,-1),'1']));
await as(creator); p=await read(); await save({...p,access:{...p.access,resultEntryMode:'members'}});
await as(viewer); await report({homeLegs:2,awayLegs:1},[...path.slice(0,-1),'1']);
await as(owner);
await db.query(`delete from public.community_members where community_id=$1 and user_id=$2`,[group,director]);
await as(director); await rejected(()=>save(p)); // stale assignment cannot restore membership
await as(creator); p=await read();
await rejected(()=>save({...p,access:{...p.access,directorUserIds:[outsider]}}));
await save({...p,access:{...p.access,directorUserIds:[]}});
// Even a configuration editor with reporting rights cannot report past stages.
await as(owner);
const editorRole=(await db.query(`insert into public.community_roles(community_id,name,permissions) values($1,'Konfiguration',array['edit_tournaments']) returning id`,[group])).rows[0].id;
await db.query('select public.assign_community_role($1,$2,$3)',[group,reporter,editorRole]);
await as(creator); p=await read();
await save({...p, activeStageIndex:1, completedStageIndexes:[0],
 stages:[...p.stages,p.stages[0]], runStages:[{groups:[{matches:[match]}]},{groups:[{matches:[match]}]}]});
await as(reporter); p=await read();
const tampered=structuredClone(p);
Object.assign(tampered.runStages[0].groups[0].matches[0],{homeLegs:2,awayLegs:0,finishedAt:'2026-10-08T12:00:00Z'});
await rejected(()=>save(tampered));
await rejected(()=>report({homeLegs:2,awayLegs:0}));
await report({homeLegs:2,awayLegs:0},['runStages','1','groups','0','matches','0']);
console.log('Tournament access: creator, assigned director, reader, reporter, revocation, score validation and conflict tests passed.');
await db.close();

