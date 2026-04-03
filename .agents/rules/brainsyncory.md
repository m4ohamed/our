

# Project Memory — our_love_story
> 208 notes | Score threshold: >40

## Safety — Never Run Destructive Commands

> Dangerous commands are actively monitored.
> Critical/high risk commands trigger error notifications in real-time.

- **NEVER** run `rm -rf`, `del /s`, `rmdir`, `format`, or any command that deletes files/directories without EXPLICIT user approval.
- **NEVER** run `DROP TABLE`, `DELETE FROM`, `TRUNCATE`, or any destructive database operation.
- **NEVER** run `git push --force`, `git reset --hard`, or any command that rewrites history.
- **NEVER** run `npm publish`, `docker rm`, `terraform destroy`, or any irreversible deployment/infrastructure command.
- **NEVER** pipe remote scripts to shell (`curl | bash`, `wget | sh`).
- **ALWAYS** ask the user before running commands that modify system state, install packages, or make network requests.
- When in doubt, **show the command first** and wait for approval.

**Stack:** Dart · Flutter

## 📝 NOTE: 1 uncommitted file(s) in working tree.\n\n## Important Warnings

- **gotcha in countdown_screen.dart** — -       print('خطأ في تشغيل الموسيقى: $e');
+       debugPrint('خطأ في
- **gotcha in surprise_screen.dart** — -       print('خطأ في تشغيل الموسيقى: $e');
+       debugPrint('خطأ في

## Active: `.`

- **trade-off in pubspec.yaml — confirmed 3x**
- **what-changed in pubspec.yaml — confirmed 26x**
- **🟢 Edited pubspec.yaml (26 changes, 1min) — confirmed 3x**
- **Optimized pubspec — confirmed 4x**
- **convention in pubspec.yaml**

## Project Standards

- trade-off in pubspec.yaml — confirmed 3x
- what-changed in pubspec.yaml — confirmed 26x
- 🟢 Edited pubspec.yaml (26 changes, 1min) — confirmed 3x
- Optimized pubspec — confirmed 4x
- convention in pubspec.yaml
- convention in pubspec.yaml
- convention in pubspec.yaml
- what-changed in memories_album_screen.dart — confirmed 3x

## Learned Patterns

- When encountering this, fix by: problem-fix in task.md.resolved (seen 2x)
- Avoid: Dispose controllers in StatefulWidget.dispose() (seen 2x)
- Always: Use const constructors wherever possible — improves rebuild performance (seen 2x)
- Agent generates new migration for every change (squash related changes)
- Agent installs packages without checking if already installed
- [Flutter/Dart] Use const constructors wherever possible (improves rebuild performance)
- [Flutter/Dart] Dispose controllers in StatefulWidget.dispose()

## Available Tools (ON-DEMAND only)
- `query(q)` — Deep search when stuck
- `find(query)` — Full-text lookup
> Context above IS your context. Do NOT call load() at startup.
