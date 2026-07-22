import { spawn } from "node:child_process";

export interface AgentRunSpec {
  command: string;
  model: string;
  args: string[];
  prompt: string;
  cwd: string;
}

export interface AgentRunResult {
  exitCode: number;
  /** Set when the agent could not be launched (e.g. command not found). */
  errorMessage?: string;
}

export interface AgentRunner {
  run(spec: AgentRunSpec): Promise<AgentRunResult>;
}

interface SpawnLike {
  (
    command: string,
    args: string[],
    options: { cwd: string; stdio: "inherit" }
  ): {
    once(event: "exit", listener: (code: number | null) => void): void;
    once(event: "error", listener: (error: Error) => void): void;
  };
}

export class CodexAgentRunner implements AgentRunner {
  constructor(private readonly spawnProcess: SpawnLike = spawn) {}

  async run(spec: AgentRunSpec): Promise<AgentRunResult> {
    return new Promise<AgentRunResult>((resolve) => {
      const child = this.spawnProcess(spec.command, ["-m", spec.model, ...spec.args, spec.prompt], {
        cwd: spec.cwd,
        stdio: "inherit"
      });
      // A launch failure (e.g. command not found) is a runtime failure, not a
      // programmer error: surface it as a typed non-zero result so the executor
      // turns it into a failed step rather than an unhandled rejection.
      child.once("error", (error) =>
        resolve({
          exitCode: 127,
          errorMessage: `Failed to launch '${spec.command}': ${error.message}`
        })
      );
      child.once("exit", (code) => resolve({ exitCode: code ?? 1 }));
    });
  }
}

export class StubAgentRunner implements AgentRunner {
  public readonly specs: AgentRunSpec[] = [];

  constructor(private readonly exitCode = 0) {}

  async run(spec: AgentRunSpec): Promise<AgentRunResult> {
    this.specs.push(spec);
    return { exitCode: this.exitCode };
  }
}
