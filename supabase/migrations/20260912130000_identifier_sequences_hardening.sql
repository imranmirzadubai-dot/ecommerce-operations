begin;

create sequence if not exists public.customer_code_seq;
create sequence if not exists public.order_number_seq;
create sequence if not exists public.parcel_number_seq;

alter sequence public.customer_code_seq no cycle;
alter sequence public.order_number_seq no cycle;
alter sequence public.parcel_number_seq no cycle;

revoke all on sequence public.customer_code_seq from anon;
revoke all on sequence public.customer_code_seq from authenticated;
revoke all on sequence public.order_number_seq from anon;
revoke all on sequence public.order_number_seq from authenticated;
revoke all on sequence public.parcel_number_seq from anon;
revoke all on sequence public.parcel_number_seq from authenticated;

commit;
