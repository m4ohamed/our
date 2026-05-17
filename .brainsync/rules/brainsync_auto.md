

# Project Memory — our
> 813 notes | Score threshold: >40

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

**Stack:** Dart · Flutter + Provider + Riverpod · DB: Hive

## 📝 NOTE: 1 uncommitted file(s) in working tree.\n\n## Important Warnings

- **⚠️ GOTCHA: Updated schema RefreshIndicator — leverages inheritance to reduce code duplic...** — -           eventsAsync.when(
+           RefreshIndicator(
-         
- **⚠️ GOTCHA: Updated schema CircularProgressIndicator — leverages inheritance to reduce co...** — -           child: CircularProgressIndicator(color: AppColors.dustyRos
- **⚠️ GOTCHA: Updated schema CircularProgressIndicator — leverages inheritance to reduce co...** — -               child: CircularProgressIndicator(color: Theme.of(conte
- **⚠️ GOTCHA: Optimized Text** — - import 'package:flutter_gen/gen_l10n/app_localizations.dart';
+ impo
- **⚠️ GOTCHA: Optimized Center — prevents null/undefined runtime crashes** — - import 'package:flutter_gen/gen_l10n/app_localizations.dart';
+ 
- 

- **⚠️ GOTCHA: Updated schema Center — prevents null/undefined runtime crashes** — -             error: (_, _) =>
+             error: (_, _) => Center(c

## Active: `.`

- **Replaced auth Love — confirmed 3x**
- **trade-off in pubspec.yaml — confirmed 3x**
- **what-changed in pubspec.yaml — confirmed 3x**
- **Replaced auth Media — confirmed 3x**
- **Replaced auth Media — confirmed 4x**

## Project Standards

- Replaced auth Love — confirmed 3x
- trade-off in pubspec.yaml — confirmed 3x
- what-changed in pubspec.yaml — confirmed 3x
- Replaced auth Media — confirmed 3x
- Replaced auth Media — confirmed 4x
- what-changed in pubspec.yaml — confirmed 4x
- trade-off in pubspec.yaml — confirmed 3x
- what-changed in pubspec.yaml — confirmed 26x

## Known Fixes

- ❌ import '../../core/errors/app_exception.dart'; → ✅ problem-fix in repositories.dart
- ❌ +       return Failure(StorageException('فشل تحميل الأحداث: $e')); → ✅ Fixed null crash in Success — prevents null/undefined runtime crashes
- ❌ -   - [ ] Resolve "const" expression errors in all screens → ✅ problem-fix in task.md.resolved

## Recent Decisions

- decision in analysis_options.yaml
- Optimized AsyncNotifierProvider — prevents null/undefined runtime crashes
- Optimized HomeScreen — prevents null/undefined runtime crashes
- decision in implementation_plan.md.resolved

## Learned Patterns

- When encountering this, fix by: problem-fix in task.md.resolved (seen 2x)
- Always: Replaced dependency timeline_event_entitydart — confirmed 8x (seen 2x)
- Always: Replaced dependency media_file_entitydart — confirmed 8x (seen 3x)
- Agent generates new migration for every change (squash related changes)
- Agent installs packages without checking if already installed

### 📚 Core Framework Rules: [better-auth/providers]
# Authentication Providers Reference

Provide a quick reference for Better Auth authentication providers:

1. If a provider name is provided (e.g., "google", "github", "email"), show detailed configuration for that provider
2. Otherwise, show an overview of all available providers organized by category:
   - OAuth providers (Google, GitHub, Discord, etc.)
   - Email/Password authentication
   - Magic link authentication
   - Passwordless authentication
   - Social providers
3. For each provider, display:
   - Configuration requirements (client ID, secret, etc.)
   - Setup instructions
   - Code example for integration
4. Use clear visual indicators for different provider types
5. Mention any special requirements or considerations
6. Provide link to full documentation: https://better-auth.com/docs

If the user is currently working on authentication code, offer to generate integration code for the selected provider.

- [Flutter/Dart] Use const constructors wherever possible (improves rebuild performance)
- [Flutter/Dart] Dispose controllers in StatefulWidget.dispose()

## Available Tools (ON-DEMAND only)
- `query(q)` — Deep search when stuck
- `find(query)` — Full-text lookup
> Context above IS your context. Do NOT call load() at startup.
