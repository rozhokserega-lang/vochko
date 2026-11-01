begin;
create schema if not exists vochko_private;
revoke all on schema vochko_private from public, anon, authenticated;
create table if not exists vochko_private.players (
 id uuid primary key,
 nickname text not null check (char_length(nickname) between 3 and 20),
 secret_hash text not null,
 created_at timestamptz not null default now()
);
create table if not exists vochko_private.endless_runs (
 id uuid primary key,
 player_id uuid not null references vochko_private.players(id),
 rules_version integer not null default 2 check (rules_version = 2),
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 battles integer check (battles between 0 and 1000),
 points bigint check (points between 0 and 9000000000000),
 best_seat bigint check (best_seat between 0 and 9000000000000)
);
create index if not exists endless_runs_player on vochko_private.endless_runs(player_id);
alter table vochko_private.players enable row level security;
alter table vochko_private.endless_runs enable row level security;
revoke all on all tables in schema vochko_private from public, anon, authenticated;

create or replace function public.vochko_register(p_player_id uuid,p_secret text,p_nickname text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare n text := btrim(regexp_replace(p_nickname,'\s+',' ','g')); h text;
begin
 if p_player_id is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then raise exception 'Invalid player credential'; end if;
 if n is null or char_length(n) not between 3 and 20 or n !~ '^[[:alnum:] _-]+$' then raise exception 'Invalid nickname'; end if;
 h := encode(sha256(convert_to(p_secret,'UTF8')),'hex');
 insert into vochko_private.players(id,nickname,secret_hash) values(p_player_id,n,h) on conflict(id) do nothing;
 if not exists(select 1 from vochko_private.players where id=p_player_id and secret_hash=h) then raise exception 'Invalid player credential'; end if;
 return jsonb_build_object('player_id',p_player_id,'nickname',(select nickname from vochko_private.players where id=p_player_id));
end; $$;

create or replace function public.vochko_start_run(p_player_id uuid,p_secret text,p_run_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if not exists(select 1 from vochko_private.players where id=p_player_id and secret_hash=encode(sha256(convert_to(p_secret,'UTF8')),'hex')) then raise exception 'Invalid player credential'; end if;
 if p_run_id is null then raise exception 'Invalid run'; end if;
 insert into vochko_private.endless_runs(id,player_id) values(p_run_id,p_player_id) on conflict(id) do nothing;
 if not exists(select 1 from vochko_private.endless_runs where id=p_run_id and player_id=p_player_id) then raise exception 'Invalid run owner'; end if;
 return jsonb_build_object('run_id',p_run_id);
end; $$;

create or replace function public.vochko_finish_run(p_player_id uuid,p_secret text,p_run_id uuid,p_battles integer,p_points bigint,p_best_seat bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r vochko_private.endless_runs%rowtype;
begin
 if not exists(select 1 from vochko_private.players where id=p_player_id and secret_hash=encode(sha256(convert_to(p_secret,'UTF8')),'hex')) then raise exception 'Invalid player credential'; end if;
 if p_battles is null or p_battles not between 0 and 1000 or p_points is null or p_points not between 0 and 9000000000000 or p_best_seat is null or p_best_seat not between 0 and 9000000000000 or p_best_seat>p_points then raise exception 'Invalid score'; end if;
 select * into r from vochko_private.endless_runs where id=p_run_id and player_id=p_player_id for update;
 if not found then raise exception 'Run not started'; end if;
 if r.finished_at is not null then
  if (r.battles,r.points,r.best_seat) is distinct from (p_battles,p_points,p_best_seat) then raise exception 'Result already submitted'; end if;
 else
  update vochko_private.endless_runs set battles=p_battles,points=p_points,best_seat=p_best_seat,finished_at=now() where id=p_run_id;
 end if;
 return jsonb_build_object('saved',true);
end; $$;

create or replace function public.vochko_leaderboard(p_player_id uuid default null)
returns jsonb language sql security definer set search_path = '' as $$
 with best as (
  select distinct on (r.player_id) r.player_id,p.nickname,r.battles,r.points,r.finished_at
  from vochko_private.endless_runs r join vochko_private.players p on p.id=r.player_id
  where r.finished_at is not null and r.battles>0
  order by r.player_id,r.battles desc,r.points desc,r.finished_at,r.id
 ), ranked as (
  select row_number() over(order by battles desc,points desc,finished_at,player_id) as place,* from best
 )
 select jsonb_build_object('total',(select count(*) from ranked),
 'entries',coalesce((select jsonb_agg(to_jsonb(t) order by t.place) from (select place,nickname,battles,points,player_id=p_player_id as is_me from ranked order by place limit 100) t),'[]'::jsonb),
 'me',(select jsonb_build_object('place',place,'nickname',nickname,'battles',battles,'points',points) from ranked where player_id=p_player_id));
$$;
revoke all on function public.vochko_register(uuid,text,text) from public;
revoke all on function public.vochko_start_run(uuid,text,uuid) from public;
revoke all on function public.vochko_finish_run(uuid,text,uuid,integer,bigint,bigint) from public;
revoke all on function public.vochko_leaderboard(uuid) from public;
grant execute on function public.vochko_register(uuid,text,text) to anon,authenticated;
grant execute on function public.vochko_start_run(uuid,text,uuid) to anon,authenticated;
grant execute on function public.vochko_finish_run(uuid,text,uuid,integer,bigint,bigint) to anon,authenticated;
grant execute on function public.vochko_leaderboard(uuid) to anon,authenticated;
commit;
