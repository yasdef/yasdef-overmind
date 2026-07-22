import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import type { InteractionPort } from "../interaction/index.js";
import type { Diagnostic } from "../types/index.js";

export const WORKER_CLASSES = ["backend", "frontend", "mobile", "infrastructure"] as const;
export type WorkerClass = (typeof WORKER_CLASSES)[number];

export interface WorkerClock {
  now(): string | number;
}

export interface UuidGenerator {
  next(): string;
}

export interface WorkerEntry {
  uuid: string;
  className: string;
  status: string;
  registeredAt?: string;
}

export interface RegisterWorkerDeps {
  interaction: InteractionPort;
  clock: WorkerClock;
  uuid: UuidGenerator;
  maxUuidAttempts?: number;
}

export interface RegisterWorkerResult {
  ok: boolean;
  diagnostics: Diagnostic[];
  changedPaths: string[];
  uuid?: string;
  workerClass?: WorkerClass;
}

interface ParsedRegistry {
  projectId?: string;
  workersLine: number;
  workers: WorkerEntry[];
}

const CLASS_BY_MENU: Record<string, WorkerClass> = {
  "1": "backend",
  "2": "frontend",
  "3": "mobile",
  "4": "infrastructure"
};

export async function registerWorker(
  projectPath: string,
  deps: RegisterWorkerDeps
): Promise<RegisterWorkerResult> {
  const definitionPath = path.join(projectPath, "init_progress_definition.yaml");
  const registryPath = path.join(projectPath, "workers.yaml");
  const projectId = readProjectId(definitionPath);
  if (!projectId) {
    return failure(definitionPath, "Project definition is missing meta_info.project_id.");
  }

  const workerClass = await promptWorkerClass(deps.interaction);
  if (!workerClass) {
    return failure("worker class", "Unsupported worker class selection.");
  }

  const existing = existsSync(registryPath) ? readFileSync(registryPath, "utf8") : undefined;
  const baseContent = existing ?? `project_id: ${projectId}\nworkers:\n`;
  const parsed = parseWorkersRegistry(baseContent);
  if (!parsed.projectId) return failure(registryPath, "workers.yaml is missing project_id.");
  if (parsed.projectId !== projectId) {
    return failure(
      registryPath,
      `workers.yaml project_id '${parsed.projectId}' does not match project definition '${projectId}'.`
    );
  }
  if (parsed.workersLine < 0) return failure(registryPath, "workers.yaml is missing workers:.");

  const uuid = generateUniqueUuid(
    new Set(parsed.workers.map((worker) => worker.uuid.toLowerCase())),
    deps.uuid,
    deps.maxUuidAttempts ?? 100
  );
  if (!uuid) return failure(registryPath, "Unable to generate a unique worker UUID.");

  const registeredAt = String(deps.clock.now());
  const normalized = normalizeInlineEmptyWorkers(baseContent);
  const nextContent = appendWorkerEntry(normalized, {
    uuid,
    className: workerClass,
    status: "active",
    registeredAt
  });
  writeFileSync(registryPath, nextContent);

  return {
    ok: true,
    diagnostics: [],
    changedPaths: ["workers.yaml"],
    uuid,
    workerClass
  };
}

export function parseWorkerClassSelection(input: string): WorkerClass | undefined {
  const normalized = input.trim().toLowerCase();
  if (CLASS_BY_MENU[normalized]) return CLASS_BY_MENU[normalized];
  if ((WORKER_CLASSES as readonly string[]).includes(normalized)) return normalized as WorkerClass;
  return undefined;
}

export function parseWorkersRegistry(content: string): ParsedRegistry {
  const lines = content.split(/\r?\n/);
  const workers: WorkerEntry[] = [];
  let projectId: string | undefined;
  let workersLine = -1;
  let current: Partial<WorkerEntry> | undefined;

  const flush = (): void => {
    if (!current?.uuid) return;
    workers.push({
      uuid: current.uuid,
      className: current.className ?? "",
      status: current.status ?? "",
      ...(current.registeredAt ? { registeredAt: current.registeredAt } : {})
    });
  };

  lines.forEach((line, index) => {
    const project = line.match(/^project_id:\s*(.*)$/);
    if (project) projectId = unquote(project[1] ?? "");
    if (/^workers:\s*(?:\[\])?\s*$/.test(line)) workersLine = index;
    const uuid = line.match(/^\s*-\s+uuid:\s*(.*)$/);
    if (uuid) {
      flush();
      current = { uuid: unquote(uuid[1] ?? "").toLowerCase() };
      return;
    }
    if (!current) return;
    const className = line.match(/^\s+class:\s*(.*)$/);
    if (className) current.className = unquote(className[1] ?? "");
    const status = line.match(/^\s+status:\s*(.*)$/);
    if (status) current.status = unquote(status[1] ?? "");
    const registeredAt = line.match(/^\s+registered_at:\s*(.*)$/);
    if (registeredAt) current.registeredAt = unquote(registeredAt[1] ?? "");
  });
  flush();

  return { projectId, workersLine, workers };
}

export function readProjectId(definitionPath: string): string | undefined {
  try {
    const content = readFileSync(definitionPath, "utf8");
    const lines = content.split(/\r?\n/);
    let inMeta = false;
    for (const line of lines) {
      if (/^meta_info:\s*$/.test(line)) {
        inMeta = true;
        continue;
      }
      if (inMeta && /^\S/.test(line)) inMeta = false;
      if (!inMeta) continue;
      const match = line.match(/^\s+project_id:\s*(.*)$/);
      if (match) return unquote(match[1] ?? "");
    }
    return undefined;
  } catch {
    return undefined;
  }
}

async function promptWorkerClass(interaction: InteractionPort): Promise<WorkerClass | undefined> {
  for (;;) {
    const answer = await interaction.input({
      message:
        "Select worker class (1 backend, 2 frontend, 3 mobile, 4 infrastructure, or class name):"
    });
    const workerClass = parseWorkerClassSelection(answer);
    if (workerClass) return workerClass;
  }
}

function generateUniqueUuid(
  existing: Set<string>,
  uuid: UuidGenerator,
  maxAttempts: number
): string | undefined {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const candidate = uuid.next().trim().toLowerCase();
    if (candidate && !existing.has(candidate)) return candidate;
  }
  return undefined;
}

function normalizeInlineEmptyWorkers(content: string): string {
  return content.replace(/^workers:\s*\[\]\s*$/m, "workers:");
}

function appendWorkerEntry(content: string, worker: Required<WorkerEntry>): string {
  const hasFinalNewline = content.endsWith("\n");
  const lines = content.split(/\n/);
  if (hasFinalNewline) lines.pop();

  const workersLine = lines.findIndex((line) => /^workers:\s*$/.test(stripCr(line)));
  if (workersLine < 0) return content;

  let insertAt = lines.length;
  for (let index = workersLine + 1; index < lines.length; index += 1) {
    const line = stripCr(lines[index]!);
    if (/^\S[^:]*:\s*/.test(line)) {
      insertAt = index;
      break;
    }
  }

  const entry = [
    `  - uuid: ${worker.uuid}\n` +
      `    class: "${worker.className}"\n` +
      `    status: "${worker.status}"\n` +
      `    registered_at: "${worker.registeredAt}"`
  ];
  const nextLines = [...lines.slice(0, insertAt), ...entry, ...lines.slice(insertAt)];
  return `${nextLines.join("\n")}${hasFinalNewline ? "\n" : ""}`;
}

function unquote(value: string): string {
  const trimmed = value.trim();
  return trimmed.replace(/^["'](.*)["']$/, "$1");
}

function stripCr(line: string): string {
  return line.endsWith("\r") ? line.slice(0, -1) : line;
}

function failure(source: string, reason: string): RegisterWorkerResult {
  return {
    ok: false,
    diagnostics: [{ severity: "error", source, reason }],
    changedPaths: []
  };
}
