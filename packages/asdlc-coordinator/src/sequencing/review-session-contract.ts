/**
 * Typed mutable-artifact gate contract shared by the review-session context
 * builders and the step catalog (CRP-165 D1). Each entry pairs a feature-relative
 * artifact a review session may edit with the gate that revalidates it after the
 * session. Context generation renders its allowed-write surface from these entries
 * and the catalog attaches the same entries as the action's `postSessionGates`, so
 * enforcement cannot diverge from the coordinator-generated write surface.
 *
 * Normative artifacts are listed first and ledgers second for stable output; the
 * executor still runs every entry regardless of earlier results.
 */
export interface MutableArtifactGate {
  /** Feature-relative artifact filename the review session may edit. */
  artifact: string;
  /** Gate name that revalidates the artifact after the session. */
  gate: string;
}

/** Step 5.1 EARS review: normative EARS artifact plus its findings ledger. */
export const EARS_REVIEW_MUTABLE_GATES: readonly MutableArtifactGate[] = [
  { artifact: "requirements_ears.md", gate: "requirements-ears" },
  { artifact: "requirements_ears_review.md", gate: "ears-review" }
];

/** Step 8.4 plan semantic review: normative implementation plan plus its findings ledger. */
export const PLAN_SEMANTIC_REVIEW_MUTABLE_GATES: readonly MutableArtifactGate[] = [
  { artifact: "implementation_plan.md", gate: "implementation-plan" },
  { artifact: "implementation_plan_semantic_review.md", gate: "plan-semantic-review" }
];
