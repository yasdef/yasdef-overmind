import { existsSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

export type SyncResult = { ok: true } | { ok: false; blockedMessage: string };
export type RepoStateResult = { ok: true } | { ok: false; blockedMessage: string };

function git(args: string[], cwd: string): { status: number; stdout: string; stderr: string } {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  return {
    status: result.status ?? 1,
    stdout: (result.stdout ?? "").trim(),
    stderr: (result.stderr ?? "").trim()
  };
}

function abortRebaseIfNeeded(repoPath: string): void {
  const r = git(["rev-parse", "--git-dir"], repoPath);
  if (r.status !== 0) {
    return;
  }
  let gitDir = r.stdout.trim();
  if (!path.isAbsolute(gitDir)) {
    gitDir = path.join(repoPath, gitDir);
  }
  if (existsSync(path.join(gitDir, "rebase-merge")) || existsSync(path.join(gitDir, "rebase-apply"))) {
    spawnSync("git", ["rebase", "--abort"], { cwd: repoPath, encoding: "utf8" });
  }
}

function resolveRemoteDefaultBranch(repoPath: string, currentBranch: string): string | undefined {
  if (currentBranch) {
    const upstreamResult = git(
      ["rev-parse", "--abbrev-ref", "--symbolic-full-name", `${currentBranch}@{upstream}`],
      repoPath
    );
    if (upstreamResult.status === 0) {
      const remoteName = upstreamResult.stdout.split("/")[0];
      if (remoteName) {
        const headRef = git(["symbolic-ref", "--quiet", `refs/remotes/${remoteName}/HEAD`], repoPath);
        if (headRef.status === 0) {
          const candidate = headRef.stdout.split("/").pop() ?? "";
          if (candidate === "main" || candidate === "master") {
            return candidate;
          }
        }
      }
    }
  }

  const remotesResult = git(["remote"], repoPath);
  if (remotesResult.status === 0 && remotesResult.stdout) {
    for (const remoteName of remotesResult.stdout.split("\n")) {
      if (!remoteName.trim()) {
        continue;
      }
      const headRef = git(["symbolic-ref", "--quiet", `refs/remotes/${remoteName}/HEAD`], repoPath);
      if (headRef.status === 0) {
        const candidate = headRef.stdout.split("/").pop() ?? "";
        if (candidate === "main" || candidate === "master") {
          return candidate;
        }
      }
    }
  }

  return undefined;
}

export function checkRepoBranchState(repoPath: string): RepoStateResult {
  const insideWorkTree = git(["rev-parse", "--is-inside-work-tree"], repoPath);
  if (insideWorkTree.status !== 0) {
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} is not a git repository.`
    };
  }

  const branchResult = git(["rev-parse", "--abbrev-ref", "HEAD"], repoPath);
  const currentBranch = branchResult.status === 0 ? branchResult.stdout : "";

  const hasMain = git(["rev-parse", "--verify", "--quiet", "refs/heads/main"], repoPath).status === 0;
  const hasMaster = git(["rev-parse", "--verify", "--quiet", "refs/heads/master"], repoPath).status === 0;

  let defaultBranch: string | undefined = resolveRemoteDefaultBranch(repoPath, currentBranch);

  if (defaultBranch === undefined) {
    if (hasMain && !hasMaster) {
      defaultBranch = "main";
    } else if (!hasMain && hasMaster) {
      defaultBranch = "master";
    } else if (hasMain && hasMaster) {
      return {
        ok: false,
        blockedMessage: `BLOCKED: ${repoPath} default branch is ambiguous; both main and master exist and no remote default is configured (D7) — configure the default branch and rerun`
      };
    }
  }

  if (!defaultBranch || currentBranch !== defaultBranch) {
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} is not on its default branch; planning reads upstream-synchronized merged truth only (D7) — check out the default branch and rerun`
    };
  }

  const statusResult = git(["status", "--porcelain"], repoPath);
  if (statusResult.status === 0 && statusResult.stdout !== "") {
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} has uncommitted changes; planning syncs and reads committed merged truth only (D7) — commit or stash and rerun`
    };
  }

  const upstreamCheck = git(
    ["rev-parse", "--abbrev-ref", "--symbolic-full-name", `${defaultBranch}@{upstream}`],
    repoPath
  );
  if (upstreamCheck.status !== 0) {
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} default branch has no upstream; planning cannot sync merged truth (D7) — configure upstream and rerun`
    };
  }

  return { ok: true };
}

export function syncRepoToDefaultBranch(repoPath: string): SyncResult {
  const state = checkRepoBranchState(repoPath);
  if (!state.ok) {
    return state;
  }

  const pullEnv: Record<string, string | undefined> = {
    ...process.env,
    GIT_TERMINAL_PROMPT: "0",
    GIT_EDITOR: "true",
    GIT_SEQUENCE_EDITOR: "true"
  };
  const pullResult = spawnSync("git", ["pull", "--rebase"], { cwd: repoPath, encoding: "utf8", env: pullEnv });
  if ((pullResult.status ?? 1) !== 0) {
    abortRebaseIfNeeded(repoPath);
    const detail = pullResult.stderr?.trim() ? `; git said: ${pullResult.stderr.trim()}` : "";
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} could not sync default branch with git pull --rebase; planning cannot read merged truth (D7) — resolve the repo and rerun${detail}`
    };
  }

  const postPullStatus = git(["status", "--porcelain"], repoPath);
  if (postPullStatus.status === 0 && postPullStatus.stdout !== "") {
    abortRebaseIfNeeded(repoPath);
    return {
      ok: false,
      blockedMessage: `BLOCKED: ${repoPath} is dirty after git pull --rebase; planning cannot read merged truth (D7) — resolve uncommitted changes and rerun`
    };
  }

  return { ok: true };
}
