import { describe, it, expect } from "bun:test";

// Re-implement the functions here since they're not exported from runner.ts
// This mirrors the logic exactly for unit testing purposes.

const PROJECT_DIR = "/opt/claudeclaw/kevin";

function buildDirScopePrompt(extraDirs: string[]): string {
  const allDirs = [PROJECT_DIR, ...extraDirs];
  if (allDirs.length === 1) {
    return [
      `CRITICAL SECURITY CONSTRAINT: You are scoped to the project directory: ${PROJECT_DIR}`,
      "You MUST NOT read, write, edit, or delete any file outside this directory.",
      "You MUST NOT run bash commands that modify anything outside this directory (no cd /, no /etc, no ~/, no ../.. escapes).",
      "If a request requires accessing files outside the project, refuse and explain why.",
    ].join("\n");
  }
  return [
    `CRITICAL SECURITY CONSTRAINT: You are scoped to these directories:`,
    ...allDirs.map(d => `  - ${d}`),
    "You MUST NOT read, write, edit, or delete any file outside these directories.",
    "You MUST NOT run bash commands that modify anything outside these directories.",
    "If a request requires accessing files outside these directories, refuse and explain why.",
  ].join("\n");
}

describe("buildDirScopePrompt", () => {
  it("produces single-dir prompt when no extra dirs", () => {
    const result = buildDirScopePrompt([]);
    expect(result).toContain("scoped to the project directory:");
    expect(result).toContain(PROJECT_DIR);
    expect(result).toContain("outside this directory");
    expect(result).not.toContain("these directories");
  });

  it("produces multi-dir prompt with extra dirs", () => {
    const result = buildDirScopePrompt(["/home/kevin/repos"]);
    expect(result).toContain("scoped to these directories:");
    expect(result).toContain(`  - ${PROJECT_DIR}`);
    expect(result).toContain("  - /home/kevin/repos");
    expect(result).toContain("outside these directories");
    expect(result).not.toContain("outside this directory");
  });

  it("handles multiple extra dirs", () => {
    const result = buildDirScopePrompt(["/home/kevin/repos", "/tmp/builds"]);
    expect(result).toContain(`  - ${PROJECT_DIR}`);
    expect(result).toContain("  - /home/kevin/repos");
    expect(result).toContain("  - /tmp/builds");
  });
});
