# TurboMesh AI Skills

一组 AI 技能包，让 Claude Code、Cursor 等 AI 助手自主管理 TurboMesh 超算云平台资源与 AI 工作负载。

## 包含技能

| 技能 | 说明 |
|------|------|
| `turbomesh-auth` | 认证管理 — 登录、登出、Token 获取 |
| `turbomesh-vm` | 虚拟机管理 — 创建、查询、删除、监控 |
| `turbomesh-baremetal` | 裸金属管理 — 分配、部署、释放、电源管理 |
| `turbomesh-usage` | 用量查询 — 资源用量、趋势、账单 |
| `turbomesh-app-deployment` | 应用部署 — 应用发现、安装、实例启停、重启与日志 |
| `turbomesh-elastic-deployment` | 弹性服务管理 — 扩缩容、配置、YAML、Ingress、日志与事件 |
| `turbomesh-finetuning-orchestrator` | 微调编排 — 实验、训练 Job、效果对比与模型发布 |
| `turbomesh-model-deployment` | 模型部署 — 推理服务部署、端点、日志与性能指标 |

## 快速安装

```bash
curl -sL https://raw.githubusercontent.com/gaowenrong/skills/main/install.sh | bash
```

详见 [index.md](index.md)。

## 仓库结构

```text
├── index.md              # 安装说明文档
├── manifest.json         # 技能注册表
├── install.sh            # CLI 安装脚本
└── skills/
    ├── turbomesh-auth/SKILL.md
    ├── turbomesh-vm/SKILL.md
    ├── turbomesh-baremetal/SKILL.md
    ├── turbomesh-usage/SKILL.md
    ├── turbomesh-app-deployment/SKILL.md
    ├── turbomesh-elastic-deployment/SKILL.md
    ├── turbomesh-finetuning-orchestrator/SKILL.md
    └── turbomesh-model-deployment/SKILL.md
```

## 安全约定

涉及部署、扩缩容、停止、删除、释放和发布等资源变更时，相关 Skill 会先展示操作方案并请求明确确认；输出中不会暴露节点内网 IP、凭据或密钥。

## 许可证

Apache 2.0
