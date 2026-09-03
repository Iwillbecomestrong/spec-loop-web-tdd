---
name: brainstorming
description: Use when a new feature, design, or behavior change needs its intent and trade-offs clarified before implementation
---

# Brainstorming Compatibility Entry

Use the host-provided `superpowers:brainstorming` skill when it is listed in the host's available skills catalog. That skill is authoritative; do not install this plugin or another copy just to obtain brainstorming. Report the exact available skill ID and source path as the connection for the user.

If the host skill is unavailable, use this fallback:

1. Classify the request as spike, bounded, or architectural.
2. Inspect the current project truth before detailed questions.
3. Ask only questions that affect purpose, scope, constraints, interfaces, or acceptance.
4. For architectural work, present 2–3 approaches and trade-offs.
5. Present the short design or design sections and wait for explicit user approval before implementation.

Use this skill alone when the intent is the main uncertainty. Compose it with `grill-me` as `brainstorming -> grill-me` when exploring approaches still leaves requirements or acceptance criteria incomplete. Use `systematic-debugging` for failures and unexpected behavior instead.
