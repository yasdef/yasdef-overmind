import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { validateSurfaceMap, validateSurfaceMapContent } from "../src/validate/surface-map.js";
import type { SurfaceMapClass } from "../src/validate/surface-map.js";

const BACKEND_LAYERS = [
  "3.1 API Layer",
  "3.2 Application / Service Layer",
  "3.3 Domain Layer",
  "3.4 Persistence / Data Layer",
  "3.5 Integration Layer",
  "3.6 Runtime / Ops Layer",
  "3.7 Test Layer"
];
const BACKEND_SURFACES = [
  "4.1 API Surface",
  "4.2 Application / Service Surface",
  "4.3 Domain Surface",
  "4.4 Persistence / Data Surface",
  "4.5 Integration Surface",
  "4.6 Runtime / Ops Surface",
  "4.7 Test Surface",
  "4.8 Unexpected Backend Surface"
];
const FRONTEND_LAYERS = [
  "3.1 UI Composition Layer",
  "3.2 Component Layer",
  "3.3 State / Data Layer",
  "3.4 API Integration Layer",
  "3.5 UX Behavior Layer",
  "3.6 Platform / Runtime Layer",
  "3.7 Test Layer"
];
const FRONTEND_SURFACES = [
  "4.1 UI Composition Surface",
  "4.2 Component Surface",
  "4.3 State / Data Surface",
  "4.4 API Integration Surface",
  "4.5 UX Behavior Surface",
  "4.6 Platform / Runtime Surface",
  "4.7 Test Surface",
  "4.8 Unexpected Frontend / Mobile Surface"
];

function buildSurfaceMap(klass: SurfaceMapClass): string {
  const isBackend = klass === "backend";
  const title = isBackend
    ? "# Project Surface Structure + Responsibility Map (Backend)"
    : "# Project Surface Structure + Responsibility Map (Frontend / Mobile)";
  const section4 = isBackend
    ? "## 4. Backend Surfaces Touched With Current Feature"
    : "## 4. Frontend / Mobile Surfaces Touched With Current Feature";
  const layers = isBackend ? BACKEND_LAYERS : FRONTEND_LAYERS;
  const surfaces = isBackend ? BACKEND_SURFACES : FRONTEND_SURFACES;
  const projectClasses = isBackend ? "backend" : klass === "mobile" ? "mobile" : "frontend";

  const lines: string[] = [
    title,
    "",
    "## 1. Document Meta",
    "- repo_name: demo-repo",
    "- service_name: demo-service",
    "- project_type_code: B",
    `- project_classes: ${projectClasses}`,
    "- feature_id: feature-a",
    "- feature_title: Feature A",
    "- analyzed_repo_paths: /repo/demo",
    "- source_inputs_used: requirements_ears.md, feature_contract_delta.md",
    "- last_updated: 2026-06-15",
    "- was_enriched_with_mcp: false",
    "",
    "## 2. Feature Scope",
    "- feature_summary: Adds a capability.",
    "- in_scope_feature_delta: New behavior.",
    "- out_of_scope_notes: none",
    "",
    "## 3. Key Parts of Repo and Their Responsibilities"
  ];
  for (const layer of layers) {
    lines.push(
      "",
      `### ${layer}`,
      `- responsibility_summary: Covers ${layer}.`,
      `- main_repo_paths: src/${layer.split(" ")[0]}`,
      `- key_components: Component`,
      `- transport_layer: Component.handle`,
      `- user_reachable_surface: none`
    );
  }
  lines.push("", "### 3.8 Another Layer(s)", "> none", "", section4);
  surfaces.forEach((surface, index) => {
    lines.push(
      "",
      `### ${surface}`,
      `- surface_summary: Covers ${surface}.`,
      `- applicability: ${index === 0 ? "applicable" : "not_applicable"}`,
      `- repo_paths: src/${surface.split(" ")[0]}`,
      `- why_feature_touches_it: Requirement RQ-1.`,
      `- expected_changes: Update behavior.`,
      `- evidence: repo src; feature_contract_delta.md item-1`,
      `- transport_layer: Component.handle`,
      `- user_reachable_surface: POST /api/example`
    );
  });
  return `${lines.join("\n")}\n`;
}

/** Blank the value of a `- key: value` line (anywhere) so the field reads as unfilled. */
function blankField(content: string, key: string): string {
  return content.replace(new RegExp(`^- ${key}:.*$`, "m"), `- ${key}:`);
}

/** Drop the first `- field:` line inside a `### <block>` subsection. */
function dropFieldFromBlock(content: string, blockHeading: string, field: string): string {
  const out: string[] = [];
  let inBlock = false;
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (trimmed === `### ${blockHeading}`) {
      inBlock = true;
      out.push(line);
      continue;
    }
    if (inBlock && (trimmed.startsWith("### ") || trimmed.startsWith("## "))) {
      inBlock = false;
    }
    if (inBlock && trimmed.startsWith(`- ${field}:`)) {
      continue;
    }
    out.push(line);
  }
  return out.join("\n");
}

const VALIDATION_CONFIGS = [
  {
    klass: "backend" as const,
    title: "# Project Surface Structure + Responsibility Map (Backend)",
    section4: "## 4. Backend Surfaces Touched With Current Feature",
    layers: BACKEND_LAYERS,
    surfaces: BACKEND_SURFACES
  },
  {
    klass: "frontend" as const,
    title: "# Project Surface Structure + Responsibility Map (Frontend / Mobile)",
    section4: "## 4. Frontend / Mobile Surfaces Touched With Current Feature",
    layers: FRONTEND_LAYERS,
    surfaces: FRONTEND_SURFACES
  }
] as const;

const META_KEYS = [
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

const SCOPE_KEYS = ["feature_summary", "in_scope_feature_delta", "out_of_scope_notes"] as const;
const LAYER_FIELDS = [
  "responsibility_summary",
  "main_repo_paths",
  "key_components",
  "transport_layer",
  "user_reachable_surface"
] as const;
const SURFACE_FIELDS = [
  "surface_summary",
  "applicability",
  "repo_paths",
  "why_feature_touches_it",
  "expected_changes",
  "evidence",
  "transport_layer",
  "user_reachable_surface"
] as const;

test("complete backend surface map passes", () => {
  assert.deepEqual(validateSurfaceMapContent(buildSurfaceMap("backend"), "backend"), []);
});

test("complete frontend surface map passes", () => {
  assert.deepEqual(validateSurfaceMapContent(buildSurfaceMap("frontend"), "frontend"), []);
});

test("mobile uses the frontend config", () => {
  assert.deepEqual(validateSurfaceMapContent(buildSurfaceMap("mobile"), "mobile"), []);
});

test("divergent_from_blueprint with a concrete value passes", () => {
  const withDivergence = buildSurfaceMap("backend").replace(
    "### 3.1 API Layer\n- responsibility_summary: Covers 3.1 API Layer.",
    "### 3.1 API Layer\n- divergent_from_blueprint: §3.1\n- responsibility_summary: Covers 3.1 API Layer."
  );
  assert.deepEqual(validateSurfaceMapContent(withDivergence, "backend"), []);
});

for (const config of VALIDATION_CONFIGS) {
  test(`${config.klass}: every required title, section, meta, and scope value is enforced`, () => {
    const base = buildSurfaceMap(config.klass);
    const missingTitle = base.replace(config.title, "# Wrong title");
    assert.ok(validateSurfaceMapContent(missingTitle, config.klass).some((problem) => problem.includes("unexpected title")));

    for (const heading of [
      "## 1. Document Meta",
      "## 2. Feature Scope",
      "## 3. Key Parts of Repo and Their Responsibilities",
      config.section4
    ]) {
      const broken = base.replace(heading, `${heading} RENAMED`);
      assert.ok(
        validateSurfaceMapContent(broken, config.klass).some((problem) => problem.includes("missing section")),
        `${config.klass} should reject missing section: ${heading}`
      );
    }

    for (const key of META_KEYS) {
      const broken = blankField(base, key);
      assert.ok(
        validateSurfaceMapContent(broken, config.klass).some((problem) => problem.includes(`missing or empty meta field: ${key}`)),
        `${config.klass} should reject missing meta key: ${key}`
      );
    }
    for (const key of SCOPE_KEYS) {
      const broken = blankField(base, key);
      assert.ok(
        validateSurfaceMapContent(broken, config.klass).some((problem) => problem.includes(`missing or empty feature scope field: ${key}`)),
        `${config.klass} should reject missing scope key: ${key}`
      );
    }

    assert.ok(
      validateSurfaceMapContent(base.replace("- project_type_code: B", "- project_type_code: Z"), config.klass)
        .some((problem) => problem.includes("project_type_code must be A, B, or C"))
    );
    assert.ok(
      validateSurfaceMapContent(base.replace("- last_updated: 2026-06-15", "- last_updated: invalid"), config.klass)
        .some((problem) => problem.includes("last_updated must be YYYY-MM-DD"))
    );
  });

  test(`${config.klass}: every required layer subsection and field is enforced`, () => {
    const base = buildSurfaceMap(config.klass);
    for (const layer of config.layers) {
      const missingLayer = base.replace(`### ${layer}`, `### ${layer} RENAMED`);
      assert.ok(
        validateSurfaceMapContent(missingLayer, config.klass).some((problem) => problem.includes(`missing layer subsection: ${layer}`)),
        `${config.klass} should reject missing layer: ${layer}`
      );
      for (const field of LAYER_FIELDS) {
        const missingField = dropFieldFromBlock(base, layer, field);
        assert.ok(
          validateSurfaceMapContent(missingField, config.klass).some((problem) => problem.includes(field) && problem.includes(layer)),
          `${config.klass} should reject ${layer} without ${field}`
        );
      }
    }
    const missingAnotherLayer = base.replace("### 3.8 Another Layer(s)", "### 3.8 Another Layer(s) RENAMED");
    assert.ok(validateSurfaceMapContent(missingAnotherLayer, config.klass).some((problem) => problem.includes("3.8 Another Layer(s)")));
  });

  test(`${config.klass}: every required surface subsection and field is enforced`, () => {
    const base = buildSurfaceMap(config.klass);
    for (const surface of config.surfaces) {
      const missingSurface = base.replace(`### ${surface}`, `### ${surface} RENAMED`);
      assert.ok(
        validateSurfaceMapContent(missingSurface, config.klass).some((problem) => problem.includes(`missing surface subsection: ${surface}`)),
        `${config.klass} should reject missing surface: ${surface}`
      );
      for (const field of SURFACE_FIELDS) {
        const missingField = dropFieldFromBlock(base, surface, field);
        assert.ok(
          validateSurfaceMapContent(missingField, config.klass).some((problem) => problem.includes(field) && problem.includes(surface)),
          `${config.klass} should reject ${surface} without ${field}`
        );
      }
    }
  });

  test(`${config.klass}: placeholders, an empty target, and no applicable surface are recoverable`, () => {
    const base = buildSurfaceMap(config.klass);
    for (const placeholder of ["[UNFILLED]", "[OPTIONAL value]"]) {
      const broken = base.replace("demo-repo", placeholder);
      assert.ok(validateSurfaceMapContent(broken, config.klass).some((problem) => problem.includes("template placeholders")));
    }
    const noneApplicable = base.replace("- applicability: applicable", "- applicability: not_applicable");
    assert.ok(validateSurfaceMapContent(noneApplicable, config.klass).some((problem) => problem.includes("at least one")));

    const dir = mkdtempSync(path.join(tmpdir(), `overmind-surface-${config.klass}-`));
    try {
      const file = path.join(dir, `project_surface_struct_resp_map_${config.klass}.md`);
      writeFileSync(file, base);
      assert.equal(validateSurfaceMap(file, config.klass).exitCode, 0);
      writeFileSync(file, "  \n");
      assert.equal(validateSurfaceMap(file, config.klass).exitCode, 1);
      assert.equal(validateSurfaceMap(path.join(dir, "missing.md"), config.klass).exitCode, 2);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}

test("wrong project_classes for the class fails", () => {
  const wrong = buildSurfaceMap("backend").replace("- project_classes: backend", "- project_classes: frontend");
  assert.ok(validateSurfaceMapContent(wrong, "backend").some((p) => p.includes("project_classes must include backend")));
  const wrongFe = buildSurfaceMap("frontend").replace("- project_classes: frontend", "- project_classes: backend");
  assert.ok(
    validateSurfaceMapContent(wrongFe, "frontend").some((p) => p.includes("project_classes must include frontend or mobile"))
  );
});
