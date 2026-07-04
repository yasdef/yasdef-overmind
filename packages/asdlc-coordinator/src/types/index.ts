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

export interface RisedItem {
  id: string;
  raw: string;
  risedState: "true" | "false" | "missing";
}

export interface MissingBrData {
  path: string;
  content: string;
  risedItems: RisedItem[];
  hasFilledAnswer: boolean;
  hasFilledUnresolvedAfterStop: boolean;
}
