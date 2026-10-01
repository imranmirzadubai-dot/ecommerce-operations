# Staging repair schema gate

The staging migration-history repair must stop on any public-schema difference except the two verified platform/representation differences documented here:

- staging-only `public.plpgsql_check` extension (v2.8), which is not present in the repository migration tree;
- `public.match_import_customers(uuid,text,text)` when its normalized function body is byte-for-byte equivalent after whitespace normalization to repository migration `20260930130000_p15_t239_match_phone_source_fix.sql`.

No other public-schema difference may be ignored. Migration-history repair is metadata-only and must never be used to conceal genuine schema drift.
