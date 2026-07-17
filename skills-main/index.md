# TurboMesh AI Skills

> 让 AI Agent 自主管理超算云资源与 AI 工作负载

TurboMesh Skills 是一组 AI 技能包，安装后你的 AI 助手（Claude Code、Cursor 等）可以自主调用 TurboMesh 平台 API，完成认证、虚拟机与裸金属管理、用量查询、应用部署、弹性服务管理、模型推理部署和大模型微调编排。

## 快速开始

### 方式一：CLI 安装（推荐）

```bash
curl -sL https://raw.githubusercontent.com/gaowenrong/skills/main/install.sh | bash
```

### 方式二：Agent 安装

将以下提示词发送给你的 AI 助手：

> 请访问 https://raw.githubusercontent.com/gaowenrong/skills/main/index.md 并按说明为我安装 turbomesh/turbomesh-ai skills。

## 技能清单

| 技能 | 说明 |
|------|------|
| turbomesh-auth | 认证管理 — 登录、登出、Token 获取与管理 |
| turbomesh-vm | 虚拟机管理 — 创建、查询、删除、监控 VM 实例 |
| turbomesh-baremetal | 裸金属管理 — 分配、部署、释放、电源管理裸金属机器 |
| turbomesh-usage | 用量查询 — 查询资源用量、趋势、构成、账单 |
| turbomesh-app-deployment | 应用部署 — 浏览应用、安装实例、启动、停止、重启与日志排查 |
| turbomesh-elastic-deployment | 弹性服务管理 — 查看部署、扩缩容、配置更新、Ingress、日志与事件 |
| turbomesh-finetuning-orchestrator | 模型微调 — 管理模型和数据集、实验、训练任务、效果对比与模型发布 |
| turbomesh-model-deployment | 模型部署 — 部署和管理推理服务、端点、日志与性能指标 |

## 能力示例

| 能力 | 自然语言指令示例 |
|------|-----------------|
| VM 创建 | “帮我创建一台 2vCPU 4GB 的 Ubuntu 虚拟机” |
| GPU VM | “创建一台 H200 GPU 服务器，使用 Ubuntu 22.04” |
| 裸金属分配 | “分配一台 A800-80G 的裸金属机器，安装 Ubuntu 24.04” |
| 用量查询 | “查看我本月的资源使用量和费用趋势” |
| 应用部署 | “查看应用广场，并把选中的应用安装到资源满足要求的节点” |
| 弹性扩缩容 | “把现有弹性服务改成 CPU 自动扩缩容，副本范围 1 到 5” |
| 模型部署 | “部署一个 Qwen 推理服务，并返回可调用端点” |
| 模型微调 | “用指定数据集创建微调实验，启动训练并监控 Job 状态” |
| 资源管理 | “列出我所有的虚拟机”或“释放那台不再需要的裸金属” |

## 认证配置

安装 Skill 后，首次使用时 AI 助手会自动引导你完成登录：

1. AI 助手会询问你的 TurboMesh 账号密码
2. 自动调用登录接口获取 Token
3. Token 缓存在 `~/.turbomesh/config.json`

你也可以手动配置：

```bash
mkdir -p ~/.turbomesh
cat > ~/.turbomesh/config.json << 'EOF'
{
  "api_url": "http://47.83.30.216:8000",
  "token": ""
}
EOF
```

`api_url` 改为你的 TurboMesh API 地址。Token 留空即可，AI 助手会在首次使用时自动获取。

## 支持的 AI 工具

| 工具 | 安装位置 |
|------|---------|
| Claude Code | `.claude/commands/*.md` |
| Cursor | `.cursor/rules/*.md` |

## 注意事项

- 创建、部署、扩缩容、停止、删除、释放和发布等资源变更操作可能产生费用或影响在线服务，AI 助手会先展示方案并请求确认
- 删除、释放和停止部分资源可能不可逆，请在确认前核对目标资源
- 初始密码等一次性凭据仅在创建成功时返回一次，请及时保存
- Skill 会隐藏节点内网 IP、凭据和密钥等敏感信息
- 建议仅在受信环境中使用
