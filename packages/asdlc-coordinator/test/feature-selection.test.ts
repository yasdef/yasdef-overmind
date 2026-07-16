import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { resolveFeatureTarget } from "../src/orchestrator/index.js";
import { FEATURE_STATE_FILE_NAME, writeFeatureState } from "../src/state/index.js";
import { StubInteraction, seedCompleteFeature, withWorkspace } from "./orchestrator-fixtures.js";

function seedUnfinishedFeature(projectDir: string, name: string): string {
  const dir = path.join(projectDir, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    path.join(dir, "feature_br_summary.md"),
    "## 1. Document Meta\n- feature_title: WIP\n- ready_to_ears: false\n"
  );
  return dir;
}

function collector() {
  const lines: string[] = [];
  return { lines, emit: (line: string) => lines.push(line) };
}

test("continue selects an unfinished feature and persists it", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedUnfinishedFeature(projectDir, "wip-1");
    const rel = path.relative(root, featureDir);
    const { emit } = collector();
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      interaction: new StubInteraction(["continue", rel]),
      emit
    });
    assert.deepEqual(decision, { kind: "continue", featurePath: rel });
    assert.ok(existsSync(path.join(projectDir, FEATURE_STATE_FILE_NAME)));
  });
});

test("a cache write failure is not reported as a successful save", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const rel = path.relative(root, seedUnfinishedFeature(projectDir, "wip-1"));
    chmodSync(projectDir, 0o555); // read-only project dir -> cache write fails
    try {
      const { lines, emit } = collector();
      const decision = await resolveFeatureTarget({
        workspaceRoot: root,
        projectRoot: projectDir,
        projectPathRel,
        interaction: new StubInteraction(["continue", rel]),
        emit
      });
      // The run still continues with the selected feature (cache is a convenience)...
      assert.deepEqual(decision, { kind: "continue", featurePath: rel });
      // ...but it must not falsely claim the cache was saved.
      assert.ok(!lines.some((line) => /Saved feature_path/.test(line)));
      assert.ok(
        lines.some((line) => /Continuing without a persisted feature-state cache/.test(line))
      );
    } finally {
      chmodSync(projectDir, 0o755);
    }
  });
});

test("start-new is chosen from the mode menu", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedUnfinishedFeature(projectDir, "wip-1");
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      interaction: new StubInteraction(["new"]),
      emit: collector().emit
    });
    assert.deepEqual(decision, { kind: "startNew" });
  });
});

test("a non-scaffold resume rejects start-new and re-prompts", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const rel = path.relative(root, seedUnfinishedFeature(projectDir, "wip-1"));
    const { lines, emit } = collector();
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "4.2",
      interaction: new StubInteraction(["new", "continue", rel]),
      emit
    });
    assert.deepEqual(decision, { kind: "continue", featurePath: rel });
    assert.ok(lines.some((line) => /Cannot start a new feature with --resume/.test(line)));
  });
});

test("--resume 3 rejects continue and re-prompts", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedUnfinishedFeature(projectDir, "wip-1");
    const { lines, emit } = collector();
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "3",
      interaction: new StubInteraction(["continue", "new"]),
      emit
    });
    assert.deepEqual(decision, { kind: "startNew" });
    assert.ok(
      lines.some((line) => /Cannot continue an existing feature with --resume 3/.test(line))
    );
  });
});

test("--resume 8.4 reopens a valid completed cached feature when none are unfinished", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    const rel = path.relative(root, featureDir);
    writeFeatureState(projectDir, rel);
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "8.4",
      interaction: new StubInteraction([]),
      emit: collector().emit
    });
    assert.deepEqual(decision, { kind: "resumeCompleted", featurePath: rel });
  });
});

test("a completed cached feature prints friendly guidance and offers a new feature", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const rel = path.relative(root, seedCompleteFeature(projectDir, "done-1"));
    writeFeatureState(projectDir, rel);
    const { lines, emit } = collector();
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      interaction: new StubInteraction([]),
      emit
    });
    assert.deepEqual(decision, { kind: "startNew" });
    assert.ok(lines.some((line) => line === `Last selected feature is already complete: ${rel}`));
    assert.ok(lines.some((line) => line === "No unfinished features are available to continue."));
  });
});

test("a non-scaffold resume with no unfinished or cached context fails with guidance", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "5",
      interaction: new StubInteraction([]),
      emit: collector().emit
    });
    assert.equal(decision.kind, "fail");
  });
});

test("a stale cache is ignored with a notice and selection continues", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    writeFileSync(
      path.join(projectDir, FEATURE_STATE_FILE_NAME),
      JSON.stringify({ featurePath: "projects/p/gone" })
    );
    const { lines, emit } = collector();
    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      interaction: new StubInteraction([]),
      emit
    });
    assert.deepEqual(decision, { kind: "startNew" });
    assert.ok(lines.some((line) => /Ignoring stale saved feature_path cache/.test(line)));
  });
});

/**
 * CRP-166 D7: a terminal failure is not persisted, so when a completed cached
 * feature and an unfinished feature coexist the coordinator cannot infer whether
 * an explicit repair resume means "repair the completed one" or "continue the
 * unfinished one". Both are offered; neither is chosen silently.
 */
test("an explicit repair resume reaches the completed cached feature past unfinished ones", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const completed = path.relative(root, seedCompleteFeature(projectDir, "done-1"));
    seedUnfinishedFeature(projectDir, "wip-1");
    writeFeatureState(projectDir, completed);
    const { lines, emit } = collector();
    const interaction = new StubInteraction(["continue", completed]);

    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "5",
      interaction,
      emit
    });

    assert.deepEqual(decision, { kind: "resumeCompleted", featurePath: completed });
    assert.ok(
      interaction.selectRequests.at(-1)!.includes(completed),
      "the completed cached feature must be offered for repair"
    );
    assert.ok(
      interaction.selectLabels
        .at(-1)!
        .some((label) => /completed; reopen for repair at step 5/.test(label))
    );
    assert.ok(
      lines.some((line) =>
        /Reopening completed cached feature at explicit repair step 5/.test(line)
      )
    );
    // The cache already names this feature; reopening it writes nothing.
    assert.ok(lines.every((line) => !/Saved feature_path/.test(line)));
  });
});

test("an explicit repair resume still continues an unfinished feature when that is chosen", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const completed = path.relative(root, seedCompleteFeature(projectDir, "done-1"));
    const unfinished = path.relative(root, seedUnfinishedFeature(projectDir, "wip-1"));
    writeFeatureState(projectDir, completed);
    const { lines, emit } = collector();

    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "5",
      interaction: new StubInteraction(["continue", unfinished]),
      emit
    });

    // No hijack: the ordinary "continue this unfinished feature at step 5" intent
    // is preserved, and the selection is persisted as the new cached target.
    assert.deepEqual(decision, { kind: "continue", featurePath: unfinished });
    assert.ok(lines.some((line) => new RegExp(`Saved feature_path: ${unfinished}`).test(line)));
  });
});

test("an ordinary run does not offer the completed cached feature", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const completed = path.relative(root, seedCompleteFeature(projectDir, "done-1"));
    const unfinished = path.relative(root, seedUnfinishedFeature(projectDir, "wip-1"));
    writeFeatureState(projectDir, completed);
    const interaction = new StubInteraction(["continue", unfinished]);

    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      interaction,
      emit: collector().emit
    });

    assert.deepEqual(decision, { kind: "continue", featurePath: unfinished });
    assert.deepEqual(interaction.selectRequests.at(-1), [unfinished]);
  });
});

test("a cached feature that is itself unfinished is not duplicated as a repair option", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const unfinished = path.relative(root, seedUnfinishedFeature(projectDir, "wip-1"));
    writeFeatureState(projectDir, unfinished);
    const interaction = new StubInteraction(["continue", unfinished]);

    const decision = await resolveFeatureTarget({
      workspaceRoot: root,
      projectRoot: projectDir,
      projectPathRel,
      resumeStepId: "5",
      interaction,
      emit: collector().emit
    });

    assert.deepEqual(decision, { kind: "continue", featurePath: unfinished });
    assert.deepEqual(interaction.selectRequests.at(-1), [unfinished]);
  });
});
