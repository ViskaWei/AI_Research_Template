---
marp: true
theme: default
paginate: true
style: |
  section {
    background: #ffffff;
    color: #333333;
    font-family: 'Noto Sans CJK SC', 'PingFang SC', -apple-system, sans-serif;
    font-size: 20px;
    padding: 30px 50px;
  }
  h1, h2 {
    color: #1a365d;
    font-size: 28px;
    margin-bottom: 16px;
  }
  strong {
    color: #d69e2e;
  }
  code {
    background: #f7fafc;
    color: #1a365d;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 14px;
  }
  pre {
    background: #f7fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    font-size: 12px;
    padding: 10px;
    overflow: hidden;
  }
  table {
    font-size: 16px;
  }
  th {
    background: #1a365d;
    color: white;
    padding: 6px 10px;
  }
  td {
    background: #f7fafc;
    padding: 4px 10px;
  }
  blockquote {
    border-left: 4px solid #1a365d;
    color: #666666;
  }
  ul, ol {
    font-size: 18px;
    margin: 8px 0;
  }
  li {
    margin: 4px 0;
  }
  details {
    display: none;
  }
math: mathjax
---

# AI Research Template — 可复现的科研操作系统

> **Topic**: 系统介绍  \
> **Author**: Viska Wei  \
> **Date**: 2026-01-26  \
> **Language**: 中文

<details>
<summary><b>note</b></summary>

大家好，今天介绍一个我在做探索性科研时沉淀下来的操作系统。

</details>

---

## 痛点与解法：在不确定中稳定产出

- **痛点**：探索性研究容易散落——实验跑了很多，但结论不可追溯、决策无依据、知识无法复用
- **解法**：$\text{Hub 假设树} \xrightarrow{\text{MVP + Gate}} \text{可交付结论 + 设计原则}$
- **核心价值**：让任何人都能追溯"为什么走这条路"，在不确定任务中稳定迭代到结果

| 组件 | 符号 | 职责 | 产出 |
|------|------|------|------|
| Hub | $\mathcal{H}$ | 问题拆解 → 假设树 | 共识表、设计原则 |
| Roadmap | $\mathcal{R}$ | 假设 → MVP + 验收阈值 | 实验进度、数值结果 |
| Exp | $\mathcal{E}$ | 单实验标准化报告 | 关键数字、图表 |
| Gate | $\mathcal{G}$ | 量化决策 | Go/No-Go 决策 |

<details>
<summary><b>note</b></summary>

核心痛点是什么呢？做研究的时候实验跑了很多，但经常出现：结论散落在各处、决策缺乏依据、下次再做类似问题又得重来一遍。

我的解法是一套闭环系统：先用 Hub 的假设树把大问题拆成可证伪的小假设，再用 Roadmap 把每个假设变成一个最小可行实验 MVP，提前写好验收阈值和止损规则。

</details>

---

## 信息流闭环架构

<!-- gemini -->

科研操作系统信息流闭环架构图

【STEP 1: Idea 脑暴】
• GPT/Claude 对话探索 → 初步假设列表
• 文件: sessions/session_*.md

【STEP 2: Hub 假设树】
• 大问题 → 假设树 (Q1→Q1.1,Q1.2) + 状态标记
• 战略层: "我们知道了什么？往哪走？"

【STEP 3: Roadmap MVP】
• 每个假设 → MVP + 验收阈值 + 止损规则
• 执行层: "计划跑哪些实验？进度如何？"

【STEP 4: Exp 实验报告】
• 标准化报告: 目标/设计/数字/图表/结论
• 原则: 前 300 行能快速了解最重要信息

【STEP 5: Gate 量化决策】
• Gate-1: 理论上限 | Gate-2: Scaling | Gate-3: 结构
• 输出: 加数据？加模型？换方向？→ Go/No-Go

【STEP 6: 知识沉淀】
• 关键数字→Hub | 原则→principles.md | 失败→已关闭方向
• 任何人都能追溯"为什么走这条路"

→ 循环: 下一轮迭代

<!-- /gemini -->

<details>
<summary><b>note</b></summary>

这张图展示了整个系统的信息流闭环。从 Idea 脑暴开始，通过 Hub 假设树进行问题拆解，然后用 Roadmap 定义 MVP，跑实验产出标准化报告，经过 Gate 决策，最后沉淀成可复用的知识。整个流程是循环迭代的。

</details>

---

## 三层架构设计

- **分层解耦**：战略思考与执行追踪分离

| Layer | 名称 | 职责 | 文件 |
|-------|------|------|------|
| L0 | Master Hub | 全局战略导航 | `hub.md` |
| L1 | Topic Hubs | 研究主题 | `[topic]/hub.md` |
| L2 | Experiments | 单实验报告 | `exp_*.md` |
| L3 | Artifacts | 知识沉淀 | `card/*.md`, `principles.md` |

- **MVP 设计三要素**：

| 要素 | 说明 | 示例 |
|------|------|------|
| 精确假设 | 一句话可证伪 | "MoE 比全局模型 ΔR² ≥ 0.05" |
| 最小配置 | 只改一个变量 | 固定数据/模型，只变 routing |
| 量化验收 | If-Then 规则 | If ΔR² ≥ 0.05 → 接受 |

<details>
<summary><b>note</b></summary>

分层上：Hub 负责战略思考——假设树、洞见汇合、设计原则；Roadmap 负责执行追踪——MVP 列表、进度、数值结果。

MVP 设计有三个硬性要求：假设必须可证伪、配置必须最小化只改一个变量、验收必须量化写成 If-Then 规则。

</details>

---

## Decision Gate 量化决策

- **资源分配三信号**：

| Gate | 信号 | 决策规则 |
|------|------|---------|
| Gate-1 | 理论上限 (Fisher/CRLB) | If headroom > 20% → 继续投模型 |
| Gate-2 | Scaling 趋势 | If Δ < 5% per 3× data → 不投数据 |
| Gate-3 | 结构红利 (Oracle) | If ΔR² > 0.05 → 投结构 (MoE) |

- **决策流程**：
  1. 检查理论上限还有多少空间
  2. 评估 Scaling 趋势是否饱和
  3. Oracle 实验验证结构红利
  4. 综合三个信号做出 Go/No-Go 决策

<details>
<summary><b>note</b></summary>

Decision Gate 是资源分配的核心机制。我用三个信号做裁决：理论上限还有多少空间、Scaling 趋势是否饱和、Oracle 实验验证结构红利是否存在。这三个信号共同决定"该加数据还是加模型还是换方向"。

</details>

---

## 核心价值与快速上手

- **解决 3 个问题**：

| 问题 | 传统做法 | 本系统 |
|------|---------|--------|
| 结论不可追溯 | 口头讨论、散落笔记 | Hub + Exp 标准化报告 |
| 决策无依据 | "感觉应该这样" | Gate 量化阈值 |
| 知识不复用 | 每次从零开始 | 设计原则自动沉淀 |

- **Cursor AI 快捷命令**：

| 命令 | 作用 |
|------|------|
| `n` | 新建实验 |
| `a` | 归档实验 |
| `u` | 更新文档 |
| `?` | 查看进度 |

- **下一步**：Fork 模板 → 创建主题 → 用 `n` 立项 → 用 `a` 归档

<details>
<summary><b>note</b></summary>

它解决了三个常见问题：结论不可追溯、决策无依据、知识不复用。

如果你也在做探索性研究，欢迎 Fork 这个模板试用。只需要配置项目信息，用 n 命令创建实验，跑完用 a 归档，知识就会自动沉淀。谢谢大家！

</details>
