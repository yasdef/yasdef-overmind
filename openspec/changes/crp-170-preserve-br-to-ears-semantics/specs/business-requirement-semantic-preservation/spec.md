## ADDED Requirements

### Requirement: Ambiguity is externalized from every business-bearing BR field
The task-to-BR stage SHALL identify unresolved acceptance-affecting ambiguity in every populated business-bearing BR field, move the unresolved value to the existing `missing_br_data.md` ledger, and set the source field to `[UNFILLED]` for clarification. The task-to-BR gate SHALL accept a retained configured ambiguity trigger only in a field named by the `source=` locator list of a `rised=true` ledger item, and SHALL report the remaining fields as one problem per trigger.

#### Scenario: Ambiguous rejection response enters clarification
- **WHEN** `## 10. Failure Cases and Edge Cases -> rejection_cases` contains `simple non-sensitive error message` and no matching answered ledger item exists
- **THEN** task-to-BR records a `rised=false` item with that source locator, sets `rejection_cases` to `[UNFILLED]`, and the gate rejects the ambiguous populated value until it is externalized

#### Scenario: Operator-confirmed wording may remain
- **WHEN** a scanned BR field contains a configured ambiguity trigger and `missing_br_data.md` contains a matching `rised=true` item for that source locator
- **THEN** the task-to-BR gate accepts that trigger as explicitly confirmed, subject to all other quality rules

#### Scenario: A repeated trigger is one question, not one per field
- **WHEN** the same configured ambiguity trigger appears in several scanned fields because the BR restates one business fact
- **THEN** the gate reports a single problem naming those fields, and one answered `rised=true` item whose `source=` locator list names all of them clears the trigger

#### Scenario: Confirmation does not reach fields it does not name
- **WHEN** an answered `rised=true` item names one field, and the same trigger word also appears in another scanned field carrying a different business fact
- **THEN** the gate continues to report the field the item does not name

#### Scenario: Non-business fields do not trigger clarification
- **WHEN** a configured trigger appears only in Document Meta, raw source references, Existing-System Context, or Linked Artifacts
- **THEN** the deterministic ambiguity backstop does not raise a task-to-BR gate problem for that occurrence

### Requirement: Explicit source prohibitions retain their scope meaning
The task-to-BR stage SHALL record every explicit source prohibition in `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`. The stage MAY additionally record the prohibition in another relevant BR field, but an additional field alone SHALL NOT satisfy this routing requirement.

#### Scenario: Negative Definition of Done statement is routed to scope
- **WHEN** captured source input says that the feature introduces no market, ledger, forecasting, blockchain, or complex analytics behavior
- **THEN** the resulting BR summary records that prohibition in `stated_constraints` or `out_of_scope_items`, even if it also appears in `config_expectations`

### Requirement: Specific cases do not erase broader obligations
The requirements-EARS stage SHALL treat a specific rule, failure case, or example as a refinement of a broader BR requirement unless the BR summary explicitly declares the specific case exhaustive or an explicit clarification narrows the broader scope.

#### Scenario: Specific invalid-input example is additive
- **WHEN** the BR summary requires rejection of invalid Telegram user data and separately identifies a missing unique Telegram user id as a rejection case
- **THEN** the EARS output preserves the broader invalid-data rejection and the missing-id behavior without allowing the specific case to replace the broader coverage

#### Scenario: Explicitly exhaustive clarification narrows scope
- **WHEN** the BR summary records an explicit clarification that missing unique Telegram user id is the only invalid Telegram-data condition in scope
- **THEN** the EARS output may express only that clarified condition as the invalid-data rejection obligation

### Requirement: EARS conversion completes a semantic coverage sweep
Before completing, the requirements-EARS stage SHALL check every populated source area in its existing extraction map and preserve each applicable obligation in the current EARS document structure. The sweep SHALL cover functional and rejection behavior, permissions, state and integration effects, scope constraints, NFR facts, and testing and quality obligations.

#### Scenario: Scope prohibitions reach the EARS overview
- **WHEN** the BR summary contains explicit prohibitions or non-goals in `stated_constraints` or `out_of_scope_items`
- **THEN** the EARS output preserves them in `Scope` or `## Overview -> Out of scope` and also expresses them as an EARS obligation when they constrain runtime behavior

#### Scenario: Required test level reaches verification
- **WHEN** `### 12.5 Testing and quality -> required_test_levels` requires backend automated test coverage
- **THEN** the EARS output preserves that obligation in the applicable `**Verification:**` fields or in an NFR block when testing is itself a product-level obligation

#### Scenario: Existing document structure is sufficient
- **WHEN** the semantic coverage sweep completes
- **THEN** it updates only the existing `requirements_ears.md` structure and creates no additional traceability or review artifact

### Requirement: Existing workflow and gate contracts remain stable
The semantic-preservation behavior SHALL reuse the existing Task-to-BR, BR clarification, and requirements-EARS stages, artifacts, commands, templates, and gate exit codes.

#### Scenario: Recoverable ambiguity failure uses the existing gate protocol
- **WHEN** the task-to-BR gate detects a retained unconfirmed ambiguity trigger
- **THEN** it returns exit code `1` with an actionable source-field diagnostic and does not add a command, CLI option, artifact, or template field
