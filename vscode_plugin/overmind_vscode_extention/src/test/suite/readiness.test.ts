import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import { FeatureSummary, ProjectSummary, scanAsdlcWorkspace } from '../../scanner/asdlcScanner';

suite('Readiness engine', () => {
  test('marks complete projects and ready features when all required state is present', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'complete-project');
    const feature = requiredFeature(project, 'feature-ready');

    assert.strictEqual(project.projectReadiness, 'complete');
    assert.strictEqual(feature.readiness, 'ready');
    assert.strictEqual(project.completedSteps, 2);
    assert.strictEqual(project.totalSteps, 2);
  });

  test('treats deferred classes as non-blocking readiness state', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'complete-project');

    assert.deepStrictEqual(
      project.classes.map((projectClass) => ({
        className: projectClass.className,
        state: projectClass.state,
        repoPath: projectClass.repoPath
      })),
      [
        { className: 'backend', state: 'deferred', repoPath: undefined },
        { className: 'frontend', state: 'ready', repoPath: 'D:/repo/frontend' }
      ]
    );
  });

  test('marks partial project readiness when a feature checklist has remaining work', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'partial-project');
    const feature = requiredFeature(project, 'feature-in-progress');

    assert.strictEqual(feature.readiness, 'in_progress');
    assert.strictEqual(project.projectReadiness, 'partial');
  });

  test('marks missing required feature artifacts as blocked', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'blocked-project');
    const feature = requiredFeature(project, 'feature-missing');

    assert.strictEqual(feature.readiness, 'blocked');
    assert.strictEqual(project.projectReadiness, 'blocked');
    assert.deepStrictEqual(feature.missingArtifacts, [
      'user_br_input.md',
      'feature_design.md',
      'step_plan.md'
    ]);
  });

  test('degrades invalid project metadata to unknown readiness with diagnostics', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'invalid-project');

    assert.strictEqual(project.projectReadiness, 'unknown');
    assert.ok(model.diagnostics.some((diagnostic) => diagnostic.code === 'project.init.parseFailed'));
  });

  test('marks unknown readiness when class repo paths or checklists are insufficient', async () => {
    const model = await scanAsdlcWorkspace(readinessFixture());
    const project = requiredProject(model.projects, 'unknown-project');
    const feature = requiredFeature(project, 'feature-no-checklist');

    assert.strictEqual(project.classes[0].state, 'unknown');
    assert.strictEqual(feature.readiness, 'unknown');
    assert.strictEqual(project.projectReadiness, 'unknown');
  });
});

function requiredProject(projects: readonly ProjectSummary[], projectId: string): ProjectSummary {
  const project = projects.find((candidate) => candidate.projectId === projectId);

  assert.ok(project, `Expected project ${projectId} to be scanned.`);

  return project;
}

function requiredFeature(project: ProjectSummary, featureId: string): FeatureSummary {
  const feature = project.features.find((candidate) => candidate.featureId === featureId);

  assert.ok(feature, `Expected feature ${featureId} to be scanned.`);

  return feature;
}

function readinessFixture(): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/readiness/asdlc'));
}
