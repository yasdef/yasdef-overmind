import { existsSync, mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  getScalarField,
  readRequiredTextFile,
  resolveInputPath
} from "../parse/index.js";

import type { CaptureResult } from "../types/index.js";

export interface TaskToBrCaptureOptions {
  sourceFile?: string;
  jira?: string;
  overwrite?: boolean;
}

export function captureTaskToBrInput(
  featurePath: string,
  options: TaskToBrCaptureOptions,
  cwd = process.cwd()
): CaptureResult {
  if (!featurePath || featurePath.trim() === "") {
    return captureError("Missing feature path.");
  }

  const featureDir = resolveInputPath(featurePath, cwd);
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    return captureError(`Feature path directory not found: ${featurePath}`);
  }

  const sourceFile = options.sourceFile?.trim();
  const jira = options.jira?.trim();
  if ((sourceFile && jira) || (!sourceFile && !jira)) {
    return captureError("Provide exactly one input source: --source-file <path> or --jira <ticket>.");
  }

  const targetBrPath = path.join(featureDir, "feature_br_summary.md");
  if (!existsSync(targetBrPath)) {
    return captureError(`Required file not found: ${displayPath(targetBrPath, cwd)}`);
  }

  const userInputPath = path.join(featureDir, "user_br_input.md");
  if (existsSync(userInputPath) && !options.overwrite) {
    return {
      exitCode: 0,
      message: `user BR input already captured: ${displayPath(userInputPath, cwd)}`
    };
  }

  const summary = readRequiredTextFile(targetBrPath);
  const featureId = normalizeCaptureField(getScalarField(summary, "feature_id"));
  const featureTitle = normalizeCaptureField(getScalarField(summary, "feature_title"));
  const requestSummary = featureTitle;
  const additionalBusinessContext = "[UNFILLED]";

  let epicStorySourceFile = "";
  let epicStory = "";
  let jiraTicket = "";

  if (sourceFile) {
    const sourceResolution = resolveStorySourceFile(sourceFile, featureDir, cwd);
    if (!sourceResolution.ok) {
      return captureError(sourceResolution.error);
    }
    epicStorySourceFile = displayPath(sourceResolution.path, cwd);
    epicStory = readFileSync(sourceResolution.path, "utf8");
    if (epicStory.trim() === "") {
      return captureError(`Epic/Story source file exists but it is empty: ${displayPath(sourceResolution.path, cwd)}`);
    }
  } else if (jira) {
    jiraTicket = jira;
    epicStorySourceFile = `jira:${jiraTicket}`;
  }

  mkdirSync(path.dirname(userInputPath), { recursive: true });
  writeFileSync(
    userInputPath,
    renderUserBrInput({
      capturedAt: new Date().toISOString().slice(0, 10),
      jiraTicket,
      featureId,
      featureTitle,
      epicStorySourceFile,
      epicStory,
      requestSummary,
      additionalBusinessContext
    })
  );

  return {
    exitCode: 0,
    message: `captured task-to-BR input: ${displayPath(userInputPath, cwd)}`
  };
}

type SourceResolution =
  | { ok: true; path: string }
  | { ok: false; error: string };

function resolveStorySourceFile(sourceInput: string, featureDir: string, cwd: string): SourceResolution {
  if (!/\.(txt|md)$/i.test(sourceInput)) {
    return { ok: false, error: "Epic/Story source file must use .txt or .md extension." };
  }

  const sourcePath = resolveStorySourceCandidate(sourceInput, featureDir, cwd);
  if (!sourcePath) {
    return { ok: false, error: `Epic/Story source file not found: ${sourceInput}` };
  }
  if (!statSync(sourcePath).isFile()) {
    return { ok: false, error: `Epic/Story source path is not a file: ${displayPath(sourcePath, cwd)}` };
  }

  const featureRoot = realpathSync(featureDir);
  const resolvedSourcePath = realpathSync(sourcePath);
  const relativeToFeature = path.relative(featureRoot, resolvedSourcePath);
  if (relativeToFeature === "" || relativeToFeature.startsWith("..") || path.isAbsolute(relativeToFeature)) {
    return {
      ok: false,
      error: `Epic/Story source file must be inside feature path root: ${displayPath(featureDir, cwd)}`
    };
  }

  return { ok: true, path: resolvedSourcePath };
}

function resolveStorySourceCandidate(sourceInput: string, featureDir: string, cwd: string): string | undefined {
  if (path.isAbsolute(sourceInput)) {
    const candidate = path.normalize(sourceInput);
    return existsSync(candidate) ? candidate : undefined;
  }

  const normalizedInput = path.normalize(sourceInput.replace(/^\.\//, ""));
  const featureRelativePath = path.relative(cwd, featureDir);
  const candidate = normalizedInput === featureRelativePath || normalizedInput.startsWith(`${featureRelativePath}${path.sep}`)
    ? path.resolve(cwd, normalizedInput)
    : path.resolve(featureDir, normalizedInput);

  return existsSync(candidate) ? candidate : undefined;
}

function renderUserBrInput(input: {
  capturedAt: string;
  jiraTicket: string;
  featureId: string;
  featureTitle: string;
  epicStorySourceFile: string;
  epicStory: string;
  requestSummary: string;
  additionalBusinessContext: string;
}): string {
  const lines = [
    "# User Business Input",
    "",
    "## 1. Capture Meta",
    `- captured_at: ${input.capturedAt}`
  ];
  if (input.jiraTicket !== "") {
    lines.push(`- jira_ticket: ${input.jiraTicket}`);
  }
  lines.push(
    "",
    "## 2. Epic/Story Input",
    `- feature_id: ${input.featureId}`,
    `- feature_title: ${input.featureTitle}`,
    `- epic_story_source_file: ${input.epicStorySourceFile}`,
    "- epic_or_story: |"
  );
  for (const line of input.epicStory.split(/\r?\n/)) {
    lines.push(`  ${line}`);
  }
  lines.push(
    `- request_summary: ${input.requestSummary}`,
    `- additional_business_context: ${input.additionalBusinessContext}`
  );
  return `${lines.join("\n")}\n`;
}

function normalizeCaptureField(value: string | undefined): string {
  if (!value || value.trim() === "") {
    return "[UNFILLED]";
  }
  return value;
}

function captureError(message: string): CaptureResult {
  return {
    exitCode: 2,
    errorMessage: message
  };
}
