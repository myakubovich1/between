create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
grant usage on schema private to service_role;
create table public.places(id text primary key,campus_id text not null default 'uf' check(campus_id='uf'),document jsonb not null,active boolean not null default true);
create table public.zones(id text primary key,place_id text not null references public.places(id),document jsonb not null,active boolean not null default true);
create table public.status_versions(campus_id text primary key check(campus_id='uf'),version bigint not null default 0);
insert into public.status_versions(campus_id) values('uf');
create table private.contributor_controls(user_id uuid primary key references auth.users(id) on delete cascade,suspended boolean not null default false,deleting boolean not null default false);
create table private.reports(
 id uuid primary key default gen_random_uuid(),author uuid not null references auth.users(id) on delete cascade,
 place_id text not null references public.places(id),zone_id text references public.zones(id),
 seat smallint not null check(seat between 0 and 3),noise smallint check(noise between 0 and 2),
 accepted_at timestamptz not null default clock_timestamp(),nearby boolean not null default false,
 removed boolean not null default false,idempotency_key uuid not null,unique(author,idempotency_key));
create index reports_author_time on private.reports(author,accepted_at desc);
create index reports_scope_time on private.reports(place_id,zone_id,accepted_at desc);
create table private.blocks(viewer uuid not null references auth.users(id) on delete cascade,target uuid not null references auth.users(id) on delete cascade,primary key(viewer,target),check(viewer<>target));
create table private.flags(reporter uuid not null references auth.users(id) on delete cascade,report_id uuid not null references private.reports(id) on delete cascade,created_at timestamptz not null default clock_timestamp(),primary key(reporter,report_id));
create table private.moderation_audit(id bigint generated always as identity primary key,operated_at timestamptz not null default clock_timestamp(),operator_name text not null,action text not null check(action in ('remove','suspend','restore')),operation_reference uuid not null);
alter table public.places enable row level security;
alter table public.zones enable row level security;
alter table public.status_versions enable row level security;
alter table private.reports enable row level security;
alter table private.blocks enable row level security;
alter table private.flags enable row level security;
alter table private.contributor_controls enable row level security;
alter table private.moderation_audit enable row level security;
revoke all on public.places,public.zones,public.status_versions from anon,authenticated;
grant select on public.places,public.zones,public.status_versions to anon,authenticated;
grant all on public.places,public.zones,public.status_versions to service_role;
grant all on all tables in schema private to service_role;
grant usage,select on all sequences in schema private to service_role;
create policy catalog_read on public.places for select to anon,authenticated using(active);
create policy zone_read on public.zones for select to anon,authenticated using(active and exists(select 1 from public.places p where p.id=place_id and p.active));
create policy safe_version_read on public.status_versions for select to anon,authenticated using(campus_id='uf');
-- All private records intentionally have NO anon/authenticated grants or policies.
create function private.invalidate() returns trigger language plpgsql security invoker set search_path='' as $$begin update public.status_versions set version=version+1 where campus_id='uf'; return null; end$$;
revoke all on function private.invalidate() from public,anon,authenticated;
create trigger reports_changed after insert or update or delete on private.reports for each statement execute function private.invalidate();
create trigger controls_changed after insert or update or delete on private.contributor_controls for each statement execute function private.invalidate();
create trigger blocks_changed after insert or update or delete on private.blocks for each statement execute function private.invalidate();

-- Service-only invoker RPC. Token validation and author/session derivation happen in Edge.
create function public.submit_observation(p_author uuid,p_session uuid,p_place text,p_zone text,p_seat integer,p_noise integer,p_key uuid,p_nearby boolean)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r private.reports;t timestamptz;retry_seconds integer;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_author::text,0)); t:=clock_timestamp();
 if not exists(select 1 from auth.users where id=p_author and deleted_at is null) or not exists(select 1 from auth.sessions where id=p_session and user_id=p_author) or exists(select 1 from private.contributor_controls where user_id=p_author and (suspended or deleting)) then raise exception 'account_ineligible'; end if;
 if p_seat is null or p_seat not between 0 and 3 or (p_noise is not null and p_noise not between 0 and 2) or p_key is null then raise exception 'invalid_observation'; end if;
 if not exists(select 1 from public.places where id=p_place and active) or (p_zone is not null and not exists(select 1 from public.zones where id=p_zone and place_id=p_place and active)) then raise exception 'invalid_scope'; end if;
 select * into r from private.reports where author=p_author and idempotency_key=p_key;
 if found then return jsonb_build_object('id',r.id,'acceptedAt',r.accepted_at,'nearby',r.nearby); end if;
 select greatest(1,ceil(extract(epoch from max(accepted_at)+interval '5 minutes'-t))::integer) into retry_seconds from private.reports where author=p_author and place_id=p_place and zone_id is not distinct from p_zone and accepted_at>t-interval '5 minutes' having count(*)>0;
 if retry_seconds is not null then raise exception 'rate_limit:%',retry_seconds; end if;
 if (select count(*) from private.reports where author=p_author and accepted_at>t-interval '1 hour')>=20 then
 select greatest(1,ceil(extract(epoch from min(accepted_at)+interval '1 hour'-t))::integer) into retry_seconds from private.reports where author=p_author and accepted_at>t-interval '1 hour'; raise exception 'rate_limit:%',retry_seconds; end if;
 insert into private.reports(author,place_id,zone_id,seat,noise,idempotency_key,nearby,accepted_at) values(p_author,p_place,p_zone,p_seat,p_noise,p_key,coalesce(p_nearby,false),t) returning * into r;
 return jsonb_build_object('id',r.id,'acceptedAt',r.accepted_at,'nearby',r.nearby);
end$$;
revoke all on function public.submit_observation(uuid,uuid,text,text,integer,integer,uuid,boolean) from public,anon,authenticated;
grant execute on function public.submit_observation(uuid,uuid,text,text,integer,integer,uuid,boolean) to service_role;

create function public.read_summaries(p_viewer uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$
with latest as (
 select distinct on(r.author,r.place_id,r.zone_id) r.*,(case when r.nearby then 1.0 else 0.5 end)*power(2.0,-extract(epoch from(now()-r.accepted_at))/600.0) w
 from private.reports r join public.places p on p.id=r.place_id and p.active left join private.contributor_controls c on c.user_id=r.author
 where not coalesce(c.suspended,false) and not coalesce(c.deleting,false) and r.accepted_at>now()-interval '30 minutes' and r.accepted_at<=now()
 and not exists(select 1 from private.blocks b where b.viewer=p_viewer and b.target=r.author)
 order by r.author,r.place_id,r.zone_id,r.accepted_at desc,r.id desc
),effective as (select * from latest where not removed),totals as (
 select place_id,zone_id,count(*) reporters,sum(w) total,sum(w) filter(where seat<2) low_weight,sum(w) filter(where seat>=2) high_weight,max(accepted_at) newest,min(accepted_at)+interval '30 minutes' expiry,jsonb_agg(id order by id) refs from effective group by place_id,zone_id
),seats as (select place_id,zone_id,seat,sum(w) w from effective group by place_id,zone_id,seat),
seat_running as (select *,sum(w) over(partition by place_id,zone_id order by seat rows unbounded preceding) cumulative from seats),
sounds as (select place_id,zone_id,noise,sum(w) w from effective where noise is not null group by place_id,zone_id,noise),
sound_running as (select *,sum(w) over(partition by place_id,zone_id order by noise rows unbounded preceding) cumulative,sum(w) over(partition by place_id,zone_id) total from sounds),
result as (select jsonb_build_object('placeID',t.place_id,'zoneID',t.zone_id,
'seat',(select min(s.seat) from seat_running s where s.place_id=t.place_id and s.zone_id is not distinct from t.zone_id and s.cumulative+1e-12>=t.total/2),
'noise',(select min(s.noise) from sound_running s where s.place_id=t.place_id and s.zone_id is not distinct from t.zone_id and s.cumulative+1e-12>=s.total/2),
'differs',t.reporters>=2 and coalesce(t.low_weight,0)/t.total>=0.30 and coalesce(t.high_weight,0)/t.total>=0.30,
'reporters',t.reporters,'newestAt',t.newest,'evaluatedAt',now(),'expiresAt',t.expiry,'references',t.refs) evidence from totals t)
select jsonb_build_object('evidence',coalesce(jsonb_agg(evidence),'[]'::jsonb)) from result$$;
revoke all on function public.read_summaries(uuid) from public,anon,authenticated;
grant execute on function public.read_summaries(uuid) to service_role;

create function public.my_observations(p_author uuid,p_session uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$begin
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_author) then raise exception 'account_ineligible'; end if;
 return(select coalesce(jsonb_agg(x),'[]'::jsonb) from(select id,place_id as "placeID",zone_id as "zoneID",seat,accepted_at as "acceptedAt" from private.reports where author=p_author order by accepted_at desc limit 100)x);
end$$;
revoke all on function public.my_observations(uuid,uuid) from public,anon,authenticated;
grant execute on function public.my_observations(uuid,uuid) to service_role;
create function public.report_feedback(p_author uuid,p_session uuid,p_reference uuid,p_action text) returns jsonb language plpgsql security invoker set search_path='' as $$declare target uuid;begin
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_author) or exists(select 1 from private.contributor_controls where user_id=p_author and(suspended or deleting)) then raise exception 'account_ineligible'; end if;
 select author into target from private.reports where id=p_reference and not removed and accepted_at>now()-interval '30 minutes';
 if target is null or target=p_author then raise exception 'invalid_reference'; end if;
 if p_action='block' then insert into private.blocks(viewer,target) values(p_author,target) on conflict do nothing;
 elsif p_action='flag' then insert into private.flags(reporter,report_id) values(p_author,p_reference) on conflict do nothing;
 else raise exception 'invalid_action'; end if;return '{"ok":true}'::jsonb;end$$;
revoke all on function public.report_feedback(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.report_feedback(uuid,uuid,uuid,text) to service_role;
create function public.begin_account_deletion(p_author uuid,p_session uuid) returns jsonb language plpgsql security invoker set search_path='' as $$begin
 perform pg_advisory_xact_lock(hashtextextended(p_author::text,0));
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_author) then raise exception 'account_ineligible';end if;
 insert into private.contributor_controls(user_id,deleting) values(p_author,true) on conflict(user_id) do update set deleting=true;return '{"ok":true}'::jsonb;end$$;
revoke all on function public.begin_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.begin_account_deletion(uuid,uuid) to service_role;
create function public.moderate_report(p_reference uuid,p_action text,p_operator text) returns jsonb language plpgsql security invoker set search_path='' as $$declare target uuid;begin
 if length(p_operator) not between 1 and 120 then raise exception 'operator_required';end if;
 select author into target from private.reports where id=p_reference;if target is null then raise exception 'invalid_reference';end if;
 if p_action='remove' then update private.reports set removed=true where id=p_reference;
 elsif p_action in('suspend','restore') then insert into private.contributor_controls(user_id,suspended) values(target,p_action='suspend') on conflict(user_id) do update set suspended=excluded.suspended;
 else raise exception 'invalid_action';end if;
 insert into private.moderation_audit(operator_name,action,operation_reference) values(p_operator,p_action,p_reference);return '{"ok":true}'::jsonb;end$$;
revoke all on function public.moderate_report(uuid,text,text) from public,anon,authenticated;
grant execute on function public.moderate_report(uuid,text,text) to service_role;
alter publication supabase_realtime add table public.status_versions;
create extension if not exists pg_cron;
select cron.schedule('between-expire-private-reports','7 * * * *', $$delete from private.reports where accepted_at<now()-interval '24 hours'$$);
-- Service-only session/account eligibility reads; Auth schema is not exposed by Data API.
grant usage on schema auth to service_role;
grant select(id,deleted_at) on auth.users to service_role;
grant select(id,user_id) on auth.sessions to service_role;
-- Auth hard-deletion runs cascade triggers as supabase_auth_admin. Give that server
-- role only the safe invalidation counter privileges; no client gains these rights.
grant usage on schema public to supabase_auth_admin;
grant select(campus_id,version),update(version) on public.status_versions to supabase_auth_admin;
create policy auth_cascade_counter_read on public.status_versions for select to supabase_auth_admin using(campus_id='uf');
create policy auth_cascade_counter_update on public.status_versions for update to supabase_auth_admin using(campus_id='uf') with check(campus_id='uf');

create function public.existing_receipt(p_author uuid,p_session uuid,p_key uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$declare r private.reports;begin
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_author) or exists(select 1 from private.contributor_controls where user_id=p_author and(suspended or deleting)) then raise exception 'account_ineligible';end if;
 select * into r from private.reports where author=p_author and idempotency_key=p_key;
 if not found then return null;end if;
 return jsonb_build_object('id',r.id,'acceptedAt',r.accepted_at,'nearby',r.nearby);
end$$;
revoke all on function public.existing_receipt(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.existing_receipt(uuid,uuid,uuid) to service_role;
create function public.review_flags() returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]'::jsonb) from(select r.id,r.place_id,r.zone_id,r.seat,r.accepted_at,count(*) as flags from private.flags f join private.reports r on r.id=f.report_id where not r.removed group by r.id order by count(*) desc,r.accepted_at desc limit 100)x;
$$;
revoke all on function public.review_flags() from public,anon,authenticated;
grant execute on function public.review_flags() to service_role;
select cron.schedule('between-trim-moderation-audit','12 3 * * *', $$delete from private.moderation_audit where operated_at<now()-interval '90 days'$$);
