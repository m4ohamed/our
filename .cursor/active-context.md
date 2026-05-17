> **BrainSync Context Pumper** 🧠
> Dynamically loaded for active file: `pubspec.yaml` (Domain: **Config/Infrastructure**)

### 📐 Config/Infrastructure Conventions & Fixes
- **[decision] decision in analysis_options.yaml**: - linter:
+ analyzer:
-   # The lint rules applied to this project can be customized in the
+   exclude:
-   # section below to disable rules from the `package:flutter_lints/flutter.yaml`
+     - "lib/generated/**"
-   # included above or to enable additional rules. A list of all available lints
+ 
-   # and their documentation is published at https://dart.dev/lints.
+ linter:
-   #
+   # The lint rules applied to this project can be customized in the
-   # Instead of disabling a lint rule for the entire project in the
+   # section below to disable rules from the `package:flutter_lints/flutter.yaml`
-   # section below, it can also be suppressed for a single line of code
+   # included above or to enable additional rules. A list of all available lints
-   # or a specific dart file by using the `// ignore: name_of_lint` and
+   # and their documentation is published at https://dart.dev/lints.
-   # `// ignore_for_file: name_of_lint` syntax on the line or in the file
+   #
-   # producing the lint.
+   # Instead of disabling a lint rule for the entire project in the
-   rules:
+   # section below, it can also be suppressed for a single line of code
-     # avoid_print: false  # Uncomment to disable the `avoid_print` rule
+   # or a specific dart file by using the `// ignore: name_of_lint` and
-     # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
+   # `// ignore_for_file: name_of_lint` syntax on the line or in the file
- 
+   # producing the lint.
- # Additional information about this file can be found at
+   rules:
- # https://dart.dev/guides/language/analysis-options
+     # avoid_print: false  # Uncomment to disable the `avoid_print` rule
- 
+     # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
+ 
+ # Additional information about this file can be found at
+ # https://dart.dev/guides/language/analysis-options
+ 
