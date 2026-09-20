# P14-T208 — Runtime RLS Negative/Positive Verification

## Scope

This milestone verifies the runtime behavior of the locked Supabase RLS model using rollback-scoped pgTAP coverage.

The verification covers:

- anonymous direct-read denial;
- authenticated operational read access for an active sales user;
- authenticated self-profile isolation;
- admin-only visibility for audit and historical-import tables;
- direct authenticated INSERT/UPDATE/DELETE denial;
- active admin access to operational and admin-only data; and
- loss of role-derived access when a profile is deactivated.

## Test method

`supabase/tests/database/120_rls_runtime_verification.sql` creates deterministic test identities and rows inside one transaction, exercises the database under `anon`, `authenticated`, and `postgres` roles, and rolls all test data back.

No production business data is used or modified by this test artifact.

## Gate interpretation

Passing this test establishes repository/local-database runtime evidence for the covered RLS policies. It does not by itself prove production control-plane configuration, external penetration-test coverage, or production credential correctness.
