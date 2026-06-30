import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import { scanAsdlcWorkspace } from '../../scanner/asdlcScanner';

suite('ASDLC scanner', () => {
  test('parses ASDLC metadata and project initialization files', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));

    assert.strictEqual(model.scanStatus, 'ready');
    assert.strictEqual(model.projects.length, 3);

    const alpha = model.projects.find((project) => project.projectId === 'alpha');

    assert.ok(alpha);
    assert.strictEqual(alpha.name, 'Alpha Project');
    assert.strictEqual(alpha.createdAt, '2026-06-01');
    assert.strictEqual(alpha.projectTypeCode, 'product');
    assert.deepStrictEqual(
      alpha.classes.map((projectClass) => ({
        className: projectClass.className,
        repoPath: projectClass.repoPath,
        state: projectClass.state
      })),
      [
        { className: 'backend', repoPath: undefined, state: 'deferred' },
        { className: 'docs', repoPath: undefined, state: 'unknown' },
        { className: 'frontend', repoPath: 'D:/repo/frontend', state: 'ready' }
      ]
    );
  });

  test('discovers only feature folders with feature_br_summary.md markers', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const alpha = requiredProject(model, 'alpha');

    assert.deepStrictEqual(alpha.features.map((feature) => feature.featureId), ['feature-complete']);

    const feature = alpha.features[0];

    assert.strictEqual(feature.name, 'Complete Feature');
    assert.strictEqual(feature.completedSteps, 3);
    assert.strictEqual(feature.totalSteps, 4);
    assert.deepStrictEqual(feature.missingArtifacts, []);
  });

  test('detects project-level and feature-level artifacts', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const alpha = requiredProject(model, 'alpha');
    const beta = requiredProject(model, 'beta');
    const betaFeature = beta.features[0];

    assert.deepStrictEqual(
      alpha.artifacts.map((artifact) => [artifact.name, artifact.exists]),
      [
        ['init_progress_definition.yaml', true],
        ['step_state.md', true]
      ]
    );
    assert.deepStrictEqual(
      betaFeature.artifacts.map((artifact) => [artifact.name, artifact.exists]),
      [
        ['feature_br_summary.md', true],
        ['user_br_input.md', false],
        ['feature_design.md', false],
        ['step_plan.md', false]
      ]
    );
    assert.deepStrictEqual(betaFeature.missingArtifacts, [
      'user_br_input.md',
      'feature_design.md',
      'step_plan.md'
    ]);
    assert.ok(alpha.artifacts.every((artifact) => artifact.uri.startsWith('file:')));
    assert.ok(betaFeature.artifacts.every((artifact) => artifact.uri.startsWith('file:')));
  });

  test('isolates project parse failures and missing project folders', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const beta = requiredProject(model, 'beta');
    const missingProject = requiredProject(model, 'missing-project');
    const diagnosticCodes = model.diagnostics.map((diagnostic) => diagnostic.code);

    assert.strictEqual(model.scanStatus, 'ready');
    assert.strictEqual(beta.features.length, 1);
    assert.strictEqual(missingProject.projectReadiness, 'blocked');
    assert.ok(diagnosticCodes.includes('project.init.parseFailed'));
    assert.ok(diagnosticCodes.includes('project.folder.missing'));
  });

  test('fails the scan when root ASDLC metadata cannot be parsed', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('invalid-metadata'));

    assert.strictEqual(model.scanStatus, 'failed');
    assert.deepStrictEqual(model.projects, []);
    assert.ok(model.diagnostics.some((diagnostic) => diagnostic.code === 'asdlc.metadata.parseFailed'));
  });
});

function requiredProject(
  model: Awaited<ReturnType<typeof scanAsdlcWorkspace>>,
  projectId: string
) {
  const project = model.projects.find((candidate) => candidate.projectId === projectId);

  assert.ok(project, `Expected project ${projectId} to be scanned.`);

  return project;
}

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
