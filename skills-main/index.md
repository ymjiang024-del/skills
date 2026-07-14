# TurboMesh AI Skills

> 让 AI Agent 自主管理超算云资源

TurboMesh Skills 是一组 AI 技能包，安装后你的 AI 助手（Claude Code、Cursor 等）可以自主调用 TurboMesh 平台 API，帮你管理虚拟机、裸金属、查询用量等。

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

## 能力示例

| 能力 | 自然语言指令示例 |
|------|-----------------|
| VM 创建 | "帮我创建一台 2vCPU 4GB 的 Ubuntu 虚拟机" |
| GPU VM | "创建一台 H200 GPU 服务器，使用 Ubuntu 22.04" |
| 裸金属分配 | "分配一台 A800-80G 的裸金属机器，安装 Ubuntu 24.04" |
| 用量查询 | "查看我本月的资源使用量和费用趋势" |
| 资源管理 | "列出我所有的虚拟机"、"释放那台不再需要的裸金属" |

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
| Claude Code | `.claude/commands/turbomesh-*.md` |
| Cursor | `.cursor/rules/turbomesh-*.md` |

## 注意事项

- 所有资源操作会产生费用，费用计入你的账户
- 删除、释放操作不可逆，AI 助手会向你确认后再执行
- 初始密码仅在 VM 创建成功时返回一次，请及时保存
- 建议在受信环境中使用
