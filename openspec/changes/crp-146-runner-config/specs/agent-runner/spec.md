## ADDED Requirements

### Requirement: AgentRunner port abstracts model-session launch

The system SHALL define an `AgentRunner` port in `runner/` that abstracts launching one model session: `run(spec) → { exitCode }`, where `spec` carries the command, model, extra args, prompt, and working directory (runtime root). The port SHALL be the single seam through which the executor launches sessions, so a second runner (e.g. a Claude adapter, or the extension's terminal-hosted runner) becomes an additional adapter with no change to callers (`02_responsibility_translation_map.md` row 8; `03_target_architecture.md ## Runner`). Adding runtime dependencies SHALL NOT be required — process launch uses the Node standard library, keeping `asdlc-coordinator`'s runtime `dependencies` empty.

#### Scenario: Executor launches sessions only through the port

- **WHEN** the executor runs a session action
- **THEN** it invokes the injected `AgentRunner.run(spec)` and consumes its `{ exitCode }` result, with no direct process-spawn call in the executor

#### Scenario: Stub adapter drives tests without spawning a process

- **WHEN** a test injects a stub `AgentRunner` that records the received spec and returns a chosen exit code
- **THEN** executor and guard tests run to completion without spawning a real agent process

### Requirement: CodexAgentRunner adapter preserves the shell launch contract

The system SHALL provide a `CodexAgentRunner` adapter that spawns `codex -m <model> <args...> <prompt>` from the runtime root with **inherited stdio**, returning the child's exit code (`02_responsibility_translation_map.md` row 8). Inherited stdio SHALL make interactive sessions the default; the shell's fd-forwarding dance SHALL have no TS equivalent. The constructed argument vector and working directory SHALL match the shell's `cmd=(codex -m <model> <args...> <prompt>)` invoked under `cd <runtime_root>`.

#### Scenario: Codex argv and cwd match the shell invocation

- **WHEN** the adapter runs a spec with model `gpt-5.4`, args `["--config", "model_reasoning_effort='high'"]`, a prompt string, and the runtime root as cwd
- **THEN** it spawns `codex -m gpt-5.4 --config model_reasoning_effort='high' <prompt>` with the working directory set to the runtime root and stdio inherited

#### Scenario: Child exit code is returned

- **WHEN** the spawned agent process exits with a non-zero code
- **THEN** the adapter returns that exit code as `{ exitCode }` without throwing
