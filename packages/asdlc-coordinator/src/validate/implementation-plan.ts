import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";

import {
  displayPath,
  parseImplementationSlicesProjectClasses,
  resolveFeatureWithinWorkspace
} from "../parse/index.js";
import type { GateResult } from "../types/index.js";

export interface TechnicalEvidenceCatalog {
  reqAll: string[];
  reqUnresolved: string[];
  compAll: string[];
  compUnresolved: string[];
  repoUnresolved: string[];
}

export interface ImplementationPlanCatalogs {
  activeClasses: Set<string>;
  requirementRefs: string[];
  evidence: TechnicalEvidenceCatalog;
  scheduledSliceRefs: string[];
  requiredSurfaces: string[];
}

interface PlanStep {
  id: string;
  heading: string;
  repo?: string;
  depends?: string;
  evidence?: string;
  preservedSurface?: string;
  coordination: boolean;
  bullets: string[];
  declarations: Record<"repo" | "depends" | "evidence" | "preservedSurface", number>;
}

const SUPPORTED_CLASSES = new Set(["backend", "frontend", "mobile"]);

export function validateImplementationPlan(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "")
    return gateError("Missing target feature path argument.");
  const resolved = resolveFeatureWithinWorkspace(inputPath, cwd);
  if (!resolved.ok) return gateError(resolved.message);
  const { workspaceRoot, featureDir, relativeFeature } = resolved.value;
  const parts = relativeFeature.split(path.sep);
  if (parts.length !== 3 || parts[0] !== "projects" || !parts[1] || !parts[2]) {
    return gateError(
      `Feature path must resolve under projects/<project-id>/<feature-folder>: ${relativeFeature}`
    );
  }
  const targetPath = path.join(featureDir, "implementation_plan.md");
  const requirementsPath = path.join(featureDir, "requirements_ears.md");
  const technicalPath = path.join(featureDir, "technical_requirements.md");
  const prerequisitePath = path.join(featureDir, "prerequisite_gaps.md");
  const definitionPath = path.join(
    workspaceRoot,
    "projects",
    parts[1],
    "init_progress_definition.yaml"
  );
  if (!isFile(targetPath))
    return gateError(
      `Target repository implementation plan artifact not found: ${displayPath(targetPath, workspaceRoot)}`
    );
  const content = readFileSync(targetPath, "utf8");
  if (!/\S/.test(content))
    return gateFailure([
      `target repository implementation plan artifact is empty: ${displayPath(targetPath, workspaceRoot)}`
    ]);
  for (const [file, message] of [
    [requirementsPath, "Required sibling artifact not found for quality check"],
    [technicalPath, "Required sibling artifact not found for quality check"],
    [prerequisitePath, "Required sibling artifact not found for quality check"],
    [definitionPath, "Required project definition not found for quality check"]
  ] as const)
    if (!isFile(file)) return gateError(`${message}: ${displayPath(file, workspaceRoot)}`);

  try {
    const activeClasses = new Set(
      parseImplementationSlicesProjectClasses(definitionPath).filter((item) =>
        SUPPORTED_CLASSES.has(item)
      )
    );
    if (activeClasses.size === 0)
      return gateError(
        `No supported repo classes found in ${displayPath(definitionPath, workspaceRoot)}`
      );
    const requirementRefs = extractImplementationPlanRequirementRefs(
      readFileSync(requirementsPath, "utf8")
    );
    if (requirementRefs.length === 0)
      return gateError(
        `No requirement ids found in ${displayPath(requirementsPath, workspaceRoot)}`
      );
    const evidence = extractTechnicalEvidenceCatalog(readFileSync(technicalPath, "utf8"));
    if (evidence.reqAll.length === 0 && evidence.compAll.length === 0)
      return gateError(
        `No technical requirement or component evidence tokens found in ${displayPath(technicalPath, workspaceRoot)}`
      );
    const prerequisite = readFileSync(prerequisitePath, "utf8");
    const problems = validateImplementationPlanContent(content, {
      activeClasses,
      requirementRefs,
      evidence,
      scheduledSliceRefs: extractScheduledSliceRefs(prerequisite),
      requiredSurfaces: extractImplementationPlanRequiredSurfaces(prerequisite)
    });
    return problems.length === 0
      ? {
          exitCode: 0,
          passMessage: "quality gate passed: repository implementation plan structure is complete",
          problems: []
        }
      : gateFailure(problems);
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

export function extractImplementationPlanRequirementRefs(content: string): string[] {
  const refs = new Set<string>();
  for (const line of content.split(/\r?\n/)) {
    if (!/^###\s+/.test(line)) continue;
    let match = line.match(/^###\s+Requirement\s+(\d+)/);
    if (match) refs.add(`REQ-${match[1]}`);
    match = line.match(/^###\s+NFR\s+(\d+)/);
    if (match) refs.add(`NFR-${match[1]}`);
    for (const token of line.matchAll(/(?:REQ|NFR)-\d+/g)) refs.add(token[0]);
  }
  return [...refs];
}

export function extractTechnicalEvidenceCatalog(content: string): TechnicalEvidenceCatalog {
  const reqAll = new Set<string>();
  const reqUnresolved = new Set<string>();
  const compAll = new Set<string>();
  const compUnresolved = new Set<string>();
  const repoUnresolved = new Set<string>();
  let section = "";
  let requirement = "";
  let requirementResolved = false;
  let component = "";
  let componentRepo = "";
  let componentResolved = false;
  const flushRequirement = (): void => {
    if (!requirement) return;
    const token = `gap/TECH_REQ-${requirement.replace(/^REQ-/, "")}`;
    reqAll.add(token);
    if (!requirementResolved) reqUnresolved.add(token);
    requirement = "";
    requirementResolved = false;
  };
  const flushComponent = (): void => {
    if (!component) return;
    const token = `comp/${component}`;
    compAll.add(token);
    if (!componentResolved) {
      compUnresolved.add(token);
      if (componentRepo) repoUnresolved.add(componentRepo);
    }
    component = "";
    componentRepo = "";
    componentResolved = false;
  };
  const flush = (): void => {
    if (section === "requirements") flushRequirement();
    else if (section === "components") flushComponent();
  };
  for (const line of content.split(/\r?\n/)) {
    if (/^## 4\.\s+Requirement Coverage and Gaps\s*$/.test(line)) {
      flush();
      section = "requirements";
      continue;
    }
    if (/^## 5\.\s+Impacted Components\s*$/.test(line)) {
      flush();
      section = "components";
      continue;
    }
    if (/^## \d+\./.test(line)) {
      flush();
      section = "";
      continue;
    }
    if (section === "requirements") {
      const heading = line.match(/^### Requirement:\s*((?:REQ|NFR)-\d+)/);
      if (heading) {
        flushRequirement();
        requirement = heading[1]!;
        continue;
      }
      if (!requirement) continue;
      const status = line.match(/^- gap_status:\s*(.*)$/);
      if (
        status &&
        ["fully_implemented", "fully implemented"].includes(status[1]!.trim().toLowerCase())
      )
        requirementResolved = true;
      const gap = line.match(/^- gap_to_close:\s*(.*)$/);
      if (gap && isNoRemainingGap(gap[1]!)) requirementResolved = true;
    } else if (section === "components") {
      const heading = line.match(/^### Component:\s*(.*)$/);
      if (heading) {
        flushComponent();
        component = slugify(heading[1]!);
        continue;
      }
      if (!component) continue;
      const repo = line.match(/^- repo:\s*(.*)$/);
      if (repo) componentRepo = repo[1]!.trim().toLowerCase();
      const gap = line.match(/^- gap_to_close:\s*(.*)$/);
      if (gap && isNoRemainingGap(gap[1]!)) componentResolved = true;
    }
  }
  flush();
  return {
    reqAll: [...reqAll],
    reqUnresolved: [...reqUnresolved],
    compAll: [...compAll],
    compUnresolved: [...compUnresolved],
    repoUnresolved: [...repoUnresolved]
  };
}

export function extractScheduledSliceRefs(content: string): string[] {
  return parsePrerequisiteCatalog(content)
    .flatMap((block) =>
      block.status === "scheduled_in_slices" && !unfilled(block.sliceRef) ? [block.sliceRef] : []
    )
    .filter(unique);
}

export function extractImplementationPlanRequiredSurfaces(content: string): string[] {
  return parsePrerequisiteCatalog(content)
    .flatMap((block) =>
      ["scheduled_in_slices", "unmet"].includes(block.status) &&
      block.surfaceKind === "required_missing_user_reachable_surface" &&
      !unfilled(block.surfaceIdentity)
        ? [block.surfaceIdentity]
        : []
    )
    .filter(unique)
    .sort();
}

export function validateImplementationPlanContent(
  content: string,
  catalogs: ImplementationPlanCatalogs
): string[] {
  const problems: string[] = [];
  const fail = (message: string): void => {
    problems.push(message);
  };
  const steps: PlanStep[] = [];
  let current: PlanStep | undefined;
  let lastMajor = -1;
  let lastMinor = -1;
  const seenSteps = new Set<string>();
  const coveredRefs = new Set<string>();
  const coveredEvidence = new Set<string>();
  const preserved: Array<{ value: string; coordination: boolean }> = [];
  const repoSteps = new Map<string, number>();
  const validRefs = new Set(catalogs.requirementRefs);
  const validReqEvidence = new Set(catalogs.evidence.reqAll);
  const validCompEvidence = new Set(catalogs.evidence.compAll);

  const validateStep = (step: PlanStep): void => {
    if (!step.repo) fail(`step ${step.id} is missing #### Repo`);
    if (!step.depends) fail(`step ${step.id} is missing #### Depends on`);
    if (!step.evidence) fail(`step ${step.id} is missing #### Evidence`);
    if (!step.preservedSurface) fail(`step ${step.id} is missing #### Preserved Surface`);
    if (step.bullets.length < 3) fail(`step ${step.id} must contain at least 3 checklist bullets`);
    if (step.bullets[0] !== "Plan and discuss the step")
      fail(`step ${step.id} must include first bullet: Plan and discuss the step`);
    if (!step.bullets.includes("Review step implementation"))
      fail(`step ${step.id} must include last bullet: Review step implementation`);
    if (step.preservedSurface && step.preservedSurface.toLowerCase() !== "none") {
      if (!hasSurfaceTerms(step.preservedSurface))
        fail(
          `step ${step.id} has non-operator-facing preserved surface value: ${step.preservedSurface}`
        );
      if (looksSupportingOnly(`${step.heading} ${step.bullets.join(" ")}`.toLowerCase()))
        fail(`step ${step.id} marks preserved surface but describes supporting-only work`);
      preserved.push({ value: step.preservedSurface, coordination: step.coordination });
    }
    if (step.depends && step.depends.toLowerCase() !== "none") {
      const seen = new Set<string>();
      for (const raw of step.depends.split(",")) {
        const dep = raw.trim();
        if (!dep) {
          fail(`step ${step.id} has empty dependency entry`);
          continue;
        }
        if (seen.has(dep)) {
          fail(`step ${step.id} repeats dependency ${dep}`);
          continue;
        }
        seen.add(dep);
        if (dep.includes("/")) {
          if (
            !/^[A-Za-z0-9._-]+\/\d+(?:\.\d+)*$/.test(dep) ||
            [".", ".."].includes(dep.slice(0, dep.indexOf("/")))
          )
            fail(`step ${step.id} has invalid cross-feature dependency ${dep}`);
        } else if (dep === step.id || !seenSteps.has(dep))
          fail(`step ${step.id} depends on unknown or later step ${dep}`);
      }
    }
    if (step.evidence) {
      const seen = new Set<string>();
      let validCount = 0;
      let nonempty = false;
      for (const raw of step.evidence.split(",")) {
        const token = raw.trim();
        if (!token) {
          fail(`step ${step.id} has empty evidence token entry`);
          continue;
        }
        nonempty = true;
        if (seen.has(token)) {
          fail(`step ${step.id} repeats evidence token ${token}`);
          continue;
        }
        seen.add(token);
        if (/^gap\/TECH_REQ-(?:\d+|NFR-\d+)$/.test(token)) {
          if (!validReqEvidence.has(token))
            fail(`step ${step.id} references unknown evidence token ${token}`);
          else {
            coveredEvidence.add(token);
            validCount++;
          }
        } else if (/^comp\/[a-z0-9]+(?:-[a-z0-9]+)*$/.test(token)) {
          if (!validCompEvidence.has(token))
            fail(`step ${step.id} references unknown evidence token ${token}`);
          else {
            coveredEvidence.add(token);
            validCount++;
          }
        } else if (/^slice\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(token)) {
          coveredEvidence.add(token);
          validCount++;
        } else fail(`step ${step.id} has invalid evidence token format: ${token}`);
      }
      if (!nonempty) fail(`step ${step.id} has empty #### Evidence value`);
      else if (validCount < 1)
        fail(`step ${step.id} is not supported by any valid technical evidence token`);
    }
  };

  for (const line of content.split(/\r?\n/)) {
    const heading = line.match(/^### Step\s+(\d+)\.(\d+)\s+(.+)$/);
    if (heading) {
      if (current) validateStep(current);
      const id = `${heading[1]}.${heading[2]}`;
      const major = Number(heading[1]);
      const minor = Number(heading[2]);
      if (lastMajor > major || (lastMajor === major && lastMinor >= minor))
        fail(`step ids must be in strictly increasing order; found out-of-order step ${id}`);
      if (seenSteps.has(id)) fail(`duplicate step id: ${id}`);
      seenSteps.add(id);
      lastMajor = major;
      lastMinor = minor;
      current = {
        id,
        heading: line,
        coordination: false,
        bullets: [],
        declarations: { repo: 0, depends: 0, evidence: 0, preservedSurface: 0 }
      };
      steps.push(current);
      let refCount = 0;
      for (const ref of line.matchAll(/\[(REQ|NFR)-\d+\]/g)) {
        const value = ref[0].slice(1, -1);
        refCount++;
        if (!validRefs.has(value))
          fail(`step heading "${line}" references unknown requirement id ${value}`);
        else coveredRefs.add(value);
      }
      if (refCount === 0)
        fail(`step heading "${line}" must reference at least one REQ-* or NFR-* id`);
      continue;
    }
    const field = line.match(/^#### (Repo|Depends on|Evidence|Preserved Surface):\s*(.*)$/);
    if (field) {
      if (!current) {
        fail(`#### ${field[1]} appears before any step heading`);
        continue;
      }
      const value = field[2]!.trim();
      const key =
        field[1] === "Repo"
          ? "repo"
          : field[1] === "Depends on"
            ? "depends"
            : field[1] === "Evidence"
              ? "evidence"
              : "preservedSurface";
      current.declarations[key]++;
      if (current.declarations[key] > 1) {
        fail(`step ${current.id} declares #### ${field[1]} more than once`);
        continue;
      }
      if (!value && (key === "depends" || key === "preservedSurface"))
        fail(`step ${current.id} has empty #### ${field[1]} value`);
      if (key === "repo") {
        const repo = value.toLowerCase();
        current.repo = repo;
        if (!catalogs.activeClasses.has(repo))
          fail(`step ${current.id} uses repo outside active project classes: ${repo}`);
        if (!SUPPORTED_CLASSES.has(repo))
          fail(`step ${current.id} has invalid repo value: ${repo}`);
        repoSteps.set(repo, (repoSteps.get(repo) ?? 0) + 1);
      } else if (key === "depends") current.depends = value;
      else if (key === "evidence") current.evidence = value;
      else current.preservedSurface = value;
      continue;
    }
    const coordination = line.match(/^#### Coordination:\s*(.*)$/);
    if (coordination) {
      if (current && coordination[1]!.trim().toLowerCase() === "true") current.coordination = true;
      continue;
    }
    if (/^#### Assigned:\s*/.test(line)) {
      if (!current) fail("#### Assigned appears before any step heading");
      continue;
    }
    const bullet = line.match(/^- \[[ xX]\]\s+(.+)$/);
    if (bullet) {
      if (!current) fail("checklist bullet appears before any step heading");
      else current.bullets.push(bullet[1]!.trim());
    }
  }
  if (current) validateStep(current);
  if (/\[UNFILLED\]/i.test(content)) fail("artifact still contains [UNFILLED] placeholders");
  if (steps.length === 0) fail("implementation plan must contain at least one step");
  for (const repo of catalogs.evidence.repoUnresolved)
    if (SUPPORTED_CLASSES.has(repo) && !repoSteps.has(repo))
      fail(
        `repo ${repo} has impacted components in technical requirements but no plan step is allocated to it`
      );
  for (const ref of catalogs.requirementRefs)
    if (!coveredRefs.has(ref))
      fail(`requirement id ${ref} is not covered by any implementation step heading`);
  for (const token of catalogs.evidence.reqUnresolved)
    if (!coveredEvidence.has(token))
      fail(
        `unresolved requirement evidence token ${token} is not covered by any implementation step`
      );
  for (const token of catalogs.evidence.compUnresolved)
    if (!coveredEvidence.has(token))
      fail(
        `unresolved component evidence token ${token} is not covered by any implementation step`
      );
  for (const ref of catalogs.scheduledSliceRefs)
    if (!coveredEvidence.has(`slice/${ref}`))
      fail(
        `scheduled prerequisite slice_ref ${ref} from prerequisite_gaps.md is not covered by any plan step evidence token (expected: slice/${ref})`
      );
  for (const required of catalogs.requiredSurfaces) {
    const matches = preserved.filter((item) =>
      implementationPlanSurfaceMatches(required, item.value)
    );
    if (matches.length === 0)
      fail(
        `required missing operator-facing surface is not preserved by any implementation plan step: ${required}`
      );
    else if (!matches.some((item) => !item.coordination))
      fail(
        `required missing operator-facing surface has no non-coordination plan step coverage: ${required}`
      );
  }
  return problems;
}

export function canonicalImplementationPlanSurface(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/sign[\s-]*in|log[\s-]*in|authenticate|authentication/g, "login")
    .replace(/screen|view/g, "page")
    .replace(/path|url|entry\s*point|entry/g, "route")
    .replace(/portal|console|dashboard/g, "route")
    .replace(/container/g, "shell")
    .replace(/search|find/g, "lookup")
    .replace(/cli\s+tool|admin\s+tool|tooling\s+command|tool\s+command/g, "command")
    .replace(/cli/g, "command")
    .replace(/scheduled\s+task|cron\s+job/g, "job")
    .replace(/rest\s+endpoint|api\s+endpoint|http\s+endpoint/g, "endpoint")
    .replace(/\b(?:post|get|put|patch|delete)\s+\/\S+/g, "endpoint")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function implementationPlanSurfaceMatches(
  requiredValue: string,
  candidateValue: string
): boolean {
  const required = canonicalImplementationPlanSurface(requiredValue);
  const candidate = canonicalImplementationPlanSurface(candidateValue);
  if (!required || !candidate) return false;
  if (required === candidate || candidate.includes(required) || required.includes(candidate))
    return true;
  const candidateTokens = new Set(candidate.split(/\s+/));
  let sharedSpecific = 0,
    requiredSpecific = 0,
    sharedContent = 0,
    requiredContent = 0;
  for (const token of required.split(/\s+/)) {
    if (/^(login|shell|route|lookup|command|job|endpoint|tool)$/.test(token)) {
      requiredSpecific++;
      if (candidateTokens.has(token)) sharedSpecific++;
    } else if (!/^(page|form|link)$/.test(token) && !isWeakContentToken(token)) {
      requiredContent++;
      if (candidateTokens.has(token)) sharedContent++;
    }
  }
  return requiredSpecific > 0
    ? requiredContent > 0
      ? sharedSpecific > 0 && sharedContent > 0
      : sharedSpecific > 0
    : sharedContent >= 2;
}

function hasSurfaceTerms(value: string): boolean {
  return /(login|shell|route|lookup|page|workspace|form|command|job|endpoint|tool|link)/.test(
    canonicalImplementationPlanSurface(value)
  );
}
function looksSupportingOnly(value: string): boolean {
  return (
    /(auth|token|api|contract|schema|state|coordination|middleware|service|repository|adapter|dto|mapper|payload)/.test(
      value
    ) &&
    !/(login|sign[ -]?in|route|page|screen|shell|workspace|entry|lookup|search|dashboard|portal|console|form|command|cli|job|endpoint|tool|http|deep link|deeplink)/.test(
      value
    )
  );
}
function isWeakContentToken(token: string): boolean {
  return /^(operator|admin|user|protected|authenticated|workflow|surface|account)$/.test(token);
}
function isNoRemainingGap(value: string): boolean {
  return ["no remaining gap", "none", "n/a"].includes(value.trim().toLowerCase());
}
function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
function unique(value: string, index: number, values: string[]): boolean {
  return values.indexOf(value) === index;
}
function unfilled(value: string): boolean {
  return !value || value === "[UNFILLED]" || value.toLowerCase() === "none";
}
function parsePrerequisiteCatalog(
  content: string
): Array<{ status: string; sliceRef: string; surfaceKind: string; surfaceIdentity: string }> {
  const blocks: Array<{
    status: string;
    sliceRef: string;
    surfaceKind: string;
    surfaceIdentity: string;
  }> = [];
  let current:
    { status: string; sliceRef: string; surfaceKind: string; surfaceIdentity: string } | undefined;
  const flush = (): void => {
    if (current) blocks.push(current);
    current = undefined;
  };
  for (const line of content.split(/\r?\n/)) {
    if (/^#### Prerequisite:/.test(line)) {
      flush();
      current = { status: "", sliceRef: "", surfaceKind: "", surfaceIdentity: "" };
      continue;
    }
    if (/^### Requirement:/.test(line)) {
      flush();
      continue;
    }
    if (!current) continue;
    const field = line.match(/^\s*-\s*(status|slice_ref|surface_kind|surface_identity):\s*(.*)$/);
    if (!field) continue;
    const key =
      field[1] === "slice_ref"
        ? "sliceRef"
        : field[1] === "surface_kind"
          ? "surfaceKind"
          : field[1] === "surface_identity"
            ? "surfaceIdentity"
            : "status";
    current[key] = field[2]!.trim();
  }
  flush();
  return blocks;
}
function isFile(file: string): boolean {
  return existsSync(file) && statSync(file).isFile();
}
function gateFailure(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}
function gateError(errorMessage: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage };
}
