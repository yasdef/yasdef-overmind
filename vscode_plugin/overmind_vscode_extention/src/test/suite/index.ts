import * as path from 'path';
import * as fs from 'fs/promises';
import Mocha from 'mocha';

export function run(): Promise<void> {
  const mocha = new Mocha({
    ui: 'tdd',
    color: true
  });

  const testsRoot = __dirname;

  return new Promise((resolve, reject) => {
    collectTestFiles(testsRoot)
      .then((files) => {
        for (const file of files) {
          mocha.addFile(file);
        }

        mocha.run((failures) => {
          if (failures > 0) {
            reject(new Error(`${failures} tests failed.`));
          } else {
            resolve();
          }
        });
      })
      .catch(reject);
  });
}

async function collectTestFiles(directory: string): Promise<string[]> {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(directory, entry.name);

      if (entry.isDirectory()) {
        return collectTestFiles(fullPath);
      }

      return entry.isFile() && entry.name.endsWith('.test.js') ? [fullPath] : [];
    })
  );

  return files.flat();
}
