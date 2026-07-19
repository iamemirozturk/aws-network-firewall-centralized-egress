# ADR 004: Block UDP/443 in this reference policy

## Decision

Drop UDP destination port 443 before stateful inspection.

## Rationale

The repository's hostname controls are designed for TCP-based HTTP/TLS processing. Blocking UDP/443 prevents QUIC from taking a different inspection path and may force compatible clients to use TCP.

## Consequence

Some applications may degrade or fail. This is a deliberate policy choice that must be tested, not a universal recommendation.
