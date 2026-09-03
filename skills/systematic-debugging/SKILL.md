---
name: systematic-debugging
description: Use when a bug, test failure, build failure, integration failure, or other unexpected behavior needs diagnosis before a fix
---

# Systematic Debugging Compatibility Entry

Use the host-provided `superpowers:systematic-debugging` skill when it is listed in the host's available skills catalog. That skill is authoritative; do not install this plugin or another copy just to obtain systematic debugging. Report the exact available skill ID and source path as the connection for the user.

If the host skill is unavailable, follow the minimum fallback contract:

1. Read the complete error and reproduce the behavior.
2. Check recent changes, working examples, dependencies, and data flow.
3. State one root-cause hypothesis and test it with the smallest diagnostic change.
4. Write a failing regression test before production code.
5. Apply one minimal fix, then run the targeted and full regression suites.

Never guess-fix a symptom before root-cause investigation. Do not use this skill for ordinary requirement clarification; use `brainstorming`, `grill-me`, or their combination instead.
