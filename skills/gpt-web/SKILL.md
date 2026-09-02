---
name: gpt-web
description: >-
  Use this skill to query ChatGPT Web with verified reasoning effort (High, Medium, Extra High, Pro) via Chrome CDP automation. Use when you need ChatGPT Web's reasoning models for complex design questions, architecture analysis, or deep reasoning.
---

# GPT Web Skill

通过自动化控制已登录的 Chrome CDP 实例，调用 ChatGPT 网页端进行高强度推理分析。

本插件不复制 AgentChat 运行时。将 `AGENTCHAT_ROOT` 设置为 AgentChat 检出目录；当前工作区默认值为 `E:\\ai-toolkit\\skills\\AgentChat`。优先从插件根目录运行 `scripts/run-web-gpt.ps1`，它会把交接文档通过 stdin 发送并把 stdout 保存到指定文件。

## 运行前准备

确保本地 Chrome 调试实例已启动：
```powershell
powershell -ExecutionPolicy Bypass -File E:\ai-toolkit\skills\AgentChat\scripts\start-chrome.ps1
```

## 执行命令

### 1. 基础提问（默认 High 推理强度）
```powershell
node $env:AGENTCHAT_ROOT\wrappers\gpt-web\cli.js ask "你的分析或推理问题"
```

### 2. 指定推理强度
```powershell
# Medium 档位
node $env:AGENTCHAT_ROOT\wrappers\gpt-web\cli.js ask -e medium "你的问题"

# High 档位（默认）
node $env:AGENTCHAT_ROOT\wrappers\gpt-web\cli.js ask -e high "你的问题"

# Extra High 档位
node $env:AGENTCHAT_ROOT\wrappers\gpt-web\cli.js ask -e xhigh "你的问题"
```

### 3. 从管道或文件输入
```powershell
Get-Content prompt.txt | node $env:AGENTCHAT_ROOT\wrappers\gpt-web\cli.js ask
```

## 输出契约
- **stdout**：仅输出 ChatGPT 的最终回答文本。
- **stderr**：输出运行状态与调试日志。

Review 请求可附加 `-ValidateReviewContract`。该选项会在保存最终响应前校验四行 attestation、`## Findings`、合法 severity，以及 `NO_FINDINGS: YES` 无发现标记；校验失败时命令失败且不归档响应。
