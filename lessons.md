# 📋 الدروس المستفادة (Lessons Learned)

This file is a self-optimizing loop. When an AI agent makes a mistake and you correct it, the agent documents the pattern here so it mathematically never repeats the mistake.

## 📋 Lessons
- **Ensure all variables are typed before pushing:** Always use explicit type annotations in Dart/Flutter to maintain strict type safety and avoid dynamic typing pitfalls.
- **MCP Tooling Priority:** Always prioritize using `dart-mcp-server` and `flutter-explorer-mcp` for project analysis, diagnostics, and structural queries before attempting shell commands.
- **Path Configuration:** When initializing `flutter-explorer-mcp`, always verify and set the correct project root path using `flutter_set_project_path` to ensure accurate indexing and avoid scanning incorrect directories.
- **Theming Best Practices:** Avoid hardcoding colors (e.g., `Colors.white`, `Colors.transparent`) inside widget trees. Always reference `Theme.of(context)` or centralized constants in `AppTheme` to maintain seamless Light/Dark mode transitions.
