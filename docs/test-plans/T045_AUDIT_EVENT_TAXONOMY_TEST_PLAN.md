# T045 Audit and Event Taxonomy Verification Test Plan

## Objective

Verify that domain events and audit logs conform to the T045 taxonomy, preserve actor/entity relationships, remain append-only, and do not duplicate on idempotent retries.

## Catalog and schema tests

- **T045-01** — Verify `order_events` contains the required event identity, order/parcel relationship, actor, timestamp, notes, and metadata fields.
- **T045-02** — Verify `audit_logs` contains actor, action, entity type/id, before/after evidence, request correlation, and timestamp fields.
- **T045-03** — Verify domain events and audit logs are distinct evidence streams.
- **T045-04** — Enumerate event types written by current migrations/commands and compare them with the canonical taxonomy.
- **T045-05** — Detect event-type synonyms or unstable naming outside the canonical vocabulary.

## Behavioral tests

- **T045-06** — `create_order` produces exactly one `OrderCreated` event and corresponding audit action on successful first execution.
- **T045-07** — `confirm_order` produces exactly one `OrderConfirmed` event and corresponding audit action.
- **T045-08** — `cancel_order` produces exactly one `OrderCancelled` event and corresponding audit action.
- **T045-09** — `cancel_parcel` produces exactly one `ParcelCancelled` event and corresponding audit action.
- **T045-10** — A failed command does not leave a success event/audit record for an uncommitted mutation.
- **T045-11** — Repeating a completed command with the same actor/command/idempotency key returns the stored result without duplicate event/audit evidence.
- **T045-12** — Reusing an idempotency key with a different request is rejected without creating new evidence.

## Authorization and immutability tests

- **T045-13** — Normal application roles cannot directly update domain events.
- **T045-14** — Normal application roles cannot directly delete domain events.
- **T045-15** — Normal application roles cannot directly update audit logs.
- **T045-16** — Normal application roles cannot directly delete audit logs.
- **T045-17** — Anonymous callers cannot create protected event/audit evidence.
- **T045-18** — Event/audit actor identity reflects the authoritative authenticated actor.
- **T045-19** — Service-role backend execution preserves originating business actor when operating on behalf of a user.

## Taxonomy and metadata tests

- **T045-20** — Lifecycle events use fact-oriented names and record material `from`/`to` state context.
- **T045-21** — Event names do not encode UI screen or application role.
- **T045-22** — Event metadata and audit snapshots contain no credentials, access tokens, service-role keys, or unnecessary secrets.
- **T045-23** — Corrections append new evidence rather than overwriting historical evidence.
- **T045-24** — Reserved taxonomy values are not reported as implemented until the producing command exists and is verified.

## Completion evidence

Record the canonical taxonomy document, this test plan, current implementation comparison, representative command/event/audit evidence, and the completion commit SHA. Known Phase 3 implementation gaps remain explicitly tracked rather than silently filled during Phase 2 formalization.

## Completion rule

T045 is complete when the taxonomy contract and verification plan are version-controlled, current implemented event values are reconciled against the taxonomy, and evidence is recorded against a commit.
