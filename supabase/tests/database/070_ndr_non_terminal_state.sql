-- P10-T149: NDR must remain non-terminal while terminal parcel states stay terminal.

select plan(10);

select ok(
  to_regprocedure('public.is_terminal_parcel_state(text)') is not null,
  'terminal parcel state classifier exists'
);

select is(
  public.is_terminal_parcel_state('NDR'),
  false,
  'NDR is explicitly non-terminal'
);

select is(
  public.is_terminal_parcel_state('In Transit'),
  false,
  'In Transit is non-terminal'
);

select is(
  public.is_terminal_parcel_state('Delivered'),
  true,
  'Delivered is terminal'
);

select is(
  public.is_terminal_parcel_state('RTO'),
  true,
  'RTO is terminal'
);

select is(
  public.is_terminal_parcel_state('Lost'),
  true,
  'Lost is terminal'
);

select is(
  public.is_terminal_parcel_state('Damaged'),
  true,
  'Damaged is terminal'
);

select is(
  public.is_terminal_parcel_state('Cancelled'),
  true,
  'Cancelled is terminal'
);

select ok(
  pg_get_functiondef('public.is_terminal_parcel_state(text)'::regprocedure) like '%NDR%'
    and pg_get_functiondef('public.is_terminal_parcel_state(text)'::regprocedure) like '%Delivered%'
    and pg_get_functiondef('public.is_terminal_parcel_state(text)'::regprocedure) like '%RTO%',
  'classifier explicitly defines NDR separately from terminal outcomes'
);

select ok(
  has_function_privilege('authenticated','public.is_terminal_parcel_state(text)','EXECUTE'),
  'authenticated users can evaluate the lifecycle classifier'
);

select * from finish();
