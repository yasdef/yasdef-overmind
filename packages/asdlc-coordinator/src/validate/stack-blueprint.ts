import { existsSync, statSync } from "node:fs";
import path from "node:path";

import {
  isUnfilled,
  normalizeValue,
  parseBulletField,
  readRequiredTextFile,
  resolveInputPath
} from "../parse/index.js";
import type { GateResult } from "../types/index.js";

const STACK_CLASSES = ["backend", "frontend", "mobile"] as const;
const CROSS_CLASS_PLACEHOLDER = "<to be defined during first feature implementation plan>";

const REQUIRED_STACK_KEYS: Record<(typeof STACK_CLASSES)[number], string[]> = {
  backend: [
    "language",
    "framework",
    "build",
    "rdbms",
    "migrations",
    "async_messaging",
    "http_clients",
    "auth",
    "logging",
    "metrics",
    "tracing",
    "health",
    "deployment",
    "test_stack"
  ],
  frontend: [
    "framework",
    "router",
    "state",
    "http",
    "styling",
    "auth_client",
    "env_validation",
    "deployment",
    "test"
  ],
  mobile: [
    "platforms",
    "android_ui",
    "ios_ui",
    "navigation",
    "state",
    "http",
    "auth_client",
    "local_storage",
    "device_integration",
    "distribution",
    "test_stack"
  ]
};

const REQUIRED_LAYERS: Record<(typeof STACK_CLASSES)[number], string[]> = {
  backend: [
    "3.1 API",
    "3.2 Service",
    "3.3 Domain",
    "3.4 Persistence",
    "3.5 Integration",
    "3.6 Runtime / Ops",
    "3.7 Test"
  ],
  frontend: [
    "3.1 UI Composition",
    "3.2 Component",
    "3.3 State / Data",
    "3.4 API Integration",
    "3.5 UX Behavior",
    "3.6 Platform / Runtime",
    "3.7 Test"
  ],
  mobile: [
    "3.1 UI Composition",
    "3.2 Component",
    "3.3 State / Data",
    "3.4 API Integration",
    "3.5 UX Behavior",
    "3.6 Platform / Runtime",
    "3.7 Native / Device Integration",
    "3.8 Local Storage / Offline / Sync",
    "3.9 Test"
  ]
};

type Section = "1" | "2" | "3" | "5" | "";

export function validateStackBlueprint(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target project stack blueprint path argument.");
  }

  try {
    const targetPath = resolveInputPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target project stack blueprint artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target project stack blueprint artifact is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([
        `quality gate failed: target project stack blueprint artifact is empty: ${targetPath}`
      ]);
    }

    const problems = validateStackBlueprintContent(content, detectPeerPresence(targetPath));
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (error) {
    return gateError(error instanceof Error ? error.message : String(error));
  }
}

export function validateStackBlueprintContent(content: string, peerExists = false): string[] {
  const problems: string[] = [];
  const fail = (message: string): void => {
    problems.push(`quality gate failed: ${message}`);
  };

  const seenSections = new Set<Section>();
  const seenLayers = new Set<string>();
  const meta = new Map<string, string>();
  const stack = new Map<string, string>();
  const crossClass = new Map<string, string>();
  const layerFields = new Map<string, Map<string, string>>();
  let section: Section = "";
  let currentLayer = "";
  let sectionCount = 0;
  let inComment = false;

  for (const rawLine of content.split(/\r?\n/)) {
    if (inComment) {
      if (rawLine.includes("-->")) inComment = false;
      continue;
    }
    if (rawLine.includes("<!--")) {
      if (!rawLine.includes("-->")) inComment = true;
      continue;
    }
    if (/\[UNFILLED\]/i.test(rawLine)) {
      fail("artifact still contains [UNFILLED] placeholders");
    }

    const heading = rawLine.trim();
    if (/^##\s+/.test(heading)) {
      section = "";
      currentLayer = "";
      sectionCount += 1;
      if (/^##\s+1\.\s+Meta\s*$/.test(heading)) section = "1";
      else if (/^##\s+2\.\s+Stack\s+Choices\s*$/.test(heading)) section = "2";
      else if (/^##\s+3\.\s+Layer\s+Bindings\s*$/.test(heading)) section = "3";
      else if (/^##\s+5\.\s+Cross-Class\s+Transport\/Contract\s+Approach\s*$/.test(heading)) {
        section = "5";
      } else fail(`unexpected top-level section: ${heading}`);
      if (section !== "") seenSections.add(section);
      continue;
    }

    if (/^###\s+/.test(heading)) {
      if (section === "3") {
        currentLayer = heading.replace(/^###\s+/, "");
        seenLayers.add(currentLayer);
        layerFields.set(currentLayer, new Map());
      }
      continue;
    }

    if (section === "") continue;
    const field = parseBulletField(rawLine);
    if (!field) continue;
    const key = normalizeValue(field.key);
    if (section === "1") meta.set(key, field.value);
    else if (section === "2") stack.set(key, field.value);
    else if (section === "3" && currentLayer !== "") {
      layerFields.get(currentLayer)?.set(key, field.value);
    } else if (section === "5") crossClass.set(key, field.value);
  }

  for (const [id, label] of [
    ["1", "## 1. Meta"],
    ["2", "## 2. Stack Choices"],
    ["3", "## 3. Layer Bindings"]
  ] as const) {
    if (!seenSections.has(id)) fail(`missing section: ${label}`);
  }
  const expectedSections = 3 + (seenSections.has("5") ? 1 : 0);
  if (sectionCount !== expectedSections) fail("unexpected number of top-level sections");

  for (const key of ["class", "repo_name", "service_name", "last_updated"]) {
    requireMapKey(meta, key, "meta key", fail);
  }
  const lastUpdated = meta.get("last_updated");
  if (!isUnfilled(lastUpdated) && !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(lastUpdated!)) {
    fail("last_updated must use YYYY-MM-DD format");
  }

  const klass = normalizeValue(meta.get("class") ?? "") as (typeof STACK_CLASSES)[number];
  if (!STACK_CLASSES.includes(klass)) {
    fail(`unsupported class value: ${klass} (allowed: backend, frontend, mobile)`);
    return problems;
  }

  if (klass === "backend") requireMapKey(meta, "group_id", "meta key", fail);
  else requireMapKey(meta, "group_id_or_package_root", "meta key", fail);

  for (const key of REQUIRED_STACK_KEYS[klass]) {
    requireMapKey(stack, key, "stack choice", fail);
  }

  const requiredLayers = REQUIRED_LAYERS[klass];
  for (const layer of requiredLayers) {
    if (!seenLayers.has(layer)) fail(`missing layer block: ${layer}`);
    requireLayerKey(layerFields, layer, "folder_paths", fail);
    requireLayerKey(layerFields, layer, "archetypes", fail);
    requireLayerKey(layerFields, layer, "user_reachable_pattern", fail);
  }
  if (klass === "backend" && seenLayers.has("3.5 Integration")) {
    requireLayerKey(layerFields, "3.5 Integration", "topics_convention", fail);
  }
  for (const layer of seenLayers) {
    if (!requiredLayers.includes(layer)) fail(`unexpected layer block: ${layer}`);
  }

  if (klass === "backend") {
    if (peerExists && !seenSections.has("5")) {
      fail(
        "missing section: ## 5. Cross-Class Transport/Contract Approach (required when in-project cross-class peer exists)"
      );
    }
    if (seenSections.has("5")) validateCrossClassSection(crossClass, fail);
  } else if (seenSections.has("5")) {
    fail(
      `section 5 Cross-Class Transport/Contract Approach is forbidden in ${klass} blueprint (backend is the sole holder)`
    );
  }

  return problems;
}

function detectPeerPresence(targetPath: string): boolean {
  const targetDir = path.dirname(targetPath);
  const basename = path.basename(targetPath);
  if (basename !== "project_stack_blueprint_backend.md") return false;
  let backendCount = 0;
  let frontendCount = 0;
  let mobileCount = 0;
  for (const name of [
    "project_stack_blueprint_backend.md",
    "project_stack_blueprint_frontend.md",
    "project_stack_blueprint_mobile.md"
  ]) {
    const candidate = path.join(targetDir, name);
    if (!existsSync(candidate)) continue;
    if (name.includes("backend")) backendCount += 1;
    else if (name.includes("frontend")) frontendCount += 1;
    else if (name.includes("mobile")) mobileCount += 1;
  }
  return frontendCount > 0 || mobileCount > 0 || backendCount > 1;
}

function requireMapKey(
  values: Map<string, string>,
  key: string,
  label: string,
  fail: (message: string) => void
): void {
  if (isUnfilled(values.get(key))) fail(`missing or unfilled ${label}: ${key}`);
}

function requireLayerKey(
  layers: Map<string, Map<string, string>>,
  layer: string,
  key: string,
  fail: (message: string) => void
): void {
  if (isUnfilled(layers.get(layer)?.get(key))) {
    fail(`missing or unfilled layer key for ${layer}: ${key}`);
  }
}

function validateCrossClassSection(
  crossClass: Map<string, string>,
  fail: (message: string) => void
): void {
  for (const field of ["transport_protocol", "schema_format", "user_approved"]) {
    if (!crossClass.has(field) || crossClass.get(field) === "") {
      fail(`missing or empty section 5 field: ${field}`);
    }
  }
  const transport = crossClass.get("transport_protocol") ?? "";
  const schema = crossClass.get("schema_format") ?? "";
  const approved = crossClass.get("user_approved") ?? "";
  const transportIsPlaceholder = transport === CROSS_CLASS_PLACEHOLDER;
  const schemaIsPlaceholder = schema === CROSS_CLASS_PLACEHOLDER;
  if (transportIsPlaceholder !== schemaIsPlaceholder) {
    fail(
      "section 5 mixed state: transport_protocol and schema_format must both be concrete or both be the literal placeholder"
    );
  }
  if (approved === "true" && (transportIsPlaceholder || schemaIsPlaceholder)) {
    fail(
      "section 5 user_approved=true is invalid when transport_protocol or schema_format carries the placeholder"
    );
  }
  if (approved !== "true" && approved !== "false") {
    fail(`section 5 user_approved must be 'true' or 'false' (got: ${approved})`);
  }
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: project stack blueprint structure is complete",
    problems: []
  };
}

function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
