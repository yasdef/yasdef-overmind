# Init Progress Definition

Single source of truth (Mermaid embedded below).
Operational note: `node .overmind/overmind.js project init --path projects/<project-id>` owns init steps 1.1 and 2 through the TypeScript coordinator and generic executor. `node .overmind/overmind.js run [--path projects/<project-id>]` runs the business requirements scaffold, resolves `feature_path`, evaluates selected-feature progress through the in-process sequencing core each run, then continues from the canonical next step (or `--resume <step>`). When `--path` is omitted, the command uses the only project under `projects/` or prompts the user to choose one. The last selected feature is cached in `projects/<project-id>/.overmind_feature_state.json`.

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
      PO->>PO: 2.1 Read approved stack blueprints as context
    end

    PO->>PO: 2.3 Common Contracts Definition via overmind project init → common_contract_definition.md
    Note over PO: Commit the project initialization baseline: init definition + applicable stack blueprints + common contract.
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
      PO->>PO: 5. BR → EARS → requirements_ears.md
      opt 5.1 Optional EARS review
        loop Until no escalated findings
          PO->>PO: 5.1 Review EARS vs feature_br_summary.md → requirements_ears_review.md
          PO->>PO: Apply accepted edits or record rejection
        end
      end
      PO->>PO: 6. Contract delta → feature_contract_delta.md
      Note over PO: Per-class gating: classes with state ready contribute repo evidence, deferred classes skipped.
      PO-->>BE: feature_contract_delta.md
      PO-->>FE: feature_contract_delta.md
    and Technical tracks
      par
        BE->>BE: 7. BE surface map → project_surface_struct_resp_map_backend.md
        Note over BE: in: init_progress_definition.yaml + requirements_ears.md + feature_contract_delta.md + committed sibling plans.<br/>Evidence per row: repo scan (state ready) → in-flight promises → blueprint planned → placeholder.<br/>All repo scans read the default branch only.
      and
        FE->>FE: 7. FE/MB surface map → project_surface_struct_resp_map_frontend/mobile.md
        Note over FE: Same inputs + committed sibling plans.<br/>Evidence per row: repo scan (state ready) → in-flight promises → blueprint planned → placeholder.
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
      end
    end
  end
```
