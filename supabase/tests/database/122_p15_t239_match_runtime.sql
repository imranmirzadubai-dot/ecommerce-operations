begin;
select plan(2);
select ok(position('from public.import_rows ir where ir.batch_id = p_batch_id' in lower(pg_get_functiondef(p.oid))) > 0,'match function qualifies batch_id in count queries');
select ok(position('from public.import_rows where batch_id = p_batch_id' in lower(pg_get_functiondef(p.oid))) = 0,'match function has no unqualified batch_id table reference');
select * from finish();
rollback;
