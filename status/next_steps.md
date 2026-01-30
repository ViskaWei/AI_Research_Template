# 📌 Next Steps

> **最后更新**: 2025-01-30

---

## 🔴 P0 - 必须完成

| # | 任务 | 状态 | 截止日期 | 备注 |
|---|------|------|---------|------|
| 1 | 配置 OPENROUTER_API_KEY | ⏳ | - | 见 `docs/ENVIRONMENT_SETUP.md` |

---

## 🟡 P1 - 应该完成

| # | 任务 | 状态 | 截止日期 | 备注 |
|---|------|------|---------|------|
| 1 | Aria/Zotero 集成 | ⏳ | - | 可选功能 |
| 2 | 测试 Theory Explorer 脚本 | ⏳ | - | 需要 API Key |

---

## 🟢 P2 - 可选完成

| # | 任务 | 状态 | 截止日期 | 备注 |
|---|------|------|---------|------|
| 1 | 在真实项目上测试完整工作流 | ⏳ | - | 使用 `rq [问题]` |

---

## ✅ 已完成

| # | 任务 | 完成日期 | 产出 |
|---|------|---------|------|
| 1 | 项目初始化 | 2025-01-08 | 基础目录结构 |
| 2 | Theory Explorer 脚本 | 2025-01-29 | `_backend/scripts/theory_explorer.py` |
| 3 | Paper Search 脚本 | 2025-01-29 | `_backend/scripts/search_papers.py` |
| 4 | Report Compile 脚本 | 2025-01-29 | `_backend/scripts/compile_report.sh` |
| 5 | LaTeX 模板 | 2025-01-29 | `_backend/template/report.tex`, `theory.tex` |
| 6 | .cursorrules 集成新命令 | 2025-01-30 | rq, loop, theory, search, latex, compile |
| 7 | 环境配置文档 | 2025-01-30 | `docs/ENVIRONMENT_SETUP.md` |
| 8 | reports/ 目录结构 | 2025-01-30 | `reports/README.md` |

---

## 📝 使用说明

### 添加任务
```
next add P0 [任务描述]
next add P1 [任务描述]
```

### 完成任务
```
next done 1       # 完成第 1 个任务
next done [描述]  # 按描述匹配完成
```

### 智能推荐
```
next plan         # AI 分析并推荐下一步
```
