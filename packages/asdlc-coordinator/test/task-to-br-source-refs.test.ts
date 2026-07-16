import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  deriveCapturedSourceRefs,
  formatSourceRefs,
  parseSourceRefs
} from "../src/parse/source-refs.js";

const cwd = "/workspace";
const userInputPath = path.join(cwd, "projects", "p1", "feature-a", "user_br_input.md");

test("derivation places the capture record before a local story path", () => {
  const refs = deriveCapturedSourceRefs({
    userInputPath,
    epicStorySourceFile: "projects/p1/feature-a/feature_requirements.txt",
    cwd
  });
  assert.deepEqual(refs.required, [
    "projects/p1/feature-a/user_br_input.md",
    "projects/p1/feature-a/feature_requirements.txt"
  ]);
  assert.equal(refs.originalSourceUnfilled, false);
});

test("derivation preserves a Jira locator exactly", () => {
  const refs = deriveCapturedSourceRefs({
    userInputPath,
    epicStorySourceFile: "  jira:CRP-164  ",
    cwd
  });
  assert.deepEqual(refs.required, ["projects/p1/feature-a/user_br_input.md", "jira:CRP-164"]);
});

test("derivation removes duplicates in first-seen order", () => {
  const refs = deriveCapturedSourceRefs({
    userInputPath,
    epicStorySourceFile: "projects/p1/feature-a/user_br_input.md",
    cwd
  });
  assert.deepEqual(refs.required, ["projects/p1/feature-a/user_br_input.md"]);
});

test("derivation flags an unfilled original source and still requires the capture record", () => {
  for (const value of [undefined, "", "[UNFILLED]"]) {
    const refs = deriveCapturedSourceRefs({
      userInputPath,
      epicStorySourceFile: value,
      cwd
    });
    assert.equal(refs.originalSourceUnfilled, true);
    assert.equal(refs.originalSourceRef, undefined);
    assert.deepEqual(refs.required, ["projects/p1/feature-a/user_br_input.md"]);
  }
});

test("source_refs parsing trims elements and drops empty ones", () => {
  assert.deepEqual(parseSourceRefs(" a/b.md ;; jira:X ;"), ["a/b.md", "jira:X"]);
});

test("source_refs formatting uses the canonical separator", () => {
  assert.equal(formatSourceRefs(["a/b.md", "jira:X"]), "a/b.md; jira:X");
});
