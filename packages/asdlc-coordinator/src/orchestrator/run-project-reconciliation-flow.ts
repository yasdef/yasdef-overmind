import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import {
  applyContractReconciledFlags,
  applyDeferredClassPolicy,
  readProjectDefinitionMetadata,
  type ProjectClassPolicy
} from "../parse/index.js";
import { attachClassRepo, type AttachResult } from "../repo/index.js";
import type { CommitResult, ProjectGitPort } from "../git/index.js";
import { InteractionClosedError, type InteractionPort } from "../interaction/index.js";
import type { Diagnostic } from "../types/index.js";
import { validateContractReconciliation } from "../validate/index.js";

import {
  OWNED_RECONCILIATION_FILES,
  restoreOwnedPaths,
  snapshotOwnedPaths
} from "./project-transaction.js";

const DEFINITION_FILE = "init_progress_definition.yaml";
const COMMIT_MESSAGE = "Update project reconciliation state";

/** Result of the shared-executor reconciliation session for one class-list binding. */
export interface ReconciliationSessionResult {
  ok: boolean;
  diagnostics: Diagnostic[];
}

export interface ProjectReconciliationDeps {
  projectRoot: string;
  projectPathRel: string;
  interaction: InteractionPort;
  git: ProjectGitPort;
  /** Attach primitive (D3); defaults to the real `attachClassRepo`. */
  attach?: (
    projectRoot: string,
    className: string,
    repoPath: string,
    policy: ProjectClassPolicy
  ) => AttachResult;
  /** One shared-executor reconciliation session over the full pending class list (D4). */
  runReconciliationSession: (classes: string[]) => Promise<ReconciliationSessionResult>;
  emit: (line: string) => void;
  emitError: (line: string) => void;
}

export type ProjectReconciliationOutcome =
  | { kind: "noPendingWork" }
  | { kind: "completed"; committed: boolean }
  | { kind: "stoppedByOperator" }
  | { kind: "failed"; diagnostics: Diagnostic[] }
  | { kind: "startupError"; diagnostics: Diagnostic[] };

function error(source: string, reason: string): Diagnostic {
  return { severity: "error", source, reason };
}

function deferredClasses(metadata: ReturnType<typeof readProjectDefinitionMetadata>): string[] {
  return Object.entries(metadata.classRepoPaths)
    .filter(([, entry]) => entry.state !== "ready")
    .map(([name]) => name);
}

function pendingReadyClasses(metadata: ReturnType<typeof readProjectDefinitionMetadata>): string[] {
  return Object.entries(metadata.classRepoPaths)
    .filter(([, entry]) => entry.state === "ready" && entry.contractReconciled !== true)
    .map(([name]) => name);
}

/**
 * The `overmind project reconcile` use case (D1). Order: validate project; if a mutation
 * may occur, establish the clean project-worktree baseline; prompt every deferred class in
 * definition order (blank keeps the current policy, closed defers, one retry after invalid input); recompute
 * pending ready/unreconciled classes; run one reconciliation session for the full list; set
 * every covered `contract_reconciled` flag only on success; verify owned paths; then offer a
 * y/N commit. Returns a typed outcome; the CLI owns rendering and exit codes.
 */
export async function runProjectReconciliationFlow(
  deps: ProjectReconciliationDeps
): Promise<ProjectReconciliationOutcome> {
  const definitionPath = path.join(deps.projectRoot, DEFINITION_FILE);
  const attach = deps.attach ?? attachClassRepo;

  const initial = readProjectDefinitionMetadata(definitionPath);
  if (!initial.parsed) {
    return { kind: "startupError", diagnostics: initial.diagnostics };
  }

  let current = initial;
  let sharedCheckpointCommitted = false;
  const sharedCheckpoint = await handlePendingSharedCheckpoint(deps);
  if (sharedCheckpoint.kind === "failed" || sharedCheckpoint.kind === "stoppedByOperator") {
    return sharedCheckpoint;
  }
  if (sharedCheckpoint.kind === "committed") {
    sharedCheckpointCommitted = true;
    current = readProjectDefinitionMetadata(definitionPath);
    if (!current.parsed) {
      return { kind: "startupError", diagnostics: current.diagnostics };
    }
  }

  const deferred = deferredClasses(current);
  const pendingBefore = pendingReadyClasses(current);
  if (deferred.length === 0 && pendingBefore.length === 0) {
    if (sharedCheckpointCommitted) {
      return { kind: "completed", committed: true };
    }
    deps.emit(
      "No pending project reconciliation work: no existing class repositories need binding or contract reconciliation."
    );
    return { kind: "noPendingWork" };
  }

  // Baseline: any mutation requires a clean git worktree; missing git or a non-worktree
  // project is a pass-through without cleanliness or commit operations (D6).
  const status = deps.git.worktreeStatus(deps.projectRoot);
  let isGit = false;
  if (status.kind === "clean") {
    isGit = true;
  } else if (status.kind === "dirty") {
    return {
      kind: "startupError",
      diagnostics: [
        error(
          "project-reconcile",
          `Project worktree must be clean before reconciliation; uncommitted changes: ${status.paths.join(", ")}`
        )
      ]
    };
  } else if (status.kind === "inspectionFailed") {
    // Uninspectable status is not a pass-through — fail before any mutation (D6).
    return {
      kind: "startupError",
      diagnostics: [
        error(
          "project-reconcile",
          `Unable to inspect project worktree before reconciliation (git status exited ${status.exitCode}): ${status.stderr.trim()}`
        )
      ]
    };
  }

  // Review every deferred class in definition order (D1).
  for (const className of deferred) {
    await attachDeferredClass(className, deps, attach, definitionPath);
  }

  // Recompute pending ready/unreconciled classes after all attaches (D8).
  const afterAttach = readProjectDefinitionMetadata(definitionPath);
  if (!afterAttach.parsed) {
    return { kind: "startupError", diagnostics: afterAttach.diagnostics };
  }
  const pending = pendingReadyClasses(afterAttach);

  if (pending.length === 0) {
    // No session ran and no flags were written; any definition edits are accepted attaches
    // (owned changes). Determine whether there is anything to commit — an uninspectable
    // worktree fails rather than claiming success, but accepted attaches are retained (D6).
    let attachOwnedChanged = false;
    if (isGit) {
      const changed = deps.git.changedPaths(deps.projectRoot);
      if (changed.kind !== "ok") {
        return {
          kind: "failed",
          diagnostics: [
            error(
              "project-reconcile",
              `Unable to inspect project worktree after attachment (${describeInspectionFailure(changed)}).`
            )
          ]
        };
      }
      attachOwnedChanged = changed.paths.some((candidate) =>
        (OWNED_RECONCILIATION_FILES as readonly string[]).includes(candidate)
      );
    }
    return finalizeCommit(deps, isGit, /* sessionRan */ false, attachOwnedChanged);
  }

  // Snapshot owned paths post-attach so a failed session rolls back flags/contract edits
  // while retaining accepted attachments (D6).
  const baseline = snapshotOwnedPaths(deps.projectRoot);

  deps.emit(`Reconciling ${pending.length} pending class(es): ${pending.join(", ")}`);
  const session = await deps.runReconciliationSession(pending);
  if (!session.ok) {
    // Report any stray paths a failed session left before rolling back, so the operator
    // sees them in this run rather than only via the next run's dirty-baseline refusal (D6).
    const diagnostics = [...session.diagnostics];
    if (isGit) {
      const changed = deps.git.changedPaths(deps.projectRoot);
      if (changed.kind === "ok") {
        const unexpected = changed.paths.filter(
          (candidate) => !(OWNED_RECONCILIATION_FILES as readonly string[]).includes(candidate)
        );
        for (const unexpectedPath of unexpected) {
          deps.emitError(
            `Unexpected changed path left by failed reconciliation session: ${unexpectedPath}`
          );
        }
        if (unexpected.length > 0) {
          diagnostics.push(
            error(
              "project-reconcile",
              `Failed reconciliation left paths outside the owned unit for inspection: ${unexpected.join(", ")}`
            )
          );
        }
      } else if (changed.kind === "inspectionFailed") {
        diagnostics.push(
          error(
            "project-reconcile",
            `Unable to enumerate stray paths after the failed session (git status exited ${changed.exitCode}): ${changed.stderr.trim()}`
          )
        );
      }
    }
    restoreOwnedPaths(baseline);
    return { kind: "failed", diagnostics };
  }

  // Success: set contract_reconciled for every covered class only after executor success (D8).
  try {
    const content = readFileSync(definitionPath, "utf8");
    writeFileSync(definitionPath, applyContractReconciledFlags(content, pending, true));
  } catch (err) {
    restoreOwnedPaths(baseline);
    return {
      kind: "failed",
      diagnostics: [
        error(
          "project-reconcile",
          `Failed to write reconciliation flags: ${err instanceof Error ? err.message : String(err)}`
        )
      ]
    };
  }

  // Owned-path verification (D6): inspect the worktree exactly once. Any result other than
  // `ok` (inspectionFailed / unavailable / notWorktree) is anomalous for a project that was a
  // clean worktree at baseline — we cannot verify, so roll back the flags/edits and fail rather
  // than commit or claim success on unverified state.
  let ownedChanged = false;
  if (isGit) {
    const changed = deps.git.changedPaths(deps.projectRoot);
    if (changed.kind !== "ok") {
      restoreOwnedPaths(baseline);
      return {
        kind: "failed",
        diagnostics: [
          error(
            "project-reconcile",
            `Unable to verify reconciliation owned paths (${describeInspectionFailure(changed)}); reconciliation flags were rolled back.`
          )
        ]
      };
    }
    const unexpected = changed.paths.filter(
      (candidate) => !(OWNED_RECONCILIATION_FILES as readonly string[]).includes(candidate)
    );
    if (unexpected.length > 0) {
      restoreOwnedPaths(baseline);
      for (const unexpectedPath of unexpected) {
        deps.emitError(
          `Unexpected changed path outside the reconciliation unit: ${unexpectedPath}`
        );
      }
      return {
        kind: "failed",
        diagnostics: [
          error(
            "project-reconcile",
            `Reconciliation changed paths outside the owned unit: ${unexpected.join(", ")}`
          )
        ]
      };
    }
    ownedChanged = changed.paths.some((candidate) =>
      (OWNED_RECONCILIATION_FILES as readonly string[]).includes(candidate)
    );
  }

  return finalizeCommit(deps, isGit, /* sessionRan */ true, ownedChanged);
}

async function handlePendingSharedCheckpoint(
  deps: ProjectReconciliationDeps
): Promise<
  | { kind: "none" }
  | { kind: "committed" }
  | { kind: "stoppedByOperator" }
  | { kind: "failed"; diagnostics: Diagnostic[] }
> {
  const inspected = deps.git.inspectPaths?.(deps.projectRoot, [...OWNED_RECONCILIATION_FILES]);
  if (!inspected || inspected.kind !== "ok") return { kind: "none" };
  const common = inspected.paths.find((entry) => entry.path === "common_contract_definition.md");
  const dirtyShared = inspected.paths.some(
    (entry) => entry.staged || entry.unstaged || entry.untracked
  );
  if (!common?.hasHeadVersion || !dirtyShared) return { kind: "none" };

  const changed = deps.git.changedPaths(deps.projectRoot);
  if (changed.kind !== "ok") {
    return {
      kind: "failed",
      diagnostics: [
        error(
          "project-reconcile",
          `Unable to inspect pending shared reconciliation checkpoint (${describeInspectionFailure(changed)}).`
        )
      ]
    };
  }
  const outside = changed.paths.filter(
    (candidate) => !(OWNED_RECONCILIATION_FILES as readonly string[]).includes(candidate)
  );
  if (outside.length > 0) return { kind: "none" };

  const metadata = readProjectDefinitionMetadata(path.join(deps.projectRoot, DEFINITION_FILE));
  if (!metadata.parsed) return { kind: "failed", diagnostics: metadata.diagnostics };
  const commonGate = validateContractReconciliation(deps.projectRoot);
  if (commonGate.exitCode !== 0) {
    return {
      kind: "failed",
      diagnostics: [
        error(
          "project-reconcile",
          commonGate.exitCode === 1
            ? `Pending shared reconciliation checkpoint is invalid: ${commonGate.problems.join("; ")}`
            : `Pending shared reconciliation checkpoint cannot be validated: ${commonGate.errorMessage ?? "validation failed"}`
        )
      ]
    };
  }

  const outcome = await finalizeCommit(deps, true, true, true);
  if (outcome.kind === "completed") {
    return { kind: "committed" };
  }
  if (outcome.kind === "failed" || outcome.kind === "stoppedByOperator") {
    return outcome;
  }
  return {
    kind: "failed",
    diagnostics: [
      error(
        "project-reconcile",
        "Pending shared reconciliation checkpoint did not produce a commit outcome."
      )
    ]
  };
}

/** Describe a non-`ok` post-baseline changedPaths result for diagnostics. */
function describeInspectionFailure(
  changed: Exclude<ReturnType<ProjectGitPort["changedPaths"]>, { kind: "ok" }>
): string {
  switch (changed.kind) {
    case "inspectionFailed":
      return `git status exited ${changed.exitCode}: ${changed.stderr.trim()}`;
    case "unavailable":
      return "git is no longer available in PATH";
    case "notWorktree":
      return "project root is no longer a git worktree";
  }
}

/** Prompt one deferred class, applying blank-to-defer and the single retry-on-invalid rule (D1). */
async function attachDeferredClass(
  className: string,
  deps: ProjectReconciliationDeps,
  attach: (
    projectRoot: string,
    className: string,
    repoPath: string,
    policy: ProjectClassPolicy
  ) => AttachResult,
  definitionPath: string
): Promise<void> {
  const policy = await promptClassPolicy(
    className,
    deps,
    currentDeferredPolicy(definitionPath, className)
  );
  if (!policy) return;
  if (policy === "A") {
    if (!recordDeferredPolicy(definitionPath, className, policy, deps)) return;
    deps.emit(`Class '${className}' remains deferred with policy A.`);
    return;
  }
  if (!recordDeferredPolicy(definitionPath, className, policy, deps)) return;

  let attemptsLeft = 2;
  while (attemptsLeft > 0) {
    attemptsLeft -= 1;
    let response: string;
    try {
      response = (
        await deps.interaction.input({
          message: `Attach repository for deferred class '${className}' (blank to keep deferred):`
        })
      ).trim();
    } catch (err) {
      if (err instanceof InteractionClosedError) {
        deps.emit(`Class '${className}' remains deferred with policy ${policy}.`);
        return;
      }
      throw err;
    }
    if (response === "") {
      deps.emit(`Class '${className}' remains deferred with policy ${policy}.`);
      return;
    }

    const snapshot = snapshotDefinition(definitionPath);
    const result = attach(deps.projectRoot, className, response, policy);
    if (result.ok) {
      deps.emit(`Attached '${className}' -> ${result.resolvedRepoPath}`);
      return;
    }
    restoreDefinition(snapshot);
    for (const diagnostic of result.diagnostics) deps.emitError(diagnostic.reason);
    if (attemptsLeft > 0) {
      deps.emit(`Retrying attach for '${className}' (one attempt remaining).`);
    }
  }
  deps.emit(`Class '${className}' remains deferred with policy ${policy}.`);
}

async function promptClassPolicy(
  className: string,
  deps: ProjectReconciliationDeps,
  currentPolicy: ProjectClassPolicy | undefined
): Promise<ProjectClassPolicy | undefined> {
  let attemptsLeft = 2;
  while (attemptsLeft > 0) {
    attemptsLeft -= 1;
    let response: string;
    try {
      response = (
        await deps.interaction.input({
          message: `Select policy for deferred class '${className}' (A/B/C, blank to keep unchanged):`
        })
      )
        .trim()
        .toUpperCase();
    } catch (err) {
      if (err instanceof InteractionClosedError) return undefined;
      throw err;
    }
    if (response === "") return currentPolicy;
    if (response === "A" || response === "B" || response === "C") return response;
    deps.emitError(`Invalid policy for '${className}': ${response}. Use A, B, or C.`);
    if (attemptsLeft > 0) {
      deps.emit(`Retrying policy for '${className}' (one attempt remaining).`);
    }
  }
  deps.emit(`Class '${className}' remains deferred with unchanged policy.`);
  return undefined;
}

function currentDeferredPolicy(
  definitionPath: string,
  className: string
): ProjectClassPolicy | undefined {
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) return undefined;
  const policy = metadata.classRepoPaths[className]?.policy;
  return policy === "A" || policy === "B" || policy === "C" ? policy : undefined;
}

function recordDeferredPolicy(
  definitionPath: string,
  className: string,
  policy: ProjectClassPolicy,
  deps: Pick<ProjectReconciliationDeps, "emitError">
): boolean {
  const content = readFileSync(definitionPath, "utf8");
  const mutation = applyDeferredClassPolicy(content, className, policy);
  if ("error" in mutation) {
    deps.emitError(mutation.error);
    return false;
  }
  writeFileSync(definitionPath, mutation.content);
  return true;
}

interface DefinitionSnapshot {
  path: string;
  bytes: Buffer;
}

function snapshotDefinition(definitionPath: string): DefinitionSnapshot {
  return { path: definitionPath, bytes: readFileSync(definitionPath) };
}

function restoreDefinition(snapshot: DefinitionSnapshot): void {
  writeFileSync(snapshot.path, snapshot.bytes);
}

/**
 * Owned-path commit decision (D7): y/N over exactly the two owned files; skipped for non-git
 * and no-op. Worktree inspection/verification happens before this in the caller, which passes
 * the already-verified `ownedChanged`; this function only prompts and commits, so no second
 * (unverified) inspection can bypass verification or leave a `failed` outcome with lingering flags.
 */
async function finalizeCommit(
  deps: ProjectReconciliationDeps,
  isGit: boolean,
  sessionRan: boolean,
  ownedChanged: boolean
): Promise<ProjectReconciliationOutcome> {
  if (!isGit) {
    if (!sessionRan) {
      deps.emit("No pending project reconciliation work.");
      return { kind: "noPendingWork" };
    }
    deps.emit("Non-git project: reconciliation applied without a commit prompt.");
    return { kind: "completed", committed: false };
  }

  if (!ownedChanged) {
    deps.emit("No reconciliation changes to commit.");
    return { kind: sessionRan ? "completed" : "noPendingWork", committed: false };
  }

  let confirmed: boolean;
  try {
    confirmed = await deps.interaction.confirm({
      message: "Commit reconciliation results?",
      defaultValue: false
    });
  } catch (err) {
    if (err instanceof InteractionClosedError) {
      deps.emit("Commit declined (input closed); owned changes left uncommitted.");
      return { kind: "stoppedByOperator" };
    }
    throw err;
  }
  if (!confirmed) {
    deps.emit("Commit declined by operator; owned changes left uncommitted.");
    return { kind: "stoppedByOperator" };
  }

  const commit = deps.git.commitOwnedPaths(
    deps.projectRoot,
    [...OWNED_RECONCILIATION_FILES],
    COMMIT_MESSAGE
  );
  if (commit.kind === "committed") {
    deps.emit(`Committed reconciliation unit: ${COMMIT_MESSAGE}`);
    return { kind: "completed", committed: true };
  }
  // Commit failure is fatal and actionable; owned changes are left uncommitted and
  // inspectable for a retry (D7) — the verified reconciliation flags are intentionally kept.
  return {
    kind: "failed",
    diagnostics: [
      error(
        "project-reconcile",
        `Commit failed: ${describeCommitFailure(commit, deps.projectRoot)}`
      )
    ]
  };
}

/** Render an actionable diagnostic from a failed commit, preserving git exit code/stderr/paths. */
function describeCommitFailure(commit: CommitResult, projectRoot: string): string {
  switch (commit.kind) {
    case "committed":
      return `committed (project root: ${projectRoot})`;
    case "unavailable":
      return `git not found in PATH (project root: ${projectRoot})`;
    case "notWorktree":
      return `project root is not a git worktree: ${projectRoot}`;
    case "stageFailed":
      return `git add exited ${commit.exitCode} for ${projectRoot}: ${commit.stderr.trim()}`;
    case "commitFailed":
      return `git commit exited ${commit.exitCode} for ${projectRoot}: ${commit.stderr.trim()}`;
    case "dirtyAfterCommit": {
      const detail = commit.paths.length
        ? `remaining changed paths: ${commit.paths.join(", ")}`
        : (commit.stderr?.trim() ?? "post-commit status could not be read");
      return `project worktree not clean after commit for ${projectRoot}; ${detail}`;
    }
    case "inspectionFailed":
      return `unable to probe project worktree at commit time for ${projectRoot} (git exited ${commit.exitCode}): ${commit.stderr.trim()}`;
  }
}
