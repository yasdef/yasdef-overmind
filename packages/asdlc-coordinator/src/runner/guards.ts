import { existsSync, readFileSync } from "node:fs";

import type { ReadOnlyGuard } from "../sequencing/step-catalog.js";
import type { Diagnostic } from "../types/index.js";

export interface GuardSnapshotEntry {
  mode: ReadOnlyGuard["mode"];
  path: string;
  existedBefore: boolean;
  bytes?: Buffer;
}

export interface GuardSnapshot {
  entries: GuardSnapshotEntry[];
}

export function validateReadOnlyGuardsBeforeSession(
  guards: ReadonlyArray<ReadOnlyGuard>,
  resolvedFromContext: string[]
): Diagnostic[] {
  if (!guards.some((guard) => guard.mode === "fromContext")) {
    return [];
  }

  if (resolvedFromContext.length === 0) {
    return [
      {
        severity: "error",
        source: "session-guards",
        reason: "fromContext guard violation: context emitted no read-only inputs."
      }
    ];
  }

  return resolvedFromContext.flatMap((file) =>
    existsSync(file)
      ? []
      : [
          guardDiagnostic(
            "fromContext",
            file,
            "Read-only input must exist before the session starts."
          )
        ]
  );
}

export function snapshotReadOnlyGuards(
  guards: ReadonlyArray<ReadOnlyGuard>,
  resolvedFromContext: string[],
  resolveGuardFiles: (files: string[]) => string[]
): GuardSnapshot {
  const entries: GuardSnapshotEntry[] = [];

  for (const guard of guards) {
    const files =
      guard.mode === "fromContext" ? resolvedFromContext : resolveGuardFiles(guard.files);

    for (const file of files) {
      const existedBefore = existsSync(file);
      entries.push({
        mode: guard.mode,
        path: file,
        existedBefore,
        bytes: existedBefore ? readFileSync(file) : undefined
      });
    }
  }

  return { entries };
}

export function verifyReadOnlyGuards(snapshot: GuardSnapshot): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];

  for (const entry of snapshot.entries) {
    const existsAfter = existsSync(entry.path);

    if (entry.mode === "fromContext") {
      if (!entry.existedBefore || !entry.bytes) {
        diagnostics.push(
          guardDiagnostic(
            entry.mode,
            entry.path,
            "Read-only input must exist before the session and stay unchanged."
          )
        );
        continue;
      }
      if (!existsAfter || !readFileSync(entry.path).equals(entry.bytes)) {
        diagnostics.push(
          guardDiagnostic(entry.mode, entry.path, "Read-only input must not be modified.")
        );
      }
      continue;
    }

    if (entry.mode === "mustExistUnchanged") {
      if (!entry.existedBefore || !entry.bytes) {
        diagnostics.push(
          guardDiagnostic(entry.mode, entry.path, "Guarded file must exist before the session.")
        );
        continue;
      }
      if (!existsAfter || !readFileSync(entry.path).equals(entry.bytes)) {
        diagnostics.push(
          guardDiagnostic(entry.mode, entry.path, "Guarded file must remain byte-identical.")
        );
      }
      continue;
    }

    if (!entry.existedBefore && existsAfter) {
      diagnostics.push(
        guardDiagnostic(entry.mode, entry.path, "Guarded file must stay absent when absent before.")
      );
      continue;
    }
    if (entry.existedBefore && !existsAfter) {
      diagnostics.push(
        guardDiagnostic(
          entry.mode,
          entry.path,
          "Guarded file must remain present when it existed before the session."
        )
      );
      continue;
    }
    if (
      entry.existedBefore &&
      entry.bytes &&
      existsAfter &&
      !readFileSync(entry.path).equals(entry.bytes)
    ) {
      diagnostics.push(
        guardDiagnostic(entry.mode, entry.path, "Guarded file must remain byte-identical.")
      );
    }
  }

  return diagnostics;
}

export function assertRequiredOutputs(outputPaths: string[]): Diagnostic[] {
  return outputPaths.flatMap((outputPath) =>
    existsSync(outputPath)
      ? []
      : [
          {
            severity: "error" as const,
            source: "session-guards",
            reason: `Required output not found: ${outputPath}`
          }
        ]
  );
}

function guardDiagnostic(mode: ReadOnlyGuard["mode"], path: string, reason: string): Diagnostic {
  return {
    severity: "error",
    source: "session-guards",
    reason: `${mode} guard violation for ${path}: ${reason}`
  };
}
