import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import type { CommitResult, ProjectGitPort } from "../git/index.js";
import { InteractionClosedError, type InteractionPort } from "../interaction/index.js";
import {
  applyProjectClassMembership,
  CANONICAL_PROJECT_CLASSES,
  readProjectDefinitionMetadata,
  type ClassRepoPath,
  type ProjectDefinitionMetadata
} from "../parse/index.js";
import type { Diagnostic } from "../types/index.js";

const DEFINITION_FILE = "init_progress_definition.yaml";
const COMMIT_MESSAGE = "Update project class membership";

export type ProjectClassMembershipOutcome =
  | { kind: "changed"; action: "added" | "reset"; className: string; committed: boolean }
  | { kind: "stoppedByOperator" }
  | { kind: "noChange" }
  | { kind: "failed"; diagnostics: Diagnostic[] };

export interface ProjectClassMembershipDeps {
  projectRoot: string;
  projectPathRel: string;
  interaction: InteractionPort;
  git: ProjectGitPort;
  emit: (line: string) => void;
}

function error(reason: string): Diagnostic {
  return { severity: "error", source: "project-add-class", reason };
}

export async function manageProjectClassMembership(
  deps: ProjectClassMembershipDeps
): Promise<ProjectClassMembershipOutcome> {
  const definitionPath = path.join(deps.projectRoot, DEFINITION_FILE);
  if (!existsSync(definitionPath)) {
    return { kind: "failed", diagnostics: [error(`Project path must contain ${DEFINITION_FILE}`)] };
  }

  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) return { kind: "failed", diagnostics: metadata.diagnostics };

  deps.emit(`Selected project: ${deps.projectPathRel}`);

  const status = deps.git.worktreeStatus(deps.projectRoot);
  const isGit = status.kind === "clean";
  if (status.kind === "dirty") {
    return {
      kind: "failed",
      diagnostics: [
        error(
          `Project worktree must be clean before class membership changes; uncommitted changes: ${status.paths.join(", ")}`
        )
      ]
    };
  }
  if (status.kind === "inspectionFailed") {
    return {
      kind: "failed",
      diagnostics: [
        error(
          `Unable to inspect project worktree before class membership changes (git status exited ${status.exitCode}): ${status.stderr.trim()}`
        )
      ]
    };
  }

  const existing = new Set(metadata.projectClasses);
  const missing = missingClasses(existing);
  const resettable = resettableClasses(existing, metadata);
  let className: string;
  for (;;) {
    let action: "add" | "change" | "done";
    try {
      action = await deps.interaction.select({
        message: "Choose class membership action:",
        options: [
          { value: "add", label: addActionLabel(missing) },
          { value: "change", label: changeActionLabel(resettable) },
          { value: "done", label: "Done" }
        ]
      });
    } catch (err) {
      if (err instanceof InteractionClosedError) return { kind: "stoppedByOperator" };
      throw err;
    }
    if (action === "done") {
      return { kind: "noChange" };
    }

    if (action === "add") {
      if (missing.length === 0) {
        deps.emit("No project classes are available to add.");
        continue;
      }
      try {
        className = await deps.interaction.select({
          message: "Select project class to add:",
          options: missing.map((klass) => ({ value: klass, label: klass }))
        });
      } catch (err) {
        if (err instanceof InteractionClosedError) return { kind: "stoppedByOperator" };
        throw err;
      }
      break;
    }

    if (resettable.length === 0) {
      deps.emit(
        "No existing project classes need reset; every class is already deferred with policy A and no repository path."
      );
      continue;
    }
    let selection: ResettableClassSelection;
    try {
      selection = await selectResettableClass(deps, metadata, resettable);
    } catch (err) {
      if (err instanceof InteractionClosedError) return { kind: "stoppedByOperator" };
      throw err;
    }
    if (selection.kind === "declined") continue;
    className = selection.className;
    break;
  }

  const before = readFileSync(definitionPath, "utf8");
  const mutation = applyProjectClassMembership(before, className);
  if ("error" in mutation) return { kind: "failed", diagnostics: [error(mutation.error)] };
  if (mutation.content === before) return { kind: "noChange" };
  writeFileSync(definitionPath, mutation.content);
  deps.emit(
    `${mutation.action === "added" ? "Added" : "Reset"} class '${className}'. Run overmind project reconcile to bind its repository.`
  );

  if (!isGit) {
    return { kind: "changed", action: mutation.action, className, committed: false };
  }

  let confirmed: boolean;
  try {
    confirmed = await deps.interaction.confirm({
      message: "Commit class membership change?",
      defaultValue: false
    });
  } catch (err) {
    if (err instanceof InteractionClosedError) {
      deps.emit("Commit declined (input closed); class membership change left uncommitted.");
      return { kind: "changed", action: mutation.action, className, committed: false };
    }
    throw err;
  }
  if (!confirmed) {
    deps.emit("Commit declined by operator; class membership change left uncommitted.");
    return { kind: "changed", action: mutation.action, className, committed: false };
  }

  const commit = deps.git.commitOwnedPaths(deps.projectRoot, [DEFINITION_FILE], COMMIT_MESSAGE);
  if (commit.kind === "committed") {
    deps.emit(`Committed class membership change: ${COMMIT_MESSAGE}`);
    return { kind: "changed", action: mutation.action, className, committed: true };
  }
  return {
    kind: "failed",
    diagnostics: [error(`Commit failed: ${describeCommitFailure(commit, deps.projectRoot)}`)]
  };
}

async function selectResettableClass(
  deps: Pick<ProjectClassMembershipDeps, "interaction" | "emit">,
  metadata: ProjectDefinitionMetadata,
  present: string[]
): Promise<ResettableClassSelection> {
  const className = await deps.interaction.select({
    message: "Select project class to change:",
    options: present.map((klass) => {
      const entry = metadata.classRepoPaths[klass] ?? {};
      return {
        value: klass,
        label: `${klass} (policy ${entry.policy ?? "unset"}, state ${entry.state ?? "unset"}, path ${entry.path ?? ""})`
      };
    })
  });
  const entry = metadata.classRepoPaths[className] ?? {};
  const confirmed = await deps.interaction.confirm({
    message: `Reset ${className} from policy ${entry.policy ?? "unset"}, state ${entry.state ?? "unset"}, path ${entry.path ?? ""}?`
  });
  if (!confirmed) {
    deps.emit("Class change declined; no project definition changes made.");
    return { kind: "declined" };
  }
  return { kind: "selected", className };
}

type ResettableClassSelection = { kind: "selected"; className: string } | { kind: "declined" };

function missingClasses(existing: Set<string>): string[] {
  return CANONICAL_PROJECT_CLASSES.filter((klass) => !existing.has(klass));
}

function addActionLabel(missing: string[]): string {
  return missing.length === 0 ? "Add a class (none available)" : "Add a class";
}

function changeActionLabel(resettable: string[]): string {
  return resettable.length === 0
    ? "Change an existing class (nothing to reset)"
    : "Change an existing class";
}

function resettableClasses(existing: Set<string>, metadata: ProjectDefinitionMetadata): string[] {
  return CANONICAL_PROJECT_CLASSES.filter(
    (klass) => existing.has(klass) && !isAlreadyDeferredPolicyA(metadata.classRepoPaths[klass])
  );
}

function isAlreadyDeferredPolicyA(entry: ClassRepoPath | undefined): boolean {
  return entry?.policy === "A" && entry.state === "deferred" && (entry.path ?? "") === "";
}

function describeCommitFailure(commit: CommitResult, projectRoot: string): string {
  switch (commit.kind) {
    case "committed":
      return "committed";
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
