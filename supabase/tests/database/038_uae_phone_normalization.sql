begin;

-- P5-T090: UAE phone normalization regression coverage.
select plan(12);

select is(public.normalize_uae_phone('0501234567'), '+971501234567', 'local UAE mobile format normalizes to +971');
select is(public.normalize_uae_phone('050 123 4567'), '+971501234567', 'formatted local UAE mobile normalizes consistently');
select is(public.normalize_uae_phone('050-123-4567'), '+971501234567', 'punctuated local UAE mobile normalizes consistently');
select is(public.normalize_uae_phone('+971501234567'), '+971501234567', 'E.164-style UAE mobile remains canonical');
select is(public.normalize_uae_phone('971501234567'), '+971501234567', '971-prefixed UAE mobile normalizes to canonical form');
select is(public.normalize_uae_phone('00971501234567'), '+971501234567', '00-prefixed UAE mobile normalizes to canonical form');
select is(public.normalize_uae_phone('04 123 4567'), '+97141234567', 'local UAE landline format normalizes to +971');
select is(public.normalize_uae_phone('+971 4 123 4567'), '+97141234567', 'formatted UAE landline normalizes consistently');
select is(public.normalize_uae_phone('12345678'), null, 'ambiguous non-UAE local number is rejected');
select is(public.normalize_uae_phone('+966501234567'), null, 'non-UAE country code is rejected');
select is(public.normalize_uae_phone('050123456'), null, 'invalid-length UAE number is rejected');
select ok((select count(*) = 1 from pg_trigger where tgname='trg_set_customer_normalized_phone' and tgrelid='public.customers'::regclass), 'customer phone trigger keeps normalized_phone synchronized');

select * from finish();
rollback;
