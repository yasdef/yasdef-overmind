import { readFileSync } from "node:fs";

import type { Diagnostic } from "../types/index.js";

const REGISTERED_AGENT_COMMANDS = new Set(["codex"]);

export interface RunnerPhaseConfig {
  command: string;
  model: string;
  args: string[];
}

export interface RunnerConfig {
  source: string;
  phases: Map<string, RunnerPhaseConfig>;
  diagnostics: Diagnostic[];
}

export interface ResolveRunnerPhaseResult {
  config?: RunnerPhaseConfig;
  diagnostics: Diagnostic[];
}

export function loadRunnerConfig(modelsPath: string): RunnerConfig {
  let content: string;
  try {
    content = readFileSync(modelsPath, "utf8");
  } catch (error) {
    const diagnostic =
      isFileSystemError(error) && error.code === "ENOENT"
        ? missingModelsDiagnostic(modelsPath)
        : unreadableModelsDiagnostic(modelsPath, error);
    return {
      source: modelsPath,
      phases: new Map(),
      diagnostics: [diagnostic]
    };
  }

  const phases = new Map<string, RunnerPhaseConfig>();
  const lines = content.split(/\r?\n/);

  for (const line of lines) {
    if (/^\s*#/.test(line)) {
      continue;
    }

    const fields = line.split("|");
    if (fields.length < 3) {
      continue;
    }

    const key = fields[0]?.trim() ?? "";
    if (key === "") {
      continue;
    }

    const phaseKey = key.toLowerCase();
    if (phases.has(phaseKey)) {
      continue;
    }

    phases.set(phaseKey, {
      command: fields[1]?.trim() ?? "",
      model: fields[2]?.trim() ?? "",
      args: fields
        .slice(3)
        .map((value) => value.trim())
        .filter((value) => value !== "")
    });
  }

  return { source: modelsPath, phases, diagnostics: [] };
}

export function resolveRunnerPhase(config: RunnerConfig, phase: string): ResolveRunnerPhaseResult {
  const requestedPhase = phase.trim();

  if (config.diagnostics.length > 0) {
    // A load-level failure (e.g. missing file) still names the affected phase and
    // expected row shape so the operator knows exactly which row to add.
    return { diagnostics: [unresolvablePhaseDiagnostic(config, requestedPhase)] };
  }
  const phaseConfig = config.phases.get(requestedPhase.toLowerCase());
  if (!phaseConfig || phaseConfig.command === "" || phaseConfig.model === "") {
    return {
      diagnostics: [invalidPhaseDiagnostic(config.source, requestedPhase)]
    };
  }

  if (!REGISTERED_AGENT_COMMANDS.has(phaseConfig.command)) {
    return {
      diagnostics: [invalidCommandDiagnostic(config.source, requestedPhase, phaseConfig.command)]
    };
  }

  return { config: phaseConfig, diagnostics: [] };
}

function missingModelsDiagnostic(modelsPath: string): Diagnostic {
  return {
    severity: "error",
    source: modelsPath,
    reason: "Models file not found."
  };
}

function unreadableModelsDiagnostic(modelsPath: string, error: unknown): Diagnostic {
  return {
    severity: "error",
    source: modelsPath,
    reason: `Unable to read models file: ${error instanceof Error ? error.message : String(error)}`
  };
}

function isFileSystemError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}

function invalidPhaseDiagnostic(modelsPath: string, phase: string): Diagnostic {
  return {
    severity: "error",
    source: modelsPath,
    reason: `Invalid or missing '${phase}' entry (expected: ${phase} | codex | <model> | <args... optional>).`
  };
}

function unresolvablePhaseDiagnostic(config: RunnerConfig, phase: string): Diagnostic {
  const cause = config.diagnostics.map((diagnostic) => diagnostic.reason).join(" ");
  return {
    severity: "error",
    source: config.source,
    reason: `${cause} Cannot resolve required phase '${phase}' (expected row: ${phase} | codex | <model> | <args... optional>).`
  };
}

function invalidCommandDiagnostic(modelsPath: string, phase: string, command: string): Diagnostic {
  return {
    severity: "error",
    source: modelsPath,
    reason: `Unsupported command '${command}' for phase '${phase}'. Registered commands: codex.`
  };
}
