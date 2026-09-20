# P14-T226 — Recovery Drill Evidence Checks

These checks are deterministic documentation gates for recording a recovery drill. They intentionally do not execute `pg_restore` or connect to production.

## Required checks

- [ ] Unique drill ID recorded.
- [ ] Source artifact ID recorded.
- [ ] Source SHA-256 recorded and independently verified.
- [ ] Export timestamp and application commit SHA recorded.
- [ ] Migration/reference state recorded.
- [ ] Target identity explicitly verified as non-production.
- [ ] PostgreSQL target version recorded and compatibility confirmed.
- [ ] Archive inspection result recorded.
- [ ] Restore exit status recorded.
- [ ] Structural validation recorded.
- [ ] PK/unique/FK validation recorded.
- [ ] Index validation recorded.
- [ ] Representative counts recorded and compared with available source evidence.
- [ ] Read-only application checks recorded where applicable.
- [ ] Restore start/end timestamps recorded.
- [ ] RPO and RTO calculated only from actual evidence.
- [ ] Operator and approval reference recorded.
- [ ] Any failure is explicitly classified as FAILED or INCOMPLETE.

## Gate

A PASS result requires every applicable check above to have evidence. A checklist with unchecked execution evidence is not a successful restore drill.

## Safety

No production endpoint, credential, backup content, or secret belongs in this test document or repository.
