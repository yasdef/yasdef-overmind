import eslintConfigPrettier from "eslint-config-prettier";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: ["**/dist/**", "**/node_modules/**"]
  },
  ...tseslint.configs.recommendedTypeChecked,
  {
    files: ["packages/*/{src,test}/**/*.ts"],
    languageOptions: {
      parserOptions: {
        project: ["./packages/*/tsconfig.json"],
        tsconfigRootDir: import.meta.dirname
      }
    },
    rules: {
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/require-await": "off"
    }
  },
  {
    files: ["packages/*/test/**/*.ts"],
    rules: {
      "@typescript-eslint/no-floating-promises": "off"
    }
  },
  eslintConfigPrettier
);
