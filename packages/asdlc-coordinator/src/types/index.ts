export type GateExitCode = 0 | 1 | 2;

export interface Diagnostic {
  severity: "error" | "warning";
  source: string;
  reason: string;
  stepId?: string;
}

export interface GateResult {
  exitCode: GateExitCode;
  passMessage: string;
  problems: string[];
  errorMessage?: string;
}

export interface ContextResult {
  exitCode: 0 | 2;
  text?: string;
  readOnlyInputs?: string[];
  errorMessage?: string;
  verbatim?: boolean;
}

export interface CaptureResult {
  exitCode: 0 | 2;
  message?: string;
  errorMessage?: string;
}

export interface SyncStepResult {
  exitCode: 0 | 2;
  syncedCount?: number;
  blockedMessages?: string[];
  errorMessage?: string;
}

export interface ReadinessResult {
  exitCode: 0 | 1 | 2;
  message?: string;
  problems?: string[];
  errorMessage?: string;
}

export interface FeatureArtifacts {
  featureDir: string;
  targetBrPath: string;
  userInputPath: string;
  missingDataPath: string;
}

export interface FeatureBrSummary {
  path: string;
  content: string;
}

export interface UserBrInput {
  path: string;
  content: string;
  capturedAt?: string;
  jiraTicket?: string;
  featureId?: string;
  featureTitle?: string;
  epicStorySourceFile?: string;
  epicOrStory: string;
  requestSummary?: string;
  additionalBusinessContext?: string;
}

/**
 * Normalized `source=<section> -> <field>` locator of a ledger item. Heading and
 * field are lowercased with collapsed whitespace so comparison survives the
 * spacing and casing variants operators write, while the artifact keeps its
 * original text.
 */
export interface RisedItemSource {
  section: string;
  field: string;
}

export interface RisedItem {
  id: string;
  raw: string;
  risedState: "true" | "false" | "missing";
  /**
   * Every `<section> -> <field>` locator the item names, in written order. One
   * answered question may cover several fields that restate the same fact. Empty
   * when the item carries no parsable locator.
   */
  sources: RisedItemSource[];
}

export interface MissingBrData {
  path: string;
  content: string;
  risedItems: RisedItem[];
  hasFilledAnswer: boolean;
  hasFilledUnresolvedAfterStop: boolean;
  /**
   * `## 7. Loop Decision -> unresolved_after_stop`, trimmed but not unquoted, so the
   * exact-literal terminal check can reject a quoted variant. Undefined when absent.
   */
  unresolvedAfterStop?: string;
}
