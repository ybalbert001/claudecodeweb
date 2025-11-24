# Claude Code UI - Kubernetes 部署版本

利用开源项目 [claudecodeui](https://github.com/siteboon/claudecodeui) (Claude Code 的可视化界面)，构建一个可以部署在 Kubernetes 上的版本，并使用 AWS Bedrock API 驱动。

## 项目目标

1. ✅ 生成 Dockerfile，支持本地测试
2. ✅ 集成 AWS Bedrock API 驱动 Claude Code
3. ✅ 提供 Kubernetes 部署配置

## 项目结构

```
.
├── Dockerfile                  # Docker 镜像构建文件
├── docker-compose.yml          # 本地 Docker Compose 配置
├── .env.bedrock               # 环境变量模板（含 Bedrock 配置）
├── k8s/                       # Kubernetes 部署配置
│   ├── configmap.yaml         # 应用配置
│   ├── secret.yaml            # 敏感信息（AWS 凭证）
│   ├── pvc.yaml               # 持久化存储
│   ├── deployment.yaml        # 应用部署
│   ├── service.yaml           # 服务暴露
│   └── ingress.yaml           # 入口配置
├── DEPLOY.md                  # 详细部署文档
└── claudecodeui/              # 原项目代码
```

## 快速开始

### 本地测试（Docker Compose）

```bash
# 1. 配置环境变量
cp .env.bedrock .env
# 编辑 .env 文件，填入你的 AWS 凭证

# 2. 启动服务
docker compose up -d

# 3. 访问服务
# 浏览器打开: http://localhost:3001
```

### Kubernetes 部署

```bash
# 1. 构建并推送镜像
docker build -t your-registry/claude-code-ui:latest .
docker push your-registry/claude-code-ui:latest

# 2. 配置 AWS 凭证
# 编辑 k8s/secret.yaml，填入你的 AWS 凭证

# 3. 更新镜像地址
# 编辑 k8s/deployment.yaml，修改镜像地址

# 4. 部署
kubectl apply -f k8s/

# 5. 查看状态
kubectl get pods
kubectl logs -f deployment/claude-code-ui
```

详细部署步骤请参考 [DEPLOY.md](./DEPLOY.md)

## 功能特性

- ✅ 基于 AWS Bedrock API，无需 Anthropic API Key
- ✅ 支持 Docker 和 Kubernetes 部署
- ✅ 多架构镜像支持（使用 Node.js Alpine）
- ✅ 持久化存储（数据库和项目文件）
- ✅ WebSocket 支持（实时通信）
- ✅ 健康检查和自动重启
- ✅ 资源限制和优化

## 环境变量说明

关键环境变量：

| 变量名 | 说明 | 必需 |
|--------|------|------|
| `CLAUDE_CODE_USE_BEDROCK` | 启用 Bedrock API | 是 |
| `AWS_REGION` | AWS 区域 | 是 |
| `AWS_ACCESS_KEY_ID` | AWS 访问密钥 | 是* |
| `AWS_SECRET_ACCESS_KEY` | AWS 密钥 | 是* |
| `PORT` | 服务端口 | 否 (默认3001) |
| `DATABASE_PATH` | 数据库路径 | 否 |

\* 在 EKS 环境可使用 IAM Role 替代

## 技术栈

- **前端**: React 18, Vite, CodeMirror, xterm.js
- **后端**: Node.js, Express, WebSocket
- **数据库**: SQLite (better-sqlite3)
- **AI**: AWS Bedrock (Claude Sonnet)
- **容器**: Docker, Kubernetes

## 参考文档

- [Claude Code 官方文档](https://code.claude.com/docs)
- [第三方集成指南](https://code.claude.com/docs/en/third-party-integrations)
- [AWS Bedrock 文档](https://docs.aws.amazon.com/bedrock/)
- [原项目仓库](https://github.com/siteboon/claudecodeui)

## 许可证

MIT License (继承自原项目)

