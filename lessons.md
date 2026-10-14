# 📋 الدروس المستفادة (Lessons Learned)

This file is a self-optimizing loop. When an AI agent makes a mistake and you correct it, the agent documents the pattern here so it mathematically never repeats the mistake.

## 📋 Lessons
- **Ensure all variables are typed before pushing:** Always use explicit type annotations in Dart/Flutter (e.g., `TimelineEventEntity` instead of `dynamic`) to maintain strict type safety and avoid dynamic typing pitfalls.
- **MCP Tooling Priority:** Always prioritize using `dart-mcp-server` and `flutter-explorer-mcp` for project analysis, diagnostics, and structural queries before attempting shell commands.
- **Path Configuration:** When initializing `flutter-explorer-mcp`, always verify and set the correct project root path using `flutter_set_project_path` to ensure accurate indexing and avoid scanning incorrect directories.
- **Theming Best Practices:** Avoid hardcoding colors (e.g., `Colors.white`, `Colors.transparent`, `Color(0x...)`) inside widget trees. Always reference `Theme.of(context)` or centralized helpers in `AppTheme` to maintain seamless Light/Dark mode transitions.
- **Never Keep `const` When Injecting Dynamic Theme Calls:** When replacing static colors (`Colors.white`) with `Theme.of(context).colorScheme.*` or `.withValues(...)`, always remove `const` from the enclosing widget constructor (`SizedBox`, `Center`, `Icon`) to prevent `invalid_constant` compile-time errors.
- **Verify All Imports & Data Mappers:** Always ensure every imported file (`media_mapper.dart`, `demo_media_seed.dart`, `app_theme.dart`) exists in the project tree before finalizing changes.
