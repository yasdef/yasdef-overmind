import { captureTaskToBrInput } from "../capture/index.js";
import {
  buildTaskToBrContext,
  buildRepoBrScanContext,
  buildBrClarificationContext,
  buildRequirementsEarsContext,
  buildEarsReviewContext,
  buildContractDeltaContext,
  buildSurfaceMapContext,
  buildSurfaceMapEnrichContext,
  buildTechnicalRequirementsContext,
  buildImplementationSlicesContext,
  buildPrerequisiteGapsContext,
  buildImplementationPlanContext,
  buildPlanSemanticReviewContext
} from "../context/index.js";
import { runBrClarificationReadiness } from "../readiness/index.js";
import {
  syncContractDeltaStep,
  syncRepoBrScanStep,
  syncSurfaceMapStep,
  syncPrerequisiteGapsStep
} from "../sync/index.js";
import {
  validateTaskToBr,
  validateRepoBrScan,
  validateBrClarification,
  validateRequirementsEars,
  validateEarsReview,
  validateContractDelta,
  validateSurfaceMap,
  validateTechnicalRequirements,
  validateImplementationSlices,
  validatePrerequisiteGaps,
  validateImplementationPlan,
  validatePlanSemanticReview
} from "../validate/index.js";

import type {
  CaptureResult,
  ContextResult,
  GateResult,
  ReadinessResult,
  SyncStepResult
} from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

const SURFACE_CLASSES = ["backend", "frontend", "mobile"] as const;

type OutputStreams = {
  stdout: Pick<NodeJS.WriteStream, "write">;
  stderr: Pick<NodeJS.WriteStream, "write">;
};

const gateRegistry: Record<string, (targetPath: string) => GateResult> = {
  "plan-semantic-review": validatePlanSemanticReview,
  "implementation-plan": validateImplementationPlan,
  "contract-delta": validateContractDelta,
  "br-clarification": validateBrClarification,
  "ears-review": validateEarsReview,
  "requirements-ears": validateRequirementsEars,
  "task-to-br": validateTaskToBr,
  "repo-br-scan": validateRepoBrScan,
  "technical-requirements": validateTechnicalRequirements,
  "implementation-slices": validateImplementationSlices,
  "prerequisite-gaps": validatePrerequisiteGaps
};

const contextRegistry: Record<string, (featurePath: string) => ContextResult> = {
  "plan-semantic-review": buildPlanSemanticReviewContext,
  "implementation-plan": buildImplementationPlanContext,
  "contract-delta": buildContractDeltaContext,
  "br-clarification": buildBrClarificationContext,
  "ears-review": buildEarsReviewContext,
  "requirements-ears": buildRequirementsEarsContext,
  "task-to-br": buildTaskToBrContext,
  "repo-br-scan": buildRepoBrScanContext,
  "surface-map-enrich": buildSurfaceMapEnrichContext,
  "technical-requirements": buildTechnicalRequirementsContext,
  "implementation-slices": buildImplementationSlicesContext,
  "prerequisite-gaps": buildPrerequisiteGapsContext
};

const captureRegistry: Record<
  string,
  (featurePath: string, options: CaptureOptions) => CaptureResult
> = {
  "task-to-br": captureTaskToBrInput
};

const syncRegistry: Record<string, (featurePath: string) => SyncStepResult> = {
  "contract-delta": syncContractDeltaStep,
  "repo-br-scan": syncRepoBrScanStep,
  "prerequisite-gaps": syncPrerequisiteGapsStep
};

const readinessRegistry: Record<string, (featurePath: string) => ReadinessResult> = {
  "br-clarification": runBrClarificationReadiness
};

const classGateRegistry: Record<
  string,
  (targetPath: string, klass: SurfaceMapClass) => GateResult
> = {
  "surface-map": validateSurfaceMap
};

const classContextRegistry: Record<
  string,
  (featurePath: string, klass: SurfaceMapClass) => ContextResult
> = {
  "surface-map": buildSurfaceMapContext
};

const classSyncRegistry: Record<
  string,
  (featurePath: string, klass: SurfaceMapClass) => SyncStepResult
> = {
  "surface-map": syncSurfaceMapStep
};

function parseClassOption(
  args: string[],
  verb: string
): { klass?: SurfaceMapClass; error?: string } {
  let klass: string | undefined;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--class") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { error: "Missing value for --class." };
      }
      klass = value;
      index += 1;
      continue;
    }
    return { error: `Unknown ${verb} argument: ${arg}` };
  }
  if (!klass) {
    return { error: "Missing required option: --class <backend|frontend|mobile>." };
  }
  if (!(SURFACE_CLASSES as readonly string[]).includes(klass)) {
    return { error: `Invalid class '${klass}'. Supported classes: backend, frontend, mobile.` };
  }
  return { klass: klass as SurfaceMapClass };
}

interface CaptureOptions {
  sourceFile?: string;
  jira?: string;
  overwrite?: boolean;
}

export async function runCli(
  argv: string[],
  streams: OutputStreams = { stdout: process.stdout, stderr: process.stderr }
): Promise<number> {
  const [command, step, targetPath, ...args] = argv.slice(2);

  if (command === "gate") {
    return runGate(step, targetPath, args, streams);
  }
  if (command === "context") {
    return runContext(step, targetPath, args, streams);
  }
  if (command === "capture") {
    return runCapture(step, targetPath, args, streams);
  }
  if (command === "sync") {
    return runSync(step, targetPath, args, streams);
  }
  if (command === "readiness") {
    return runReadiness(step, targetPath, streams);
  }

  streams.stderr.write(
    "ERROR: Usage: overmind <capture|context|gate|sync|readiness> <step> <path>\n"
  );
  return 2;
}

function runGate(
  step: string | undefined,
  targetPath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !targetPath) {
    streams.stderr.write("ERROR: Usage: overmind gate <step> <path>\n");
    return 2;
  }

  const classValidator = classGateRegistry[step];
  let result: GateResult;
  if (classValidator) {
    const parsed = parseClassOption(args, "gate");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classValidator(targetPath, parsed.klass);
  } else {
    const validator = gateRegistry[step];
    if (!validator) {
      streams.stderr.write(`ERROR: Unknown gate step: ${step}\n`);
      return 2;
    }
    result =
      step === "br-clarification"
        ? validateBrClarification(targetPath, process.cwd(), {
            onProgress: (line) => streams.stdout.write(`${line}\n`)
          })
        : validator(targetPath);
  }
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.passMessage}\n`);
    return 0;
  }
  if (result.exitCode === 1) {
    streams.stdout.write("business-context gate failed\n");
    for (const problem of result.problems) {
      streams.stdout.write(`missing: ${problem}\n`);
    }
    return 1;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Validation cannot run."}\n`);
  return 2;
}

function runContext(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind context <step> <feature_path>\n");
    return 2;
  }

  const classBuilder = classContextRegistry[step];
  let result: ContextResult;
  if (classBuilder) {
    const parsed = parseClassOption(args, "context");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classBuilder(featurePath, parsed.klass);
  } else {
    const builder = contextRegistry[step];
    if (!builder) {
      streams.stderr.write(`ERROR: Unknown context step: ${step}\n`);
      return 2;
    }
    result = builder(featurePath);
  }
  if (result.exitCode === 0) {
    streams.stdout.write(result.text ?? "");
    return 0;
  }

  const errMsg = result.errorMessage ?? "Context cannot be assembled.";
  streams.stderr.write(result.verbatim ? `${errMsg}\n` : `ERROR: ${errMsg}\n`);
  return 2;
}

function runCapture(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write(
      "ERROR: Usage: overmind capture <step> <feature_path> (--source-file <path> | --jira <ticket>) [--overwrite]\n"
    );
    return 2;
  }

  const capture = captureRegistry[step];
  if (!capture) {
    streams.stderr.write(`ERROR: Unknown capture step: ${step}\n`);
    return 2;
  }

  const parsed = parseCaptureOptions(args);
  if (parsed.error) {
    streams.stderr.write(`ERROR: ${parsed.error}\n`);
    return 2;
  }

  const result = capture(featurePath, parsed.options);
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.message ?? "capture complete"}\n`);
    return 0;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Capture cannot run."}\n`);
  return 2;
}

function runSync(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind sync <step> <feature_path>\n");
    return 2;
  }

  const classSyncer = classSyncRegistry[step];
  let result: SyncStepResult;
  if (classSyncer) {
    const parsed = parseClassOption(args, "sync");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classSyncer(featurePath, parsed.klass);
  } else {
    const syncer = syncRegistry[step];
    if (!syncer) {
      streams.stderr.write(`ERROR: Unknown sync step: ${step}\n`);
      return 2;
    }
    result = syncer(featurePath);
  }
  if (result.exitCode === 0) {
    const count = result.syncedCount ?? 0;
    streams.stdout.write(
      count === 0 ? "No ready repos to sync.\n" : `Synced ${count} repo(s) to default branch.\n`
    );
    return 0;
  }

  if (result.blockedMessages && result.blockedMessages.length > 0) {
    for (const msg of result.blockedMessages) {
      streams.stderr.write(`${msg}\n`);
    }
    return 2;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Sync cannot run."}\n`);
  return 2;
}

function runReadiness(
  step: string | undefined,
  featurePath: string | undefined,
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind readiness <step> <feature_path>\n");
    streams.stderr.write(
      "ERROR: Usage: overmind <capture|context|gate|sync|readiness> <step> <path>\n"
    );
    return 2;
  }

  const checker = readinessRegistry[step];
  if (!checker) {
    streams.stderr.write(`ERROR: Unknown readiness step: ${step}\n`);
    return 2;
  }

  const result = checker(featurePath);
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.message ?? "readiness check passed"}\n`);
    return 0;
  }
  if (result.exitCode === 1) {
    streams.stdout.write("business-context gate failed\n");
    for (const problem of result.problems ?? []) {
      streams.stdout.write(`missing: ${problem}\n`);
    }
    return 1;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Readiness cannot run."}\n`);
  return 2;
}

function parseCaptureOptions(args: string[]): { options: CaptureOptions; error?: string } {
  const options: CaptureOptions = {};

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--source-file") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { options, error: "Missing value for --source-file." };
      }
      options.sourceFile = value;
      index += 1;
      continue;
    }
    if (arg === "--jira") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { options, error: "Missing value for --jira." };
      }
      options.jira = value;
      index += 1;
      continue;
    }
    if (arg === "--overwrite") {
      options.overwrite = true;
      continue;
    }
    return { options, error: `Unknown capture argument: ${arg}` };
  }

  return { options };
}
