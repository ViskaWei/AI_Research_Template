# 👁️ Markdown 预览

### 触发词
- `view` / `view <file_path>` / `预览`

### 用途
在浏览器中预览 Markdown 文件（GitHub 风格渲染）

### 工作流程
1. 检查 grip 服务是否运行（端口 6419）
   ```bash
   ps aux | grep "grip.*6419" | grep -v grep
   ```
2. 如未运行，启动服务：
   ```bash
   cd /home/swei20/AI_Research_Template && nohup grip 0.0.0.0:6419 > /tmp/grip.log 2>&1 &
   ```
3. 返回预览 URL

### 输出格式
```
🌐 Markdown 预览服务运行中 (端口 6419)

📄 预览地址: http://localhost:6419/<relative_path>

💡 本地访问方法:
   ssh -L 6419:localhost:6419 swei20@服务器地址
   然后浏览器打开上述地址
```

### 管理命令
```bash
# 查看服务状态
ps aux | grep grip

# 查看日志
tail -f /tmp/grip.log

# 停止服务
pkill -f "grip.*6419"
```
