import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { computeCrossClassPeerTrigger, listCommittedSiblingFeatures } from "../src/repo/index.js";

test("committed sibling lister returns sorted planned siblings and excludes current feature", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-siblings-"));
  try {
    const project = path.join(root, "projects", "p1");
    for (const name of ["current", "planned-b", "planned-a", "unplanned"]) {
      mkdirSync(path.join(project, name), { recursive: true });
    }
    writeFileSync(path.join(project, "current", "implementation_plan.md"), "current");
    writeFileSync(path.join(project, "planned-a", "implementation_plan.md"), "plan");
    writeFileSync(path.join(project, "planned-b", "implementation_plan.md"), "plan");
    assert.deepEqual(listCommittedSiblingFeatures(path.join(project, "current")), ["planned-a", "planned-b"]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("cross-class trigger matches block and inline shell-helper cases", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-trigger-"));
  try {
    const definition = path.join(root, "definition.yaml");
    const cases: Array<[string, string[], "active" | "inactive", boolean?]> = [
      ["A", ["backend", "frontend"], "active"],
      ["A", ["backend", "mobile"], "active", true],
      ["A", ["backend", "backend"], "active"],
      ["A", ["backend"], "inactive"],
      ["A", ["frontend"], "inactive"],
      ["B", ["backend", "frontend"], "inactive"]
    ];
    for (const [type, classes, expected, inline] of cases) {
      const classLines = inline
        ? `  project_classes: [${classes.join(", ")}]`
        : `  project_classes:\n${classes.map((value) => `    - ${value}`).join("\n")}`;
      writeFileSync(definition, `meta_info:\n${classLines}\n  project_type_code: "${type}"\n  class_repo_paths: {}\nsteps: []\n`);
      assert.equal(computeCrossClassPeerTrigger(definition), expected);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
