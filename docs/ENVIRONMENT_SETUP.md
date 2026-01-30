# 🔧 环境变量配置指南

> **作者**: Viska Wei  
> **最后更新**: 2025-01-30

---

## 📋 必需环境变量

### 1. OPENROUTER_API_KEY (推荐)

用于 Perplexity Sonar Pro 学术搜索。

```bash
# 获取: https://openrouter.ai/keys
export OPENROUTER_API_KEY="sk-or-v1-..."
```

**用途**:
- `search_papers.py` — AI 增强的论文搜索
- `theory_explorer.py` — 自动理论分析生成

---

## 📋 可选环境变量

### 2. SEMANTIC_SCHOLAR_KEY (可选)

提高 Semantic Scholar API 请求限制。

```bash
# 获取: https://www.semanticscholar.org/product/api
export SEMANTIC_SCHOLAR_KEY="..."
```

**用途**:
- 更高的 API 请求限额
- 访问更多论文元数据

---

## 🚀 快速配置

### 方法 1: 添加到 ~/.bashrc (推荐)

```bash
# 编辑 ~/.bashrc
echo 'export OPENROUTER_API_KEY="你的密钥"' >> ~/.bashrc
source ~/.bashrc
```

### 方法 2: 项目级 .env 文件

```bash
# 创建 .env 文件 (已在 .gitignore 中)
cd /home/swei20/AI_Research_Template
cat > .env << 'EOF'
OPENROUTER_API_KEY=sk-or-v1-...
SEMANTIC_SCHOLAR_KEY=...
EOF

# 使用前加载
source .env
```

---

## ✅ 验证配置

```bash
# 检查环境变量
echo "OPENROUTER: ${OPENROUTER_API_KEY:+✅ 已设置}"
echo "SEMANTIC_SCHOLAR: ${SEMANTIC_SCHOLAR_KEY:+✅ 已设置}"

# 测试论文搜索
cd /home/swei20/AI_Research_Template/_backend/scripts
python search_papers.py "neural network approximation" --max-results 3
```

---

## 📚 无 API Key 的降级模式

即使没有配置 API Key，系统仍可工作：

| 功能 | 有 API Key | 无 API Key |
|------|-----------|------------|
| **arXiv 搜索** | ✅ | ✅ (始终可用) |
| **Semantic Scholar** | ✅ (高限额) | ⚠️ (低限额) |
| **Perplexity AI 搜索** | ✅ | ❌ 跳过 |
| **Theory Explorer** | ✅ AI 分析 | ⚠️ 仅模板 |

---

## 🔗 获取 API Key

| 服务 | 链接 | 费用 |
|------|------|------|
| **OpenRouter** | https://openrouter.ai/keys | 按用量付费 |
| **Semantic Scholar** | https://www.semanticscholar.org/product/api | 免费 |
