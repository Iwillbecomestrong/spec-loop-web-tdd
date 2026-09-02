# GitHub Remote 模式

当项目已关联 GitHub 远程仓库，且已配置 GitHub Connector 时采用本模式。

## 一、优势
- **精准极速**：通过 GitHub 绝对 URL 定位文件，毫秒级读取；
- **真实 Diff 审查**：ChatGPT 能够直接对比 `Base Commit` 与 `Target Commit` 之间的精确代码差异；
- **自证协议保障**：强制核验 `REPOSITORY_VERIFIED: YES` 与 `BASE_COMMIT_VERIFIED: YES`。

## 二、标准调用命令

### 1. 方案规划 (Plan)
```powershell
node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-repo\cli.js plan `
  --repo <owner/repo> `
  --commit <target_sha> `
  --spec docs/specs/<feature>.md
```

### 2. 代码审查 (Review)
```powershell
node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-repo\cli.js review `
  --repo <owner/repo> `
  --base <base_sha> `
  --commit <target_sha> `
  --spec docs/specs/<feature>.md
```
