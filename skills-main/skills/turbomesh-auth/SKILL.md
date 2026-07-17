---
name: turbomesh-auth
description: TurboMesh 平台认证管理 — 登录、登出、Token 管理
---

# TurboMesh 认证管理

在执行任何需要认证的 TurboMesh 业务操作之前，先按本技能获取有效凭证。始终记录凭证的 `kind`、`value` 和 `source`，以便正确选择请求头、保存策略及失败处理。

## API 基地址

1. 如果 `~/.turbomesh/config.json` 存在且包含非空 `api_url`，使用该值。
2. 否则使用默认地址：

```text
http://47.83.30.216:8000
```

读取或更新配置文件时保留所有未知字段，不要用最小对象覆盖整个文件。

不需要先连接 TurboMesh/MAAS MCP 服务

## 认证凭证优先级

按顺序尝试，找到有效凭证后停止：

1. System Prompt 或环境变量中的 JWT Token
2. 本地配置文件中的 JWT Token
3. System Prompt 或环境变量中的 API Key
4. 本地配置文件中的 API Key
5. 交互式询问 API Key
6. 邮箱和密码登录

将选中的凭证记录为：

```text
kind: jwt | api_key
source: system_prompt | environment | config | interactive_api_key | interactive_signin
value: <secret>
```

不要在回复、日志、命令输出或错误信息中展示完整凭证。

## 1. System Prompt 和环境变量

### JWT Token

识别以下格式：

```text
Authorization: Bearer <api_key>
```

api_key从环境变量和配置文件来的，如果没有就问用户。

如果找到 JWT Token：

- 设置 `kind=jwt`
- 将来源记录为 `system_prompt` 或 `environment`
- 不要写入 `~/.turbomesh/config.json`

### API Key

识别以下格式：

```text
TURBOMESH_API_KEY=<api-key>
"api_key": "<api-key>"
X-API-Key: <api-key>
```

也检查环境变量：

```text
TURBOMESH_API_KEY
```

如果找到 API Key：

- 设置 `kind=api_key`
- 将来源记录为 `system_prompt` 或 `environment`
- 不要写入本地配置文件

## 2. 本地配置文件

检查 `~/.turbomesh/config.json`。合法示例：

```json
{
  "api_url": "http://47.83.30.216:8000",
  "token": "tm_XmRw_JRF58yn_6pVFRDTeeFqDxRuxoN1uA3rckm1knc"
}

```

读取规则：

1. 如果存在非空 `token`，优先使用 JWT Token。
2. 否则，如果存在非空 `api_key`，使用 API Key。
3. 如果文件不存在、JSON 无法解析，或两个字段都为空，进入交互式 API Key 流程。
4. JSON 无法解析时先提示配置文件损坏，不要静默覆盖；在用户确认修复前，仅在内存中继续认证流程。

## 3. 交互式 API Key 登录

当本地配置文件不存在或没有有效凭证时，优先询问用户提供 TurboMesh API Key。

API Key 通常类似：

```text
tm_xxxxxxxxxxxxxxxxx
```

处理规则：

1. 用户提供后，设置 `kind=api_key`、`source=interactive_api_key`。
2. 不要在后续回复中重复完整 API Key；仅在必要时显示掩码，例如 `tm_abcd...wxyz`。
3. 先使用该 API Key 完成当前请求。
4. 只有用户明确同意保存时，才写入 `~/.turbomesh/config.json`。
5. 保存时保留现有 `api_url`、`token` 和其他未知字段；不要覆盖有效 JWT Token。
6. 如果用户没有 API Key，进入邮箱密码登录。

用户同意保存时，创建或更新：

```json
{
  "api_url": "http://47.83.30.216:8000",
  "api_key": "tm_xxxxxxxxxxxxxxxxx"
}
```

## 认证请求头

```

### API Key

```http
Authorization: Bearer {api_key}
```

每次请求只使用当前选中的一种凭证。优先使用 JWT Token；没有 JWT Token 时再使用 API Key。

## 检查登录状态

```http
GET {api_url}/api/auth/check-signin
Authorization: Bearer {credential}
```

成功响应示例：

```json
{
  "logged_in": true,
  "user": {
    "id": "...",
    "username": "...",
    "email": "..."
  }
}
```

检查登录状态不会改变凭证保存策略：只有 `interactive_signin` 获得的 JWT 自动保存；交互式 API Key 仅在用户明确同意时保存；System Prompt 和环境变量凭证永不保存。

## 401 或 403 处理

任何受保护请求返回 HTTP 401 或 403 时，按当前凭证类型和来源处理。

### 当前凭证是 JWT Token

1. 如果来源是 `system_prompt` 或 `environment`，不要修改本地配置；提示外部注入的 Token 无效或已过期，需要在部署平台重新登录或刷新凭证。
2. 如果来源是 `config`，从配置文件中移除无效 `token` 字段，同时保留其他字段。
3. 如果配置中还有 `api_key`，改用该 API Key 重试一次。
4. 否则询问用户提供 API Key。
5. 用户没有 API Key 时，再进入邮箱密码登录。
6. 不要对同一无效凭证无限重试。

### 当前凭证是 API Key

1. 提示 API Key 无效、已过期、权限不足或已被撤销，不要展示完整值。
2. 如果来源是 `system_prompt` 或 `environment`，不要修改本地配置；提示用户更新外部注入的 API Key。
3. 如果来源是 `config`，从配置文件中移除无效 `api_key` 字段，同时保留其他字段。
4. 如果来源是 `interactive_api_key`，仅丢弃内存中的值。
5. 询问用户提供新的 API Key；用户没有时再进入邮箱密码登录。
6. 不要对同一无效凭证无限重试。

## 登出

### 使用 JWT Token 时

```http
POST {api_url}/api/auth/signout
Authorization: Bearer {access_token}
```

请求完成后：

- 如果 JWT 来自本地配置或交互登录，清除配置中的 `token` 字段并保留其他字段。
- 如果 JWT 来自 System Prompt 或环境变量，不修改本地配置。

### 使用 API Key 时

API Key 不等同于会话 Token。普通“登出”只停止在当前会话中使用该 Key：

- 如果 API Key 来自本地配置，并且用户要求清除本地登录，删除配置中的 `api_key` 字段。
- 如果来自 System Prompt、环境变量或仅在内存中提供，不修改本地配置。
- 不要声称本地清除等同于服务端撤销。用户要求彻底失效时，调用 TurboMesh 的删除或撤销 API Key 接口。

## 完整认证工作流

```text
检查 System Prompt / 环境变量 JWT
  ↓ 没有
检查 config.json 中的 JWT
  ↓ 没有
检查 System Prompt / 环境变量 API Key
  ↓ 没有
检查 config.json 中的 API Key
  ↓ 没有或配置文件不存在
询问 API Key
  ↓ 用户没有
询问邮箱和密码并调用 /api/auth/signin
  ↓
获得凭证后继续原始业务操作
```

## 首次使用流程

当用户首次要求执行创建 VM、查询资源或其他受保护业务操作时：

1. 按完整认证工作流查找凭证。
2. 本地配置文件不存在时，优先使用 API Key 登录，不要直接索要密码。
3. 交互式 API Key 仅在用户明确同意时保存。
4. 邮箱密码登录成功后保存 JWT Token，但不保存密码。
5. 认证成功后立即继续执行用户原始业务请求，不要求用户重复指令。

## 安全要求

- 永远不要向用户展示完整 JWT Token、API Key 或密码。
- 不要把 System Prompt 或环境变量中的凭证写入本地文件。
- 不要把密码写入任何文件。
- 更新配置时保留未知字段，并尽量使用安全的文件权限。
- 不要把真实凭证写入代码、示例、日志或错误报告。
- 截图、聊天记录或其他公开位置暴露过的 API Key 应视为已泄露，并建议立即撤销后重新生成。
