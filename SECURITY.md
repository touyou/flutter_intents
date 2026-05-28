# Security Policy

## Supported versions

Flutter Intents follows semantic versioning. Until a `1.0.0` release, only the **latest minor
version** receives security fixes — please upgrade to the most recent release before reporting,
when possible.

| Package                    | Supported               |
| -------------------------- | ----------------------- |
| `app_intents`              | Latest `0.x` minor only |
| `app_intents_annotations`  | Latest `0.x` minor only |
| `app_intents_codegen`      | Latest `0.x` minor only |

## Reporting a vulnerability

**Please do not file public GitHub issues for security problems.**

Use GitHub's private vulnerability reporting flow instead:

  https://github.com/touyou/flutter_intents/security/advisories/new

Include as much of the following as you can:

- The affected package(s) and version(s)
- A description of the issue and the impact (e.g. data exposure, code execution, privilege boundary)
- A minimal reproduction (sample code, generated Swift/Kotlin output, intent definition, etc.)
- Whether the issue is already public and any references (CVE, blog posts, advisories)
- Your suggested fix, if you have one

## What to expect

Flutter Intents is currently maintained by volunteers in their spare time, so
these are best-effort response targets rather than guarantees:

- **Acknowledgement:** within ~14 days of your report.
- **Initial assessment:** within ~30 days, including a tentative severity and a plan.
- **Fix & disclosure:** coordinated through the same GitHub Security Advisory. We will
  publish a CVE-numbered advisory and a patched release together, and credit the reporter
  unless they prefer to remain anonymous.

If you do not hear back within these windows, please feel free to nudge the
advisory thread — it likely means the notification was missed, not ignored.

## Scope

In-scope:

- The published Dart/Flutter packages (`app_intents`, `app_intents_annotations`, `app_intents_codegen`)
- Generated Swift / Kotlin code produced by `app_intents_codegen`
- The iOS Swift Package `AppIntentsBridge`
- The plugin's native iOS / Android sources

Out of scope (please report upstream instead):

- Vulnerabilities in Flutter, Dart, iOS App Intents, Android AppFunctions, or other upstream platforms
- Issues that require an attacker to already control the user's device or developer machine
- Issues in third-party dependencies that are not exploitable through this project's APIs
