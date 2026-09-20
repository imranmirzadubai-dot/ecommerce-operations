# P14-T225 Restore Testing Checklist

This checklist is intentionally deterministic and does not execute a restore.

- [ ] Target explicitly identified as non-production.
- [ ] Source artifact SHA-256 verified before restore.
- [ ] Export archive enumerates successfully with `pg_restore --list`.
- [ ] PostgreSQL target version compatibility confirmed.
- [ ] Restore completed with a successful exit status.
- [ ] Expected schemas validated.
- [ ] Expected tables validated.
- [ ] Expected functions/views validated where included.
- [ ] Expected constraints validated.
- [ ] Expected indexes validated.
- [ ] Representative row/object counts reconciled to source evidence.
- [ ] Read-only application/report checks completed against isolated target where supported.
- [ ] Restore duration recorded.
- [ ] RPO/RTO measurements recorded only from actual evidence.
- [ ] Recovery evidence retained without secrets.
- [ ] Disposable target destroyed/reset after testing.

A checked box requires corresponding evidence. Do not mark this checklist complete merely because the runbook exists.
