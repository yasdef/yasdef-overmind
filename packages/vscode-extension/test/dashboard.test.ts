import assert from "node:assert/strict";
import test from "node:test";

import type { ProgressReport } from "asdlc-coordinator/sequencing";

import { dashboardFeatureFromReport } from "../src/read-model.js";
import { DashboardViewProvider, renderDashboard } from "../src/view-provider.js";

function report(): ProgressReport {
  return {
    workspaceRoot: "/workspace",
    projectRoot: "/workspace/projects/demo",
    featureRoot: "/workspace/projects/demo/feature-a",
    featureTitle: "Feature A",
    definitionParsed: true,
    steps: [
      {
        stepId: "1",
        name: "Init",
        scope: "project",
        optional: false,
        state: "done",
        missingArtifacts: []
      },
      {
        stepId: "2",
        name: "Plan",
        scope: "feature",
        optional: false,
        state: "done",
        missingArtifacts: []
      },
      {
        stepId: "3",
        name: "Review",
        scope: "feature",
        optional: false,
        state: "blocked",
        missingArtifacts: ["/workspace/projects/demo/feature-a/review.md"]
      }
    ],
    diagnostics: [
      {
        severity: "error",
        source: "/workspace/projects/demo/feature-a/review.md",
        reason: "Unreadable completion artifact"
      }
    ]
  };
}

test("read model reuses the total sequencing projection and carries diagnostics", () => {
  const feature = dashboardFeatureFromReport(report());
  assert.deepEqual(feature.summary, {
    readiness: "blocked",
    completedSteps: 2,
    totalSteps: 3,
    missingArtifacts: ["/workspace/projects/demo/feature-a/review.md"]
  });
  assert.equal(feature.diagnostics[0]?.reason, "Unreadable completion artifact");
});

test("read model projects unknown readiness for an inconsistent definition", () => {
  const inconsistent = report();
  inconsistent.definitionParsed = false;
  inconsistent.diagnostics = [
    {
      severity: "error",
      source: "/workspace/projects/demo/init_progress_definition.yaml",
      reason: "Declared step ids do not match the sequencing catalog."
    }
  ];

  const feature = dashboardFeatureFromReport(inconsistent);

  assert.equal(feature.summary.readiness, "unknown");
  assert.equal(
    feature.diagnostics[0]?.reason,
    "Declared step ids do not match the sequencing catalog."
  );
});

test("read-only render/provider path shows summary, missing artifacts, and diagnostics", () => {
  const feature = dashboardFeatureFromReport(report());
  const model = {
    workspacePath: "/workspace",
    features: [feature],
    diagnostics: feature.diagnostics
  };
  const rows = renderDashboard(model);
  assert.deepEqual(rows, [
    { label: "Feature A", description: "blocked · 2/3 steps" },
    {
      label: "Missing artifacts",
      description: "/workspace/projects/demo/feature-a/review.md"
    },
    {
      label: "error: Unreadable completion artifact",
      description: "/workspace/projects/demo/feature-a/review.md"
    }
  ]);
  assert.deepEqual(new DashboardViewProvider(() => model).getRows("/workspace"), rows);
});

test("provider recomputes rows after its filesystem-backed model changes", () => {
  const feature = dashboardFeatureFromReport(report());
  let current = {
    workspacePath: "/workspace",
    features: [feature],
    diagnostics: feature.diagnostics
  };
  const provider = new DashboardViewProvider(() => current);
  assert.equal(provider.getRows("/workspace")[0]?.description, "blocked · 2/3 steps");

  current = {
    workspacePath: "/workspace",
    features: [
      {
        ...feature,
        summary: {
          readiness: "ready",
          completedSteps: 3,
          totalSteps: 3,
          missingArtifacts: []
        },
        diagnostics: []
      }
    ],
    diagnostics: []
  };
  assert.equal(provider.getRows("/workspace")[0]?.description, "ready · 3/3 steps");
});
