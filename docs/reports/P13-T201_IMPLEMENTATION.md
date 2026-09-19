# P13-T201 Implementation Note

The operational reporting layer is implemented as three read-only PostgreSQL views aligned to the locked Phase 13 report specifications. Date, state, city, customer, shipper, tracking, outcome, and identifier filtering remains server-side by querying these projections with predicates. The views do not introduce unit prices, VAT, discounts, service fees, or mutable reporting state.
