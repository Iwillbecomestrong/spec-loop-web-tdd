---
name: gpt-repo
description: >-
  Use this skill to perform Plan (implementation planning) or Review (code review against specification) using ChatGPT Web connected to a GitHub repository. Requires explicitly providing repo, commit, and spec path.
---

# GPT Repo Planner & Reviewer Skill

使用 ChatGPT Web 针对指定 GitHub 仓库、指定 Commit 与 SPEC 进行独立的实现计划生成或代码审查。

本插件不复制 AgentChat 运行时和凭据。将 `AGENTCHAT_ROOT` 设置为 AgentChat 检出目录；当前工作区默认值为 `E:\\ai-toolkit\\skills\\AgentChat`。运行前需确认 Chrome CDP 已启动并且 ChatGPT Web 已登录。

## 运行前准备

确保本地 Chrome 调试实例已启动并登录 ChatGPT（ChatGPT 账号内具备 GitHub Connector 授权即可直接访问仓库，无需在 Chrome 中登录 GitHub 网页）：
```powershell
powershell -ExecutionPolicy Bypass -File E:\ai-toolkit\skills\AgentChat\scripts\start-chrome.ps1
```

## 执行方式

### 1. Plan 模式（为 SPEC 生成技术实现计划）
```powershell
node $env:AGENTCHAT_ROOT\wrappers\gpt-repo\cli.js plan `
  --repo <owner/repo> `
  --commit <target_commit_sha> `
  --spec <spec_file_path>
```

### 2. Review 模式（审查 Base 到 Target Commit 之间的代码变更是否满足 SPEC）
```powershell
node $env:AGENTCHAT_ROOT\wrappers\gpt-repo\cli.js review `
  --repo <owner/repo> `
  --base <base_commit_sha> `
  --commit <target_commit_sha> `
  --spec <spec_file_path>
```

### 3. JSON 配置文件驱动 (Agent API)
本地 AI 生成请求文件 `request.json`：
```json
{
  "mode": "plan",
  "repo": "owner/repo",
  "commit": "abc1234",
  "spec": "docs/SPEC.md",
  "effort": "high",
  "instruction": "为该 SPEC 生成实现计划"
}
```
然后调用：
```powershell
node $env:AGENTCHAT_ROOT\wrappers\gpt-repo\cli.js --request request.json
```

## 运行收据 (Receipt)
每次调用的执行收据、自证状态、完整响应保存在 `.gpt-web/runs/<timestamp>/` 目录下。
GPT 回复第一段必须包含自证头（`REPOSITORY_VERIFIED: YES` 等），未通过自证的任务将判定为 `failed`。
