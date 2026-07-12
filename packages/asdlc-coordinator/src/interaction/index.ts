import readline from "node:readline/promises";

export interface ConfirmRequest {
  message: string;
  defaultValue?: boolean;
}

export interface SelectOption<T extends string = string> {
  value: T;
  label: string;
}

export interface SelectRequest<T extends string = string> {
  message: string;
  options: SelectOption<T>[];
}

export interface InputRequest {
  message: string;
}

export interface InteractionPort {
  confirm(request: ConfirmRequest): Promise<boolean>;
  select<T extends string>(request: SelectRequest<T>): Promise<T>;
  input(request: InputRequest): Promise<string>;
}

/**
 * Thrown by an `InteractionPort` when the operator input stream closes (EOF).
 * The orchestrator treats this as a clean stop, matching the shell's rc-2
 * "user input stream closed" behavior — distinct from invalid input, which is
 * re-prompted.
 */
export class InteractionClosedError extends Error {
  constructor(message = "Operator input stream closed.") {
    super(message);
    this.name = "InteractionClosedError";
  }
}

export interface TtyInteractionStreams {
  input: NodeJS.ReadableStream;
  output: NodeJS.WritableStream;
}

export function createTtyInteractionPort(
  streams: TtyInteractionStreams = { input: process.stdin, output: process.stderr }
): InteractionPort {
  return {
    async confirm(request) {
      const suffix =
        request.defaultValue === true
          ? "[Y/n]"
          : request.defaultValue === false
            ? "[y/N]"
            : "[y/n]";
      // Re-prompt on anything but y/yes/n/no (shell parity); EOF is a clean stop.
      return promptUntil(
        streams,
        `${request.message} ${suffix}`,
        (answer) =>
          /^(y|yes)$/i.test(answer)
            ? { value: true }
            : /^(n|no)$/i.test(answer)
              ? { value: false }
              : answer === "" && request.defaultValue !== undefined
                ? { value: request.defaultValue }
                : undefined,
        () => streams.output.write("Please answer yes or no.\n")
      );
    },
    async select<T extends string>(request: SelectRequest<T>): Promise<T> {
      request.options.forEach((option, index) => {
        streams.output.write(`${index + 1}. ${option.label}\n`);
      });
      return promptUntil<T>(
        streams,
        request.message,
        (answer) => {
          const byIndex = Number(answer);
          if (Number.isInteger(byIndex) && byIndex >= 1 && byIndex <= request.options.length) {
            const selected = request.options[byIndex - 1];
            if (selected) return { value: selected.value };
          }
          const byValue = request.options.find((option) => option.value === answer);
          return byValue ? { value: byValue.value } : undefined;
        },
        (answer) => streams.output.write(`Invalid selection: ${answer}\n`)
      );
    },
    async input(request) {
      return ask(streams, `${request.message} `);
    }
  };
}

/**
 * Prompt on a single readline, re-prompting on invalid input and surfacing EOF as
 * an `InteractionClosedError`. `interpret` returns `{ value }` for a valid answer
 * or `undefined` to re-prompt (so a falsy valid value like `false` is preserved).
 * A single readline is reused across re-prompts so buffered lines are not lost.
 */
async function promptUntil<T>(
  streams: TtyInteractionStreams,
  message: string,
  interpret: (answer: string) => { value: T } | undefined,
  onInvalid: (answer: string) => void
): Promise<T> {
  const rl = readline.createInterface({ input: streams.input, output: streams.output });
  let closed = false;
  rl.once("close", () => {
    closed = true;
  });
  try {
    for (;;) {
      let answer: string;
      try {
        answer = (await rl.question(`${message} `)).trim();
      } catch (error) {
        if (closed) throw new InteractionClosedError();
        throw error;
      }
      const result = interpret(answer);
      if (result) return result.value;
      onInvalid(answer);
    }
  } finally {
    rl.close();
  }
}

async function ask(streams: TtyInteractionStreams, prompt: string): Promise<string> {
  const rl = readline.createInterface({
    input: streams.input,
    output: streams.output
  });
  let closed = false;
  const onClose = (): void => {
    closed = true;
  };
  rl.once("close", onClose);
  try {
    return await rl.question(prompt);
  } catch (error) {
    // readline rejects the pending question when the input stream ends (EOF).
    if (closed) throw new InteractionClosedError();
    throw error;
  } finally {
    rl.close();
  }
}
