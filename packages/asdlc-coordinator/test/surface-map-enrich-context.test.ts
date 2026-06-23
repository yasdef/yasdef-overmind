import { existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildSurfaceMapEnrichContext } from "../src/context/surface-map-enrich.js";

const PLACEHOLDER = "<to be defined during implementation>";

function fixture(root: string): { project: string; feature: string } {
  const project = path.join(root, "projects", "p1");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  mkdirSync(path.join(root, ".setup"), { recursive: true });
  return { project, feature };
}

function writeBackendMap(feature: string, withPlaceholder = true): void {
  const content = withPlaceholder
    ? `# Map\n\n## Section\n\n- field: ${PLACEHOLDER}\n`
    : "# Map\n\n## Section\n\n- field: actual_value\n";
  writeFileSync(path.join(feature, "project_surface_struct_resp_map_backend.md"), content);
}

function writeFrontendMap(feature: string, withPlaceholder = true): void {
  const content = withPlaceholder
    ? `# Map\n\n## Section\n\n- field: ${PLACEHOLDER}\n`
    : "# Map\n\n## Section\n\n- field: actual_value\n";
  writeFileSync(path.join(feature, "project_surface_struct_resp_map_frontend.md"), content);
}

function writeExternalSources(root: string, names: string[]): void {
  const items = names.map((n) => `  - name: ${n}`).join("\n");
  const content = names.length === 0
    ? "sources: []\n"
    : `sources:\n${items}\n`;
  writeFileSync(path.join(root, ".setup", "external_sources.yaml"), content);
}

test("surface-map-enrich context: no-op when no surface maps contain placeholder", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-noop-1-"));
  try {
    const { feature } = fixture(root);
    writeBackendMap(feature, false);
    writeExternalSources(root, ["my-kb-source"]);

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.ok(result.text?.includes("no_op: true"), "expected no_op: true");
    assert.ok(result.text?.includes("No surface maps with placeholder"), result.text);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: no-op when no eligible KB sources configured", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-noop-2-"));
  try {
    const { feature } = fixture(root);
    writeBackendMap(feature, true);
    writeExternalSources(root, ["generic-mcp-source", "another-tool"]);

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.ok(result.text?.includes("no_op: true"), "expected no_op: true");
    assert.ok(result.text?.includes("No eligible knowledge-base MCP sources"), result.text);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: full context emitted with backend map path, gate command, and KB source name", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-full-"));
  try {
    const { feature } = fixture(root);
    writeBackendMap(feature, true);
    writeExternalSources(root, ["project-kb", "other-tool"]);

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.ok(text.includes("projects/p1/feature-a/project_surface_struct_resp_map_backend.md"), text);
    assert.ok(text.includes("class: backend"), text);
    assert.ok(text.includes("gate surface-map projects/p1/feature-a --class backend"), text);
    assert.ok(text.includes("- project-kb"), text);
    assert.ok(!text.includes("no_op"), "should not contain no_op");
    assert.doesNotMatch(text, /\.codex\/skills|\.claude\/skills/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: multiple class maps listed when multiple classes have placeholders", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-multi-"));
  try {
    const { feature } = fixture(root);
    writeBackendMap(feature, true);
    writeFrontendMap(feature, true);
    writeExternalSources(root, ["knowledge-base-mcp"]);

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.ok(text.includes("class: backend"), text);
    assert.ok(text.includes("class: frontend"), text);
    assert.ok(text.includes("gate surface-map projects/p1/feature-a --class backend"), text);
    assert.ok(text.includes("gate surface-map projects/p1/feature-a --class frontend"), text);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: exit 2 when external_sources.yaml is missing and surface maps have placeholders", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-nosources-"));
  try {
    const { feature } = fixture(root);
    writeBackendMap(feature, true);
    // Do NOT write external_sources.yaml

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.errorMessage?.includes("external_sources.yaml"), result.errorMessage);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: exit 2 when feature path does not resolve under projects/<id>/<feature>/", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-badpath-"));
  try {
    mkdirSync(path.join(root, "not-projects", "feature-a"), { recursive: true });

    // Path resolves outside workspace root — fails at workspace resolution
    const outsideResult = buildSurfaceMapEnrichContext(path.join(root, "not-projects", "feature-a"), root);
    assert.equal(outsideResult.exitCode, 2, outsideResult.errorMessage);

    // Path does not have projects/<id>/<feature> shape — fails at path structure check
    mkdirSync(path.join(root, "projects", "p1"), { recursive: true });
    const shallowResult = buildSurfaceMapEnrichContext("projects/p1", root);
    assert.equal(shallowResult.exitCode, 2, shallowResult.errorMessage);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("surface-map-enrich context: exit 2 for feature path symlinked outside workspace", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-sme-symlink-"));
  const outside = mkdtempSync(path.join(tmpdir(), "overmind-sme-outside-"));
  try {
    writeFileSync(path.join(outside, "project_surface_struct_resp_map_backend.md"), `field: ${PLACEHOLDER}\n`);
    mkdirSync(path.join(root, "projects", "p1"), { recursive: true });
    symlinkSync(outside, path.join(root, "projects", "p1", "feature-a"));

    const result = buildSurfaceMapEnrichContext("projects/p1/feature-a", root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /must resolve inside ASDLC workspace/);
  } finally {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});
