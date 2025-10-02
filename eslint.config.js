import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    rules: {
      "no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
      "no-console": "off"
    },
    ignores: ["node_modules/**", "packages/**/node_modules/**", "dist/**"]
  }
];
