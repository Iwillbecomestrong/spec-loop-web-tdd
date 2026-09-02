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

## 四、Diff 范围门禁

`scripts/prepare-review-handoff.ps1` 默认审查 `BASE_COMMIT..TARGET_COMMIT` 的完整 diff，并在 handoff 中列出全部变更文件。使用 `-DiffPaths` 时，脚本会将路径过滤结果与完整变更清单比较：

- 若过滤路径遗漏任何变更文件，默认直接失败；
- 只有显式传入 `-AllowPartialDiff` 才允许生成部分 handoff；
- 部分 handoff 必须标记 `REVIEW_SCOPE: SCOPED`，列出 `OMITTED_CHANGED_FILES`，并声明这些文件未被审查；
- 没有 Git diff 且没有 before/after snapshot 时，handoff 生成直接失败。

因此，过滤 diff 只是传输限制下的显式降级协议，不得被当作完整代码审查结果。

## 五、Review 输出协议

Review handoff 要求 Web GPT 的响应以四行 attestation 开始：

```text
REPOSITORY_VERIFIED: YES/NO
BASE_COMMIT_VERIFIED: YES/NO
TARGET_COMMIT_VERIFIED: YES/NO
SPEC_VERIFIED: YES/NO
```

随后必须有 `## Findings`。每个发现使用 `Severity`、`File`、`Location`、`Evidence`、`Reason`、`Recommended Fix` 字段；没有发现时使用固定标记 `NO_FINDINGS: YES`。这样原始响应才能被后续归档和自动收敛流程可靠判断。
