# Claude 

crp-128 Real-World Evidence Report

  Subject: auth_for_admin3-1781734516 (planned 2026-06-18, post-crp-128)
  Baseline for contrast: umss_core_functionality-1777635876 (planned 2026-05-03, pre-crp-128) — same project.

  Verdict

  crp-128 fired as designed and improved planning quality — surface maps and prerequisite traces are now
  grounded in real repo evidence instead of blueprint placeholders, with per-layer fallback, dated citations,
  and divergence tags all working. One concern (frontend divergence over-tagging) and one blind spot (the
  concurrency machinery was never actually exercised, because the sibling feature was already merged).
  Details below.

  What crp-128 changed (the mechanisms to look for)

  Per-class blueprint→repo transition (D1/D2), a permanent per-layer evidence chain repo → in-flight promise 
  → blueprint → placeholder with dated blueprint citations (D3), policy-C divergent_from_blueprint tags (D5),
  and concurrency-aware planning that reads sibling feature plans as promises (D7).

  Evidence the mechanisms ran (quantified, AFTER vs BEFORE, same project)

  Signal: Surface map grounding
  BEFORE (umss_core): 100% blueprint placeholders — analyzed_repo_paths: no ready backend repository path … 
    planned structural evidence only (backend map:10); generic rows like "REST controller, request DTO"
  AFTER (auth_for_admin3): Real components TelegramOnboardingController, AdminUserCountsController and real
    endpoints GET /api/admin/user-counts scanned from repo (backend map:25–27)
  Mechanism: D1/D2 per-class transition
  ────────────────────────────────────────
  Signal: divergent_from_blueprint tags
  BEFORE (umss_core): backend 0 / frontend 0
  AFTER (auth_for_admin3): backend 1 (map:49) / frontend 7 (map:28,36,44,52,60,68,76)
  Mechanism: D5 policy-C tagging
  ────────────────────────────────────────
  Signal: Dated blueprint-fallback citations
  BEFORE (umss_core): 0
  AFTER (auth_for_admin3): backend 3 — (planned, project_stack_blueprint_backend.md §3.5 (last_updated: 
    2026-05-03)) (map:53–55)
  Mechanism: D3 permanent dated chain
  ────────────────────────────────────────
  Signal: Sibling-plan-as-promise
  BEFORE (umss_core): absent
  AFTER (auth_for_admin3): both maps cite umss_core_functionality-…/implementation_plan.md reviewed for  
    in-flight promise evidence (backend map:11, frontend map:11)
  Mechanism: D7 promise tier
  ────────────────────────────────────────
  Signal: Contract overlap reporting
  BEFORE (umss_core): absent
  AFTER (auth_for_admin3): Delta 1: "the sibling umss_core_functionality delta already claims the user-count
    endpoint payload, and this feature does not change that response shape" (contract_delta:22)
  Mechanism: D7 step-6 overlap surfacing
  ────────────────────────────────────────
  Signal: Plan shape
  BEFORE (umss_core): scaffold-readiness coordination steps (BEFORE plan Step 1.0 + Step 1.6)
  AFTER (auth_for_admin3): those steps gone; plan goes straight to real work, per-step #### Repo: 
    backend/frontend (plan:7,11,40)
  Mechanism: D1/D2 (class is now repo-backed, so no readiness ceremony)

  I verified the citation accuracy: class_repo_paths.{backend,frontend} are both state: ready, policy: "C" in
  init_progress_definition.yaml:8–16, and both blueprints really carry last_updated: 2026-05-03 — so the
  dated fallback citation is correct, not fabricated.

  Quality assessment: net positive

  The single sharpest piece of evidence is the same project's backend surface map before vs after:
  pre-crp-128 every layer was a generic blueprint guess with user_reachable_surface: none even for the API
  layer; post-crp-128 the map carries actual class names, actual endpoints, and present_in_repo prerequisite
  statuses traced to GET /api/admin/user-counts (prerequisite_gaps:51–54). The plan correctly preserved the
  existing payload, dropped wasted scaffold steps, and proactively flagged the cross-feature contract overlap
  and reasoned it as non-breaking. The evidence chain also correctly mixed sources per layer — repo-scanned
  for touched layers, blueprint (planned) only for the still-untouched Integration layer (3.5) — which is
  exactly the D3 permanent demand-driven behavior, not the old type-A-only fallback.

  Concerns / caveats (the honest "bad" column)

  1. Frontend divergence over-tagging (precision risk). The frontend map tags all 7 layers
  divergent_from_blueprint, vs 1 on the backend. A tag that fires on every row carries little discriminating
  signal for the operator. It's passive under policy C (nothing blocks), but it looks like the detector is
  wholesale-flagging a real scaffolded Angular repo against a generic blueprint rather than isolating genuine
  structural divergence. Worth eyeballing whether those 7 are real Stack-Choice/Layer-Binding divergences or
  just shape noise.
  2. The concurrency machinery was never actually exercised. By the time auth_for_admin3 was planned, the
  sibling umss_core was already merged into the repo, so the merged-truth scan won every row and the promise
  tier collapsed to the degenerate case. Concretely, none of these crp-128 concurrency features fired:
  scheduled_in_feature (prerequisite_gaps used present_in_repo throughout), cross-feature #### Depends on: 
  <folder>/<step> syntax (all deps stayed intra-feature), (in-flight) semantic-review findings (no_findings: 
  true), and assignment hold markers. This run validates D1/D2/D3/D5/D6 strongly; it does not validate D7's 
  execution gating. That path still needs a test with a genuinely in-flight, unmerged sibling.

  Recommendations

  1. Trust the per-class transition + evidence chain — ship it. D1/D2/D3/D5 are demonstrably working on real
  artifacts and measurably improved grounding.
  2. Tighten policy-C divergence precision. Investigate the 7/7 frontend tagging; if the detector flags
  shape/style differences as divergence, scope it to structural (Stack Choices / Layer Bindings) per the D5
  intent so the tag stays meaningful.
  3. Run a dedicated concurrency validation before claiming D7 proven: plan feature B while feature A's plan
  exists but is not yet merged, and confirm the four signals above appear (scheduled_in_feature,
  cross-feature Depends on, (in-flight) semantic finding, assignment hold marker). This is the one part of
  crp-128 the real project didn't get to stress.

# Codex

## Verdict

  CRP-128 materially improved planning quality, but concurrency-aware planning is only partially effective.

  ### What improved

  - Per-class repository transition worked: despite project type A, both classes are now repo-backed under
    policy C (/Users/aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/
    init_progress_definition.yaml:6).

  - Planning used concrete code paths and accurately distinguished implemented, partial, and missing behavior
    (/Users/aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/auth_for_admin3-
    1781734516/technical_requirements.md:19).

  - The plan consequently targets real gaps—JWT validation, OIDC bootstrap, route protection—without the
    speculative scaffold-readiness steps required before CRP-128 (/Users/aleksandrkalinin/repo/asdlc/
    projects/teleforecaster_umss_v2-1777635457000/auth_for_admin3-1781734516/implementation_plan.md:6).

  - First-attach reconciliation corrected the planned OpenAPI 3.1 baseline to repository-proven OpenAPI 3.0.3
    (/Users/aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/
    common_contract_definition.md:87).

  - The permanent evidence chain worked: the backend integration layer falls back to a dated blueprint while
    other layers use repository evidence (/Users/aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-
    1777635457000/auth_for_admin3-1781734516/project_surface_struct_resp_map_backend.md:51).

  - Policy-C divergence tagging appeared eight times: once in backend and seven times in frontend (/Users/
    aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/auth_for_admin3-1781734516/
    project_surface_struct_resp_map_frontend.md:22).

  - Contract concurrency worked: the delta explicitly recognizes the sibling feature’s user-count contract
    and preserves its response shape (/Users/aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-
    1777635457000/auth_for_admin3-1781734516/feature_contract_delta.md:19).

  ### What failed

  A real cross-feature implementation collision was missed.

  The earlier, unfinished plan still promises the frontend count API client, page state, and widgets (/Users/
  aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/umss_core_functionality-
  1777635876/implementation_plan.md:124). The new plan schedules essentially the same work (/Users/
  aleksandrkalinin/repo/asdlc/projects/teleforecaster_umss_v2-1777635457000/auth_for_admin3-1781734516/
  implementation_plan.md:51).

  Nevertheless:

  - Both surface maps state that the sibling plan was reviewed.
  - No row received an (in-flight ...) tag.
  - Semantic review returned no_findings: true (/Users/aleksandrkalinin/repo/asdlc/projects/
    teleforecaster_umss_v2-1777635457000/auth_for_admin3-1781734516/
    implementation_plan_semantic_review.md:23).

  - The new plan contains neither a cross-feature dependency nor an explicit supersession decision.

  The likely cause is structural: repo evidence wins per row and only one source is allowed (overmind/rules/
  feature_repo_surface_and_exec_context_rule.md:43). Because /admin already exists as a scaffold, the
  repository resolves the row and masks the sibling promise. Semantic review only checks rows already tagged
  as in-flight.

  ## Recommendations

  1. Before execution, reconcile new Step 1.5 with umss_core_functionality.../1.8. Either depend on it,
     supersede it, or remove the duplicated work.

  2. Detect promise overlaps independently of evidence resolution. Repository truth should remain
     authoritative, but sibling steps touching the same path, component, contract, or surface must still be
     recorded.

  3. Require every detected overlap to have an explicit disposition: depends_on, supersedes, shared_scope, or
     no_conflict.

  4. Treat only unchecked sibling steps as promises. Completed steps should be represented through merged
     repository truth.

  5. Update existing project init_progress_definition.yaml during deployment; it still contains stale
     project-type gating that says Type-A repo scanning is skipped.

  Overall: CRP-128 produced a substantially more accurate and executable plan, but its primary concurrency
  safeguard generated a false negative in this real trial.