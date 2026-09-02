# 防死循环与升级机制 (Anti-Loop Escalation)

严禁让 AI 陷入 `Review ➔ Fix ➔ Review ➔ Fix` 的无止境重试黑洞。必须设定硬性升级阶梯：

```mermaid
flowchart TD
    R1["Round 1 Review 发现缺陷"] --> F1["执行常规缺陷修复 ➔ 重新提审"]
    F1 --> R2["Round 2 Review"]
    R2 -- "通过" --> PASS["通过审查 ➔ 进入交付"]
    R2 -- "仍存在同类缺陷" --> F2["强制执行根因分析 (Root Cause Analysis)\n重新核查架构假设 ➔ 修复提审"]
    F2 --> R3["Round 3 Review"]
    R3 -- "通过" --> PASS
    R3 -- "仍失败 (≥3次)" --> STOP["🚨 STOP 熔断退出\n禁止继续自动尝试\n向用户汇报阻塞点 ➔ 重新 Grill 需求或人工介入"]
```

---

## 熔断升级规则

1. **第 1 次 Review 失败**：
   - 本地 AI 根据 GPT Review 报告中的明确代码/单测缺陷进行点对点修复并补充回归测试。
2. **第 2 次 Review 失败**：
   - 严禁盲目小修小补；
   - 必须停下来进行**根本原因分析（RCA）**，检查是否是对 SPEC 理解偏差或使用了错误的底层依赖。
3. **第 3 次仍未通过（连续 3 次失败）**：
   - **立即触发 STOP 熔断**；
   - 冻结当前分支，记录已尝试路径及失败日志至 `docs/work/escalation.md`；
   - 告知用户：“当前实现多次未能通过审查，底层设计可能存在根本冲突，建议重新执行 `/grill-me` 重新审视需求或人工指导”。
