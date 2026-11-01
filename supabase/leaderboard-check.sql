-- Run in SQL Editor. All fixtures are rolled back; no test scores are published.
begin;
set local role anon;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();r uuid:=gen_random_uuid();r2 uuid:=gen_random_uuid();j jsonb;ja jsonb;jb jsonb;denied boolean:=false;
begin
 perform public.vochko_register(a,repeat('a',64),'Проверка_А');
 perform public.vochko_register(b,repeat('b',64),'Проверка_Б');
 perform public.vochko_start_run(a,repeat('a',64),r);
 perform public.vochko_finish_run(a,repeat('a',64),r,12,48000,5000);
 perform public.vochko_finish_run(a,repeat('a',64),r,12,48000,5000);
 perform public.vochko_start_run(b,repeat('b',64),r2);
 perform public.vochko_finish_run(b,repeat('b',64),r2,12,50000,6000);
 ja:=public.vochko_leaderboard(a);jb:=public.vochko_leaderboard(b);
 if (ja->'me'->>'battles')::integer<>12 or (ja->'me'->>'place')::bigint<=(jb->'me'->>'place')::bigint then raise exception 'Ranking failed';end if;
 begin perform public.vochko_start_run(a,repeat('c',64),gen_random_uuid());exception when others then denied:=true;end;
 if not denied then raise exception 'Wrong credential accepted';end if;denied:=false;
 begin perform public.vochko_finish_run(b,repeat('b',64),r,1,200,100);exception when others then denied:=true;end;
 if not denied then raise exception 'Wrong owner accepted';end if;denied:=false;
 begin perform public.vochko_finish_run(a,repeat('a',64),r,99,200000,20000);exception when others then denied:=true;end;
 if not denied then raise exception 'Final score overwritten';end if;
 begin perform 1 from vochko_private.players;raise exception 'Private table exposed';exception when insufficient_privilege then null;end;
end $$;
rollback;
