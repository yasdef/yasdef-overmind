import type {
  ArtifactSummary,
  DashboardModel,
  FeatureSummary,
  ProjectClassSummary,
  ProjectSummary
} from '../scanner/asdlcScanner';
import type { AsdlcWorkspaceDiagnostic } from '../scanner/workspaceDetection';

export type DashboardViewKind = 'loading' | 'dashboard' | 'empty' | 'error';

export interface DashboardViewState {
  readonly kind: DashboardViewKind;
  readonly title: string;
  readonly message: string;
  readonly model?: DashboardModel;
  readonly metadataPath?: string;
  readonly diagnostics?: readonly AsdlcWorkspaceDiagnostic[];
}

export function renderDashboardHtml(state: DashboardViewState): string {
  const diagnostics = state.diagnostics ?? state.model?.diagnostics ?? [];
  const body = renderStateBody(state, diagnostics);
  const nonce = createNonce();

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Overmind Dashboard</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: var(--vscode-font-family);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      padding: 20px;
      min-width: 320px;
    }

    main {
      max-width: 1180px;
    }

    h1 {
      margin: 0 0 8px;
      font-size: 22px;
      line-height: 1.25;
      font-weight: 600;
    }

    h2 {
      margin: 0 0 10px;
      font-size: 15px;
      line-height: 1.35;
      font-weight: 600;
    }

    h3 {
      margin: 0;
      font-size: 13px;
      line-height: 1.35;
      font-weight: 600;
    }

    p {
      margin: 0;
      line-height: 1.45;
      color: var(--vscode-descriptionForeground);
    }

    .header {
      padding-bottom: 14px;
      border-bottom: 1px solid var(--vscode-panel-border);
    }

    .header-row {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
    }

    .section {
      padding-top: 18px;
      margin-top: 18px;
      border-top: 1px solid var(--vscode-panel-border);
    }

    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 10px;
      margin-top: 14px;
    }

    .metric {
      min-width: 0;
      padding: 10px;
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      background: var(--vscode-editorWidget-background);
    }

    .metric-label {
      margin-bottom: 3px;
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
    }

    .metric-value {
      font-size: 18px;
      line-height: 1.2;
      font-weight: 600;
      overflow-wrap: anywhere;
    }

    .project-list {
      display: grid;
      gap: 10px;
    }

    details.project,
    details.feature {
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      background: var(--vscode-sideBar-background);
    }

    summary {
      cursor: pointer;
      list-style-position: outside;
    }

    .project-summary,
    .feature-summary {
      display: grid;
      grid-template-columns: minmax(180px, 1fr) repeat(3, max-content);
      gap: 12px;
      align-items: center;
      padding: 10px 12px;
    }

    .feature-summary {
      grid-template-columns: minmax(180px, 1fr) repeat(2, max-content);
    }

    .project-body,
    .feature-body {
      padding: 0 12px 12px;
    }

    .subgrid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
      margin-top: 10px;
    }

    .compact-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
    }

    .compact-table th,
    .compact-table td {
      padding: 6px 8px;
      text-align: left;
      vertical-align: top;
      border-bottom: 1px solid var(--vscode-panel-border);
    }

    .compact-table th {
      color: var(--vscode-descriptionForeground);
      font-weight: 600;
    }

    .path,
    .mono {
      font-family: var(--vscode-editor-font-family);
      overflow-wrap: anywhere;
    }

    .badge {
      display: inline-block;
      min-width: 76px;
      padding: 2px 7px;
      border: 1px solid var(--vscode-panel-border);
      border-radius: 999px;
      text-align: center;
      font-size: 11px;
      line-height: 1.5;
      color: var(--vscode-foreground);
      background: var(--vscode-badge-background);
    }

    .badge-ready,
    .badge-complete {
      background: var(--vscode-testing-iconPassed);
      color: var(--vscode-editor-background);
    }

    .badge-partial,
    .badge-in_progress,
    .badge-stale,
    .badge-scanning {
      background: var(--vscode-notificationsWarningIcon-foreground);
      color: var(--vscode-editor-background);
    }

    .badge-blocked,
    .badge-failed {
      background: var(--vscode-errorForeground);
      color: var(--vscode-editor-background);
    }

    .badge-deferred,
    .badge-unknown {
      background: var(--vscode-descriptionForeground);
      color: var(--vscode-editor-background);
    }

    .feature-list {
      display: grid;
      gap: 8px;
      margin-top: 10px;
    }

    .empty-note {
      margin-top: 10px;
      padding: 10px;
      border: 1px dashed var(--vscode-panel-border);
      border-radius: 6px;
      color: var(--vscode-descriptionForeground);
    }

    ul {
      margin: 0;
      padding-left: 18px;
    }

    li + li {
      margin-top: 5px;
    }

    .toolbar-button,
    .artifact-action,
    .script-action {
      min-width: 72px;
      padding: 4px 8px;
      border: 1px solid var(--vscode-button-border, transparent);
      border-radius: 4px;
      color: var(--vscode-button-foreground);
      background: var(--vscode-button-background);
      font: inherit;
      cursor: pointer;
    }

    .toolbar-button {
      flex: 0 0 auto;
      margin-top: 1px;
    }

    .toolbar-button:hover,
    .artifact-action:hover:not(:disabled),
    .script-action:hover:not(:disabled) {
      background: var(--vscode-button-hoverBackground);
    }

    .artifact-action:disabled,
    .script-action:disabled {
      cursor: default;
      color: var(--vscode-disabledForeground);
      background: var(--vscode-button-secondaryBackground);
    }

    .script-action {
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
    }

    .script-action-danger {
      border-color: var(--vscode-notificationsWarningIcon-foreground);
    }

    .action-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
      margin-top: 10px;
    }

    .capture-form {
      display: grid;
      gap: 10px;
      margin-top: 10px;
      max-width: 560px;
    }

    .capture-source {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin: 0;
      padding: 0;
      border: 0;
    }

    .capture-source legend {
      margin-bottom: 6px;
      color: var(--vscode-descriptionForeground);
      font-size: 12px;
      font-weight: 600;
    }

    .capture-source label,
    .capture-field label {
      display: grid;
      gap: 5px;
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
    }

    .capture-source label {
      display: inline-flex;
      grid-template-columns: none;
      align-items: center;
      gap: 6px;
      color: var(--vscode-foreground);
    }

    .capture-field input {
      width: 100%;
      min-height: 28px;
      padding: 4px 7px;
      border: 1px solid var(--vscode-input-border, var(--vscode-panel-border));
      border-radius: 4px;
      color: var(--vscode-input-foreground);
      background: var(--vscode-input-background);
      font: inherit;
    }

    .form-error {
      color: var(--vscode-errorForeground);
      font-size: 12px;
      line-height: 1.4;
    }

    .form-message {
      margin-top: 10px;
      padding: 8px 10px;
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      font-size: 12px;
      line-height: 1.4;
      overflow-wrap: anywhere;
    }

    .form-message-info {
      color: var(--vscode-descriptionForeground);
      background: var(--vscode-editorWidget-background);
    }

    .form-message-success {
      border-color: var(--vscode-testing-iconPassed);
      color: var(--vscode-foreground);
      background: var(--vscode-editorWidget-background);
    }

    .form-message-warning {
      border-color: var(--vscode-notificationsWarningIcon-foreground);
      color: var(--vscode-foreground);
      background: var(--vscode-editorWidget-background);
    }

    .form-message-error {
      border-color: var(--vscode-errorForeground);
      color: var(--vscode-errorForeground);
      background: var(--vscode-editorWidget-background);
    }

    .capture-form:has(:disabled) {
      opacity: 0.82;
    }

    @media (max-width: 760px) {
      .project-summary,
      .feature-summary {
        grid-template-columns: 1fr;
        gap: 6px;
      }

      .badge {
        width: max-content;
      }

      .header-row {
        display: block;
      }

      .toolbar-button {
        margin-top: 8px;
      }
    }
  </style>
</head>
<body>
  <main>${body}</main>
  ${renderWebviewScript(nonce)}
</body>
</html>`;
}

function renderStateBody(
  state: DashboardViewState,
  diagnostics: readonly AsdlcWorkspaceDiagnostic[]
): string {
  const header = renderHeader(state);

  if (state.kind === 'loading') {
    return `${header}<section class="section"><p>Scanning ASDLC workspace data...</p></section>`;
  }

  if (state.kind === 'empty' || state.kind === 'error' || !state.model) {
    return `${header}${renderDiagnostics(diagnostics)}`;
  }

  return `${header}
    ${renderWorkspaceSummary(state.model, state.metadataPath)}
    ${renderProjects(state.model.projects)}
    ${renderDiagnostics(diagnostics)}`;
}

function renderHeader(state: DashboardViewState): string {
  const scanBadge = state.model ? `<span class="badge badge-${escapeClass(state.model.scanStatus)}">${escapeHtml(state.model.scanStatus)}</span>` : '';
  const refreshButton = state.model
    ? '<button class="toolbar-button" type="button" data-dashboard-action="refresh">Refresh</button>'
    : '';

  return `<section class="header">
    <div class="header-row">
      <h1>${escapeHtml(state.title)} ${scanBadge}</h1>
      ${refreshButton}
    </div>
    <p>${escapeHtml(state.message)}</p>
  </section>`;
}

function renderWorkspaceSummary(model: DashboardModel, metadataPath: string | undefined): string {
  const projectCount = model.projects.length;
  const featureCount = model.projects.reduce((count, project) => count + project.features.length, 0);
  const blockedCount = model.projects.filter((project) => project.projectReadiness === 'blocked').length;
  const diagnosticsCount = model.diagnostics.length;

  return `<section class="section">
    <h2>Workspace</h2>
    <table class="compact-table">
      <tbody>
        <tr>
          <th>Path</th>
          <td class="path">${escapeHtml(model.workspacePath)}</td>
        </tr>
        ${metadataPath ? `<tr><th>Metadata</th><td class="path">${escapeHtml(metadataPath)}</td></tr>` : ''}
      </tbody>
    </table>
    <div class="summary-grid">
      ${renderMetric('Projects', String(projectCount))}
      ${renderMetric('Features', String(featureCount))}
      ${renderMetric('Blocked Projects', String(blockedCount))}
      ${renderMetric('Diagnostics', String(diagnosticsCount))}
    </div>
    ${renderWorkspaceActions()}
  </section>`;
}

function renderProjects(projects: readonly ProjectSummary[]): string {
  if (projects.length === 0) {
    return `<section class="section">
      <h2>Projects</h2>
      <div class="empty-note">No projects were found in asdlc_metadata.yaml.</div>
    </section>`;
  }

  return `<section class="section">
    <h2>Projects</h2>
    <div class="project-list">${projects.map(renderProject).join('')}</div>
  </section>`;
}

function renderProject(project: ProjectSummary): string {
  return `<details class="project" open>
    <summary class="project-summary">
      <div>
        <h3>${escapeHtml(project.name)}</h3>
        <div class="mono">${escapeHtml(project.projectId)}</div>
      </div>
      ${renderBadge(project.projectReadiness)}
      <span>${escapeHtml(formatStepCount(project.completedSteps, project.totalSteps))}</span>
      <span>${project.features.length} feature${project.features.length === 1 ? '' : 's'}</span>
    </summary>
    <div class="project-body">
      <div class="subgrid">
        <div>
          <h3>Project Details</h3>
          ${renderProjectDetails(project)}
        </div>
        <div>
          <h3>Repo Classes</h3>
          ${renderClasses(project.classes)}
        </div>
      </div>
      ${renderMissingArtifacts(project.missingArtifacts)}
      ${renderProjectActions(project)}
      ${renderArtifacts(project.artifacts, 'Project Artifacts')}
      ${renderFeatures(project)}
    </div>
  </details>`;
}

function renderProjectDetails(project: ProjectSummary): string {
  const rows = [
    ['Folder', project.folderPath],
    ['Created', project.createdAt ?? 'unknown'],
    ['Project Type', project.projectTypeCode ?? 'unknown']
  ];

  return `<table class="compact-table"><tbody>${rows.map(([label, value]) =>
    `<tr><th>${escapeHtml(label)}</th><td class="path">${escapeHtml(value)}</td></tr>`
  ).join('')}</tbody></table>`;
}

function renderClasses(classes: readonly ProjectClassSummary[]): string {
  if (classes.length === 0) {
    return '<div class="empty-note">No repo classes detected.</div>';
  }

  const rows = classes.map((projectClass) => `<tr>
    <td>${escapeHtml(projectClass.className)}</td>
    <td>${renderBadge(projectClass.state)}</td>
    <td class="path">${escapeHtml(projectClass.repoPath ?? '')}</td>
  </tr>`);

  return `<table class="compact-table">
    <thead><tr><th>Class</th><th>State</th><th>Repo</th></tr></thead>
    <tbody>${rows.join('')}</tbody>
  </table>`;
}

function renderFeatures(project: ProjectSummary): string {
  const features = project.features;

  if (features.length === 0) {
    return '<div class="empty-note">No feature folders with feature_br_summary.md were found.</div>';
  }

  return `<div class="feature-list">${features.map((feature) => renderFeature(project, feature)).join('')}</div>`;
}

function renderFeature(project: ProjectSummary, feature: FeatureSummary): string {
  return `<details class="feature">
    <summary class="feature-summary">
      <div>
        <h3>${escapeHtml(feature.name)}</h3>
        <div class="mono">${escapeHtml(feature.featureId)}</div>
      </div>
      ${renderBadge(feature.readiness)}
      <span>${escapeHtml(formatStepCount(feature.completedSteps, feature.totalSteps))}</span>
    </summary>
    <div class="feature-body">
      <table class="compact-table">
        <tbody>
          <tr><th>Folder</th><td class="path">${escapeHtml(feature.folderPath)}</td></tr>
        </tbody>
      </table>
      ${renderMissingArtifacts(feature.missingArtifacts)}
      ${renderFeatureActions(project, feature)}
      ${renderArtifacts(feature.artifacts, 'Feature Artifacts')}
    </div>
  </details>`;
}

function renderWorkspaceActions(): string {
  return `<div class="section">
    <h3>Terminal Actions</h3>
    <div class="action-row">
      ${renderScriptActionButton('createProject', 'Create Project')}
    </div>
  </div>`;
}

function renderProjectActions(project: ProjectSummary): string {
  return `<div class="section">
    <h3>Terminal Actions</h3>
    <div class="action-row">
      ${renderScriptActionButton(
        'createOrContinueFeature',
        'Create Feature / Continue E2E',
        project.projectId
      )}
    </div>
  </div>`;
}

function renderFeatureActions(project: ProjectSummary, feature: FeatureSummary): string {
  return `${renderTaskToBrCapture(project, feature)}
  <div class="section">
    <h3>Terminal Actions</h3>
    <div class="action-row">
      ${renderScriptActionButton(
        'runInitProgressScanner',
        'Run Scanner',
        project.projectId,
        feature.featureId
      )}
    </div>
  </div>`;
}

function renderTaskToBrCapture(project: ProjectSummary, feature: FeatureSummary): string {
  const userBrArtifact = feature.artifacts.find((artifact) => artifact.name === 'user_br_input.md');
  const userBrExists = userBrArtifact?.exists === true;
  const formHiddenAttribute = userBrExists ? ' hidden' : '';
  const sourceName = escapeHtml(`capture-source-${project.projectId}-${feature.featureId}`);
  const recaptureButton = userBrExists
    ? '<button class="script-action" type="button" data-capture-toggle>Recapture</button>'
    : '';
  const cancelButton = userBrExists
    ? '<button class="script-action" type="button" data-capture-cancel>Cancel</button>'
    : '';

  return `<div class="section capture-panel" data-capture-panel data-project-id="${escapeHtml(project.projectId)}" data-feature-id="${escapeHtml(feature.featureId)}">
    <h3>Task-to-BR Capture</h3>
    <div class="form-message" data-capture-status role="status" hidden></div>
    ${recaptureButton ? `<div class="action-row">${recaptureButton}</div>` : ''}
    <form class="capture-form" data-capture-form data-project-id="${escapeHtml(project.projectId)}" data-feature-id="${escapeHtml(feature.featureId)}"${formHiddenAttribute}>
      <fieldset class="capture-source">
        <legend>Source</legend>
        <label>
          <input type="radio" name="${sourceName}" value="localFile" data-capture-source-kind checked>
          Story file
        </label>
        <label>
          <input type="radio" name="${sourceName}" value="jira" data-capture-source-kind>
          Jira ticket
        </label>
      </fieldset>
      <div class="capture-field" data-capture-local-field>
        <label>
          Story file (.txt/.md)
          <input type="text" data-capture-source-file autocomplete="off" placeholder="story.md">
        </label>
      </div>
      <div class="capture-field" data-capture-jira-field hidden>
        <label>
          Jira ticket
          <input type="text" data-capture-jira-ticket autocomplete="off" placeholder="PROJECT-123">
        </label>
      </div>
      <div class="action-row">
        <button class="script-action script-action-danger" type="submit" data-capture-submit>Capture</button>
        ${cancelButton}
      </div>
      <div class="form-error" data-capture-error role="alert" hidden></div>
    </form>
  </div>`;
}

function renderScriptActionButton(
  actionId: string,
  label: string,
  projectId?: string,
  featureId?: string
): string {
  const projectAttribute = projectId ? ` data-project-id="${escapeHtml(projectId)}"` : '';
  const featureAttribute = featureId ? ` data-feature-id="${escapeHtml(featureId)}"` : '';

  return `<button class="script-action script-action-danger" type="button" data-script-action-id="${escapeHtml(actionId)}"${projectAttribute}${featureAttribute}>${escapeHtml(label)}</button>`;
}

function renderArtifacts(artifacts: readonly ArtifactSummary[], title: string): string {
  if (artifacts.length === 0) {
    return '';
  }

  const rows = artifacts.map((artifact) => `<tr>
    <td>${escapeHtml(artifact.name)}</td>
    <td>${artifact.exists ? 'present' : 'missing'}</td>
    <td>${artifact.required ? 'required' : 'optional'}</td>
    <td class="path">${escapeHtml(artifact.path)}</td>
    <td>${renderArtifactAction(artifact)}</td>
  </tr>`);

  return `<div class="section">
    <h3>${escapeHtml(title)}</h3>
    <table class="compact-table">
      <thead><tr><th>Name</th><th>Status</th><th>Rule</th><th>Path</th><th>Action</th></tr></thead>
      <tbody>${rows.join('')}</tbody>
    </table>
  </div>`;
}

function renderArtifactAction(artifact: ArtifactSummary): string {
  if (!artifact.exists) {
    return '<button class="artifact-action" type="button" disabled aria-disabled="true">Missing</button>';
  }

  return `<button class="artifact-action" type="button" data-artifact-uri="${escapeHtml(artifact.uri)}">Open</button>`;
}

function renderMissingArtifacts(missingArtifacts: readonly string[]): string {
  if (missingArtifacts.length === 0) {
    return '';
  }

  return `<div class="section">
    <h3>Missing Artifacts</h3>
    <ul>${missingArtifacts.map((artifact) => `<li class="mono">${escapeHtml(artifact)}</li>`).join('')}</ul>
  </div>`;
}

function renderDiagnostics(diagnostics: readonly AsdlcWorkspaceDiagnostic[]): string {
  if (diagnostics.length === 0) {
    return '';
  }

  const items = diagnostics.map((diagnostic) => {
    const path = diagnostic.path ? ` ${diagnostic.path}` : '';

    return `<li>
      <strong>${escapeHtml(diagnostic.severity)}</strong>
      <span class="mono">${escapeHtml(diagnostic.code)}</span>
      ${escapeHtml(path)} - ${escapeHtml(diagnostic.message)}
    </li>`;
  });

  return `<section class="section">
    <h2>Diagnostics</h2>
    <ul>${items.join('')}</ul>
  </section>`;
}

function renderMetric(label: string, value: string): string {
  return `<div class="metric">
    <div class="metric-label">${escapeHtml(label)}</div>
    <div class="metric-value">${escapeHtml(value)}</div>
  </div>`;
}

function renderBadge(value: string): string {
  return `<span class="badge badge-${escapeClass(value)}">${escapeHtml(value)}</span>`;
}

function formatStepCount(completedSteps: number, totalSteps: number): string {
  return totalSteps > 0 ? `${completedSteps}/${totalSteps} steps` : 'unknown steps';
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeClass(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, '_');
}

function renderWebviewScript(nonce: string): string {
  return `<script nonce="${nonce}">
    (() => {
      const vscode = acquireVsCodeApi();

      document.addEventListener('click', (event) => {
        const target = event.target;
        const captureToggle = target instanceof Element ? target.closest('[data-capture-toggle]') : null;

        if (captureToggle instanceof HTMLElement) {
          const panel = captureToggle.closest('[data-capture-panel]');
          const form = panel ? panel.querySelector('[data-capture-form]') : null;

          if (form instanceof HTMLFormElement) {
            form.hidden = false;
            captureToggle.hidden = true;
            setCaptureStatus(panel, '', '');
            updateCaptureSourceMode(form);
          }

          return;
        }

        const captureCancel = target instanceof Element ? target.closest('[data-capture-cancel]') : null;

        if (captureCancel instanceof HTMLElement) {
          const panel = captureCancel.closest('[data-capture-panel]');
          const form = panel ? panel.querySelector('[data-capture-form]') : null;
          const toggle = panel ? panel.querySelector('[data-capture-toggle]') : null;

          if (form instanceof HTMLFormElement) {
            form.hidden = true;
            setCaptureError(form, '');
            setCapturePending(form, false);
          }

          if (toggle instanceof HTMLElement) {
            toggle.hidden = false;
          }

          setCaptureStatus(panel, 'warning', 'Capture cancelled.');
          return;
        }

        const actionButton = target instanceof Element ? target.closest('[data-dashboard-action]') : null;

        if (actionButton instanceof HTMLElement && actionButton.dataset.dashboardAction === 'refresh') {
          vscode.postMessage({
            type: 'refreshDashboard'
          });
          return;
        }

        const scriptActionButton = target instanceof Element ? target.closest('[data-script-action-id]') : null;

        if (scriptActionButton instanceof HTMLElement && !scriptActionButton.hasAttribute('disabled')) {
          vscode.postMessage({
            type: 'runScriptAction',
            actionId: scriptActionButton.dataset.scriptActionId,
            projectId: scriptActionButton.dataset.projectId,
            featureId: scriptActionButton.dataset.featureId
          });
          return;
        }

        const button = target instanceof Element ? target.closest('[data-artifact-uri]') : null;

        if (!button || button.hasAttribute('disabled')) {
          return;
        }

        const artifactUri = button.getAttribute('data-artifact-uri');

        if (!artifactUri) {
          return;
        }

        vscode.postMessage({
          type: 'openArtifact',
          artifactUri
        });
      });

      document.addEventListener('change', (event) => {
        const target = event.target;
        const sourceControl = target instanceof Element ? target.closest('[data-capture-source-kind]') : null;

        if (!(sourceControl instanceof HTMLInputElement)) {
          return;
        }

        const form = sourceControl.closest('[data-capture-form]');

        if (form instanceof HTMLFormElement) {
          updateCaptureSourceMode(form);
        }
      });

      document.addEventListener('submit', (event) => {
        const target = event.target;

        if (!(target instanceof HTMLFormElement) || !target.hasAttribute('data-capture-form')) {
          return;
        }

        event.preventDefault();
        submitCaptureForm(target);
      });

      document.querySelectorAll('[data-capture-form]').forEach((form) => {
        if (form instanceof HTMLFormElement) {
          updateCaptureSourceMode(form);
        }
      });

      window.addEventListener('message', (event) => {
        const message = event.data;

        if (!message || message.type !== 'captureTaskToBrResult') {
          return;
        }

        handleCaptureResultMessage(message);
      });

      function updateCaptureSourceMode(form) {
        const sourceKind = getSelectedCaptureKind(form);
        const localField = form.querySelector('[data-capture-local-field]');
        const jiraField = form.querySelector('[data-capture-jira-field]');

        if (localField instanceof HTMLElement) {
          localField.hidden = sourceKind !== 'localFile';
        }

        if (jiraField instanceof HTMLElement) {
          jiraField.hidden = sourceKind !== 'jira';
        }

        setCaptureError(form, '');
      }

      function submitCaptureForm(form) {
        const sourceKind = getSelectedCaptureKind(form);
        const projectId = form.dataset.projectId || '';
        const featureId = form.dataset.featureId || '';
        const sourceFileInput = form.querySelector('[data-capture-source-file]');
        const jiraInput = form.querySelector('[data-capture-jira-ticket]');
        const sourceFile = sourceFileInput instanceof HTMLInputElement ? sourceFileInput.value.trim() : '';
        const jiraTicket = jiraInput instanceof HTMLInputElement ? jiraInput.value.trim() : '';
        const validationError = validateCaptureForm({
          sourceKind,
          projectId,
          featureId,
          sourceFile,
          jiraTicket
        });

        if (validationError) {
          setCaptureError(form, validationError);
          return;
        }

        setCaptureError(form, '');
        setCapturePending(form, true);
        setCaptureStatus(form.closest('[data-capture-panel]'), 'info', 'Capture request submitted.');

        const message = {
          type: 'captureTaskToBr',
          projectId,
          featureId
        };

        if (sourceKind === 'localFile') {
          message.sourceFile = sourceFile;
        } else {
          message.jiraTicket = jiraTicket;
        }

        vscode.postMessage(message);
      }

      function handleCaptureResultMessage(message) {
        const panel = findCapturePanel(message.projectId, message.featureId);

        if (!panel) {
          return;
        }

        const form = panel.querySelector('[data-capture-form]');

        if (form instanceof HTMLFormElement) {
          setCapturePending(form, false);
        }

        if (message.status === 'captured') {
          setCaptureStatus(panel, 'success', message.message || 'Capture completed.');
          return;
        }

        if (message.status === 'cancelled') {
          setCaptureStatus(panel, 'warning', message.message || 'Capture cancelled.');
          return;
        }

        if (message.status === 'rejected') {
          setCaptureStatus(panel, 'error', message.message || 'Capture failed.');
        }
      }

      function validateCaptureForm(value) {
        if (!value.projectId || !value.featureId) {
          return 'Feature selection is unavailable.';
        }

        if (value.sourceKind === 'localFile') {
          if (!value.sourceFile) {
            return 'Select a story file.';
          }

          if (hasControlCharacters(value.sourceFile) || isAbsoluteOrUriPath(value.sourceFile)) {
            return 'Story file must be inside this feature folder.';
          }

          const segments = value.sourceFile.replace(/\\\\/g, '/').split('/');

          if (segments.some((segment) => !segment || segment === '.' || segment === '..')) {
            return 'Story file must stay inside this feature folder.';
          }

          if (!/\\.(txt|md)$/i.test(value.sourceFile)) {
            return 'Story file must be .txt or .md.';
          }

          return '';
        }

        if (value.sourceKind === 'jira') {
          if (!value.jiraTicket) {
            return 'Enter a Jira ticket.';
          }

          if (value.jiraTicket.length > 128 || hasControlCharacters(value.jiraTicket) || /\\s/.test(value.jiraTicket) || value.jiraTicket.indexOf('/') !== -1 || value.jiraTicket.indexOf('\\\\') !== -1) {
            return 'Jira ticket must be a single identifier.';
          }

          return '';
        }

        return 'Choose one source.';
      }

      function getSelectedCaptureKind(form) {
        const selected = form.querySelector('[data-capture-source-kind]:checked');

        return selected instanceof HTMLInputElement ? selected.value : '';
      }

      function setCaptureError(form, message) {
        const error = form.querySelector('[data-capture-error]');

        if (!(error instanceof HTMLElement)) {
          return;
        }

        error.textContent = message;
        error.hidden = message.length === 0;
      }

      function setCaptureStatus(panel, kind, message) {
        if (!(panel instanceof HTMLElement)) {
          return;
        }

        const status = panel.querySelector('[data-capture-status]');

        if (!(status instanceof HTMLElement)) {
          return;
        }

        status.textContent = message;
        status.hidden = message.length === 0;
        status.className = kind ? 'form-message form-message-' + kind : 'form-message';
      }

      function setCapturePending(form, pending) {
        form.querySelectorAll('input, button').forEach((control) => {
          if (control instanceof HTMLInputElement || control instanceof HTMLButtonElement) {
            control.disabled = pending;
          }
        });
      }

      function findCapturePanel(projectId, featureId) {
        const panels = document.querySelectorAll('[data-capture-panel]');

        for (const panel of panels) {
          if (panel instanceof HTMLElement &&
              panel.dataset.projectId === projectId &&
              panel.dataset.featureId === featureId) {
            return panel;
          }
        }

        return null;
      }

      function hasControlCharacters(value) {
        return /[\\x00-\\x1F\\x7F]/.test(value);
      }

      function isAbsoluteOrUriPath(value) {
        return value.startsWith('/') ||
          value.startsWith('\\\\') ||
          /^[A-Za-z]:[\\\\/]/.test(value) ||
          /^[A-Za-z][A-Za-z0-9+.-]*:/.test(value);
      }
    })();
  </script>`;
}

function createNonce(): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let nonce = '';

  for (let index = 0; index < 32; index += 1) {
    nonce += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  }

  return nonce;
}
