---
name: grill-me
description: Use when a request is ambiguous, acceptance criteria are incomplete, or important scope and constraint decisions must be resolved one question at a time
---

# Grill-Me Clarification

If the host already provides a `grill-me` skill, use that existing skill and do not install this plugin or another copy for clarification. Report its exact skill ID and source path as the connection for the user. Otherwise use this built-in fallback.

Ask one material question at a time. Resolve, in order: user goal, observable behavior, non-goals, constraints, interfaces, failure behavior, acceptance tests, affected modules, repository mode, and open questions. Do not invent answers. Record confirmed answers in a clarification record and classify the work as Small, Standard, or Epic.

When the request is already clear, this skill is optional. When the user wants to explore alternatives first, compose the skills as `brainstorming -> grill-me`. Do not request a Web GPT plan or begin implementation until material questions are closed and a usable SPEC has user confirmation.
