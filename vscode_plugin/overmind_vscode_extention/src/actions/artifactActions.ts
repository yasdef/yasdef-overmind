import * as vscode from 'vscode';
import type { ArtifactSummary, DashboardModel } from '../scanner/asdlcScanner';

export const OPEN_ARTIFACT_MESSAGE_TYPE = 'openArtifact';

export type ArtifactOpenResult = 'ignored' | 'opened' | 'rejected';

export interface OpenArtifactMessage {
  readonly type: typeof OPEN_ARTIFACT_MESSAGE_TYPE;
  readonly artifactUri: string;
}

export interface ArtifactOpenServices {
  readonly fileSystem: {
    stat(uri: vscode.Uri): Thenable<vscode.FileStat>;
  };
  readonly openTextDocument: (uri: vscode.Uri) => Thenable<vscode.TextDocument>;
  readonly showTextDocument: (document: vscode.TextDocument) => Thenable<vscode.TextEditor>;
  readonly showWarningMessage?: (message: string) => Thenable<unknown>;
  readonly log?: (message: string) => void;
}

export async function handleDashboardWebviewMessage(
  message: unknown,
  model: DashboardModel | undefined,
  services: ArtifactOpenServices = createDefaultServices()
): Promise<ArtifactOpenResult> {
  if (!isOpenArtifactMessage(message)) {
    return 'ignored';
  }

  return openArtifact(message.artifactUri, model, services);
}

export async function openArtifact(
  artifactUri: string,
  model: DashboardModel | undefined,
  services: ArtifactOpenServices = createDefaultServices()
): Promise<ArtifactOpenResult> {
  const artifact = findArtifact(model, artifactUri);

  if (!model || !artifact) {
    await rejectOpen(
      services,
      'Artifact is not available in the current dashboard scan.',
      `[warning] artifact.open.rejected: unknown artifact ${artifactUri}`
    );

    return 'rejected';
  }

  if (!artifact.exists) {
    await rejectOpen(
      services,
      `Artifact is missing: ${artifact.path}`,
      `[warning] artifact.open.rejected: missing artifact ${artifact.path}`
    );

    return 'rejected';
  }

  const uri = vscode.Uri.parse(artifact.uri, true);

  try {
    const stat = await services.fileSystem.stat(uri);

    if ((stat.type & vscode.FileType.File) === 0) {
      await rejectOpen(
        services,
        `Artifact is not a file: ${artifact.path}`,
        `[warning] artifact.open.rejected: not a file ${artifact.path}`
      );

      return 'rejected';
    }

    const document = await services.openTextDocument(uri);

    await services.showTextDocument(document);
    services.log?.(`[info] artifact.opened: ${artifact.path}`);

    return 'opened';
  } catch (error) {
    await rejectOpen(
      services,
      `Could not open artifact: ${artifact.path}`,
      `[error] artifact.open.failed: ${artifact.path} - ${getErrorMessage(error)}`
    );

    return 'rejected';
  }
}

function findArtifact(model: DashboardModel | undefined, artifactUri: string): ArtifactSummary | undefined {
  if (!model) {
    return undefined;
  }

  for (const project of model.projects) {
    const projectArtifact = project.artifacts.find((artifact) => artifact.uri === artifactUri);

    if (projectArtifact) {
      return projectArtifact;
    }

    for (const feature of project.features) {
      const featureArtifact = feature.artifacts.find((artifact) => artifact.uri === artifactUri);

      if (featureArtifact) {
        return featureArtifact;
      }
    }
  }

  return undefined;
}

function isOpenArtifactMessage(message: unknown): message is OpenArtifactMessage {
  return isRecord(message) &&
    message.type === OPEN_ARTIFACT_MESSAGE_TYPE &&
    typeof message.artifactUri === 'string' &&
    message.artifactUri.trim().length > 0;
}

async function rejectOpen(
  services: ArtifactOpenServices,
  userMessage: string,
  logMessage: string
): Promise<void> {
  services.log?.(logMessage);
  await services.showWarningMessage?.(userMessage);
}

function createDefaultServices(): ArtifactOpenServices {
  return {
    fileSystem: vscode.workspace.fs,
    openTextDocument: (uri) => vscode.workspace.openTextDocument(uri),
    showTextDocument: (document) => vscode.window.showTextDocument(document),
    showWarningMessage: (message) => vscode.window.showWarningMessage(message)
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
