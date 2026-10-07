import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
await db.exec(`
create role anon;
create role authenticated;
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb not null default '{}');
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
`);
await db.exec(await fs.readFile(new URL('../../supabase/migrations/20261028000100_backend_foundation.sql', import.meta.url),'utf8'));
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
await db.query("insert into auth.users values ($1,'{\"display_name\":\"Student A\"}'),($2,'{\"display_name\":\"Student B\",\"role\":\"organiser\"}')",[a,b]);
async function asUser(id) {
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id??'']);
 await db.exec('set role '+(id?'authenticated':'anon'));
}
async function rejected(sql,params=[],code='42501') {
 await assert.rejects(()=>db.query(sql,params), e=>e.code===code);
}
await asUser(null);
await rejected('select * from public.groups');
await rejected('select public.my_group_overview()');
await asUser(a);
await rejected("select public.create_group('   ',$1)",['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'],'22023');
const request='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const created=await db.query("select public.create_group('Project Circle',$1) as id",[request]);
const gid=created.rows[0].id;
const replay=await db.query("select public.create_group('Project Circle',$1) as id",[request]);
assert.equal(replay.rows[0].id,gid);
assert.equal((await db.query('select * from public.groups')).rows.length,1);
await rejected("select public.create_group('Different',$1)",[request],'22023');
let ctx=(await db.query('select public.group_context($1) as data',[gid])).rows[0].data;
assert.equal(ctx.members.length,1);
assert.equal(ctx.group.holder_id,a);
assert.equal(ctx.group.member_count,1);
const code=ctx.invite_code;
assert.match(code,/^[A-Z0-9]{12}$/);
await asUser(b);
assert.equal((await db.query('select * from public.groups')).rows.length,0);
assert.equal((await db.query('select * from public.profiles where id=$1',[a])).rows.length,0);
await rejected('select public.group_context($1)',[gid]);
await rejected("insert into public.memberships(group_id,user_id,role) values($1,$2,'organiser')",[gid,b]);
await rejected('update public.spark_states set holder_id=$1 where group_id=$2',[b,gid]);
await rejected("select public.request_to_join('NOTVALIDCODE')",[],'22023');
await db.query('select public.request_to_join($1)',[code.toLowerCase()]);
await db.query('select public.request_to_join($1)',[code]);
let req=(await db.query('select * from public.join_requests')).rows;
assert.equal(req.length,1);
assert.equal(req[0].status,'pending');
await rejected('select public.group_context($1)',[gid]);
await rejected('select public.approve_join_request($1)',[req[0].id]);
assert.equal((await db.query('select * from public.memberships')).rows.length,0);
await asUser(a);
await db.query('select public.approve_join_request($1)',[req[0].id]);
await db.query('select public.approve_join_request($1)',[req[0].id]);
ctx=(await db.query('select public.group_context($1) as data',[gid])).rows[0].data;
assert.equal(ctx.members.length,2);
assert.equal(ctx.group.holder_id,a);
await asUser(b);
ctx=(await db.query('select public.group_context($1) as data',[gid])).rows[0].data;
assert.equal(ctx.members.length,2);
assert.equal(ctx.invite_code,null);
await rejected('select public.approve_join_request($1)',[req[0].id]);
assert.equal((await db.query('select * from public.invite_codes')).rows.length,0);
await asUser(a);
await db.exec('reset role');
assert.equal((await db.query('select count(*)::int n from public.groups')).rows[0].n,1);
assert.equal((await db.query('select count(*)::int n from public.spark_states')).rows[0].n,1);
assert.equal((await db.query("select count(*)::int n from public.memberships where role='organiser'")).rows[0].n,1);
console.log('PostgreSQL migration and access checks passed: anonymous access, private reads, role forgery, pending requests, approval, replay and holder invariants.');
await db.close();
