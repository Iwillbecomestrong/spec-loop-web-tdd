# Web GPT 收敛审查 (Web Review & Convergence)

## 一、审查维度：审查“全面收敛”

Web Review 不仅仅是检查代码语法或风格，核心是检查**代码与文档状态是否全面重新收敛**：

1. **SPEC Compliance**：是否 100% 满足 SPEC 中的每项功能点与边界条件？
2. **PLAN Consistency**：实际实现是否与批准的 PLAN 结构保持一致？
3. **Local README Compliance**：是否遵守了修改模块所在目录的局部契约？
4. **Regressions & Edge Cases**：是否破坏了已有功能，是否遗漏极端异常分支？
5. **Tests Adequacy**：测试覆盖率是否完备，是否有漏网的边界？
6. **Documentation Sync**：代码修改后，相关注释、局部 README、使用文档是否已同步？
7. **History-Worthy Findings**：排查过程中发现的坑和教训是否需要沉淀至 `HISTORY.md`？

---

## 二、自证协议校验

`gpt-repo review` 会强制校验 GPT 输出的自证头：
- `REPOSITORY_VERIFIED: YES`
- `BASE_COMMIT_VERIFIED: YES`
- `TARGET_COMMIT_VERIFIED: YES`
- `SPEC_VERIFIED: YES`

若未通过自证，自动判定为 Review 失败，并记录在 `.gpt-web/runs/<timestamp>/receipt.json`。

---

## 三、审查输出分流

```text
Web Review 原始输出
        ↓
存入 docs/work/review-<commit>.md
        ↓
若有 BLOCKER / CRITICAL 缺陷 ➔ 进入本地修复环节 (受防死循环控制)
        ↓
若全部通过 ➔ 提取有价值结论 ➔ 准备进入 Knowledge Sync
```
