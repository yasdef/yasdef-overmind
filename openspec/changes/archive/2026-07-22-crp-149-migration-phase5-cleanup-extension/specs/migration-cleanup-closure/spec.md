## ADDED Requirements

### Requirement: Orphaned shell helpers and staging entries are removed behind a no-active-reference audit

This change SHALL remove `overmind/scripts/common_libs` helpers, their `STAGED_COMMAND_LIB_FILES` staging entries in `project_setup_first_init_machine.sh`, and their dedicated shell tests when the helper has no remaining functional production consumer after Slices 0–4. Liveness SHALL be judged by functional production consumers only — an active runtime/setup/update script that sources, executes as a child process, or otherwise invokes the helper — and SHALL explicitly exclude the candidate's own staging entry and its own dedicated test suite, which are the plumbing being deleted with it. Helpers with at least one functional production consumer SHALL be retained.

#### Scenario: A helper with no functional consumer is removed
- **WHEN** the audit shows a `common_libs` helper is neither sourced, executed, nor otherwise invoked by any active runtime, setup, or update script — counting neither its own `STAGED_COMMAND_LIB_FILES` entry nor its own dedicated test as a consumer
- **THEN** the helper file, its staging entry, and its dedicated shell tests are deleted in this change

#### Scenario: An executed helper is retained
- **WHEN** an active script invokes a `common_libs` helper as an executable child process (for example `feature_assing_workers.sh` running `check_implementation_plan_readiness.sh`) rather than sourcing it
- **THEN** that helper counts as live, is retained with its staging entry, and the audit records the invoking consumer

#### Scenario: Removal leaves the runtime green
- **WHEN** the orphan removal is complete
- **THEN** the surviving `tests/ai_scripts/*.sh` suites and `npm run verify` pass, and no active operator-facing invocation surface references a deleted helper (cleanup regression tests naming the removed helper are exempt, as with tombstones)

### Requirement: Removing a staged helper cleans it from deployed workspaces

Deleting a helper from source and from `STAGED_COMMAND_LIB_FILES` SHALL NOT strand its already-staged copy in existing workspaces. `stage_command_libs()` only copies configured files and performs no removal, so this change SHALL add an update-mode cleanup for removed command libs via an **explicit `OBSOLETE_STAGED_COMMAND_LIB_FILES` tombstone list** (analogous to `OBSOLETE_STAGED_COMMAND_FILES`) that removes exactly the named stale staged libs from the workspace. The cleanup SHALL delete only tombstoned filenames; it SHALL NOT blanket-sweep every staged lib that is not in the managed set, because the staged `common_libs` directory currently preserves unmanaged content (it has no unmanaged-file removal today, unlike support-asset staging) and is not defined as a package-owned directory. A destructive managed-manifest sweep MAY be used only if this change first establishes an explicit ownership contract declaring the staged `common_libs` directory package-owned; absent that contract, tombstones are the required mechanism. Every command lib removed in this change SHALL be tombstoned, and a direct-upgrade regression test SHALL prove a workspace staged before the removal has the stale helper deleted after update mode. Tombstone entries follow the same retain-until-proven rule as the command tombstones.

#### Scenario: Update mode removes a tombstoned staged helper
- **WHEN** a workspace was staged with a helper that this change removes and tombstones, and it later runs update mode
- **THEN** the update-mode cleanup deletes the stale staged copy of that named helper from the workspace, leaving no orphaned executable behind

#### Scenario: Unmanaged operator files are preserved
- **WHEN** the staged `common_libs` directory contains an operator-placed file that is neither managed nor tombstoned
- **THEN** the cleanup leaves it untouched, because removal is by explicit tombstone, not a blanket "not in the managed set" sweep

#### Scenario: Direct-upgrade cleanup is regression-tested
- **WHEN** the removal lands
- **THEN** a test stages the old helper into a fixture workspace, runs update mode, and asserts the helper is gone — and this test is allowed to name the removed helper despite the no-reference sweep

#### Scenario: Still-managed helpers are not removed
- **WHEN** update mode runs
- **THEN** it removes only tombstoned filenames and never deletes a helper still listed in `STAGED_COMMAND_LIB_FILES`

### Requirement: Obsolete-command staging tombstones are retained

This change SHALL retain the `OBSOLETE_STAGED_COMMAND_FILES` tombstone entries in `project_setup_first_init_machine.sh` for scripts deleted in earlier slices. These entries delete already-staged legacy scripts from a deployed workspace during update mode, and no mechanism proves every deployed workspace has already passed through their cleanup; removing them would let a workspace upgrading directly from an older release keep executable legacy scripts staged. Tombstones MAY be pruned only if a versioned workspace-migration mechanism proves the cleanup already ran everywhere, which is not in scope here.

#### Scenario: A direct upgrade still removes legacy staged scripts
- **WHEN** a workspace that never received an intermediate-slice update runs update mode after this change
- **THEN** the retained `OBSOLETE_STAGED_COMMAND_FILES` tombstones still delete the corresponding legacy `.commands/*.sh` scripts from that workspace

#### Scenario: Tombstones are not pruned without a migration proof
- **WHEN** the cleanup considers removing an `OBSOLETE_STAGED_COMMAND_FILES` entry
- **THEN** it retains the entry because no versioned mechanism proves every deployed workspace already cleaned up that script

### Requirement: Versioned operator docs carry no dead references to deleted flows

This change SHALL sweep the versioned operator docs — root `README.md` (the file the migration plan's `overmind/README.md` reference resolves to, since no `overmind/README.md` exists), `QUICKRUN.md`, and repository command references — for mentions of deleted shell scripts, stale entrypoints, and superseded workflows, replacing or removing each so the versioned docs describe only the shipped `overmind` verbs and surviving scripts. The sweep SHALL cover the known-stale legacy-reconciliation references in `README.md` (deferred-class attach and `project_contract_reconciliation.sh`/`persist_class_repo_attach.sh` "separate legacy staged flow" language, and "until ... project reconcile lands in Slice 4" notes) now that `overmind project reconcile` has shipped.

#### Scenario: No active operator-facing doc names a deleted script
- **WHEN** the doc sweep is complete
- **THEN** no active operator-facing documentation or invocation guidance in `README.md`, `QUICKRUN.md`, or repository command references presents `init_progress_scanner.sh`, `project_add_feature_e2e.sh`, `feature_br_scaffold.sh`, `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, or any other Slice 1–4 deleted script as a runnable step

#### Scenario: Cleanup tombstones and historical records are exempt
- **WHEN** a deleted-script name still appears in an `OBSOLETE_STAGED_COMMAND_FILES` tombstone, an archived change, a design/migration doc's historical narrative, or another non-operator-facing record
- **THEN** that occurrence is left in place, because the assertion targets active operator-facing guidance only and the tombstones must keep naming those scripts to remove them from deployed workspaces

#### Scenario: AGENTS.md is updated when conventions shift
- **WHEN** the cleanup changes a canonical test command, path, or convention recorded in `AGENTS.md`
- **THEN** `AGENTS.md` is updated in this same change to match

### Requirement: Extension design docs are revised to the shipped overmind verbs

This change SHALL revise `design_docs/overmind_vscode_extention/requirements_ears.md`, `technical_requirements.md`, and `implementation_plan.md` so every `.commands/*.sh` launching surface is replaced by the shipped `overmind` verbs and in-process core per `03_target_architecture.md ### Supersession of the extension design docs`, and the supersession banners are removed. The revision SHALL cover the Requirement 7 clauses, the Requirement 9 verification, the Run Scanner / Create Feature / Continue E2E actions, the script allow-list, and scanner freshness/stale-state caveats. Run Scanner and stale scanner state SHALL be replaced by fresh in-process `sequencing/` recomputation: manual refresh and file watching may trigger recomputation, but no terminal scanner action or persisted stale scanner state remains. Because the old `Create Project` terminal action has no shipped coordinator primitive or `overmind` verb, the revised docs SHALL remove it from the executable action plan and record it as postponed until such a shared surface exists; this change SHALL NOT invent a replacement verb or retain `.commands/project_setup_add_new_project.sh` as an extension launcher. This revision SHALL land before the minimal dashboard is implemented, so the extension is built against the corrected plan rather than the superseded `.commands/*.sh` launcher plan (`04_migration_plan.md ## Slice 5 — Cleanup + extension enablement`: "Extension implementation must not restart from the old plan before this revision lands").

#### Scenario: The revision precedes dashboard implementation
- **WHEN** the minimal read-only dashboard is implemented in this change
- **THEN** the three extension design docs have already been revised to the shipped `overmind` verbs and had their supersession banners removed, so no dashboard work derives from the old launcher plan

#### Scenario: Launcher surfaces are replaced per the mapping
- **WHEN** an extension-doc clause previously described running a `.commands/*.sh` script
- **THEN** it is rewritten to the mapped replacement in `03_target_architecture.md ### Supersession of the extension design docs` (`overmind status` / in-process `sequencing/`, `overmind scaffold feature`, terminal-hosted `overmind run`, the `overmind` verb allow-list, and coordinator-primitive mutation paths)

#### Scenario: Scanner freshness semantics are retired
- **WHEN** the extension docs describe scanner lifecycle, manual refresh, file watching, or stale readiness data
- **THEN** they describe fresh in-process `sequencing/` recomputation with no terminal Run Scanner action and no persisted stale scanner state

#### Scenario: Create Project has an explicit postponed disposition
- **WHEN** the old implementation plan's `Create Project` terminal action is revised
- **THEN** the action is removed from the executable extension plan and recorded as postponed until a shared coordinator primitive or shipped `overmind` verb exists, without retaining `.commands/project_setup_add_new_project.sh` as an extension launcher or inventing a new verb in this slice

#### Scenario: Supersession banners are removed
- **WHEN** the extension-doc revision lands
- **THEN** the supersession banners in the three extension docs are removed and no revised clause still names a deleted `.commands/*.sh` script as an extension action

#### Scenario: No stale launcher surface remains
- **WHEN** the revision is complete
- **THEN** the extension docs contain no script allow-list of `.commands/*.sh` names and no "script missing or not executable" launcher-availability contract, using instead the `overmind` CLI availability check on the bundled core

### Requirement: The formal Full parity gate is marked closed and rows 18–20 lose the detection-only caveat

This change SHALL fold the executed behavior-level sweep from `05_parity_reconciliation.md ## Sweep result — behavior-parity gate CLOSED (Slice 3)` into `02_responsibility_translation_map.md ## Full parity gate`, mark that gate closed, and retire the "detection only" caveat on responsibility rows 18–20 now that Slice 4 landed their execution tests. An audit SHALL confirm every row of `02_responsibility_translation_map.md` is marked owned-or-retired.

#### Scenario: The Full parity gate write-up is closed
- **WHEN** the closure edit lands
- **THEN** `02_responsibility_translation_map.md ## Full parity gate` records the gate as closed and references the executed Slice 3 sweep as the evidence, consistent with `05_parity_reconciliation.md ## Remaining Slice 5 CRP scope`

#### Scenario: Rows 18–20 are execution-owned
- **WHEN** the row audit runs
- **THEN** rows 18–20 point to their Slice 4 execution tests rather than a detection-only caveat, and every remaining row is marked owned by a named module or explicitly retired with a recorded decision

#### Scenario: No parity row is left unresolved
- **WHEN** the audit against `02_responsibility_translation_map.md ## Full parity gate` completes
- **THEN** no row lacks an owner-or-retired disposition, matching the "any missing row blocks the migration" discipline
