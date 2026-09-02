# Spec Loop Web TDD

This plugin combines a SPEC-first Spec-Loop with ChatGPT Web planning and review, plus isolated subagent-driven TDD.

## Main behavior

The workflow refuses to request a Web GPT implementation plan until the user's requirements have been clarified and a usable SPEC exists. It then creates self-contained text handoffs, selects the correct repository mode, delegates small TDD tasks to fresh subagents, and sends the resulting snapshot or diff to Web GPT for convergence review.

## Repository modes

- GitHub remote and accessible commit: `gpt-repo` Plan/Review.
- Local Git: `gpt-web` with a generated text handoff containing the local diff.
- No Git: `gpt-web` with a generated text handoff containing bounded snapshots and relevant file contents.

## Runtime

The plugin packages workflow skills and handoff scripts, but not the AgentChat runtime or credentials. Configure `AGENTCHAT_ROOT` or pass `-AgentChatRoot` to the scripts. The current workspace default is `E:\ai-toolkit\skills\AgentChat`.

The Web GPT CLI currently sends text through stdin; arbitrary local text files are not uploaded as ChatGPT attachments.
