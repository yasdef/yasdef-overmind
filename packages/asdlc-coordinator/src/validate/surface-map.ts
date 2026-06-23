import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { readRequiredTextFile, resolveInputPath } from "../parse/index.js";
import type { GateResult } from "../types/index.js";

export type SurfaceMapClass = "backend" | "frontend" | "mobile";

interface ClassConfig {
  title: string;
  titleFailure: string;
  section4: string;
  section4Missing: string;
  layers: readonly string[];
  surfaces: readonly string[];
  projectClassesOk: (value: string) => boolean;
  projectClassesFailure: string;
  noApplicableSurfaceFailure: string;
  passMessage: string;
}

const REQUIRED_META_KEYS = [
  "repo_name",
  "service_name",
  "project_type_code",
  "project_classes",
  "feature_id",
  "feature_title",
  "analyzed_repo_paths",
  "source_inputs_used",
  "last_updated"
] as const;
const REQUIRED_SCOPE_KEYS = ["feature_summary", "in_scope_feature_delta", "out_of_scope_notes"] as const;
const REQUIRED_LAYER_FIELDS = [
  "responsibility_summary",
  "main_repo_paths",
  "key_components",
  "transport_layer",
  "user_reachable_surface"
] as const;
const REQUIRED_SURFACE_FIELDS = [
  "surface_summary",
  "applicability",
  "repo_paths",
  "why_feature_touches_it",
  "expected_changes",
  "evidence",
  "transport_layer",
  "user_reachable_surface"
] as const;
const LAYER_3_8 = "3.8 Another Layer(s)";

const BACKEND_CONFIG: ClassConfig = {
  title: "# Project Surface Structure + Responsibility Map (Backend)",
  titleFailure: "unexpected title for backend surface map",
  section4: "## 4. Backend Surfaces Touched With Current Feature",
  section4Missing: "missing section ## 4. Backend Surfaces Touched With Current Feature",
  layers: [
    "3.1 API Layer",
    "3.2 Application / Service Layer",
    "3.3 Domain Layer",
    "3.4 Persistence / Data Layer",
    "3.5 Integration Layer",
    "3.6 Runtime / Ops Layer",
    "3.7 Test Layer"
  ],
  surfaces: [
    "4.1 API Surface",
    "4.2 Application / Service Surface",
    "4.3 Domain Surface",
    "4.4 Persistence / Data Surface",
    "4.5 Integration Surface",
    "4.6 Runtime / Ops Surface",
    "4.7 Test Surface",
    "4.8 Unexpected Backend Surface"
  ],
  projectClassesOk: (value) => /backend/.test(value),
  projectClassesFailure: "project_classes must include backend",
  noApplicableSurfaceFailure: "at least one backend surface should be marked applicable",
  passMessage: "quality gate passed: backend repo surface map is complete enough"
};

const FRONTEND_CONFIG: ClassConfig = {
  title: "# Project Surface Structure + Responsibility Map (Frontend / Mobile)",
  titleFailure: "unexpected title for frontend/mobile surface map",
  section4: "## 4. Frontend / Mobile Surfaces Touched With Current Feature",
  section4Missing: "missing section ## 4. Frontend / Mobile Surfaces Touched With Current Feature",
  layers: [
    "3.1 UI Composition Layer",
    "3.2 Component Layer",
    "3.3 State / Data Layer",
    "3.4 API Integration Layer",
    "3.5 UX Behavior Layer",
    "3.6 Platform / Runtime Layer",
    "3.7 Test Layer"
  ],
  surfaces: [
    "4.1 UI Composition Surface",
    "4.2 Component Surface",
    "4.3 State / Data Surface",
    "4.4 API Integration Surface",
    "4.5 UX Behavior Surface",
    "4.6 Platform / Runtime Surface",
    "4.7 Test Surface",
    "4.8 Unexpected Frontend / Mobile Surface"
  ],
  projectClassesOk: (value) => /frontend/.test(value.toLowerCase()) || /mobile/.test(value.toLowerCase()),
  projectClassesFailure: "project_classes must include frontend or mobile",
  noApplicableSurfaceFailure: "at least one frontend/mobile surface should be marked applicable",
  passMessage: "quality gate passed: frontend/mobile repo surface map is complete enough"
};

function configForClass(klass: SurfaceMapClass): ClassConfig {
  return klass === "backend" ? BACKEND_CONFIG : FRONTEND_CONFIG;
}

function isSurfaceUnfilled(value: string | undefined): boolean {
  if (value === undefined) {
    return true;
  }
  const trimmed = value.trim();
  const upper = trimmed.toUpperCase();
  return trimmed === "" || upper === "[UNFILLED]" || upper.includes("[OPTIONAL");
}

function parseSurfaceBullet(line: string): { key: string; value: string } | undefined {
  const match = line.match(/^-\s+(.*)$/);
  if (!match) {
    return undefined;
  }
  const content = match[1];
  const colonIndex = content.indexOf(":");
  if (colonIndex < 0) {
    return undefined;
  }
  return {
    key: content.slice(0, colonIndex).trim(),
    value: content.slice(colonIndex + 1).trim()
  };
}

export function validateSurfaceMap(
  inputPath: string,
  klass: SurfaceMapClass,
  cwd = process.cwd()
): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target surface map path argument.");
  }
  try {
    const targetPath = resolveSurfaceMapPath(inputPath, klass, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target surface map artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target surface map artifact is a directory: ${targetPath}`);
    }
    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([`quality gate failed: target surface map artifact is empty: ${targetPath}`]);
    }
    const problems = validateSurfaceMapContent(content, klass);
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed(configForClass(klass).passMessage);
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validateSurfaceMapContent(content: string, klass: SurfaceMapClass): string[] {
  const config = configForClass(klass);
  const problems: string[] = [];
  const failQuality = (message: string): void => {
    problems.push(`quality gate failed: ${message}`);
  };

  const meta = new Map<string, string>();
  const scope = new Map<string, string>();
  const layerFields = new Map<string, string>();
  const surfaceFields = new Map<string, string>();
  const seenLayers = new Set<string>();
  const seenSurfaces = new Set<string>();
  let sawTitle = false;
  let sawSection1 = false;
  let sawSection2 = false;
  let sawSection3 = false;
  let sawSection4 = false;
  let saw38 = false;
  let sawPlaceholder = false;
  let region: "meta" | "scope" | "none" = "none";
  let currentLayer = "";
  let currentSurface = "";

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    const upper = line.toUpperCase();
    if (upper.includes("[UNFILLED]") || upper.includes("[OPTIONAL")) {
      sawPlaceholder = true;
    }

    if (line === config.title) {
      sawTitle = true;
    }

    if (line === "## 1. Document Meta") {
      sawSection1 = true;
      region = "meta";
      currentLayer = "";
      currentSurface = "";
      continue;
    }
    if (line === "## 2. Feature Scope") {
      sawSection2 = true;
      region = "scope";
      currentLayer = "";
      currentSurface = "";
      continue;
    }
    if (line === "## 3. Key Parts of Repo and Their Responsibilities") {
      sawSection3 = true;
      region = "none";
      currentLayer = "";
      currentSurface = "";
      continue;
    }
    if (line === config.section4) {
      sawSection4 = true;
      region = "none";
      currentLayer = "";
      currentSurface = "";
      continue;
    }

    const layerHeading = line.match(/^### (3\.[0-9]+ .*)$/);
    if (layerHeading) {
      currentLayer = layerHeading[1];
      currentSurface = "";
      if (currentLayer === LAYER_3_8) {
        saw38 = true;
      } else {
        seenLayers.add(currentLayer);
      }
      continue;
    }
    const surfaceHeading = line.match(/^### (4\.[0-9]+ .*)$/);
    if (surfaceHeading) {
      currentSurface = surfaceHeading[1];
      currentLayer = "";
      seenSurfaces.add(currentSurface);
      continue;
    }

    const field = parseSurfaceBullet(line);
    if (!field) {
      continue;
    }
    if (currentLayer !== "") {
      if (currentLayer !== LAYER_3_8) {
        layerFields.set(`${currentLayer}|${field.key}`, field.value);
      }
    } else if (currentSurface !== "") {
      surfaceFields.set(`${currentSurface}|${field.key}`, field.value);
    } else if (region === "meta") {
      meta.set(field.key, field.value);
    } else if (region === "scope") {
      scope.set(field.key, field.value);
    }
  }

  if (sawPlaceholder) {
    failQuality("artifact still contains template placeholders");
  }
  if (!sawTitle) {
    failQuality(config.titleFailure);
  }
  if (!sawSection1) {
    failQuality("missing section ## 1. Document Meta");
  }
  if (!sawSection2) {
    failQuality("missing section ## 2. Feature Scope");
  }
  if (!sawSection3) {
    failQuality("missing section ## 3. Key Parts of Repo and Their Responsibilities");
  }
  if (!sawSection4) {
    failQuality(config.section4Missing);
  }

  for (const key of REQUIRED_META_KEYS) {
    if (isSurfaceUnfilled(meta.get(key))) {
      failQuality(`missing or empty meta field: ${key}`);
    }
  }
  if (!config.projectClassesOk(meta.get("project_classes") ?? "")) {
    failQuality(config.projectClassesFailure);
  }
  const projectTypeCode = meta.get("project_type_code") ?? "";
  if (projectTypeCode !== "A" && projectTypeCode !== "B" && projectTypeCode !== "C") {
    failQuality("project_type_code must be A, B, or C");
  }
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(meta.get("last_updated") ?? "")) {
    failQuality("last_updated must be YYYY-MM-DD");
  }

  for (const key of REQUIRED_SCOPE_KEYS) {
    if (isSurfaceUnfilled(scope.get(key))) {
      failQuality(`missing or empty feature scope field: ${key}`);
    }
  }

  for (const layer of config.layers) {
    if (!seenLayers.has(layer)) {
      failQuality(`missing layer subsection: ${layer}`);
      continue;
    }
    if (isSurfaceUnfilled(layerFields.get(`${layer}|responsibility_summary`))) {
      failQuality(`missing responsibility_summary in ${layer}`);
    }
    if (isSurfaceUnfilled(layerFields.get(`${layer}|main_repo_paths`))) {
      failQuality(`missing main_repo_paths in ${layer}`);
    }
    if (isSurfaceUnfilled(layerFields.get(`${layer}|key_components`))) {
      failQuality(`missing key_components in ${layer}`);
    }
    if (isSurfaceUnfilled(layerFields.get(`${layer}|transport_layer`))) {
      failQuality(`missing or blank transport_layer in ${layer}`);
    }
    if (isSurfaceUnfilled(layerFields.get(`${layer}|user_reachable_surface`))) {
      failQuality(`missing or blank user_reachable_surface in ${layer}`);
    }
  }
  if (!saw38) {
    failQuality(`missing subsection: ${LAYER_3_8}`);
  }

  let applicableCount = 0;
  for (const surface of config.surfaces) {
    if (!seenSurfaces.has(surface)) {
      failQuality(`missing surface subsection: ${surface}`);
      continue;
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|surface_summary`))) {
      failQuality(`missing surface_summary in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|applicability`))) {
      failQuality(`missing applicability in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|repo_paths`))) {
      failQuality(`missing repo_paths in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|why_feature_touches_it`))) {
      failQuality(`missing why_feature_touches_it in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|expected_changes`))) {
      failQuality(`missing expected_changes in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|evidence`))) {
      failQuality(`missing evidence in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|transport_layer`))) {
      failQuality(`missing or blank transport_layer in ${surface}`);
    }
    if (isSurfaceUnfilled(surfaceFields.get(`${surface}|user_reachable_surface`))) {
      failQuality(`missing or blank user_reachable_surface in ${surface}`);
    }
    if (surfaceFields.get(`${surface}|applicability`) === "applicable") {
      applicableCount += 1;
    }
  }
  if (applicableCount < 1) {
    failQuality(config.noApplicableSurfaceFailure);
  }

  return problems;
}

function resolveSurfaceMapPath(inputPath: string, klass: SurfaceMapClass, cwd: string): string {
  const resolved = resolveInputPath(inputPath, cwd);
  if (existsSync(resolved) && statSync(resolved).isFile()) {
    return resolved;
  }
  return path.join(resolved, `project_surface_struct_resp_map_${klass}.md`);
}

function gatePassed(passMessage: string): GateResult {
  return { exitCode: 0, passMessage, problems: [] };
}

function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
