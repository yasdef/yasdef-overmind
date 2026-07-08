import { fileURLToPath } from "node:url";

export * from "./cli/run.js";
export * from "./config/index.js";
export * from "./capture/index.js";
export * from "./context/index.js";
export * from "./git/index.js";
export * from "./interaction/index.js";
export * from "./orchestrator/index.js";
export * from "./parse/index.js";
export * from "./readiness/index.js";
export * from "./runner/index.js";
export * from "./sequencing/index.js";
export * from "./state/index.js";
export * from "./types/index.js";
export * from "./validate/index.js";
export * from "./workers/index.js";
export * from "./workspace/index.js";

export function getBundledOvermindPath(): string {
  return fileURLToPath(new URL("../overmind.js", import.meta.url));
}
