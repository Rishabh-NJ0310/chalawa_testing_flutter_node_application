import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],       // entry point(s)
  outDir: "dist",                // output directory
  format: ["esm"],               // use ESM for Node 22
  target: "node22",              // optimize for Node 22 LTS
  sourcemap: true,               // generate .map files
  clean: true,                   // clear dist before build
  minify: false,                 // keep code readable
  dts: false,                    // set to true if you want .d.ts files (for libs)
  splitting: false,              // optional - disable code splitting
  skipNodeModulesBundle: true,   // don't bundle dependencies (faster startup)
  shims: false,                  // no global polyfills
  bundle: false                  // optional: false means just transpile, not bundle
});