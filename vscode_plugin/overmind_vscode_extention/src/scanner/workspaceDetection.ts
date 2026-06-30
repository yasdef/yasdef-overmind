import * as vscode from 'vscode';

export const ASDLC_METADATA_FILE = 'asdlc_metadata.yaml';
export const ACTIVE_ASDLC_WORKSPACE_KEY = 'overmind.activeAsdlcWorkspaceUri';

export type DiagnosticSeverity = 'info' | 'warning' | 'error';

export interface WorkspaceFileSystem {
  stat(uri: vscode.Uri): Thenable<vscode.FileStat>;
  readFile(uri: vscode.Uri): Thenable<Uint8Array>;
}

export interface WorkspaceFolderLike {
  readonly uri: vscode.Uri;
  readonly name: string;
  readonly index: number;
}

export interface AsdlcWorkspaceDiagnostic {
  readonly severity: DiagnosticSeverity;
  readonly code: string;
  readonly path: string;
  readonly message: string;
}

export interface AsdlcWorkspaceCandidate {
  readonly workspaceUri: vscode.Uri;
  readonly workspaceName: string;
  readonly metadataUri: vscode.Uri;
  readonly diagnostics: AsdlcWorkspaceDiagnostic[];
}

export interface AsdlcWorkspaceDetection {
  readonly candidates: AsdlcWorkspaceCandidate[];
  readonly diagnostics: AsdlcWorkspaceDiagnostic[];
}

export type ActiveAsdlcWorkspaceStatus =
  | 'selected'
  | 'noWorkspaceFolders'
  | 'notFound'
  | 'selectionRequired'
  | 'selectionCancelled';

export type ActiveAsdlcWorkspaceSelectionReason = 'single' | 'stored' | 'prompted';

export interface ActiveAsdlcWorkspaceResolution {
  readonly status: ActiveAsdlcWorkspaceStatus;
  readonly detection: AsdlcWorkspaceDetection;
  readonly workspace?: AsdlcWorkspaceCandidate;
  readonly selectionReason?: ActiveAsdlcWorkspaceSelectionReason;
}

export interface ResolveActiveAsdlcWorkspaceOptions {
  readonly fileSystem?: WorkspaceFileSystem;
  readonly storedWorkspaceUri?: string;
  readonly chooseWorkspace?: (
    candidates: AsdlcWorkspaceCandidate[]
  ) => Promise<AsdlcWorkspaceCandidate | undefined>;
  readonly storeActiveWorkspaceUri?: (workspaceUri: string) => Thenable<void> | Promise<void> | void;
}

export async function resolveActiveAsdlcWorkspace(
  workspaceFolders: readonly WorkspaceFolderLike[] | undefined,
  options: ResolveActiveAsdlcWorkspaceOptions = {}
): Promise<ActiveAsdlcWorkspaceResolution> {
  const detection = await detectAsdlcWorkspaceFolders(workspaceFolders, options.fileSystem);

  if (!workspaceFolders || workspaceFolders.length === 0) {
    return { status: 'noWorkspaceFolders', detection };
  }

  if (detection.candidates.length === 0) {
    return { status: 'notFound', detection };
  }

  if (detection.candidates.length === 1) {
    return {
      status: 'selected',
      detection,
      workspace: detection.candidates[0],
      selectionReason: 'single'
    };
  }

  const storedWorkspace = findStoredWorkspace(detection.candidates, options.storedWorkspaceUri);

  if (storedWorkspace) {
    return {
      status: 'selected',
      detection,
      workspace: storedWorkspace,
      selectionReason: 'stored'
    };
  }

  if (!options.chooseWorkspace) {
    return { status: 'selectionRequired', detection };
  }

  const selectedWorkspace = await options.chooseWorkspace(detection.candidates);

  if (!selectedWorkspace) {
    return { status: 'selectionCancelled', detection };
  }

  await options.storeActiveWorkspaceUri?.(selectedWorkspace.workspaceUri.toString());

  return {
    status: 'selected',
    detection,
    workspace: selectedWorkspace,
    selectionReason: 'prompted'
  };
}

export async function detectAsdlcWorkspaceFolders(
  workspaceFolders: readonly WorkspaceFolderLike[] | undefined,
  fileSystem: WorkspaceFileSystem = vscode.workspace.fs
): Promise<AsdlcWorkspaceDetection> {
  if (!workspaceFolders || workspaceFolders.length === 0) {
    const diagnostic = createDiagnostic(
      'info',
      'workspace.none',
      '',
      'No VS Code workspace folders are open.'
    );

    return {
      candidates: [],
      diagnostics: [diagnostic]
    };
  }

  const inspectedFolders = await Promise.all(
    workspaceFolders.map((folder) => inspectWorkspaceFolder(folder, fileSystem))
  );
  const candidates = inspectedFolders.flatMap((result) => result.candidate ? [result.candidate] : []);
  const diagnostics = inspectedFolders.flatMap((result) => result.diagnostics);

  return { candidates, diagnostics };
}

export function getWorkspaceDisplayPath(uri: vscode.Uri): string {
  return uri.scheme === 'file' ? uri.fsPath : uri.toString();
}

async function inspectWorkspaceFolder(
  folder: WorkspaceFolderLike,
  fileSystem: WorkspaceFileSystem
): Promise<{ candidate?: AsdlcWorkspaceCandidate; diagnostics: AsdlcWorkspaceDiagnostic[] }> {
  const metadataUri = vscode.Uri.joinPath(folder.uri, ASDLC_METADATA_FILE);
  const metadataPath = getWorkspaceDisplayPath(metadataUri);

  let metadataStat: vscode.FileStat;

  try {
    metadataStat = await fileSystem.stat(metadataUri);
  } catch {
    return {
      diagnostics: [
        createDiagnostic(
          'info',
          'asdlc.metadata.missing',
          metadataPath,
          `Workspace folder "${folder.name}" does not contain ${ASDLC_METADATA_FILE}.`
        )
      ]
    };
  }

  if ((metadataStat.type & vscode.FileType.File) === 0) {
    return {
      diagnostics: [
        createDiagnostic(
          'error',
          'asdlc.metadata.notFile',
          metadataPath,
          `${ASDLC_METADATA_FILE} exists but is not a file.`
        )
      ]
    };
  }

  const diagnostics = await validateMetadataFile(metadataUri, fileSystem);
  const candidate: AsdlcWorkspaceCandidate = {
    workspaceUri: folder.uri,
    workspaceName: folder.name,
    metadataUri,
    diagnostics
  };

  return { candidate, diagnostics };
}

async function validateMetadataFile(
  metadataUri: vscode.Uri,
  fileSystem: WorkspaceFileSystem
): Promise<AsdlcWorkspaceDiagnostic[]> {
  const metadataPath = getWorkspaceDisplayPath(metadataUri);

  try {
    const content = Buffer.from(await fileSystem.readFile(metadataUri)).toString('utf8');
    const trimmedContent = content.trim();

    if (trimmedContent.length === 0) {
      return [
        createDiagnostic(
          'error',
          'asdlc.metadata.empty',
          metadataPath,
          `${ASDLC_METADATA_FILE} is empty.`
        )
      ];
    }

    if (!looksLikeYamlMapping(trimmedContent)) {
      return [
        createDiagnostic(
          'warning',
          'asdlc.metadata.unrecognized',
          metadataPath,
          `${ASDLC_METADATA_FILE} does not look like ASDLC mapping metadata.`
        )
      ];
    }

    return [];
  } catch (error) {
    return [
      createDiagnostic(
        'error',
        'asdlc.metadata.unreadable',
        metadataPath,
        `Could not read ${ASDLC_METADATA_FILE}: ${getErrorMessage(error)}`
      )
    ];
  }
}

function looksLikeYamlMapping(content: string): boolean {
  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'))
    .some((line) => /^[A-Za-z0-9_.-]+:\s*/.test(line));
}

function findStoredWorkspace(
  candidates: readonly AsdlcWorkspaceCandidate[],
  storedWorkspaceUri: string | undefined
): AsdlcWorkspaceCandidate | undefined {
  if (!storedWorkspaceUri) {
    return undefined;
  }

  return candidates.find((candidate) =>
    candidate.workspaceUri.toString() === storedWorkspaceUri ||
    getWorkspaceDisplayPath(candidate.workspaceUri) === storedWorkspaceUri
  );
}

function createDiagnostic(
  severity: DiagnosticSeverity,
  code: string,
  diagnosticPath: string,
  message: string
): AsdlcWorkspaceDiagnostic {
  return {
    severity,
    code,
    path: diagnosticPath,
    message
  };
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
