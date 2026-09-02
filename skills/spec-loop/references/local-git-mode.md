# Local Git / No-Git 降级模式

当项目仅在本地 Git 管理或无 Git 仓库时，自动降级为本模式。

## 一、方案规划 (Plan)
由本地 AI 提取 SPEC 文件内容与相关局部 README / 历史教训，组织自包含 Prompt 后通过 `gpt-web` 提交：

```powershell
Get-Content docs/work/plan-prompt.txt | node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-web\cli.js ask -e high
```

## 二、代码审查 (Review)
本地 AI 生成 `git diff <base_sha> <target_sha>` 并打包进 `docs/work/review-prompt.txt` 后调用 `gpt-web`：

```powershell
Get-Content docs/work/review-prompt.txt | node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-web\cli.js ask -e high
```
