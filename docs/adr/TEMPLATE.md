# ADR NNNN: <Decision in a few words>

<!--
Copy this file to `NNNN-<slug>.md`, with the next free number. Keep every section.
Write short sentences. Prefer a table to prose.
An ADR that implements a roadmap decision names its roadmap ID in Status (for example "roadmap ADR-001").
-->

## Status

Proposed | Accepted on YYYY-MM-DD (<task ID>, #<issue>). Roadmap ID: ADR-NNN, if any.

Amended on YYYY-MM-DD (#<issue>): <what changed>. See [<section>](#<anchor>).

Superseded by [ADR NNNN](NNNN-<slug>.md) on YYYY-MM-DD.

## Context

<Why a decision is necessary now. The constraints, each with its source: App Review guideline, technote, roadmap item, earlier ADR.>

| Constraint | Source |
|---|---|
| <constraint> | <guideline, TN, ADR, issue> |

Trust boundary: <the boundary that this decision protects, as named in [THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries)>.

| Threat | Example |
|---|---|
| T1: <threat> | <concrete abuse case> |

## Decision

### D1: <Decision> (T1)

<What we do. Name each threat that the decision addresses. Later tickets cite `ADR NNNN D1`.>

## Alternatives considered

- **<Alternative>.** <Why it is attractive.> Rejected (<threat or cost>).

## Consequences

- <What becomes easier, harder or required. Open items with their owner issue.>

## Validation

Each check proves that the decision holds. A decision without a check states why no check is possible, and which manual step replaces it.

| Check | Kind | Scope | Decision |
|---|---|---|---|
| <`SomeTests`, `scripts/<name>`, App Store Connect validation, manual step> | Test, script, upload, review | <What it inspects> | D1 |
