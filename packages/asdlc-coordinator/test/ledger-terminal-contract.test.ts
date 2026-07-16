import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

function readRepoFile(relativePath: string): string {
  return readFileSync(
    fileURLToPath(new URL(`../../../../${relativePath}`, import.meta.url)),
    "utf8"
  );
}

const TERMINAL_SOURCES = [
  "packages/installer/_data/skills/overmind-task-to-br/SKILL.md",
  "packages/installer/_data/skills/overmind-br-clarification/SKILL.md"
] as const;

for (const source of TERMINAL_SOURCES) {
  test(`${source} states the terminal ledger summary rule`, () => {
    const content = readRepoFile(source);
    assert.match(content, /Ledger Terminal State/);
    assert.match(
      content,
      /`## 3\. Unresolved Items Ledger \(Rised\)` is empty, or when every `rised_item_N` is `rised=true`/
    );
    assert.match(content, /`## 7\. Loop Decision -> unresolved_after_stop`[^\n]*exactly `none`/);
  });

  test(`${source} requires preserving historical gate_result values`, () => {
    const content = readRepoFile(source);
    assert.match(content, /preserve every pre-existing `gate_result` line and value exactly/);
  });

  // The producer and the consumer of missing_br_data.md must describe the same
  // locator syntax: a multi-field item written by one and read as single-field by
  // the other silently leaves BR fields stale but gate-confirmed.
  test(`${source} states the multi-field source locator form`, () => {
    const content = readRepoFile(source);
    assert.match(
      content,
      /`- rised_item_N: source=<section> -> <field>, <section> -> <field>; rised=(?:false|true); unresolved_item=<text>`/
    );
  });
}

const LEDGER_TEMPLATES = [
  "overmind/templates/missing_br_data_TEMPLATE.md",
  "packages/installer/_data/skills/overmind-task-to-br/assets/missing_br_data_TEMPLATE.md"
] as const;

// Templates carry the line shape only. When to use the multi-field form, and how
// many answer pointers it produces, are rules owned by the skills above.
for (const template of LEDGER_TEMPLATES) {
  test(`${template} offers the multi-field source locator shape`, () => {
    assert.match(
      readRepoFile(template),
      /`- rised_item_N: source=<section> -> <field>\[, <section> -> <field>\]; rised=false; unresolved_item=<text>`/
    );
  });
}

// A superseded phrasing surviving in one section is how this contract drifts:
// the positive assertions above still pass while a stale copy contradicts them.
for (const source of [...TERMINAL_SOURCES, ...LEDGER_TEMPLATES]) {
  test(`${source} keeps no per-item answer-pointer wording`, () => {
    assert.doesNotMatch(readRepoFile(source), /per discussed item/);
  });
}

test("BR clarification applies an answer to every field its ledger item names", () => {
  const content = readRepoFile(
    "packages/installer/_data/skills/overmind-br-clarification/SKILL.md"
  );
  assert.match(
    content,
    /write the business answer to `feature_br_summary\.md` in every field the item's `source=` locator list names/
  );
  assert.match(
    content,
    /may only become `rised=true` once each field it names carries the answered wording/
  );
  assert.match(content, /one `- answers:` line per destination field written/);
});

test("the BR-clarification skill closes the ledger when the final answer is recorded", () => {
  const content = readRepoFile(
    "packages/installer/_data/skills/overmind-br-clarification/SKILL.md"
  );
  assert.match(
    content,
    /leaves every tracked `rised_item_N` at `rised=true`, set `## 7\. Loop Decision -> unresolved_after_stop` to exactly `none` in the same write, before rerunning the gate/
  );
  assert.match(content, /leave `## 1\. Gate Status -> gate_result` unchanged/);
});
