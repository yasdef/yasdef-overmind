import { existsSync, statSync } from "node:fs";
import path from "node:path";

import { readRequiredTextFile, resolveInputPath } from "../parse/index.js";
import type { GateResult } from "../types/index.js";

/**
 * TypeScript port of `check_common_contract_definition_quality.sh` (D5). Validates
 * `<project>/common_contract_definition.md` preserving the shell helper's stable exit
 * classification: `0` structurally/semantically valid, `1` recoverable content issues
 * with `quality gate failed: ...` messages, `2` missing/unreadable runtime inputs. Shared
 * parity fixtures drive this and the retained shell helper so their checks cannot drift.
 */

const SECTION_HEADINGS: Array<{ id: Section; test: RegExp; label: string }> = [
  { id: "1", test: /^##\s+1\.\s+Document\s+Meta\s*$/, label: "## 1. Document Meta" },
  {
    id: "2",
    test: /^##\s+2\.\s+Source\s+Repository\s+Evidence\s*$/,
    label: "## 2. Source Repository Evidence"
  },
  {
    id: "3",
    test: /^##\s+3\.\s+Common\s+Contract\s+Baseline\s*$/,
    label: "## 3. Common Contract Baseline"
  },
  {
    id: "4",
    test: /^##\s+4\.\s+Reconciliation\s+Decisions\s*$/,
    label: "## 4. Reconciliation Decisions"
  },
  {
    id: "5",
    test: /^##\s+5\.\s+Known\s+Risks\s*\/\s*Uncertainties\s*$/,
    label: "## 5. Known Risks / Uncertainties"
  },
  {
    id: "6",
    test: /^##\s+6\.\s+Common\s+Planning\s+Signals\s*$/,
    label: "## 6. Common Planning Signals"
  }
];

const ALLOWED_CONTRACT_STATUS = ["aligned", "drifted", "single_source", "inferred"];
const ALLOWED_CONTRACT_KIND = [
  "http_api",
  "event",
  "async_message",
  "db_schema",
  "config",
  "auth_token",
  "file_interface",
  "library_api",
  "other"
];
const ALLOWED_INTERACTION_MODE = ["sync", "async", "pull", "push"];
const ALLOWED_TRUST_BOUNDARY = ["public", "internal", "service_to_service", "admin_only", "none"];

const CONTRACT_KEYS = [
  "contract_kind",
  "interaction_mode",
  "producer_repositories",
  "consumer_repositories",
  "contract_surface",
  "contract_status",
  "source_of_truth",
  "canonical_shape",
  "shared_types",
  "trust_boundary",
  "compatibility_rule",
  "planning_implication",
  "notes"
] as const;

type Section = "1" | "2" | "3" | "4" | "5" | "6" | "";

export function validateContractReconciliation(inputPath: string, cwd = process.cwd()): GateResult {
  if (!inputPath || inputPath.trim() === "") {
    return gateError("Missing target common contract definition path argument.");
  }

  try {
    const targetPath = resolveTargetPath(inputPath, cwd);
    if (!existsSync(targetPath)) {
      return gateError(`Target common contract definition artifact not found: ${targetPath}`);
    }
    if (statSync(targetPath).isDirectory()) {
      return gateError(`Target common contract definition artifact is a directory: ${targetPath}`);
    }

    const content = readRequiredTextFile(targetPath);
    if (!/[^ \t\r\n]/.test(content)) {
      return gateRecoverable([
        `quality gate failed: target common contract definition artifact is empty: ${targetPath}`
      ]);
    }

    const problems = validateCommonContractContent(content);
    return problems.length > 0 ? gateRecoverable(problems) : gatePassed();
  } catch (err) {
    return gateError(err instanceof Error ? err.message : String(err));
  }
}

interface RepositoryBlock {
  name: string;
  class?: string;
  repo_path?: string;
  contract_evidence_summary?: string;
  key_surfaces_reviewed?: string;
  notes?: string;
}

interface ContractBlock {
  name: string;
  fields: Map<string, string>;
}

/** Port of the shell helper's awk program; returns `quality gate failed: ...` problems. */
export function validateCommonContractContent(content: string): string[] {
  const blockProblems: string[] = [];
  const endProblems: string[] = [];
  const fail = (list: string[], message: string): void => {
    list.push(`quality gate failed: ${message}`);
  };

  const seen = new Set<Section>();
  let section: Section = "";
  let hasUnfilled = false;

  const meta = { project_id: "", source_repo_count: "", last_updated: "", confidence_level: "" };
  let repositoryBlocks = 0;
  let contractBlocks = 0;
  let decisionCount = 0;
  let uncertaintyCount = 0;
  let uncertainty1 = "";
  let prepCount = 0;

  let repo: RepositoryBlock | undefined;
  let contract: ContractBlock | undefined;

  const finishRepository = (): void => {
    if (!repo) return;
    if (isUnfilled(repo.name))
      fail(blockProblems, "repository block heading is empty in section 2");
    if (isUnfilled(repo.class))
      fail(blockProblems, `repository ${repo.name} has unfilled key class`);
    if (isUnfilled(repo.repo_path))
      fail(blockProblems, `repository ${repo.name} has unfilled key repo_path`);
    if (isUnfilled(repo.contract_evidence_summary))
      fail(blockProblems, `repository ${repo.name} has unfilled key contract_evidence_summary`);
    if (isUnfilled(repo.key_surfaces_reviewed))
      fail(blockProblems, `repository ${repo.name} has unfilled key key_surfaces_reviewed`);
    if (isUnfilled(repo.notes))
      fail(blockProblems, `repository ${repo.name} has unfilled key notes`);
    repo = undefined;
  };

  const finishContract = (): void => {
    if (!contract) return;
    const name = contract.name;
    const get = (key: string): string | undefined => contract!.fields.get(key);
    if (isUnfilled(name)) fail(blockProblems, "contract block heading is empty in section 3");
    for (const key of CONTRACT_KEYS) {
      if (isUnfilled(get(key))) fail(blockProblems, `contract ${name} has unfilled key ${key}`);
    }
    const status = get("contract_status");
    if (
      !isUnfilled(status) &&
      !ALLOWED_CONTRACT_STATUS.includes(normalize(status!).toLowerCase())
    ) {
      fail(
        blockProblems,
        `contract ${name} has invalid contract_status: ${status} (allowed: aligned, drifted, single_source, inferred)`
      );
    }
    const kind = get("contract_kind");
    if (!isUnfilled(kind) && !ALLOWED_CONTRACT_KIND.includes(normalize(kind!).toLowerCase())) {
      fail(
        blockProblems,
        `contract ${name} has invalid contract_kind: ${kind} (allowed: http_api, event, async_message, db_schema, config, auth_token, file_interface, library_api, other)`
      );
    }
    const mode = get("interaction_mode");
    if (!isUnfilled(mode) && !ALLOWED_INTERACTION_MODE.includes(normalize(mode!).toLowerCase())) {
      fail(
        blockProblems,
        `contract ${name} has invalid interaction_mode: ${mode} (allowed: sync, async, pull, push)`
      );
    }
    const trust = get("trust_boundary");
    if (!isUnfilled(trust) && !ALLOWED_TRUST_BOUNDARY.includes(normalize(trust!).toLowerCase())) {
      fail(
        blockProblems,
        `contract ${name} has invalid trust_boundary: ${trust} (allowed: public, internal, service_to_service, admin_only, none)`
      );
    }
    const shape = get("canonical_shape");
    if (!isUnfilled(shape) && !isCompactStructuredShape(shape!)) {
      fail(
        blockProblems,
        `contract ${name} key canonical_shape must be compact and structured (not narrative prose)`
      );
    }
    contract = undefined;
  };

  for (const rawLine of content.split(/\r?\n/)) {
    if (/\[UNFILLED\]/i.test(rawLine)) hasUnfilled = true;

    const heading = rawLine.trim();
    if (/^##\s+/.test(heading)) {
      finishRepository();
      finishContract();
      section = "";
      const matched = SECTION_HEADINGS.find((candidate) => candidate.test.test(heading));
      if (matched) {
        section = matched.id;
        seen.add(matched.id);
      }
      continue;
    }

    const repoMatch = rawLine.match(/^###\s+Repository:\s*(.*)$/);
    if (repoMatch) {
      finishRepository();
      finishContract();
      repositoryBlocks += 1;
      repo = { name: normalize(repoMatch[1]!) };
      continue;
    }
    const contractMatch = rawLine.match(/^###\s+Contract:\s*(.*)$/);
    if (contractMatch) {
      finishRepository();
      finishContract();
      contractBlocks += 1;
      contract = { name: normalize(contractMatch[1]!), fields: new Map() };
      continue;
    }

    const field = parseField(rawLine);
    if (!field) continue;
    const { key, value } = field;

    if (section === "1") {
      if (key === "project_id") meta.project_id = value;
      else if (key === "source_repo_count") meta.source_repo_count = value;
      else if (key === "last_updated") meta.last_updated = value;
      else if (key === "confidence_level") meta.confidence_level = value;
    } else if (section === "4") {
      if (/^decision_[0-9]+$/.test(key) && !isUnfilled(value)) decisionCount += 1;
    } else if (section === "5") {
      if (/^uncertainty_[0-9]+$/.test(key) && !isUnfilled(value)) uncertaintyCount += 1;
      if (key === "uncertainty_1") uncertainty1 = value;
    } else if (section === "6") {
      if (/^prep_[0-9]+$/.test(key) && !isUnfilled(value)) prepCount += 1;
    }

    if (repo) {
      if (key === "class") repo.class = value;
      else if (key === "repo_path") repo.repo_path = value;
      else if (key === "contract_evidence_summary") repo.contract_evidence_summary = value;
      else if (key === "key_surfaces_reviewed") repo.key_surfaces_reviewed = value;
      else if (key === "notes") repo.notes = value;
    }
    if (contract && (CONTRACT_KEYS as readonly string[]).includes(key)) {
      contract.fields.set(key, value);
    }
  }

  finishRepository();
  finishContract();

  for (const heading of SECTION_HEADINGS) {
    if (!seen.has(heading.id)) fail(endProblems, `missing section ${heading.label}`);
  }
  if (hasUnfilled) fail(endProblems, "artifact still contains [UNFILLED] placeholders");

  if (isUnfilled(meta.project_id)) fail(endProblems, "key project_id is unfilled in section 1");
  const countIsInteger = /^[0-9]+$/.test(meta.source_repo_count);
  if (!countIsInteger)
    fail(endProblems, "key source_repo_count must be a non-negative integer in section 1");
  if (countIsInteger && Number(meta.source_repo_count) < 1)
    fail(endProblems, "key source_repo_count must be >= 1 in section 1");
  if (isUnfilled(meta.last_updated)) fail(endProblems, "key last_updated is unfilled in section 1");
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(meta.last_updated))
    fail(endProblems, "key last_updated must be YYYY-MM-DD in section 1");
  if (isUnfilled(meta.confidence_level))
    fail(endProblems, "key confidence_level is unfilled in section 1");

  if (repositoryBlocks < 1)
    fail(endProblems, "section 2 must contain at least one ### Repository block");
  if (contractBlocks < 1)
    fail(endProblems, "section 3 must contain at least one ### Contract block");
  if (decisionCount < 1)
    fail(endProblems, "section 4 must include at least one filled decision_N entry");
  if (uncertaintyCount < 1)
    fail(
      endProblems,
      "section 5 must include at least one filled uncertainty_N entry (use explicit values like none or not_observed when applicable)"
    );
  if (isUnfilled(uncertainty1))
    fail(
      endProblems,
      "key uncertainty_1 is required and must be explicit (use none or not_observed if no active uncertainty)"
    );
  if (prepCount < 1) fail(endProblems, "section 6 must include at least one filled prep_N entry");
  if (countIsInteger && Number(meta.source_repo_count) !== repositoryBlocks)
    fail(endProblems, "source_repo_count must match number of repository blocks in section 2");

  return [...blockProblems, ...endProblems];
}

function parseField(line: string): { key: string; value: string } | undefined {
  const stripped = line.replace(/^\s*-\s*/, "");
  const colon = stripped.indexOf(":");
  if (colon <= 0) return undefined;
  return {
    key: trim(stripped.slice(0, colon)),
    value: normalize(stripped.slice(colon + 1))
  };
}

function trim(value: string): string {
  return value.replace(/^\s+/, "").replace(/\s+$/, "");
}

function normalize(value: string): string {
  const trimmed = trim(value);
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function isUnfilled(value: string | undefined): boolean {
  const raw = value ?? "";
  const t = trim(raw);
  return t === "" || t.toUpperCase() === "[UNFILLED]";
}

function isCompactStructuredShape(value: string): boolean {
  const shape = trim(value).toLowerCase();
  if (isUnfilled(shape)) return false;
  if (/\.\s*$/.test(shape)) return false;
  if (
    /request\s*:/.test(shape) ||
    /response\s*:/.test(shape) ||
    /payload\s*:/.test(shape) ||
    /schema\s*:/.test(shape) ||
    /topic\s/.test(shape) ||
    /->\s*/.test(shape) ||
    shape.includes("{") ||
    shape.includes("}") ||
    shape.includes("[") ||
    shape.includes("]")
  ) {
    return true;
  }
  return false;
}

function resolveTargetPath(inputPath: string, cwd: string): string {
  const resolved = resolveInputPath(inputPath, cwd);
  if (existsSync(resolved) && statSync(resolved).isFile()) {
    return resolved;
  }
  return path.join(resolved, "common_contract_definition.md");
}

function gatePassed(): GateResult {
  return {
    exitCode: 0,
    passMessage: "quality gate passed: common contract definition is complete",
    problems: []
  };
}

function gateRecoverable(problems: string[]): GateResult {
  return { exitCode: 1, passMessage: "", problems };
}

function gateError(message: string): GateResult {
  return { exitCode: 2, passMessage: "", problems: [], errorMessage: message };
}
