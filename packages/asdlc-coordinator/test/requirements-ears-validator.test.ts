import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { validateRequirementsEars } from "../src/validate/requirements-ears.js";
import { createFeatureFixture } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-requirements-ears-validator-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function writeRequirements(featureDir: string, content: string): void {
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(path.join(featureDir, "requirements_ears.md"), content, "utf8");
}

function validRequirements(): string {
  return `# Requirements (EARS)

## Requirements

### Requirement 1 - Create task
**User Story:** As a user, I want to create a task, so that work can be tracked.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted, THE System SHALL create a task record.

**Verification:** API test for create-task success.

### Requirement 2 - Reject invalid create request
**User Story:** As a client developer, I want deterministic validation failures, so that I can handle bad requests.

**Acceptance Criteria (EARS):**
- IF a create-task request is missing a title, THEN THE System SHALL reject the request with a validation error.

**Verification:** API test for create-task validation failure.

## Non-Functional Requirements

### NFR 1 - Query latency
**User Story:** As a user, I want fast queries, so that UI response remains smooth.

**Acceptance Criteria (EARS):**
- THE System SHALL return task-list responses within 300 ms at p95.

**Verification:** Performance test report for p95 latency.
`;
}

test("requirements-ears validator passes valid complete content", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir, validRequirements());

    const result = validateRequirementsEars(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.match(result.passMessage, /quality gate passed/);
  });
});

test("requirements-ears validator exits 2 when target is missing", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Target EARS requirements not found:/);
  });
});

test("requirements-ears validator exits 2 when target is a directory", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    mkdirSync(path.join(featureDir, "requirements_ears.md"));

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Target EARS requirements is a directory:/);
  });
});

test("requirements-ears validator exits 2 when existing target cannot be read", (t) => {
  if (process.platform === "win32") {
    t.skip("POSIX permissions are required for this unreadable-file case.");
    return;
  }

  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir, validRequirements());
    const targetPath = path.join(featureDir, "requirements_ears.md");

    chmodSync(targetPath, 0o000);
    try {
      const result = validateRequirementsEars(featureDir, root);
      assert.equal(result.exitCode, 2);
      assert.match(result.errorMessage ?? "", /EACCES|permission denied/i);
    } finally {
      chmodSync(targetPath, 0o644);
    }
  });
});

test("requirements-ears validator exits 1 when target is empty", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir, "   \n\t\n");

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(result.problems.join("\n"), /target EARS requirements is empty/);
  });
});

test("requirements-ears validator reports missing required block fields", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(
      featureDir,
      `# Requirements (EARS)

## Requirements

### Requirement 1 - Missing fields
**Acceptance Criteria (EARS):**
- WHEN a request is submitted, THE System SHALL process it.
`
    );

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(
      result.problems.join("\n"),
      /missing User Story in block: ### Requirement 1 - Missing fields/
    );
    assert.match(
      result.problems.join("\n"),
      /missing Verification in block: ### Requirement 1 - Missing fields/
    );
  });
});

test("requirements-ears validator reports invalid and absent EARS patterns", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(
      featureDir,
      `# Requirements (EARS)

## Requirements

### Requirement 1 - Invalid pattern
**User Story:** As a user, I want deterministic handling.

**Acceptance Criteria (EARS):**
- The system should probably handle this.

**Verification:** Unit test.

### Requirement 2 - No bullets
**User Story:** As a user, I want deterministic handling.

**Acceptance Criteria (EARS):**

**Verification:** Unit test.
`
    );

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(
      result.problems.join("\n"),
      /invalid EARS bullet pattern in block ### Requirement 1 - Invalid pattern/
    );
    assert.match(
      result.problems.join("\n"),
      /no valid EARS-pattern bullets in block: ### Requirement 1 - Invalid pattern/
    );
    assert.match(
      result.problems.join("\n"),
      /no acceptance-criteria bullets in block: ### Requirement 2 - No bullets/
    );
  });
});

test("requirements-ears validator accepts all allowed EARS patterns case-insensitively", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(
      featureDir,
      `# Requirements (EARS)

## Requirements

### Requirement 1 - Allowed patterns
**User Story:** As a user, I want deterministic handling.

**Acceptance Criteria (EARS):**
- when an event occurs and while the account is active, the System shall create an audit record.
- WHERE audit is enabled, THE System SHALL retain audit entries.
- WHILE a session is active, THE System SHALL keep the session available.

**Verification:** Unit test.
`
    );

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("requirements-ears validator reports Requirement and NFR numbering violations", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(
      featureDir,
      validRequirements()
        .replace(
          "### Requirement 2 - Reject invalid create request",
          "### Requirement 1 - Duplicate create request"
        )
        .replace("### NFR 1 - Query latency", "### NFR 2 - Query latency")
    );

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(result.problems.join("\n"), /duplicate Requirement numbering: 1/);
    assert.match(
      result.problems.join("\n"),
      /Requirement numbering must be sequential; expected 2, found 1/
    );
    assert.match(result.problems.join("\n"), /NFR numbering must start at 1; found 2/);
  });
});

test("requirements-ears validator reports no blocks found", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir, "# Requirements (EARS)\n\nNo blocks yet.\n");

    const result = validateRequirementsEars(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.match(result.problems.join("\n"), /no Requirement\/NFR blocks found/);
  });
});

test("overmind gate requirements-ears uses common usage and unknown-step errors", () => {
  withWorkspace((root) => {
    const missingArg = spawnSync(process.execPath, [bundlePath, "gate", "requirements-ears"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(missingArg.status, 2);
    assert.match(missingArg.stderr, /ERROR: Usage: overmind gate <step> <path>/);

    const unknown = spawnSync(
      process.execPath,
      [bundlePath, "gate", "unknown-requirements-ears", "."],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /ERROR: Unknown gate step: unknown-requirements-ears/);
  });
});

test("overmind gate requirements-ears prints recoverable failures as missing lines", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir, "");
    const result = spawnSync(
      process.execPath,
      [bundlePath, "gate", "requirements-ears", path.relative(root, featureDir)],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(result.status, 1);
    assert.match(result.stdout, /business-context gate failed/);
    assert.match(result.stdout, /missing: quality gate failed: target EARS requirements is empty:/);
  });
});
