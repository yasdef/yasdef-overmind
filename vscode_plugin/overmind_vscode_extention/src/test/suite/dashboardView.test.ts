import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import { DashboardModel, scanAsdlcWorkspace } from '../../scanner/asdlcScanner';
import { renderDashboardHtml } from '../../webview/dashboardView';

suite('Dashboard Webview', () => {
  test('renders project readiness, repo classes, and feature details', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const html = renderDashboardHtml({
      kind: 'dashboard',
      title: 'Overmind Dashboard',
      message: 'Showing read-only ASDLC state.',
      model,
      metadataPath: path.join(model.workspacePath, 'asdlc_metadata.yaml')
    });

    assert.ok(html.includes('Alpha Project'));
    assert.ok(html.includes('alpha'));
    assert.ok(html.includes('product'));
    assert.ok(html.includes('frontend'));
    assert.ok(html.includes('D:/repo/frontend'));
    assert.ok(html.includes('Complete Feature'));
    assert.ok(html.includes('3/4 steps'));
    assert.ok(html.includes('Project Artifacts'));
    assert.ok(html.includes('Feature Artifacts'));
    assert.ok(html.includes('Task-to-BR Capture'));
    assert.ok(html.includes('data-capture-status'));
    assert.ok(html.includes('data-capture-toggle'));
    assert.ok(html.includes('data-dashboard-action="refresh"'));
    assert.ok(html.includes('data-script-action-id="createProject"'));
    assert.ok(html.includes('data-script-action-id="createOrContinueFeature"'));
    assert.ok(html.includes('data-script-action-id="runInitProgressScanner"'));
    assert.ok(html.includes('data-project-id="alpha"'));
    assert.ok(html.includes('data-feature-id="feature-complete"'));
    assert.ok(html.includes('<details class="project" open>'));
    assert.ok(html.includes('<details class="feature">'));
  });

  test('renders missing artifacts and blocked readiness for incomplete features', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const html = renderDashboardHtml({
      kind: 'dashboard',
      title: 'Overmind Dashboard',
      message: 'Showing read-only ASDLC state.',
      model
    });

    assert.ok(html.includes('Beta Project'));
    assert.ok(html.includes('Incomplete Feature'));
    assert.ok(html.includes('user_br_input.md'));
    assert.ok(html.includes('feature_design.md'));
    assert.ok(html.includes('step_plan.md'));
    assert.ok(html.includes('data-capture-form'));
    assert.ok(html.includes('data-capture-submit'));
    assert.ok(html.includes('data-project-id="beta"'));
    assert.ok(html.includes('data-feature-id="feature-incomplete"'));
    assert.ok(html.includes('Story file (.txt/.md)'));
    assert.ok(html.includes('Jira ticket'));
    assert.ok(html.includes('blocked'));
  });

  test('renders artifact open actions only for present artifacts', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const alpha = model.projects.find((project) => project.projectId === 'alpha');

    assert.ok(alpha);

    const feature = alpha.features[0];
    const presentArtifact = feature.artifacts.find((artifact) => artifact.name === 'feature_br_summary.md');

    assert.ok(presentArtifact);

    const html = renderDashboardHtml({
      kind: 'dashboard',
      title: 'Overmind Dashboard',
      message: 'Showing read-only ASDLC state.',
      model
    });

    assert.ok(html.includes(`data-artifact-uri="${presentArtifact.uri}"`));
    assert.ok(html.includes('vscode.postMessage'));
    assert.ok(html.includes("type: 'openArtifact'"));
    assert.ok(html.includes("type: 'refreshDashboard'"));
    assert.ok(html.includes("type: 'runScriptAction'"));
    assert.ok(html.includes("type: 'captureTaskToBr'"));
    assert.ok(html.includes("message.type !== 'captureTaskToBrResult'"));
    assert.ok(html.includes('Capture request submitted.'));
    assert.ok(html.includes('setCapturePending(form, true)'));
    assert.ok(html.includes('form-message-success'));
    assert.ok(html.includes('form-message-warning'));
    assert.ok(html.includes('form-message-error'));
    assert.ok(html.includes('<button class="artifact-action" type="button" disabled aria-disabled="true">Missing</button>'));
  });

  test('renders loading, empty, stale, and error states', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const staleModel: DashboardModel = {
      ...model,
      scanStatus: 'stale'
    };
    const loadingHtml = renderDashboardHtml({
      kind: 'loading',
      title: 'Overmind Dashboard',
      message: 'Detecting ASDLC workspace.'
    });
    const emptyHtml = renderDashboardHtml({
      kind: 'empty',
      title: 'No ASDLC Workspace Detected',
      message: 'Open an ASDLC folder.'
    });
    const staleHtml = renderDashboardHtml({
      kind: 'dashboard',
      title: 'Overmind Dashboard',
      message: 'Showing stale data.',
      model: staleModel
    });
    const errorHtml = renderDashboardHtml({
      kind: 'error',
      title: 'ASDLC Scan Failed',
      message: 'The dashboard could not parse metadata.',
      diagnostics: [
        {
          severity: 'error',
          code: 'asdlc.metadata.parseFailed',
          path: 'asdlc_metadata.yaml',
          message: 'parse failed'
        }
      ]
    });

    assert.ok(loadingHtml.includes('Scanning ASDLC workspace data'));
    assert.ok(emptyHtml.includes('No ASDLC Workspace Detected'));
    assert.ok(staleHtml.includes('stale'));
    assert.ok(errorHtml.includes('ASDLC Scan Failed'));
    assert.ok(errorHtml.includes('asdlc.metadata.parseFailed'));
  });
});

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
