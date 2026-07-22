# Valid feature fixture (CRP-166)

A feature whose deterministic artifacts genuinely pass their own gates, used to
prove terminal repair ownership against the **real** gate registry rather than
stubbed siblings.

`implementation_plan.md` is stored **without** the template's leading
`# Implementation Plan` header, reproducing the measured migration defect. With
the fixture copied as-is, the terminal chain is expected to return exit `1` with
repair owner step `8.3` — every gate ordered before `implementation-plan` either
passes or is skipped as inapplicable. Prepending the header line makes the whole
chain exit `0`.

`init_progress_definition.yaml` belongs at the **project** level; every other
file belongs in the feature folder. Files not present here (`feature_br_summary.md`,
`feature_contract_delta.md`, the frontend/mobile surface maps, both review
ledgers) are absent on purpose so their gates report as skipped.

Consumed by `packages/asdlc-coordinator/test/terminal-regressions.test.ts` and,
across the workspace boundary, by `packages/installer/test/init.test.ts`. Keep it
mutually consistent: requirement ids flow into technical-requirement evidence
tokens and prerequisite slice refs, which the plan steps then have to cover. A
validator change that breaks this fixture is a signal worth reading, not noise to
paper over.
