## ADDED Requirements

### Requirement: Coordination slices are optional and evidence-gated
The implementation slices artifact MAY include zero-or-more coordination slices. A coordination slice SHALL only be emitted when at least one of the following conditions is met: the shared contract semantics are materially ambiguous, multiple repos would otherwise implement incompatible interpretations, a concrete shared artifact must be frozen before safe parallel delivery, or a `cross_repo_contract_lock` planning signal in `technical_requirements.md` section 6 makes the drift risk explicit. The absence of any coordination slice SHALL be a valid outcome.

#### Scenario: No coordination slice when evidence is absent
- **WHEN** the feature has no planning signals in section 6 and no material cross-repo contract ambiguity is present
- **THEN** the slices artifact contains no coordination slices and the quality gate passes

#### Scenario: Coordination slice emitted when drift risk is explicit
- **WHEN** section 6 of technical requirements contains a `cross_repo_contract_lock` signal with documented ambiguity
- **THEN** the slices artifact may include a coordination slice referencing that signal, and the quality gate passes

### Requirement: Coordination slices carry a kind field and a signal_ref
Each coordination slice SHALL declare `kind: coordination` in its slice block. It SHALL also declare a non-empty `signal_ref` field identifying the upstream planning signal that justifies the coordination work. A slice with `kind: coordination` that has an empty or missing `signal_ref` SHALL fail the quality gate.

#### Scenario: Coordination slice with valid signal_ref passes quality
- **WHEN** a slice block declares `kind: coordination` and `signal_ref: signal-id-1`
- **THEN** the quality gate passes for that slice

#### Scenario: Coordination slice with missing signal_ref fails quality
- **WHEN** a slice block declares `kind: coordination` but omits `signal_ref` or sets it to empty
- **THEN** the quality gate fails with a message identifying the slice and the missing field

#### Scenario: Feature-delivery slices without kind field are unaffected
- **WHEN** a slice block has no `kind` field
- **THEN** the quality helper treats it as a feature-delivery slice and applies existing validation rules

### Requirement: Coordination plan steps are optional and only emitted when downstream work is blocked
The implementation plan MAY lift a coordination slice into a plan step only when one or more downstream implementation steps cannot safely begin without the coordination artifact being resolved. The coordination plan step SHALL be marked with `#### Coordination: true`. No coordination plan step is required merely because a coordination slice exists. The absence of any coordination plan step SHALL be a valid plan outcome.

#### Scenario: No coordination plan step when no downstream blocking
- **WHEN** a coordination slice exists but downstream implementation can proceed in parallel without the shared artifact being frozen
- **THEN** the plan contains no coordination plan step and the quality gate passes

#### Scenario: Coordination plan step emitted when downstream is blocked
- **WHEN** a coordination slice exists and at least one downstream implementation step cannot begin without the coordination artifact
- **THEN** the plan includes a coordination plan step marked `#### Coordination: true` with `#### Depends on: none` and the blocked downstream steps declare a dependency on it

### Requirement: Coordination emission triggers are narrowly defined
Neither the rules nor the quality helpers SHALL treat any of the following as sufficient justification to emit a coordination slice or coordination plan step: multi-repo feature scope alone, `delta_needed: true` in `feature_contract_delta.md` alone, shared `comp/*` evidence overlap alone, or the presence of one or more planning signals alone. Emission SHALL require at least one of the concrete conditions listed in the "Coordination slices are optional and evidence-gated" requirement above.

#### Scenario: Multi-repo scope alone does not trigger coordination
- **WHEN** a feature spans multiple repos but has no materially ambiguous shared contract, no shared-artifact freeze need, and no documented drift risk
- **THEN** no coordination slice is emitted and the quality gate passes

#### Scenario: `delta_needed: true` alone does not trigger coordination
- **WHEN** `feature_contract_delta.md` declares `delta_needed: true` but no planning signal or other evidence documents ambiguity or drift risk
- **THEN** no coordination slice is emitted and the quality gate passes

#### Scenario: Shared comp/* evidence overlap alone does not trigger coordination
- **WHEN** multiple slices reference overlapping `comp/*` evidence tokens but no upstream ambiguity is documented
- **THEN** no coordination slice is emitted and the quality gate passes

#### Scenario: Presence of a planning signal alone does not require coordination
- **WHEN** `technical_requirements.md` section 6 contains a `cross_repo_contract_lock` signal but repo-local delivery can proceed safely
- **THEN** no coordination slice is required and the quality gate passes

### Requirement: Downstream dependencies on coordination steps are per-step justified
A `#### Depends on:` edge from a downstream implementation step to a coordination plan step SHALL reflect a real per-step dependency reason. The rules SHALL NOT require or recommend applying the same coordination dependency edge to every consumer-repo step; each dependency edge SHALL be justified by that specific step's need for the coordination artifact.

#### Scenario: Dependency added only to the step that needs the coordination artifact
- **WHEN** a coordination step exists and only one of several consumer-repo steps actually needs the resolved artifact before starting
- **THEN** only that specific step declares a `#### Depends on:` edge to the coordination step and the quality gate passes

#### Scenario: Blanket dependency wiring is not required
- **WHEN** a coordination step exists and some consumer-repo steps can proceed without waiting for it
- **THEN** those steps do not declare a dependency on the coordination step and the quality gate passes

### Requirement: Quality helpers treat coordination artifact absence as valid
Neither `check_implementation_slices_quality.sh` nor `check_implementation_plan_quality.sh` SHALL fail because no coordination slice or coordination plan step is present. The quality helpers SHALL apply coordination-specific validation only when coordination artifacts are actually present in the artifact being checked.

#### Scenario: Slices quality passes with no coordination slices
- **WHEN** a valid implementation slices artifact contains only feature-delivery slices
- **THEN** the slices quality gate passes without any coordination-related error

#### Scenario: Plan quality passes with no coordination steps
- **WHEN** a valid implementation plan contains only feature-delivery steps
- **THEN** the plan quality gate passes without any coordination-related error

### Requirement: Coordination work may not displace required operator-facing delivery
A plan step marked `#### Coordination: true` SHALL NOT be the sole coverage for a required operator-facing surface identified in `prerequisite_gaps.md`. If a required surface is tracked, at least one non-coordination plan step with `#### Preserved Surface:` referencing that surface SHALL also exist.

#### Scenario: Coordination step beside required surface step passes quality
- **WHEN** a coordination step and a separate feature-delivery step both exist, and the feature-delivery step carries the preserved operator-facing surface
- **THEN** the plan quality gate passes

#### Scenario: Coordination step as sole surface coverage fails quality
- **WHEN** a coordination step is the only plan step covering a required operator-facing surface from prerequisite gaps
- **THEN** the plan quality gate fails identifying that the required surface has no non-coordination coverage

### Requirement: Implementation slices template and golden example show both valid paths
The `implementation_slices_TEMPLATE.md` SHALL document the optional `kind` and `signal_ref` fields. The golden example SHALL demonstrate both paths: one complete example where a coordination slice is present with a valid `signal_ref`, and one complete example where no coordination slice is present and the quality gate passes.

#### Scenario: Template shows kind and signal_ref as optional fields
- **WHEN** a practitioner reads the implementation slices template
- **THEN** they see `kind` and `signal_ref` fields documented with comments indicating they are optional and coordination-only

#### Scenario: Golden example with coordination slice passes quality gate
- **WHEN** the golden example containing a coordination slice is validated by the quality helper
- **THEN** the quality gate passes

#### Scenario: Golden example without coordination slice passes quality gate
- **WHEN** the golden example containing only feature-delivery slices is validated by the quality helper
- **THEN** the quality gate passes
