#!/usr/bin/env node
import { installProject } from "../init.js";

const [, , command, extra] = process.argv;

if (command !== "init" || extra !== undefined) {
  process.stderr.write("ERROR: Usage: overmind init\n");
  process.exitCode = 2;
} else {
  try {
    const result = installProject(process.cwd());
    process.stdout.write(`Installed overmind CLI to ${relative(result.projectRoot, result.cliPath)}\n`);
    process.stdout.write(`Installed skill to ${relative(result.projectRoot, result.skillPath)}\n`);
    process.exitCode = 0;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`ERROR: ${message}\n`);
    process.exitCode = 2;
  }
}

function relative(root: string, target: string): string {
  return target.startsWith(root) ? target.slice(root.length + 1) : target;
}
