# Antigravity compatibility

This package supports both Codex and Google Antigravity:

- `.codex-plugin/plugin.json` is the Codex manifest.
- `plugin.json` at the package root is the Antigravity manifest.
- The shared `skills/` directory contains the workflow skills for either host.

## Install as an Antigravity plugin

From a local checkout, use the Antigravity CLI:

```powershell
agy plugin install E:\ai-toolkit\plugins\spec-loop-web-tdd
```

Alternatively, place the plugin directory under the opened workspace's `.agents/plugins/` directory. A global installation can use Antigravity's global plugin directory.

## Skill-only installation

If the host does not expose plugin installation, copy the contents of `skills/` into:

```text
<workspace>/.agents/skills/
```

or the Antigravity global skills directory. Keep the plugin `scripts/` directory available in the same checkout when the workflow needs handoff generation or output validation.

## Runtime prerequisites

The Web GPT stages are host-independent instructions, but their execution still requires the existing AgentChat runtime, Node.js, PowerShell 7, a logged-in Chrome CDP session, and the GitHub Connector for `gpt-repo`. Configure `AGENTCHAT_ROOT` when the default `E:\ai-toolkit\skills\AgentChat` path is not used. Installing this plugin into Antigravity does not provide ChatGPT access or credentials.

The workflow is framework-agnostic: each project supplies its own build and test commands through its repository truth and local README rules.
