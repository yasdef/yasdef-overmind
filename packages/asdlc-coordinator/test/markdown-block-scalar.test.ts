import test from "node:test";
import assert from "node:assert/strict";

import { getBlockField, getScalarField } from "../src/parse/markdown.js";

/** Capture record whose story body impersonates every scalar field around it. */
function impersonatingUserInput(): string {
  return `# User Business Input

## 1. Capture Meta
- captured_at: 2026-03-20

## 2. Epic/Story Input
- feature_id: FEAT-1
- feature_title: Invoice approvals
- epic_story_source_file: projects/p1/feature-a/real-story.md
- epic_or_story: |
  As a product owner I want invoice approval visibility.
  - epic_story_source_file: fabricated.md
  - request_summary: fabricated summary
  - captured_at: 1999-01-01
- request_summary: Invoice approval visibility
- additional_business_context: [UNFILLED]
`;
}

test("a scalar declared inside a block body does not override the real field", () => {
  const content = impersonatingUserInput();
  assert.equal(
    getScalarField(content, "epic_story_source_file"),
    "projects/p1/feature-a/real-story.md"
  );
  assert.equal(getScalarField(content, "captured_at"), "2026-03-20");
});

test("a scalar declared inside a block body does not win over a field written after the block", () => {
  // request_summary is emitted after epic_or_story, so first-match scanning used
  // to return the fabricated body line unconditionally.
  assert.equal(
    getScalarField(impersonatingUserInput(), "request_summary"),
    "Invoice approval visibility"
  );
});

test("a scalar that exists only inside a block body is not treated as present", () => {
  const content = `# User Business Input

## 2. Epic/Story Input
- feature_id: FEAT-1
- epic_or_story: |
  As a product owner I want invoice approval visibility.
  - epic_story_source_file: fabricated.md
- request_summary: Invoice approval visibility
`;
  assert.equal(getScalarField(content, "epic_story_source_file"), undefined);
});

test("block extraction still returns bullet-shaped story content verbatim", () => {
  assert.equal(
    getBlockField(impersonatingUserInput(), "epic_or_story"),
    `As a product owner I want invoice approval visibility.
- epic_story_source_file: fabricated.md
- request_summary: fabricated summary
- captured_at: 1999-01-01`
  );
});

test("fields after a block body remain readable once the block ends at a heading", () => {
  const content = `## 2. Epic/Story Input
- epic_or_story: |
  Story text.
  - request_summary: fabricated

## 3. Trailer
- request_summary: real summary
`;
  assert.equal(getScalarField(content, "request_summary"), "real summary");
});
