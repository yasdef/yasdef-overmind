import { createRequire } from "node:module";

// Injected via esbuild --define when bundled into dist/overmind.js (the artifact
// copied out to ASDLC workspaces, which has no sibling package.json to read).
declare const __OVERMIND_BUNDLED_VERSION__: string | undefined;

export function getOvermindVersion(): string {
  if (typeof __OVERMIND_BUNDLED_VERSION__ !== "undefined") {
    return __OVERMIND_BUNDLED_VERSION__;
  }
  // Path is relative to the compiled dist/src/version.js, not this source file.
  const packageJson = createRequire(import.meta.url)("../../package.json") as {
    version: string;
  };
  return packageJson.version;
}
