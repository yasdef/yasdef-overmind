## ADDED Requirements

### Requirement: Task-to-BR performs a focused source-obligation review
Before completing step 4.1, the Task-to-BR model SHALL inspect every explicit business obligation in the captured source for unresolved information that can change observable behavior or acceptance.

#### Scenario: Source obligation is fully specified
- **WHEN** the source states an actor, trigger, guard, outcome, and required result with no material business decision left open
- **THEN** Task-to-BR SHALL represent that obligation in `feature_br_summary.md` without creating a redundant clarification question

#### Scenario: Source obligation leaves a material decision open
- **WHEN** two reasonable answers to missing source information would change an actor, guard, allowed or rejected outcome, state transition, persisted result, returned data, scope boundary, or acceptance verification
- **THEN** Task-to-BR SHALL create a targeted `rised=false` question in `missing_br_data.md` and leave every affected unresolved BR field `[UNFILLED]`

### Requirement: Clarification questions are relevant and consolidated
Task-to-BR SHALL create one business question per independent unresolved decision, consolidate repeated statements of the same fact, and exclude questions already answered by the source or limited to technical implementation.

#### Scenario: One fact is repeated across BR fields
- **WHEN** one unresolved business decision is restated in several generated BR fields
- **THEN** Task-to-BR SHALL create one ledger item whose existing multi-field `source=` locator names every affected field

#### Scenario: Source already answers a candidate question
- **WHEN** the source explicitly defines the candidate business decision, including in an adjacent acceptance criterion or scope statement
- **THEN** Task-to-BR SHALL preserve that answer and SHALL NOT create a clarification question for it

#### Scenario: Ambiguous wording is descriptive but bounded
- **WHEN** a potentially ambiguous word describes a capability whose exact accepted behavior is already enumerated by the source
- **THEN** Task-to-BR SHALL NOT create a question solely because that word appears

### Requirement: Lexical validation remains a bounded backstop
The configured TypeScript ambiguity-token check SHALL remain a deterministic backstop over generated BR business fields, while the Task-to-BR skill MUST complete source-obligation review independently of whether that lexical check reports a problem.

#### Scenario: Ambiguity token survives in generated BR
- **WHEN** a configured ambiguity token remains in a scanned generated BR field without matching clarification evidence
- **THEN** the existing task-to-BR gate SHALL return its current recoverable diagnostic

#### Scenario: Source ambiguity is paraphrased in generated BR
- **WHEN** the model paraphrases an acceptance-affecting source ambiguity so no configured token remains in the generated BR
- **THEN** the Task-to-BR semantic review SHALL still externalize the unresolved business decision to the existing ledger

### Requirement: Existing clarification workflow remains the consumer
Task-to-BR SHALL use the existing `missing_br_data.md` format and SHALL leave step 4.2 responsible for asking and recording answers to the ledger items it receives.

#### Scenario: Task-to-BR produces pending questions
- **WHEN** step 4.1 completes with one or more `rised=false` items
- **THEN** step 4.2 SHALL ask those items through its existing sequential clarification protocol without a new discovery phase or artifact

### Requirement: Behavioral acceptance demonstrates stable material-question recovery
The change SHALL remain behaviorally incomplete until one complete acceptance batch of three clean runs of the identical measured UMSS source recovers the known material questions in every run.

#### Scenario: Measured UMSS acceptance run
- **WHEN** the candidate Task-to-BR skill processes the identical UMSS source with the configured model settings in a clean installed workspace
- **THEN** the resulting ledger SHALL ask about valid Telegram-data criteria, the outcome when new-identity creation encounters an inconsistent pre-existing OFFCHAIN_POINTS account without a corresponding identity, and the under-specified frontend error response

#### Scenario: Acceptance run raises an additional material question
- **WHEN** a run asks an additional question, including whether total registered-user counts include identities without an ACTIVE OFFCHAIN_POINTS account
- **THEN** the evaluator SHALL apply the same behavioral-impact materiality rule and SHALL NOT reject the run solely because the legacy run did not ask that question

#### Scenario: Initial acceptance batch has a partial result
- **WHEN** any run in the initial three-run batch misses one of the three required material decisions
- **THEN** the batch SHALL fail, the missed source obligation SHALL drive a skill or example correction, contract verification SHALL be rerun, and one fresh three-run batch SHALL replace rather than extend the failed batch

#### Scenario: Replacement acceptance batch still has a partial result
- **WHEN** any run in the replacement three-run batch misses one of the three required material decisions
- **THEN** behavioral acceptance SHALL remain incomplete and the owner SHALL explicitly decide the next disposition before the acceptance rule is changed or another batch is run

#### Scenario: CRP-173 implementation order
- **WHEN** CRP-172 behavioral acceptance is executed before or after CRP-173 implementation
- **THEN** CRP-172 SHALL be evaluated only from step 4.1 outputs and SHALL NOT depend on step 5.1 execution

#### Scenario: Contract tests pass before behavioral rerun
- **WHEN** unit and installer tests prove that the semantic contract is authored and deployed but the repeated model rerun has not completed
- **THEN** the behavioral acceptance task SHALL remain incomplete
