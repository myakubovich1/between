-- Disposable localhost verification only. Transaction rolls back every fixture.
begin;
insert into auth.users(id,email) values
('10000000-0000-4000-8000-000000000001','between-sql-a@example.test'),
('10000000-0000-4000-8000-000000000002','between-sql-b@example.test'),
('10000000-0000-4000-8000-000000000003','between-sql-c@example.test'),
('10000000-0000-4000-8000-000000000004','between-sql-viewer@example.test');
do $$
declare e jsonb; all_e jsonb;begin
insert into private.reports(id,author,place_id,seat,nearby,accepted_at,idempotency_key) values
('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','marston',0,true,now(),gen_random_uuid()),
('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','marston',3,true,now(),gen_random_uuid());
select value into e from jsonb_array_elements(public.read_summaries(null)->'evidence') where value->>'placeID'='marston' and value->>'zoneID' is null;
assert (e->>'seat')::int=0,'exact median tie chooses lower ordinal';
assert (e->>'differs')::boolean,'opposing independent reports conflict';
assert e->>'noise' is null,'missing noise stays unknown';
update private.reports set accepted_at=now()-interval '20 minutes',nearby=false where id='20000000-0000-4000-8000-000000000002';
select value into e from jsonb_array_elements(public.read_summaries(null)->'evidence') where value->>'placeID'='marston' and value->>'zoneID' is null;
assert not(e->>'differs')::boolean,'decay and presence weighting reduce opposing influence';
assert (e->>'seat')::int=0,'weighted median follows recent evidence';
delete from private.reports where id='20000000-0000-4000-8000-000000000002';
update private.reports set accepted_at=now()-interval '5 minutes' where id='20000000-0000-4000-8000-000000000001';
insert into private.reports(id,author,place_id,seat,nearby,accepted_at,idempotency_key) values('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','marston',2,true,now(),gen_random_uuid());
select value into e from jsonb_array_elements(public.read_summaries(null)->'evidence') where value->>'placeID'='marston' and value->>'zoneID' is null;
assert (e->>'reporters')::int=1 and(e->>'seat')::int=2,'latest report replaces influence without adding a person';
insert into private.reports(author,place_id,zone_id,seat,noise,nearby,accepted_at,idempotency_key) values('10000000-0000-4000-8000-000000000003','marston','marston-4',1,1,true,now(),gen_random_uuid());
select value into e from jsonb_array_elements(public.read_summaries(null)->'evidence') where value->>'zoneID'='marston-4';
assert(e->>'noise')::int=1 and(e->>'reporters')::int=1,'floor evidence remains scoped';
insert into private.blocks(viewer,target) values('10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001');
all_e:=public.read_summaries('10000000-0000-4000-8000-000000000004')->'evidence';
assert not exists(select 1 from jsonb_array_elements(all_e) where value->>'placeID'='marston' and value->>'zoneID' is null),'viewer blocks apply without identity exposure';
update private.reports set removed=true where id='20000000-0000-4000-8000-000000000003';
all_e:=public.read_summaries(null)->'evidence';
assert not exists(select 1 from jsonb_array_elements(all_e) where value->>'placeID'='marston' and value->>'zoneID' is null),'removing latest does not resurrect replaced influence';
update private.reports set accepted_at=now()-interval '30 minutes' where zone_id='marston-4';
all_e:=public.read_summaries(null)->'evidence';
assert not exists(select 1 from jsonb_array_elements(all_e) where value->>'zoneID'='marston-4'),'exact thirty-minute boundary expires without writes';
raise notice 'PASS SQL aggregation: tie, opposition, decay, presence, deduplication, missing noise, scope, blocks, moderation, expiry';
end $$;
rollback;
