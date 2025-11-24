# Claude Code UI 部署指南

本指南介绍如何使用 AWS Bedrock API 部署 Claude Code UI。

## 前置要求

- Docker 和 Docker Compose
- AWS 账号，并已开通 Bedrock Claude 模型访问权限
- AWS 访问密钥（Access Key ID 和 Secret Access Key）
- Kubernetes 集群（用于 K8s 部署）

## 方式一：本地 Docker 测试

### 1. 配置环境变量

复制环境变量模板并编辑：

```bash
cp .env.bedrock .env
```

编辑 `.env` 文件，填入你的 AWS 凭证：

```bash
# 必需配置
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
```

### 2. 启动服务

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 3. 访问服务

打开浏览器访问：http://localhost:3001

### 4. 停止服务

```bash
docker-compose down
```

## 方式二：Kubernetes 部署

### 1. 构建并推送 Docker 镜像

```bash
# 构建镜像
docker build -t your-registry/claude-code-ui:latest .

# 推送到镜像仓库
docker push your-registry/claude-code-ui:latest
```

### 2. 配置 AWS 凭证

编辑 `k8s/secret.yaml`，填入你的 AWS 凭证：

```yaml
stringData:
  AWS_REGION: "us-east-1"
  AWS_ACCESS_KEY_ID: "your-access-key-id"
  AWS_SECRET_ACCESS_KEY: "your-secret-access-key"
```

**安全提示**：生产环境建议使用 AWS IAM Role 或 External Secrets Operator。

### 3. 更新 Deployment 镜像地址

编辑 `k8s/deployment.yaml`，修改镜像地址：

```yaml
image: your-registry/claude-code-ui:latest
```

### 4. 部署到 K8s

```bash
# 创建所有资源
kubectl apply -f k8s/

# 查看部署状态
kubectl get pods
kubectl get svc

# 查看日志
kubectl logs -f deployment/claude-code-ui
```

### 5. 访问服务

根据你的配置方式访问：

**方式 A - Port Forward（快速测试）：**
```bash
kubectl port-forward svc/claude-code-ui 3001:80
```
访问：http://localhost:3001

**方式 B - Ingress（生产环境）：**

编辑 `k8s/ingress.yaml`，设置你的域名：
```yaml
spec:
  rules:
  - host: claude-code-ui.your-domain.com
```

应用配置后通过域名访问。

### 6. 清理资源

```bash
kubectl delete -f k8s/
```

## 配置说明

### AWS Bedrock 区域

支持的 AWS 区域：
- `us-east-1` (美国东部)
- `us-west-2` (美国西部)
- `eu-west-1` (欧洲)
- `ap-southeast-1` (亚太新加坡)

### 使用 IAM Role（推荐用于 EKS）

如果在 EKS 上运行，推荐使用 IAM Role for Service Account (IRSA)：

1. 创建 IAM 策略，授予 Bedrock 访问权限
2. 创建 IAM Role 并关联到 Service Account
3. 删除 Secret 中的 AWS 凭证配置
4. 在 Deployment 中添加 Service Account

参考：https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html

## 故障排查

### 1. 容器启动失败

查看日志：
```bash
# Docker
docker-compose logs

# K8s
kubectl logs deployment/claude-code-ui
```

### 2. AWS 认证失败

检查：
- AWS 凭证是否正确
- AWS 区域是否支持 Bedrock
- IAM 用户是否有 Bedrock 权限

### 3. 数据库权限问题

确保容器有权限写入数据目录：
```bash
# Docker
chmod -R 777 ./data

# K8s - 检查 PVC 权限
kubectl describe pvc claude-code-ui-data
```

### 4. WebSocket 连接失败

检查：
- Ingress 是否配置了 WebSocket 支持
- 服务是否使用 sessionAffinity: ClientIP

### 5. 健康检查失败

确保 `/health` 端点可访问：
```bash
# 进入容器测试
docker exec -it claude-code-ui curl http://localhost:3001/health
```

## 性能优化

### 资源配置

根据使用情况调整 `k8s/deployment.yaml` 中的资源限制：

```yaml
resources:
  limits:
    cpu: "2000m"      # 2 核 CPU
    memory: "2Gi"     # 2GB 内存
  requests:
    cpu: "500m"       # 0.5 核 CPU
    memory: "512Mi"   # 512MB 内存
```

### 存储配置

根据项目规模调整 PVC 大小：
- 数据库：10Gi（存储用户数据和会话）
- 项目目录：50Gi（存储代码项目）

## 安全建议

1. **不要在代码仓库中提交包含真实凭证的文件**
2. 使用 `.gitignore` 排除 `.env` 和 `k8s/secret.yaml`
3. 生产环境使用 IAM Role 或 Secrets Manager
4. 启用 HTTPS/TLS 加密
5. 限制网络访问（使用 NetworkPolicy）

## 更新说明

更新到新版本：

```bash
# 1. 构建新镜像
docker build -t your-registry/claude-code-ui:v1.x.x .
docker push your-registry/claude-code-ui:v1.x.x

# 2. 更新 Deployment
kubectl set image deployment/claude-code-ui \
  claude-code-ui=your-registry/claude-code-ui:v1.x.x

# 3. 查看滚动更新状态
kubectl rollout status deployment/claude-code-ui
```

## 参考链接

- [Claude Code 第三方集成文档](https://code.claude.com/docs/en/third-party-integrations)
- [AWS Bedrock 文档](https://docs.aws.amazon.com/bedrock/)
- [原项目地址](https://github.com/siteboon/claudecodeui)
