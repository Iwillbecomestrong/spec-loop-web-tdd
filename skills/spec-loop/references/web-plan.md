# Web GPT 方案规划 (Web Plan & Negative Constraints)

## 一、方案规划的核心准则

1. **外部输出非真相**：
   网页版 GPT 返回的 Plan **只是外部分析建议**，绝不能直接盲目覆盖本地 `PLAN.md`。
2. **中间态落盘**：
   GPT 原始返回内容一律先保存至 `docs/work/plan-raw.md`。
3. **本地二次集成**：
   本地 AI 必须对照当前的 `HISTORY.md`、局部 `README.md` 和现有代码进行合理性审查，剔除不可行建议后，才提升写入 `docs/plans/<feature>.md` 或更新全局 `PLAN.md`。

---

## 二、必须注入的 Prompt 要素

向 GPT 请求 Plan 时，Prompt 必须结构化注入以下上下文：

1. **目标任务与 SPEC 内容**；
2. **相关代码上下文与受影响的局部 README**；
3. **关键历史失败教训 (Negative Constraints)**：
   必须从 `HISTORY.md` 中提取已验证失败的方案、死胡同或被明确否定的技术路线，并加上强制声明：
   ```text
   MANDATORY CONSTRAINT ON REJECTED APPROACHES:
   The following approaches have already been attempted and REJECTED in previous iterations:
   {rejected_approaches_from_history}

   Do NOT re-propose any approach listed above unless you provide definitive new technical evidence that invalidates the previous failure reason.
   ```

---

## 三、调用命令

### GitHub Remote 模式
```powershell
node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-repo\cli.js plan `
  --repo <owner/repo> `
  --commit <target_sha> `
  --spec docs/specs/<feature>.md `
  --instruction "根据 SPEC 生成技术实现计划，注意遵守局部 README 约定并避开 HISTORY 中已失败方案"
```

### 本地降级模式
```powershell
Get-Content docs/work/plan-prompt.txt | node E:\ai-toolkit\skills\AgentChat\wrappers\gpt-web\cli.js ask -e high
```
