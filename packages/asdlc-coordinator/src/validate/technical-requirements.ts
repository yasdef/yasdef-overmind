import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import { resolveFeatureWithinWorkspace } from "../parse/index.js";
import type { GateResult } from "../types/index.js";
import { parseTechnicalRequirementsProjectClasses } from "../context/technical-requirements.js";

const SURFACE_CLASSES = new Set(["backend", "frontend", "mobile"]);
const SECTIONS = [
  { label: "1. Document Meta", pattern: /^##[ \t]+1\.[ \t]+Document[ \t]+Meta[ \t]*$/ },
  {
    label: "2. Feature Scope and Inputs",
    pattern: /^##[ \t]+2\.[ \t]+Feature[ \t]+Scope[ \t]+and[ \t]+Inputs[ \t]*$/
  },
  { label: "3. Repository Evidence", pattern: /^##[ \t]+3\.[ \t]+Repository[ \t]+Evidence[ \t]*$/ },
  {
    label: "4. Requirement Coverage and Gaps",
    pattern: /^##[ \t]+4\.[ \t]+Requirement[ \t]+Coverage[ \t]+and[ \t]+Gaps[ \t]*$/
  },
  { label: "5. Impacted Components", pattern: /^##[ \t]+5\.[ \t]+Impacted[ \t]+Components[ \t]*$/ },
  {
    label: "6. Cross-Repo Constraints and Planning Signals",
    pattern:
      /^##[ \t]+6\.[ \t]+Cross-Repo[ \t]+Constraints[ \t]+and[ \t]+Planning[ \t]+Signals[ \t]*$/
  },
  {
    label: "7. Known Risks / Uncertainties",
    pattern: /^##[ \t]+7\.[ \t]+Known[ \t]+Risks[ \t]*\/[ \t]*Uncertainties[ \t]*$/
  }
] as const;
const META_KEYS = [
  "feature_id",
  "feature_title",
  "project_type_code",
  "source_requirements_ears",
  "source_common_contract_definition",
  "source_surface_map_artifacts",
  "analyzed_repo_classes",
  "last_updated",
  "confidence_level"
] as const;
const SCOPE_KEYS = ["feature_summary", "included_behavior", "excluded_behavior"] as const;
const REPO_FIELDS = [
  "class",
  "evidence_scope",
  "primary_paths",
  "key_findings",
  "constraints",
  "open_gaps"
] as const;
const REQUIREMENT_FIELDS = [
  "requirement_summary",
  "transport_layer",
  "user_reachable_surface",
  "gap_status",
  "repo_impact",
  "evidence",
  "gap_to_close"
] as const;
const COMPONENT_FIELDS = [
  "repo",
  "component_kind",
  "relevant_paths",
  "requirement_refs",
  "current_state",
  "required_behavior",
  "gap_to_close",
  "dependency_notes",
  "evidence"
] as const;
const SIGNAL_FIELDS = [
  "signal_id",
  "signal_type",
  "owner_repo",
  "consumer_repos",
  "required_artifact",
  "must_precede",
  "output_requirements",
  "source_evidence"
] as const;
const COMPONENT_KINDS = new Set([
  "controller",
  "service",
  "dto",
  "mapper",
  "domain",
  "persistence",
  "migration",
  "security",
  "config",
  "test",
  "ui",
  "state",
  "api_client",
  "other"
]);
const GAP_STATUSES = new Set([
  "fully_implemented",
  "partially_implemented",
  "not_implemented",
  "unclear"
]);

interface Block {
  name: string;
  fields: Map<string, string>;
}

export function validateTechnicalRequirements(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "")
    return gateError("Missing target feature path argument.");
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return gateError(resolved.message);
  const { featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects") {
    return gateError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }
  const projectDir = path.dirname(featureDir);
  const targetPath = path.join(featureDir, "technical_requirements.md");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");

  try {
    if (!isFile(targetPath))
      return gateError(`Target feature technical requirements artifact not found: ${targetPath}`);
    const content = readFileSync(targetPath, "utf8");
    if (!/[^\s]/.test(content))
      return gateRecoverable([
        `target feature technical requirements artifact is empty: ${targetPath}`
      ]);
    if (!isFile(requirementsPath))
      return gateError(
        `Required sibling artifact not found for quality check: ${requirementsPath}`
      );
    if (!isFile(definitionPath))
      return gateError(
        `Required project definition not found for quality check: ${definitionPath}`
      );

    const activeClasses = parseTechnicalRequirementsProjectClasses(definitionPath).filter((item) =>
      SURFACE_CLASSES.has(item)
    );
    if (activeClasses.length === 0)
      return gateError(`No supported repo classes found in ${definitionPath}`);
    const requirementIds = extractRequirementIds(readFileSync(requirementsPath, "utf8"));
    if (requirementIds.size === 0)
      return gateError(`No requirement ids found in ${requirementsPath}`);
    const requiredComponentRepos = new Set<string>();
    for (const klass of activeClasses) {
      const surfacePath = path.join(featureDir, `project_surface_struct_resp_map_${klass}.md`);
      if (!isFile(surfacePath))
        return gateError(
          `Required surface-map artifact not found for active repo '${klass}': ${surfacePath}`
        );
      if (/^\s*-\s*applicability:\s*applicable\s*$/m.test(readFileSync(surfacePath, "utf8")))
        requiredComponentRepos.add(klass);
    }
    const problems = validateTechnicalRequirementsContent(
      content,
      new Set(activeClasses),
      requirementIds,
      requiredComponentRepos
    );
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function validateTechnicalRequirementsContent(
  content: string,
  activeClasses: Set<string>,
  requirementIds: Set<string>,
  requiredComponentRepos: Set<string>
): string[] {
  const problems: string[] = [];
  const fail = (message: string): void => {
    problems.push(`quality gate failed: ${message}`);
  };
  const sectionFields = new Map<number, Map<string, string>>();
  const repos: Block[] = [];
  const requirements: Block[] = [];
  const components: Block[] = [];
  const signals: Block[] = [];
  let section = 0;
  let current: Block | undefined;
  let currentKind = "";
  let emptyMarkerCount = 0;
  let legacyCount = 0;
  let section6Entries = 0;
  let riskCount = 0;
  const seenSections = new Set<number>();

  const finishBlock = (): void => {
    if (!current) return;
    if (currentKind === "repo") repos.push(current);
    else if (currentKind === "requirement") requirements.push(current);
    else if (currentKind === "component") components.push(current);
    else if (currentKind === "signal") signals.push(current);
    current = undefined;
    currentKind = "";
  };

  if (/\[UNFILLED\]/i.test(content)) fail("artifact still contains [UNFILLED] placeholders");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (/^##[ \t]+/.test(line)) {
      finishBlock();
      const index = SECTIONS.findIndex(({ pattern }) => pattern.test(line));
      section = index < 0 ? 0 : index + 1;
      if (section > 0) seenSections.add(section);
      continue;
    }
    const heading = line.match(/^### (Repository|Requirement|Component|Planning Signal):\s*(.*)$/);
    if (heading) {
      finishBlock();
      currentKind =
        heading[1] === "Repository"
          ? "repo"
          : heading[1] === "Requirement"
            ? "requirement"
            : heading[1] === "Component"
              ? "component"
              : "signal";
      current = { name: heading[2]!.trim(), fields: new Map() };
      if (currentKind === "signal") {
        if (section !== 6) fail("planning signal block is only allowed in section 6");
        section6Entries++;
      }
      continue;
    }
    const scalar = line.match(/^-\s*([A-Za-z0-9_.-]+):\s*(.*)$/);
    if (!scalar) continue;
    const key = scalar[1]!;
    const value = scalar[2]!.trim();
    if (current) {
      current.fields.set(key, value);
      if (currentKind === "signal") section6Entries++;
    } else if (section === 1 || section === 2) {
      const fields = sectionFields.get(section) ?? new Map<string, string>();
      fields.set(key, value);
      sectionFields.set(section, fields);
    } else if (section === 6) {
      section6Entries++;
      if (key === "planning_signals") {
        if (value !== "none")
          fail("section 6 empty marker must be exactly: - planning_signals: none");
        emptyMarkerCount++;
      } else if (/^(constraint|prep)_[0-9]+$/.test(key)) legacyCount++;
      else fail(`unsupported section 6 entry: ${key}`);
    } else if (section === 7 && /^risk_[0-9]+$/.test(key) && !unfilled(value)) riskCount++;
  }
  finishBlock();

  for (let index = 0; index < SECTIONS.length; index++) {
    if (!seenSections.has(index + 1)) fail(`missing section ${SECTIONS[index]!.label}`);
  }
  for (const key of META_KEYS)
    if (unfilled(sectionFields.get(1)?.get(key))) fail(`section 1 key ${key} is required`);
  for (const key of SCOPE_KEYS)
    if (unfilled(sectionFields.get(2)?.get(key))) fail(`section 2 key ${key} is required`);

  const repoSeen = new Map<string, number>();
  for (const block of repos) {
    if (unfilled(block.name)) fail("repository block heading is empty in section 3");
    for (const field of REPO_FIELDS)
      if (unfilled(block.fields.get(field)))
        fail(`repository ${block.name} has unfilled key ${field}`);
    const klass = (block.fields.get("class") ?? "").toLowerCase();
    if (klass !== "" && !activeClasses.has(klass))
      fail(`repository ${block.name} uses repo outside active project classes: ${klass}`);
    repoSeen.set(klass, (repoSeen.get(klass) ?? 0) + 1);
  }
  if (repos.length === 0) fail("section 3 must contain at least one repository block");
  for (const klass of activeClasses)
    if (!repoSeen.has(klass))
      fail(`active repo class ${klass} must have a repository evidence block in section 3`);

  const requirementSeen = new Set<string>();
  for (const block of requirements) {
    const id = block.name;
    if (unfilled(id)) fail("requirement block heading is empty in section 4");
    if (!requirementIds.has(id)) fail(`requirement block references unknown requirement id ${id}`);
    if (requirementSeen.has(id)) fail(`duplicate requirement block for ${id}`);
    for (const field of REQUIREMENT_FIELDS) {
      if (unfilled(block.fields.get(field))) {
        fail(
          field === "transport_layer" || field === "user_reachable_surface"
            ? `requirement ${id} is missing ${field} subfield`
            : `requirement ${id} has unfilled key ${field}`
        );
      }
    }
    if (!unfilled(block.fields.get("current_state")))
      fail(
        `requirement ${id} uses conflated current_state: line — use transport_layer and user_reachable_surface subfields instead`
      );
    const status = (block.fields.get("gap_status") ?? "").toLowerCase();
    if (status !== "" && !GAP_STATUSES.has(status))
      fail(`requirement ${id} has invalid gap_status: ${block.fields.get("gap_status")}`);
    const impact = (block.fields.get("repo_impact") ?? "").toLowerCase();
    if (impact !== "" && impact !== "multiple" && !activeClasses.has(impact))
      fail(`requirement ${id} has invalid repo_impact: ${block.fields.get("repo_impact")}`);
    requirementSeen.add(id);
  }
  if (requirements.length === 0) fail("section 4 must contain at least one requirement block");
  for (const id of requirementIds)
    if (!requirementSeen.has(id)) fail(`section 4 is missing requirement block for ${id}`);

  const componentSeen = new Map<string, number>();
  const componentSlugs = new Set<string>();
  for (const block of components) {
    if (unfilled(block.name)) fail("component block heading is empty in section 5");
    for (const field of COMPONENT_FIELDS)
      if (unfilled(block.fields.get(field)))
        fail(`component ${block.name} has unfilled key ${field}`);
    const repo = (block.fields.get("repo") ?? "").toLowerCase();
    if (repo !== "" && !activeClasses.has(repo))
      fail(
        `component ${block.name} uses repo outside active project classes: ${block.fields.get("repo")}`
      );
    const kind = (block.fields.get("component_kind") ?? "").toLowerCase();
    if (kind !== "" && !COMPONENT_KINDS.has(kind))
      fail(
        `component ${block.name} has invalid component_kind: ${block.fields.get("component_kind")}`
      );
    const refs = block.fields.get("requirement_refs")?.match(/(?:REQ|NFR)-[0-9]+/g) ?? [];
    if (refs.length === 0)
      fail(`component ${block.name} in repo ${repo} must reference at least one REQ-* or NFR-* id`);
    for (const ref of refs)
      if (!requirementIds.has(ref))
        fail(`component ${block.name} in repo ${repo} references unknown requirement id ${ref}`);
    componentSeen.set(repo, (componentSeen.get(repo) ?? 0) + 1);
    const slug = slugify(block.name);
    if (slug !== "") componentSlugs.add(slug);
  }
  if (components.length === 0) fail("section 5 must contain at least one component block");
  for (const repo of requiredComponentRepos)
    if (!componentSeen.has(repo))
      fail(
        `repo ${repo} has applicable touched surfaces but no impacted component block is allocated to it`
      );

  const signalIds = new Set<string>();
  for (const block of signals) {
    if (unfilled(block.name)) fail("planning signal block heading is empty in section 6");
    for (const field of SIGNAL_FIELDS)
      if (unfilled(block.fields.get(field)))
        fail(`planning signal ${block.name} has unfilled key ${field}`);
    for (const field of block.fields.keys())
      if (!(SIGNAL_FIELDS as readonly string[]).includes(field))
        fail(`unsupported key in planning signal block: ${field}`);
    const id = block.fields.get("signal_id") ?? "";
    if (signalIds.has(id)) fail(`duplicate planning signal id in section 6: ${id}`);
    signalIds.add(id);
    if ((block.fields.get("signal_type") ?? "").toLowerCase() !== "cross_repo_contract_lock")
      fail(
        `planning signal ${id} uses unsupported signal_type: ${block.fields.get("signal_type")}`
      );
    const owner = (block.fields.get("owner_repo") ?? "").toLowerCase();
    if (owner !== "" && !activeClasses.has(owner))
      fail(
        `planning signal ${id} uses repo outside active project classes in owner_repo: ${block.fields.get("owner_repo")}`
      );
    const consumers = csv(block.fields.get("consumer_repos") ?? "");
    if (consumers.length === 0)
      fail(`planning signal ${id} must reference at least one repo in consumer_repos`);
    for (const repo of consumers)
      if (!activeClasses.has(repo.toLowerCase()))
        fail(
          `planning signal ${id} references repo outside active project classes in consumer_repos: ${repo.toLowerCase()}`
        );
    const evidence = csv(block.fields.get("source_evidence") ?? "");
    if (evidence.length === 0)
      fail(`planning signal ${id} must include at least one source_evidence token`);
    for (const token of evidence) {
      if (/^(REQ|NFR)-[0-9]+$/.test(token)) {
        if (!requirementIds.has(token))
          fail(`planning signal ${id} references unknown source_evidence token ${token}`);
      } else if (/^comp\/[a-z0-9][a-z0-9-]*$/.test(token)) {
        if (!componentSlugs.has(token.slice(5)))
          fail(`planning signal ${id} references unknown source_evidence token ${token}`);
      } else fail(`planning signal ${id} has invalid source_evidence token ${token}`);
    }
  }
  if (legacyCount > 0)
    fail(
      "section 6 uses retired loose-entry format (constraint_* / prep_*); use typed planning-signal blocks or - planning_signals: none"
    );
  if (emptyMarkerCount > 1) fail("section 6 empty marker appears more than once");
  if (emptyMarkerCount > 0 && signals.length > 0)
    fail("section 6 cannot mix typed planning-signal blocks with - planning_signals: none");
  if (section6Entries < 1 || (emptyMarkerCount < 1 && signals.length < 1))
    fail(
      "section 6 must contain at least one typed planning-signal block or - planning_signals: none"
    );
  if (riskCount < 1) fail("section 7 must contain at least one explicit risk_N entry");
  return problems;
}

function extractRequirementIds(content: string): Set<string> {
  const ids = new Set<string>();
  for (const line of content.split(/\r?\n/)) {
    const match = line.match(/^###\s+(Requirement|NFR)\s+([0-9]+)/);
    if (match) ids.add(`${match[1] === "Requirement" ? "REQ" : "NFR"}-${match[2]}`);
  }
  return ids;
}
function isFile(file: string): boolean {
  return existsSync(file) && statSync(file).isFile();
}
function unfilled(value: string | undefined): boolean {
  return value === undefined || value.trim() === "" || value.trim().toUpperCase() === "[UNFILLED]";
}
function csv(value: string): string[] {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}
function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: feature technical requirements structure is complete",
    problems: []
  };
}
function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}
function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
