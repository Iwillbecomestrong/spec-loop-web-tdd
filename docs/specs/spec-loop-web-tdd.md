# SPEC: Spec Loop Web TDD Plugin

## Goal

Package a reusable Codex plugin that runs a SPEC-first development workflow with requirement clarification, ChatGPT Web planning and review, and subagent-driven TDD.

## Required workflow

1. Read the user's request and the available project truth: AGENT_CORE, AGENTS.md, README files, existing SPEC/PLAN/HISTORY, and relevant source files.
2. Clarify material ambiguity before planning. If a separate Grill-Me skill is unavailable, use the built-in clarification contract documented by this plugin.
3. Reuse a suitable existing SPEC, or create one before requesting a Web GPT plan. Small changes may use `docs/work/task-<slug>.md`; standard features use `docs/specs/<feature>.md`; major changes use an architecture-level SPEC.
4. Do not request a Web GPT plan until the SPEC is usable and the user has confirmed a new or materially changed SPEC.
5. Create a self-contained plan handoff containing the confirmed request, SPEC, relevant code, local README contracts, HISTORY constraints, repository mode, and output location.
6. Send the handoff to ChatGPT Web or use the GitHub repository planner according to repository mode. Preserve the raw response under `docs/work/plan-raw.md` and locally integrate it into the final plan.
7. Execute the approved plan through small, serial subagent tasks. Each task must complete RED, GREEN, REFACTOR, targeted regression, full regression, report, and commit. The implementation worker must not spawn another worker or reviewer.
8. Create a review handoff containing the exact snapshot or diff and send it to ChatGPT Web or the GitHub repository reviewer. Preserve the raw response under `docs/work/review-<target>.md`.
9. Fix real review findings with regression tests and re-review. After three consecutive review failures, stop and escalate for root-cause analysis.
10. Before completion, verify tests, synchronize validated conclusions to SPEC/PLAN/local README/HISTORY, and keep transient handoffs in `docs/work/`.

## Repository modes

- GitHub remote with an accessible committed snapshot and GitHub Connector: use `gpt-repo` Plan/Review with explicit repository, base, target, and SPEC.
- Local Git without a usable GitHub snapshot: generate a self-contained text handoff containing the local diff and use `gpt-web`.
- No Git: generate a self-contained text handoff containing bounded before/after snapshots and relevant file contents and use `gpt-web`.

## Runtime boundary

The plugin must not vendor AgentChat credentials, `.env` files, or `node_modules`. It may call an existing AgentChat runtime through `AGENTCHAT_ROOT` or an explicit script parameter. The current workspace fallback is `E:\ai-toolkit\skills\AgentChat`.

The current `gpt-web` CLI sends text through stdin; arbitrary local Markdown, text, or PDF files are not attached to ChatGPT as native file uploads.

## Acceptance criteria

- The plugin manifest validates.
- The main skill enforces `SPEC_READY -> WEB_PLAN_ALLOWED`.
- Plan and review handoff scripts include explicit output contracts and repository mode information.
- Review handoff generation enumerates the complete changed-file list, rejects incomplete `DiffPaths` unless `-AllowPartialDiff` is explicit, and labels/list omissions in an allowed scoped handoff.
- Review handoff generation fails when neither Git commit evidence nor before/after snapshots are supplied.
- No-Git review handoffs require paired before/after snapshots, embed bounded text contents, and mark added, deleted, binary, and size-limited files explicitly.
- Review handoffs require a machine-checkable attestation header and stable findings/no-findings output contract.
- The `gpt-web` runner can validate that contract before archiving a review response.
- The validator checks every finding block independently, and contract-check temporary files use unique names.
- The validator rejects `NO_FINDINGS: YES` when any finding is also present, including reverse-order cases.
- Missing SPEC blocks plan handoff generation.
- The Web GPT runner saves stdout separately from stderr.
- Regression tests cover complete, rejected partial, explicitly allowed partial, and evidence-free review handoffs.
- The package contains the Spec-Loop, GPT Repo, GPT Web, subagent TDD, and test-driven development skills.
- No credentials or runtime dependency directories are included.
