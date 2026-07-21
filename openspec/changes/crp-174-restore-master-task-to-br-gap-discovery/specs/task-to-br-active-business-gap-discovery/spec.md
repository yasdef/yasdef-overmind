## ADDED Requirements

### Requirement: Task-to-BR actively discovers business gaps
Before completing step 4.1, the Task-to-BR model SHALL read the captured story and current BR and externalize every relevant business detail that remains unresolved or that it cannot state confidently from the available business input.

#### Scenario: Business outcome remains open
- **WHEN** the source establishes a rule but leaves more than one reasonable business outcome open
- **THEN** Task-to-BR SHALL create a targeted clarification question instead of selecting or inventing an outcome

#### Scenario: User-visible wording is low-confidence
- **WHEN** the source requires a user-visible result using wording such as `simple`, `appropriate`, or another imprecise description that does not make the intended result concrete
- **THEN** Task-to-BR SHALL create a targeted business question about the intended result

#### Scenario: Business detail is stated clearly
- **WHEN** the available business input states a detail clearly enough to record without inference
- **THEN** Task-to-BR SHALL represent that detail in `feature_br_summary.md` without creating a redundant question for the same fact

### Requirement: Discovery remains concise and business-focused
Task-to-BR SHALL create one targeted question per independent business gap and SHALL restrict discovery to business intent, actors, access, scope, rules, inputs, outputs, states, failures, and user-visible outcomes.

#### Scenario: One gap affects several BR fields
- **WHEN** one unresolved business detail affects several fields in `feature_br_summary.md`
- **THEN** Task-to-BR SHALL create one ledger item whose existing `source=` locator names every affected field

#### Scenario: Choice is technical implementation
- **WHEN** an open choice concerns architecture, framework, deployment, code structure, or another technical implementation detail
- **THEN** Task-to-BR SHALL exclude that choice from business clarification

### Requirement: Discovered gaps use the existing clarification ledger
For every discovered business gap, Task-to-BR SHALL use the existing `missing_br_data.md` format, create the item with `rised=false`, and leave each affected unresolved BR field `[UNFILLED]` until step 4.2 records the operator's answer.

#### Scenario: Step 4.1 discovers a gap
- **WHEN** Task-to-BR cannot fill a relevant business detail confidently
- **THEN** it SHALL create a gap-free `rised_item_N` entry with a targeted `unresolved_item`, an accurate `source=` locator, and `rised=false`

#### Scenario: Step 4.2 receives pending items
- **WHEN** step 4.1 completes with one or more `rised=false` ledger items
- **THEN** the existing step 4.2 clarification flow SHALL ask and record those items without a new discovery phase or artifact

### Requirement: Semantic discovery remains model-owned
The Task-to-BR validator SHALL validate deterministic artifact, source-binding, ledger, and terminal-state contracts and SHALL NOT use a closed lexical token list to decide whether business clarification is complete.

#### Scenario: Ambiguous token appears in a generated BR field
- **WHEN** a generated BR field contains a word such as `simple`
- **THEN** the gate result SHALL be determined by the surviving structural and ledger contracts rather than by the word itself

#### Scenario: Semantic gap exists without a configured token
- **WHEN** the story leaves a relevant business decision unresolved without using a known ambiguity word
- **THEN** the Task-to-BR model SHALL still externalize the gap through active business judgment

### Requirement: Current runtime contracts remain stable
The restoration SHALL preserve current Task-to-BR capture and context commands, raw-source binding, allowed-write surface, source-reference handling, Jira and linked-artifact behavior, ledger syntax, terminal-state rules, and gate exit-code meanings.

#### Scenario: Task-to-BR runs after restoration
- **WHEN** the installed Task-to-BR skill processes a captured source
- **THEN** it SHALL use the existing artifacts and commands and SHALL introduce no new phase, artifact, state, command, or CLI option

### Requirement: Examples illustrate quality without defining policy
Task-to-BR golden examples SHALL demonstrate useful active-gap questions but SHALL remain reference examples rather than a required question catalog or exact-output baseline.

#### Scenario: Story domain differs from the golden example
- **WHEN** a source contains different business gaps from those illustrated in the golden example
- **THEN** Task-to-BR SHALL discover questions from that source rather than reproduce the example's wording, count, or categories mechanically
