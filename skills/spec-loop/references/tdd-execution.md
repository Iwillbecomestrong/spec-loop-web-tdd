# 本地 TDD 执行与 Local README Gate

## 一、Local README Gate（局部契约门禁）

在修改任何子目录代码前，本地 AI 必须无条件执行 Local README Gate：

```text
准备修改 src/foo/bar.py
        ↓
检查 src/foo/README.md（若不存在，往上级目录递归寻找最近的 README.md）
        ↓
阅读该模块的对外接口契约、边界红线、设计约束
        ↓
确保本次改动不违背局部契约
        ↓
开始编写测试与实现代码
```

> [!WARNING]
> 任何外部 Skill（包括 Superpowers、spec-loop 等）决定“怎么做”，但如何落地修改代码**必须受所在目录局部 README 约束**。

---

## 二、TDD 标准节奏

1. **RED（编写失败测试）**：
   - 针对 Plan 中拆分的最小单元或功能点，先编写单元测试 / 回归测试；
   - 运行测试并捕获明确的失败报错（确认测试确实有效拦截了缺失能力）。
2. **GREEN（最小改动实现）**：
   - 编写满足测试的最小生产代码；
   - 运行测试，确保目标测试变绿。
3. **REFACTOR & REGRESSION（重构与全量回归）**：
   - 优化代码结构与命名；
   - 运行全量测试套件（如 `npm test` 或 `pytest`），确保没有引发历史功能的回归退化。
