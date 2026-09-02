# 自适应粒度规则 (Adaptive Granularity)

`spec-loop` 绝不强制每一次微小改动都创建一套繁琐的 `SPEC-xxx.md` 和 `PLAN-xxx.md`。必须根据任务影响面自动判定并适配粒度：

---

## 粒度判定三级梯队

### 1. 轻量任务 (Small / Minor Fix)
* **典型场景**：修复导出文件名拼写、调整单个报错文案、补齐已有函数的单测用例、简单局部重构。
* **文档动作**：
  - **不生成独立的 SPEC / PLAN 文件**。
  - 直接在现有 `SPEC.md` / `PLAN.md` 或当前临时文件 `docs/work/task.md` 中记录简要上下文。
  - 快速完成 TDD 实现并执行本地回归测试。

### 2. 独立功能 (Standard / Feature)
* **典型场景**：新增一个 API 端点、添加一个新的 Provider 适配器、实现某个独立的工具类。
* **文档动作**：
  - 在 `docs/work/` 中起草需求与方案；
  - 确认后归档至 `docs/specs/<feature>.md` 与 `docs/plans/<feature>.md`；
  - 走标准 Web GPT Plan + Local TDD + Web Review 流程。

### 3. 大型重构 / 跨模块架构 (Epic / Major)
* **典型场景**：重构核心调用链路、多 Provider 状态机改造、涉及底层数据存储模型变更。
* **文档动作**：
  - 启动完整 Grill-Me 需求访谈；
  - 生成正式全局 `SPEC.md` 章节或独立架构 SPEC；
  - 组织多次里程碑式的 Plan 与阶段性 Review。
