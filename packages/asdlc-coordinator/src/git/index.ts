import { spawnSync } from "node:child_process";

/**
 * Result of a best-effort checkpoint against an explicit repository root. Every
 * non-committed variant is a *typed value*, not an error: the shell's
 * `commit_feature_progress` treated missing git, a non-worktree root, and add/
 * commit failures as notices that never stop the run, and a clean tree simply
 * had nothing to commit.
 */
export type CheckpointResult =
  | { kind: "committed"; message: string }
  | { kind: "clean" }
  | { kind: "unavailable" }
  | { kind: "notWorktree" }
  | { kind: "addFailed"; exitCode: number }
  | { kind: "commitFailed"; exitCode: number };

export interface GitRunner {
  (root: string, args: string[]): { status: number; stdout: string; stderr: string };
}

const defaultGitRunner: GitRunner = (root, args) => {
  // Force the C locale so git's human-readable messages (e.g. "not a git repository")
  // are stable and can be classified reliably; porcelain output is already locale-independent.
  const result = spawnSync("git", ["-C", root, ...args], {
    encoding: "utf8",
    env: { ...process.env, LC_ALL: "C", LANG: "C" }
  });
  if (result.error) {
    // ENOENT => git not installed; surface as a non-zero status the caller maps
    // to "unavailable" rather than throwing.
    return { status: 127, stdout: "", stderr: String(result.error.message ?? "") };
  }
  return {
    status: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? ""
  };
};

/**
 * Repo-scoped git adapter: every operation receives an explicit `root` and never
 * relies on the process working directory (D7). Commit commands run without
 * hook-dependent behavior, preserving the migration's local/hook-free contract.
 */
export class RepoGitAdapter {
  constructor(private readonly run: GitRunner = defaultGitRunner) {}

  private available(): boolean {
    const probe = this.run(".", ["--version"]);
    return probe.status === 0;
  }

  isWorktree(root: string): boolean {
    return this.run(root, ["rev-parse", "--is-inside-work-tree"]).status === 0;
  }

  isClean(root: string): boolean {
    const status = this.run(root, ["status", "--porcelain"]);
    return status.status === 0 && status.stdout.trim() === "";
  }

  /**
   * Stage all supplied-root changes (`git add -A`) and commit them with a
   * checkpoint message. Any obstacle degrades to a typed result and never throws.
   */
  checkpoint(root: string, label: string): CheckpointResult {
    if (!this.available()) return { kind: "unavailable" };
    if (!this.isWorktree(root)) return { kind: "notWorktree" };
    if (this.isClean(root)) return { kind: "clean" };

    const add = this.run(root, ["add", "-A"]);
    if (add.status !== 0) return { kind: "addFailed", exitCode: add.status };

    const commitMessage = `Checkpoint: ${label}`;
    const commit = this.run(root, ["commit", "-m", commitMessage]);
    if (commit.status !== 0) return { kind: "commitFailed", exitCode: commit.status };

    return { kind: "committed", message: commitMessage };
  }
}

/** Render a checkpoint result as the operator-facing notice line, matching the shell wording. */
export function renderCheckpointNotice(result: CheckpointResult, label: string): string {
  switch (result.kind) {
    case "committed":
      return `Checkpoint commit created: ${result.message}`;
    case "clean":
      return `Checkpoint commit skipped (${label}): nothing to commit.`;
    case "unavailable":
      return `Checkpoint commit skipped (${label}): git not found in PATH.`;
    case "notWorktree":
      return `Checkpoint commit skipped (${label}): repository root is not a git worktree.`;
    case "addFailed":
      return `Checkpoint commit notice (${label}): git add exited ${result.exitCode}; continuing without checkpoint.`;
    case "commitFailed":
      return `Checkpoint commit notice (${label}): git commit exited ${result.exitCode}; continuing without checkpoint.`;
  }
}

/** Checkpoint boundary labels, preserved verbatim from the shell orchestrator. */
export const CHECKPOINT_LABELS = {
  before51: "before step 5.1 (EARS review)",
  before71: "before step 7.1 (MCP enrichment)",
  before84: "before step 8.4 (semantic review)",
  after84: "after step 8.4 (semantic review)"
} as const;

/** Port the orchestrator uses to request checkpoints; the CLI supplies `RepoGitAdapter`. */
export interface CheckpointPort {
  checkpoint(root: string, label: string): CheckpointResult;
}

/**
 * A git command that should have succeeded on an identified worktree exited non-zero
 * (e.g. `status` exits 128 while `rev-parse` reported a worktree). This is never a
 * pass-through: the flow must fail rather than mutate or claim completion (D6).
 */
export type InspectionFailure = { kind: "inspectionFailed"; exitCode: number; stderr: string };

/** Project-worktree status for the reconciliation transaction baseline (D6). */
export type WorktreeStatus =
  | { kind: "unavailable" }
  | { kind: "notWorktree" }
  | { kind: "clean" }
  | { kind: "dirty"; paths: string[] }
  | InspectionFailure;

/** Project-worktree changed paths after a session, or a pass-through typed result (D6). */
export type ChangedPathsResult =
  | { kind: "unavailable" }
  | { kind: "notWorktree" }
  | { kind: "ok"; paths: string[] }
  | InspectionFailure;

export interface PathGitInspection {
  path: string;
  hasHeadVersion: boolean;
  staged: boolean;
  unstaged: boolean;
  untracked: boolean;
}

export type PathInspectionResult =
  | { kind: "unavailable" }
  | { kind: "notWorktree" }
  | { kind: "ok"; paths: PathGitInspection[] }
  | InspectionFailure;

/** Result of committing exactly the owned reconciliation paths (D7). */
export type CommitResult =
  | { kind: "committed" }
  | { kind: "unavailable" }
  | { kind: "notWorktree" }
  | { kind: "stageFailed"; exitCode: number; stderr: string }
  | { kind: "commitFailed"; exitCode: number; stderr: string }
  | { kind: "dirtyAfterCommit"; paths: string[]; stderr?: string }
  | InspectionFailure;

/**
 * Project-root git port the reconciliation flow depends on (D6/D7). Every operation
 * receives an explicit project root; missing git or a non-worktree project is a typed
 * pass-through, never an exception.
 */
export interface ProjectGitPort {
  worktreeStatus(root: string): WorktreeStatus;
  changedPaths(root: string): ChangedPathsResult;
  inspectPaths?(root: string, paths: string[]): PathInspectionResult;
  commitOwnedPaths(root: string, paths: string[], message: string): CommitResult;
}

export type ProjectInitResult =
  | { kind: "ok"; appliedFallbackName: boolean; appliedFallbackEmail: boolean }
  | { kind: "unavailable" }
  | { kind: "initFailed"; exitCode: number; stderr: string }
  | { kind: "identityFailed"; field: "user.name" | "user.email"; exitCode: number; stderr: string }
  | { kind: "stageFailed"; exitCode: number; stderr: string }
  | { kind: "commitFailed"; exitCode: number; stderr: string };

export interface ProjectInitGitPort {
  initAndCommitDefinition(root: string, definitionFileName: string): ProjectInitResult;
}

export const PROJECT_INIT_COMMIT_MESSAGE = "Initialize ASDLC project workspace";
export const PROJECT_GIT_FALLBACK_USER_NAME = "Overmind ASDLC";
export const PROJECT_GIT_FALLBACK_USER_EMAIL = "overmind-asdlc@local.invalid";

/** Parse `git status --porcelain` output into repo-relative paths (handles renames). */
function parsePorcelainPaths(stdout: string): string[] {
  const paths: string[] = [];
  for (const rawLine of stdout.split("\n")) {
    if (rawLine.trim() === "") continue;
    const entry = rawLine.slice(3);
    const renameIndex = entry.indexOf(" -> ");
    paths.push(renameIndex >= 0 ? entry.slice(renameIndex + 4) : entry);
  }
  return paths;
}

function parsePathPorcelain(
  stdout: string
): Map<string, Pick<PathGitInspection, "staged" | "unstaged" | "untracked">> {
  const byPath = new Map<string, Pick<PathGitInspection, "staged" | "unstaged" | "untracked">>();
  for (const rawLine of stdout.split("\n")) {
    if (rawLine.trim() === "") continue;
    const x = rawLine[0] ?? " ";
    const y = rawLine[1] ?? " ";
    const entry = rawLine.slice(3);
    const renameIndex = entry.indexOf(" -> ");
    const statusPath = renameIndex >= 0 ? entry.slice(renameIndex + 4) : entry;
    byPath.set(statusPath, {
      staged: x !== " " && x !== "?",
      unstaged: y !== " ",
      untracked: x === "?" && y === "?"
    });
  }
  return byPath;
}

export class RepoGitProjectAdapter implements ProjectGitPort {
  constructor(private readonly run: GitRunner = defaultGitRunner) {}

  private available(): boolean {
    return this.run(".", ["--version"]).status === 0;
  }

  /**
   * Probe whether `root` is a git worktree. Only a confirmed non-repository maps to
   * `notWorktree` (a supported pass-through, D6); any other `rev-parse` failure — a
   * corrupt or unreadable repo — is an `InspectionFailure` so the flow fails rather than
   * mutating an existing repo without cleanliness/commit protection.
   */
  private probeWorktree(root: string): "worktree" | "notWorktree" | InspectionFailure {
    const probe = this.run(root, ["rev-parse", "--is-inside-work-tree"]);
    if (probe.status === 0) return "worktree";
    if (/not a git repository/i.test(probe.stderr)) return "notWorktree";
    return { kind: "inspectionFailed", exitCode: probe.status, stderr: probe.stderr };
  }

  worktreeStatus(root: string): WorktreeStatus {
    if (!this.available()) return { kind: "unavailable" };
    const probe = this.probeWorktree(root);
    if (probe !== "worktree") return probe === "notWorktree" ? { kind: "notWorktree" } : probe;
    const status = this.run(root, ["status", "--porcelain"]);
    if (status.status !== 0) {
      return { kind: "inspectionFailed", exitCode: status.status, stderr: status.stderr };
    }
    const paths = parsePorcelainPaths(status.stdout);
    return paths.length === 0 ? { kind: "clean" } : { kind: "dirty", paths };
  }

  changedPaths(root: string): ChangedPathsResult {
    if (!this.available()) return { kind: "unavailable" };
    const probe = this.probeWorktree(root);
    if (probe !== "worktree") return probe === "notWorktree" ? { kind: "notWorktree" } : probe;
    const status = this.run(root, ["status", "--porcelain"]);
    if (status.status !== 0) {
      return { kind: "inspectionFailed", exitCode: status.status, stderr: status.stderr };
    }
    return { kind: "ok", paths: parsePorcelainPaths(status.stdout) };
  }

  inspectPaths(root: string, paths: string[]): PathInspectionResult {
    if (!this.available()) return { kind: "unavailable" };
    const probe = this.probeWorktree(root);
    if (probe !== "worktree") return probe === "notWorktree" ? { kind: "notWorktree" } : probe;
    const status = this.run(root, ["status", "--porcelain", "--", ...paths]);
    if (status.status !== 0) {
      return { kind: "inspectionFailed", exitCode: status.status, stderr: status.stderr };
    }
    const changed = parsePathPorcelain(status.stdout);
    return {
      kind: "ok",
      paths: paths.map((pathspec) => {
        const head = this.run(root, ["cat-file", "-e", `HEAD:${pathspec}`]);
        const state = changed.get(pathspec) ?? {
          staged: false,
          unstaged: false,
          untracked: false
        };
        return {
          path: pathspec,
          hasHeadVersion: head.status === 0,
          ...state
        };
      })
    };
  }

  commitOwnedPaths(root: string, paths: string[], message: string): CommitResult {
    if (!this.available()) return { kind: "unavailable" };
    const probe = this.probeWorktree(root);
    if (probe !== "worktree") return probe === "notWorktree" ? { kind: "notWorktree" } : probe;
    const add = this.run(root, ["add", "--", ...paths]);
    if (add.status !== 0) return { kind: "stageFailed", exitCode: add.status, stderr: add.stderr };
    const commit = this.run(root, ["commit", "-m", message, "--", ...paths]);
    if (commit.status !== 0) {
      return { kind: "commitFailed", exitCode: commit.status, stderr: commit.stderr };
    }
    const after = this.run(root, ["status", "--porcelain", "--", ...paths]);
    if (after.status !== 0) {
      return { kind: "inspectionFailed", exitCode: after.status, stderr: after.stderr };
    }
    const remaining = parsePorcelainPaths(after.stdout);
    return remaining.length === 0
      ? { kind: "committed" }
      : { kind: "dirtyAfterCommit", paths: remaining };
  }
}

export class RepoGitProjectInitAdapter implements ProjectInitGitPort {
  constructor(private readonly run: GitRunner = defaultGitRunner) {}

  private available(): boolean {
    return this.run(".", ["--version"]).status === 0;
  }

  initAndCommitDefinition(root: string, definitionFileName: string): ProjectInitResult {
    if (!this.available()) return { kind: "unavailable" };
    const init = this.run(root, ["init", "-q"]);
    if (init.status !== 0) {
      return { kind: "initFailed", exitCode: init.status, stderr: init.stderr };
    }

    const nameProbe = this.run(root, ["config", "user.name"]);
    let appliedFallbackName = false;
    if (nameProbe.status !== 0 || nameProbe.stdout.trim() === "") {
      const setName = this.run(root, ["config", "user.name", PROJECT_GIT_FALLBACK_USER_NAME]);
      if (setName.status !== 0) {
        return {
          kind: "identityFailed",
          field: "user.name",
          exitCode: setName.status,
          stderr: setName.stderr
        };
      }
      appliedFallbackName = true;
    }

    const emailProbe = this.run(root, ["config", "user.email"]);
    let appliedFallbackEmail = false;
    if (emailProbe.status !== 0 || emailProbe.stdout.trim() === "") {
      const setEmail = this.run(root, ["config", "user.email", PROJECT_GIT_FALLBACK_USER_EMAIL]);
      if (setEmail.status !== 0) {
        return {
          kind: "identityFailed",
          field: "user.email",
          exitCode: setEmail.status,
          stderr: setEmail.stderr
        };
      }
      appliedFallbackEmail = true;
    }

    const add = this.run(root, ["add", "--", definitionFileName]);
    if (add.status !== 0) return { kind: "stageFailed", exitCode: add.status, stderr: add.stderr };
    const commit = this.run(root, ["commit", "-qm", PROJECT_INIT_COMMIT_MESSAGE]);
    if (commit.status !== 0) {
      return { kind: "commitFailed", exitCode: commit.status, stderr: commit.stderr };
    }
    return { kind: "ok", appliedFallbackName, appliedFallbackEmail };
  }
}
