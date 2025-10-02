import tseslint from "@typescript-eslint/eslint-plugin";
import parser from "@typescript-eslint/parser";

export default [
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parser,
      parserOptions: {
        project: "./tsconfig.json",
        tsconfigRootDir: new URL(".", import.meta.url),
        sourceType: "module",
        ecmaVersion: "latest"
      }
    },
    plugins: { "@typescript-eslint": tseslint },
    rules: {
      "no-unused-vars": ["error", { "argsIgnorePattern": "^_" }]
    }
  },
  {
    files: ["src/**/*.js"],
    rules: {
      "no-unused-vars": "off"
    }
  }
];
