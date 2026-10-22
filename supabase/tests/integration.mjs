import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
const status = process.env.BETWEEN_LOCAL_STATUS ? JSON.parse(readFileSync(process.env.BETWEEN_LOCAL_STATUS,'utf8')) : {};
const url=process.env.SUPABASE_URL??status.API_URL??'http://127.0.0.1:54321';
assert.match(url,/^http:\/\/(127\.0\.0\.1|localhost):54321$/,'This destructive fixture runner is LOCAL ONLY.');
const key=process.env.SUPABASE_PUBLISHABLE_KEY??status.PUBLISHABLE_KEY??status.ANON_KEY;
const secret=process.env.SUPABASE_SERVICE_ROLE_KEY??status.SERVICE_ROLE_KEY;
assert.ok(key&&secret,'Supply local status JSON or local-only keys via env.');
const options={auth:{persistSession:false,autoRefreshToken:false}};
const admin=createClient(url,secret,options);const accounts=[];let passed=0;let channel;
function sql(query){return execFileSync('docker',['exec','-i','supabase_db_Between','psql','-U','postgres','-At','-v','ON_ERROR_STOP=1'],{input:query,encoding:'utf8'}).trim();}
async function test(name,fn){await fn();passed++;console.log(`PASS ${name}`);}
async function account(name){
 const email=`between-${name}-${randomUUID()}@example.test`,password=randomUUID()+'Aa1!';
 const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true});assert.equal(error,null);accounts.push(data.user.id);
 const a=createClient(url,key,options),b=createClient(url,key,options);
 const one=await a.auth.signInWithPassword({email,password}),two=await b.auth.signInWithPassword({email,password});assert.equal(one.error,null);assert.equal(two.error,null);
 return {id:data.user.id,a,b,one:one.data.session,two:two.data.session};
}
async function api(path,{token,method='GET',body}={}){
 const r=await fetch(url+'/functions/v1/between-api/'+path,{method,headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
 return {status:r.status,body:await r.json()};
}
const payload=(placeID='marston',zoneID=null)=>({placeID,zoneID,seat:1,noise:null,idempotencyKey:randomUUID(),reconfirmedAt:new Date().toISOString()});
try{
 const alice=await account('a'),bob=await account('b'),limiter=await account('limits'),deleting=await account('deleting');
 await test('guest catalog and private write protection',async()=>{
  assert.equal((await api('catalog')).body.length,6);
  assert.equal((await api('reports',{method:'POST',body:payload()})).status,401);
  const guest=createClient(url,key,options);
  assert.ok((await guest.rpc('submit_observation',{p_author:alice.id})).error);
  assert.ok((await guest.from('places').update({active:false}).eq('id','marston')).error);
  assert.ok((await alice.a.schema('private').from('reports').select('*')).error);
  assert.ok((await alice.a.rpc('read_summaries',{p_viewer:bob.id})).error);
 });
 let receipt;
 await test('simultaneous idempotency across independent sessions',async()=>{
  const body=payload();body.author=bob.id;body.acceptedAt='2099-01-01T00:00:00Z';body.nearby=true;body.moderationState='approved';
  const answers=await Promise.all(Array.from({length:8},(_,i)=>api('reports',{method:'POST',token:i%2?alice.one.access_token:alice.two.access_token,body})));
  for(const answer of answers)assert.equal(answer.status,200,JSON.stringify(answer.body));
  receipt=answers[0].body;assert.ok(answers.every(a=>a.body.id===receipt.id&&a.body.acceptedAt===receipt.acceptedAt));
  assert.equal(receipt.nearby,false);
  const lateDuplicate=await api('reports',{method:'POST',token:alice.one.access_token,body:{...body,reconfirmedAt:'2000-01-01T00:00:00Z'}});assert.equal(lateDuplicate.body.id,receipt.id);assert.equal(lateDuplicate.body.acceptedAt,receipt.acceptedAt);assert.ok(Date.now()-Date.parse(receipt.acceptedAt)<10000);
  assert.equal(sql(`select count(*) from private.reports where author='${alice.id}';`),'1');
  const mine=await api('reports/mine',{token:bob.one.access_token});assert.equal(mine.body.length,0);
 });
 await test('per-scope rate limit cannot race across sessions',async()=>{
  const values=await Promise.all([api('reports',{method:'POST',token:alice.one.access_token,body:payload('west')}),api('reports',{method:'POST',token:alice.two.access_token,body:payload('west')})]);
  assert.deepEqual(values.map(v=>v.status).sort(),[200,429]);assert.ok(values.find(v=>v.status===429).body.retryAfter>0);
 });
 await test('invalid scope, zone, enum, stale draft, and body limit rejected',async()=>{
  for(const body of [payload('unknown'),payload('marston','west-4'),{...payload(),seat:8}])assert.equal((await api('reports',{method:'POST',token:bob.one.access_token,body})).status,400);
  assert.equal((await api('reports',{method:'POST',token:bob.one.access_token,body:{...payload(),reconfirmedAt:new Date(Date.now()-180000).toISOString()}})).status,409);
  assert.equal((await api('reports',{method:'POST',token:bob.one.access_token,body:{...payload(),extra:'x'.repeat(5000)}})).status,413);
 });
 await test('two-client Realtime invalidation and persistent aggregate',async()=>{
  const started=Date.now();let resolve, readyResolve; const ready=new Promise(r=>readyResolve=r);
  const event=new Promise(r=>resolve=r);
  channel=bob.a.channel('between-integration-'+randomUUID()).on('system',{},p=>{if(p.status==='ok'&&p.extension==='postgres_changes')readyResolve();}).on('postgres_changes',{event:'UPDATE',schema:'public',table:'status_versions',filter:'campus_id=eq.uf'},()=>resolve(Date.now()));
  await new Promise((resolve,reject)=>{channel.subscribe(s=>{if(s==='SUBSCRIBED')resolve();if(['CHANNEL_ERROR','TIMED_OUT'].includes(s))reject(new Error(s));});setTimeout(()=>reject(new Error('Realtime subscribe timeout')),10000).unref();});
  await Promise.race([ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Postgres subscription was not ready')),10000).unref())]);
  const body=payload('smathers');const sent=Date.now();assert.equal((await api('reports',{method:'POST',token:alice.one.access_token,body})).status,200);
  const observed=await Promise.race([event,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Realtime propagation >15s')),15000).unref())]);
  assert.ok(observed-sent<15000);console.log(`MEASURE realtime invalidation ${observed-sent} ms`);
  const other=await api('summaries',{token:bob.one.access_token});assert.ok(other.body.evidence.some(e=>e.placeID==='smathers'&&e.reporters>=1));
  const restarted=await api('summaries');assert.ok(restarted.body.evidence.some(e=>e.placeID==='smathers'));
  assert.ok(!JSON.stringify(other.body).includes(alice.id));assert.ok(Date.now()-started<20000);
  await bob.a.removeChannel(channel);channel=null;
 });
 await test('viewer blocks, flags, and moderation affect aggregates privately',async()=>{
  assert.equal((await api('feedback',{method:'POST',token:bob.one.access_token,body:{reference:receipt.id,action:'flag'}})).status,200);
  assert.equal((await api('feedback',{method:'POST',token:bob.one.access_token,body:{reference:receipt.id,action:'block'}})).status,200);
  const personalized=await api('summaries',{token:bob.one.access_token});assert.ok(!personalized.body.evidence.some(e=>e.placeID==='marston'));
  assert.ok((await api('summaries')).body.evidence.some(e=>e.placeID==='marston'));
  const removed=await admin.rpc('moderate_report',{p_reference:receipt.id,p_action:'remove',p_operator:'local-integration'});assert.equal(removed.error,null);
  assert.ok(!(await api('summaries')).body.evidence.some(e=>e.placeID==='marston'));
  assert.ok((await alice.a.rpc('moderate_report',{p_reference:receipt.id,p_action:'restore',p_operator:'self-appointed'})).error);
  assert.equal((await admin.rpc('moderate_report',{p_reference:receipt.id,p_action:'suspend',p_operator:'local-integration'})).error,null);
  assert.equal((await api('reports',{method:'POST',token:alice.one.access_token,body:payload('education')})).status,403);
 });
 await test('hourly global limit serialized across distinct scopes and sessions',async()=>{
  for(let i=0;i<21;i++)sql(`insert into public.zones(id,place_id,document) values('test-limit-${i}','marston','{}') on conflict do nothing;`);
  const answers=await Promise.all(Array.from({length:21},(_,i)=>api('reports',{method:'POST',token:i%2?limiter.one.access_token:limiter.two.access_token,body:payload('marston',`test-limit-${i}`)})));
  assert.equal(answers.filter(v=>v.status===200).length,20);assert.equal(answers.filter(v=>v.status===429).length,1);
 });
 await test('server expiry, deduplication and scope separation',async()=>{
  sql(`update private.reports set accepted_at=now()-interval '31 minutes' where author='${limiter.id}';`);
  assert.ok(!(await api('summaries')).body.evidence.some(e=>e.zoneID?.startsWith('test-limit-')));
  // Deletion of expired data cannot be used to bypass an hourly limit within the rolling hour.
  assert.equal((await api('reports',{method:'POST',token:limiter.one.access_token,body:payload('marston','marston-4')})).status,429);
 });
 await test('deletion eligibility gate, cascades and old-token rejection',async()=>{
  const before=await api('reports',{method:'POST',token:deleting.one.access_token,body:payload('education')});assert.equal(before.status,200);
  const claims=JSON.parse(Buffer.from(deleting.one.access_token.split('.')[1],'base64url').toString());
  assert.equal((await admin.rpc('begin_account_deletion',{p_author:deleting.id,p_session:claims.session_id})).error,null);
  assert.equal((await api('reports',{method:'POST',token:deleting.two.access_token,body:payload('afa')})).status,403);
  assert.equal((await admin.auth.admin.deleteUser(deleting.id)).error,null);
  assert.ok([401,403].includes((await api('reports',{method:'POST',token:deleting.one.access_token,body:payload('afa')})).status));
  assert.equal(sql(`select count(*) from private.reports where author='${deleting.id}';`),'0');
  assert.ok((await deleting.a.auth.refreshSession({refresh_token:deleting.one.refresh_token})).error);
 });
 console.log(`RESULT ${passed} backend integration groups passed. Apple revocation not exercised; local Auth test users use password sessions.`);
}finally{
 if(channel)await channel.unsubscribe();
 for(const id of accounts)await admin.auth.admin.deleteUser(id);
 sql("delete from public.zones where id like 'test-limit-%';");
}
