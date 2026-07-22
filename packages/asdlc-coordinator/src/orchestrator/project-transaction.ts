import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";

/** The only two paths the reconciliation unit may change (D6/D7). */
export const OWNED_RECONCILIATION_FILES = [
  "init_progress_definition.yaml",
  "common_contract_definition.md"
] as const;

export interface OwnedPathSnapshot {
  path: string;
  existed: boolean;
  bytes?: Buffer;
}

/**
 * Byte snapshot of the two owned reconciliation paths at a project root (D6). Taken
 * post-attach/pre-session so a failed session can restore contract edits and flags to
 * this baseline while retaining accepted attachments.
 */
export function snapshotOwnedPaths(projectRoot: string): OwnedPathSnapshot[] {
  return OWNED_RECONCILIATION_FILES.map((name) => {
    const filePath = path.join(projectRoot, name);
    const existed = existsSync(filePath);
    return existed
      ? { path: filePath, existed, bytes: readFileSync(filePath) }
      : { path: filePath, existed };
  });
}

/**
 * Scoped restoration of owned paths to a prior snapshot: rewrite snapshotted bytes or
 * delete files that did not exist. Unexpected paths outside the owned set are never
 * touched so they remain available for operator inspection.
 */
export function restoreOwnedPaths(snapshots: OwnedPathSnapshot[]): void {
  for (const snapshot of snapshots) {
    if (snapshot.existed && snapshot.bytes) {
      writeFileSync(snapshot.path, snapshot.bytes);
    } else if (!snapshot.existed && existsSync(snapshot.path)) {
      rmSync(snapshot.path, { force: true });
    }
  }
}
