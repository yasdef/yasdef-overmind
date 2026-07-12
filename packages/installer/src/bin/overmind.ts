#!/usr/bin/env node
import { stdin, stdout } from "node:process";
import { createInterface } from "node:readline";

import { classifyInstallTarget, installProject, resolveInstallTarget } from "../init.js";

const [, , command, extra] = process.argv;

type PromptSelection =
  | {
      resolvedTarget: string;
      classification: Extract<
        ReturnType<typeof classifyInstallTarget>,
        { kind: "clean-install" | "update" }
      >;
    }
  | undefined;

if (command !== "init" || extra !== undefined) {
  process.stderr.write("ERROR: Usage: overmind init\n");
  process.exitCode = 2;
} else {
  void runInit();
}

function relative(root: string, target: string): string {
  return target.startsWith(root) ? target.slice(root.length + 1) : target;
}

async function runInit(): Promise<void> {
  try {
    const selected = await promptForTarget();
    if (selected === undefined) {
      process.stdout.write("No ASDLC workspace target selected; nothing installed.\n");
      process.exitCode = 0;
      return;
    }

    const result = installProject(selected.resolvedTarget);
    reportInstallResult(result, selected.classification.kind);
    process.exitCode = 0;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`ERROR: ${message}\n`);
    process.exitCode = 2;
  }
}

function promptForTarget(): Promise<PromptSelection> {
  const readline = createInterface({ input: stdin, output: stdout });

  return new Promise((resolve) => {
    let settled = false;
    const finish = (value: PromptSelection): void => {
      if (settled) return;
      settled = true;
      readline.close();
      resolve(value);
    };
    const prompt = (): void => {
      readline.setPrompt("ASDLC workspace path: ");
      readline.prompt();
    };

    readline.on("line", (value) => {
      if (value.trim() === "") {
        finish(undefined);
        return;
      }

      let resolvedTarget;
      try {
        resolvedTarget = resolveInstallTarget(value);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        process.stderr.write(`ERROR: ${message}\n`);
        prompt();
        return;
      }

      const classification = classifyInstallTarget(resolvedTarget);
      if (classification.kind === "refuse-not-directory") {
        process.stderr.write(
          `ERROR: Refusing to install into non-directory target: ${resolvedTarget}\n`
        );
        prompt();
        return;
      }
      if (classification.kind === "refuse-not-empty") {
        process.stderr.write(
          `ERROR: Refusing to install into non-empty non-workspace directory: ${resolvedTarget}\n`
        );
        prompt();
        return;
      }
      finish({ resolvedTarget, classification });
    });
    readline.once("close", () => finish(undefined));
    prompt();
  });
}

function reportInstallResult(
  result: ReturnType<typeof installProject>,
  mode: "clean-install" | "update"
): void {
  const verb = mode === "update" ? "updated" : "bootstrapped";
  process.stdout.write(`Overmind workspace ${verb}: ${result.projectRoot}\n`);
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
}
