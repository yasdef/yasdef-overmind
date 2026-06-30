export class SimpleYamlParseError extends Error {
  constructor(message: string, readonly lineNumber: number) {
    super(`Line ${lineNumber}: ${message}`);
    this.name = 'SimpleYamlParseError';
  }
}

interface ParsedLine {
  readonly indent: number;
  readonly text: string;
  readonly lineNumber: number;
}

interface ParseResult {
  readonly value: unknown;
  readonly index: number;
}

export function parseSimpleYaml(content: string): unknown {
  const lines = toParsedLines(content);

  if (lines.length === 0) {
    return null;
  }

  const result = parseBlock(lines, 0, lines[0].indent);

  if (result.index < lines.length) {
    throw new SimpleYamlParseError('Unexpected trailing content.', lines[result.index].lineNumber);
  }

  return result.value;
}

function toParsedLines(content: string): ParsedLine[] {
  return content
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .map((line, index) => {
      if (/\t/.test(line)) {
        throw new SimpleYamlParseError('Tabs are not supported for indentation.', index + 1);
      }

      const withoutComment = stripComment(line);
      const trimmedRight = withoutComment.trimEnd();

      if (trimmedRight.trim().length === 0) {
        return undefined;
      }

      return {
        indent: trimmedRight.length - trimmedRight.trimStart().length,
        text: trimmedRight.trimStart(),
        lineNumber: index + 1
      };
    })
    .filter((line): line is ParsedLine => line !== undefined);
}

function parseBlock(lines: readonly ParsedLine[], index: number, indent: number): ParseResult {
  if (index >= lines.length || lines[index].indent < indent) {
    return { value: null, index };
  }

  if (lines[index].indent > indent) {
    throw new SimpleYamlParseError('Unexpected indentation.', lines[index].lineNumber);
  }

  if (lines[index].text.startsWith('- ')) {
    return parseSequence(lines, index, indent);
  }

  return parseMapping(lines, index, indent);
}

function parseMapping(lines: readonly ParsedLine[], startIndex: number, indent: number): ParseResult {
  const result: Record<string, unknown> = {};
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];

    if (line.indent < indent) {
      break;
    }

    if (line.indent > indent) {
      throw new SimpleYamlParseError('Unexpected indentation in mapping.', line.lineNumber);
    }

    if (line.text.startsWith('- ')) {
      break;
    }

    const pair = splitKeyValue(line.text, line.lineNumber);

    if (pair.valueText.length === 0) {
      const nextIndex = index + 1;

      if (nextIndex < lines.length && lines[nextIndex].indent > indent) {
        const nested = parseBlock(lines, nextIndex, lines[nextIndex].indent);
        result[pair.key] = nested.value;
        index = nested.index;
      } else {
        result[pair.key] = null;
        index = nextIndex;
      }
    } else {
      result[pair.key] = parseScalar(pair.valueText, line.lineNumber);
      index += 1;
    }
  }

  return { value: result, index };
}

function parseSequence(lines: readonly ParsedLine[], startIndex: number, indent: number): ParseResult {
  const result: unknown[] = [];
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];

    if (line.indent < indent) {
      break;
    }

    if (line.indent > indent) {
      throw new SimpleYamlParseError('Unexpected indentation in sequence.', line.lineNumber);
    }

    if (!line.text.startsWith('- ')) {
      break;
    }

    const itemText = line.text.slice(2).trim();
    const nextIndex = index + 1;

    if (itemText.length === 0) {
      if (nextIndex < lines.length && lines[nextIndex].indent > indent) {
        const nested = parseBlock(lines, nextIndex, lines[nextIndex].indent);
        result.push(nested.value);
        index = nested.index;
      } else {
        result.push(null);
        index = nextIndex;
      }

      continue;
    }

    if (looksLikeKeyValue(itemText)) {
      const pair = splitKeyValue(itemText, line.lineNumber);
      const item: Record<string, unknown> = {};

      if (pair.valueText.length === 0) {
        if (nextIndex < lines.length && lines[nextIndex].indent > indent) {
          const nested = parseBlock(lines, nextIndex, lines[nextIndex].indent);
          item[pair.key] = nested.value;
          index = nested.index;
        } else {
          item[pair.key] = null;
          index = nextIndex;
        }
      } else {
        item[pair.key] = parseScalar(pair.valueText, line.lineNumber);
        index = nextIndex;
      }

      if (index < lines.length && lines[index].indent > indent) {
        const nestedMapping = parseMapping(lines, index, lines[index].indent);
        Object.assign(item, asRecord(nestedMapping.value, lines[index].lineNumber));
        index = nestedMapping.index;
      }

      result.push(item);
      continue;
    }

    if (nextIndex < lines.length && lines[nextIndex].indent > indent) {
      throw new SimpleYamlParseError('Nested content after a scalar sequence item is not supported.', lines[nextIndex].lineNumber);
    }

    result.push(parseScalar(itemText, line.lineNumber));
    index = nextIndex;
  }

  return { value: result, index };
}

function splitKeyValue(text: string, lineNumber: number): { key: string; valueText: string } {
  const colonIndex = findUnquotedColon(text);

  if (colonIndex <= 0) {
    throw new SimpleYamlParseError('Expected a key/value mapping.', lineNumber);
  }

  const key = text.slice(0, colonIndex).trim();

  if (!/^[A-Za-z0-9_.-]+$/.test(key)) {
    throw new SimpleYamlParseError(`Unsupported mapping key "${key}".`, lineNumber);
  }

  return {
    key,
    valueText: text.slice(colonIndex + 1).trim()
  };
}

function parseScalar(text: string, lineNumber: number): unknown {
  if (text.length === 0) {
    return null;
  }

  if ((text.startsWith('"') && text.endsWith('"')) || (text.startsWith("'") && text.endsWith("'"))) {
    return text.slice(1, -1);
  }

  if (text.startsWith('[') && text.endsWith(']')) {
    const inner = text.slice(1, -1).trim();

    if (inner.length === 0) {
      return [];
    }

    return splitInlineList(inner, lineNumber).map((item) => parseScalar(item, lineNumber));
  }

  switch (text) {
    case 'true':
      return true;
    case 'false':
      return false;
    case 'null':
    case '~':
      return null;
    default:
      break;
  }

  if (/^-?\d+(\.\d+)?$/.test(text)) {
    return Number(text);
  }

  return text;
}

function splitInlineList(text: string, lineNumber: number): string[] {
  const parts: string[] = [];
  let current = '';
  let quote: string | undefined;

  for (const character of text) {
    if ((character === '"' || character === "'") && quote === undefined) {
      quote = character;
    } else if (character === quote) {
      quote = undefined;
    }

    if (character === ',' && quote === undefined) {
      parts.push(current.trim());
      current = '';
    } else {
      current += character;
    }
  }

  if (quote !== undefined) {
    throw new SimpleYamlParseError('Unterminated quoted inline list item.', lineNumber);
  }

  parts.push(current.trim());

  return parts;
}

function stripComment(line: string): string {
  let quote: string | undefined;

  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];

    if ((character === '"' || character === "'") && quote === undefined) {
      quote = character;
      continue;
    }

    if (character === quote) {
      quote = undefined;
      continue;
    }

    if (character === '#' && quote === undefined) {
      return line.slice(0, index);
    }
  }

  return line;
}

function looksLikeKeyValue(text: string): boolean {
  const colonIndex = findUnquotedColon(text);

  return colonIndex > 0;
}

function findUnquotedColon(text: string): number {
  let quote: string | undefined;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];

    if ((character === '"' || character === "'") && quote === undefined) {
      quote = character;
      continue;
    }

    if (character === quote) {
      quote = undefined;
      continue;
    }

    if (character === ':' && quote === undefined) {
      return index;
    }
  }

  return -1;
}

function asRecord(value: unknown, lineNumber: number): Record<string, unknown> {
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  throw new SimpleYamlParseError('Expected nested mapping content.', lineNumber);
}
