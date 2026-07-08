#!/usr/bin/env node
import { installProject } from "../init.js";

const [, , command, extra] = process.argv;

if (command !== "init" || extra !== undefined) {
  process.stderr.write("ERROR: Usage: overmind init\n");
  process.exitCode = 2;
} else {
  try {
    const result = installProject(process.cwd());
    process.stdout.write("Overmind workspace bootstrap complete.\n");
    process.stdout.write(`CLI: ${relative(result.projectRoot, result.cliPath)}\n`);
    process.stdout.write(`Skills: ${result.skillPaths.length} installed\n`);
    for (const skillPath of result.skillPaths) {
      process.stdout.write(`- ${relative(result.projectRoot, skillPath)}\n`);
    }
    process.stdout.write("Runtime templates:\n");
    for (const templatePath of result.templatePaths) {
      process.stdout.write(`- ${relative(result.projectRoot, templatePath)}\n`);
    }
    process.stdout.write("Setup defaults:\n");
    for (const setupPath of result.setupPaths) {
      process.stdout.write(`- ${relative(result.projectRoot, setupPath)}\n`);
    }
    process.stdout.write(`Quick run: ${relative(result.projectRoot, result.quickrunPath)}\n`);
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
