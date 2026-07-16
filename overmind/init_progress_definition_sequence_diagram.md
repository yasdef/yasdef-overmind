# Init Progress Definition

Canonical end-to-end process map for the Overmind workflow (Mermaid embedded below). It is authoritative for step sequence and phase boundaries; the packaged skills under `packages/installer/_data/skills/` and their coordinator gates are authoritative for operational and quality rules. For running the workflow, see the [operator guide](README.md).

Operational note: `node .overmind/overmind.js project init --path projects/<project-id>` owns init steps 1.1 and 2 through the TypeScript coordinator and generic executor. For type A projects it commits the step 1.1 stack baseline before asking `Continue with common contract definition? [Y/n]`; yes continues into step 2, no pauses with step 2 pending and the same command resumes directly. `node .overmind/overmind.js run [--path projects/<project-id>]` runs the business requirements scaffold, resolves `feature_path`, evaluates selected-feature progress through the in-process sequencing core each run, then continues from the canonical next step (or `--resume <step>`). When `--path` is omitted, the command uses the only project under `projects/` or prompts the user to choose one. The last selected feature is cached in `projects/<project-id>/.overmind_feature_state.json`.

```mermaid
sequenceDiagram
  autonumber
  actor PO as Product Owner
  actor BE as Repo_BE
  actor FE as Repo_FE/MB
  actor KB as MDC knowledge base

  Note over PO: Business context + phase orchestration
  Note over BE, FE: surface maps split transport_layer / user_reachable_surface per layer<br/>technical_requirements.md keeps the same split per Requirement block<br/>prerequisite_gaps.md gates zero unmet before implementation_plan.md
  Note over KB: Type A: provides technical best-practices

  rect rgb(236, 244, 251)
    Note over PO,FE: Phase: init
    PO->>PO: 1. Init ASDLC metadata → init_progress_definition.yaml
    Note over PO: project_type_code records how the project started and is not read by feature-phase steps.

    alt Type A
      PO->>KB: 1.1 Request stack-family guidance per active class
      KB-->>PO: Stack-family options or unavailable
      PO->>PO: 1.1 Approve stack-family blueprints via overmind project init → project_stack_blueprint_class.md
      PO->>PO: 1.1 Approve agent guidelines derived from each blueprint → project_agents_md_claude_md_class.md
      PO->>PO: Commit finalized stack baseline
      alt Continue with common contract definition? [Y/n]
        PO->>PO: Yes/blank starts step 2 in the same invocation
      else No or closed input
        PO->>PO: Pause successfully; rerun project init to resume step 2
      end
    else Type B/C
      PO->>PO: 1.1 skipped
    end

    alt Type B/C
      par
        PO->>BE: 2.1 Request BE contract evidence
        BE-->>PO: BE contract evidence
      and
        PO->>FE: 2.2 Request FE/MB contract evidence
        FE-->>PO: FE/MB contract evidence
      end
    else Type A
      PO->>PO: 2.1 Confirm approved stack blueprints and agent guidelines are present
    end

    PO->>PO: 2.3 Common Contracts Definition via overmind project init → common_contract_definition.md
    Note over PO: Commit final repository initialization baseline: init definition + common contract + applicable stack baseline already present in HEAD.
  end

  rect rgb(247, 248, 240)
    Note over PO,FE: Phase: feature
    Note over PO,FE: Concurrency: committed sibling plans are read as promises (in-flight evidence tier).<br/>All repo scans read the default branch only — accepted work must be merged before the next feature plans against it.
    par PO track
      PO->>PO: 3. BR scaffold → feature_br_summary.md
      PO->>PO: 4.1 Scan repo + overmind-task-to-br skill → user_br_input.md
      Note over PO: Per-class gating: classes with state ready are scanned, deferred classes skipped, no-op when no class is ready.
      loop Until ready_to_ears
        PO->>PO: 4.2 BR clarification
        par For each ready class
          PO->>BE: 4.1 Request BE business-context data
          BE-->>PO: BE data
        and
          PO->>FE: 4.1 Request FE/MB business-context data
          FE-->>PO: FE/MB data
        end
        PO->>PO: 4.2 EARS readiness check
      end
      Note over PO: Ledger close-out: once every missing_br_data.md rised_item_N is rised=true, unresolved_after_stop is exactly none; pre-existing gate_result values stay as historical evidence.
      PO->>PO: 5. BR → EARS → requirements_ears.md
      opt 5.1 Optional EARS review
        loop Until no escalated findings
          PO->>PO: 5.1 Review EARS vs authoritative feature_br_summary.md + raw user_br_input.md narrowing backstop → requirements_ears_review.md
          PO->>PO: Apply accepted edits or record rejection
        end
        Note over PO: Post-session completion check: coordinator re-runs the requirements-ears gate over requirements_ears.md and the ears-review gate over requirements_ears_review.md; both must pass before 5.1 completes and checkpoints.
      end
      PO->>PO: 6. Contract delta → feature_contract_delta.md
      Note over PO: Per-class gating: classes with state ready contribute repo evidence, deferred classes skipped.
      PO-->>BE: feature_contract_delta.md
      PO-->>FE: feature_contract_delta.md
    and Technical tracks
      par
        BE->>BE: 7. BE surface map → project_surface_struct_resp_map_backend.md
        Note over BE: in: init_progress_definition.yaml + requirements_ears.md + feature_contract_delta.md + committed sibling plans.<br/>Evidence per row: repo scan (state ready) → in-flight promises → policy A blueprint planned → placeholder.<br/>Deferred policy B/C classes without repo evidence remain unavailable.<br/>All repo scans read the default branch only.
      and
        FE->>FE: 7. FE/MB surface map → project_surface_struct_resp_map_frontend/mobile.md
        Note over FE: Same inputs + committed sibling plans.<br/>Evidence per row: repo scan (state ready) → in-flight promises → policy A blueprint planned → placeholder.<br/>Deferred policy B/C classes without repo evidence remain unavailable.
      end

      opt 7.1 Optional MCP placeholder enrichment
        PO->>KB: 7.1 Query KB for candidate placeholder replacements
        KB-->>PO: Proposed values with evidence (or unavailable)
        PO->>PO: 7.1 Confirm replacements → update project_surface_struct_resp_map_class.md in place
      end

      PO->>PO: 8. Technical requirements → technical_requirements.md
      Note over PO: in: surface_map_*.md + requirements_ears.md + common_contract_definition.md

      PO->>PO: 8.1 Implementation slices → implementation_slices.md
      Note over PO: in: technical_requirements.md + requirements_ears.md + feature_contract_delta.md + surface_map_*.md

      PO->>PO: 8.2 Prerequisite gap trace → prerequisite_gaps.md
      Note over PO: in: requirements_ears.md + technical_requirements.md + implementation_slices.md — gate: zero unmet before Implementation plan

      PO->>PO: 8.3 Implementation plan → implementation_plan.md
      Note over PO: in: prerequisite_gaps.md + implementation_slices.md + technical_requirements.md + requirements_ears.md + feature_contract_delta.md

      opt 8.4 Optional semantic review
        PO->>PO: 8.4 Semantic review → implementation_plan.md + implementation_plan_semantic_review.md
        Note over PO: in: init_progress_definition.yaml + implementation_plan.md + requirements_ears.md + technical_requirements.md + prerequisite_gaps.md + surface_map_*.md
        Note over PO: Post-session completion check: coordinator re-runs the implementation-plan gate over implementation_plan.md and the plan-semantic-review gate over implementation_plan_semantic_review.md; both must pass before 8.4 completes and checkpoints.
      end

      PO->>PO: Terminal validation → gate all <feature-path>
      Note over PO: After the final optional-review decision the coordinator re-runs every applicable deterministic feature gate over the artifacts that exist. Aggregate exit 0 is required before plan completion is reported; a failure names the earliest owning step for an explicit repair resume.
    end
  end
```
