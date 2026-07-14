# TurboMesh AI Skills

一组 AI 技能包，让 Claude Code、Cursor 等 AI 助手自主管理 TurboMesh 超算云平台资源。

## 包含技能

| 技能 | 说明 |
|------|------|
| `turbomesh-auth` | 认证管理 — 登录、登出、Token 获取 |
| `turbomesh-vm` | 虚拟机管理 — 创建、查询、删除、监控 |
| `turbomesh-baremetal` | 裸金属管理 — 分配、部署、释放、电源管理 |
| `turbomesh-usage` | 用量查询 — 资源用量、趋势、账单 |

## 快速安装

```bash
curl -sL https://raw.githubusercontent.com/gaowenrong/skills/main/install.sh | bash
```

详见 [index.md](index.md)。

## 仓库结构

```
├── index.md              # 安装说明文档
├── manifest.json         # 技能注册表
├── install.sh            # CLI 安装脚本
└── skills/
    ├── turbomesh-auth/SKILL.md
    ├── turbomesh-vm/SKILL.md
    ├── turbomesh-baremetal/SKILL.md
    └── turbomesh-usage/SKILL.md
```

## 许可证

Apache 2.0
