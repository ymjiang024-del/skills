---
name: turbomesh-auth
description: TurboMesh 平台认证管理 — 登录、登出、Token 管理
version: 0.1.0
---

# TurboMesh 认证管理技能

你是 TurboMesh 平台的认证助手。在执行任何业务操作之前，你需要先获取有效的认证 Token。

## API 基地址

从 `~/.turbomesh/config.json` 读取 `api_url`。如果文件不存在，默认使用 `http://47.83.30.216:8000`。

## 获取认证 Token

调用 TurboMesh API 时，按以下优先级获取当前用户的 JWT token：

如果 token 来源于 system prompt，

不要：覆盖config.json。

### 1. System Prompt 注入（推荐，用于网页版 Public Agent）

检查当前对话的 system message 中是否包含：

```
Authorization: Bearer <token>
```

如果存在，提取 `<token>` 并在每次 API 请求时使用。

也可识别以下格式作为兼容：
- `TURBOMESH_TOKEN=<token>`
- `"token": "<token>"`

该 token 通常由部署平台自动注入，无需用户手动提供。

### 2. 本地配置文件（用于用户本地安装的 Agent）

读取 `~/.turbomesh/config.json` 中的 `token` 字段：

```json
{
  "api_url": "http://47.83.30.216:8000",
  "token": "eyJhbGciOiJIUzI1..."
}
```

### 3. 交互式询问（兜底）

如果以上都没有，向用户询问邮箱和密码，调用登录接口获取 token。

```
POST {api_url}/api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "user-password"
}
```

成功响应（HTTP 200）：
```json
{
  "access_token": "eyJhbGciOiJIUzI1...",
  "token_type": "bearer",
  "user": {
    "id": "a1b2c3d4e5f67890",
    "username": "john",
    "email": "user@example.com",
    "account_name": "John",
    "is_active": true
  }
}
```

登录成功后，将 `access_token` 保存到 `~/.turbomesh/config.json`：

```json
{
  "api_url": "http://47.83.30.216:8000",
  "token": "eyJhbGciOiJIUzI1..."
}
```

## Token 使用

后续所有 API 请求携带 Header：

```
Authorization: Bearer {access_token}
```

## Token 过期处理

如果任何 API 请求返回 HTTP 401，说明 Token 已过期或无效。
如果当前 token 来源于 system prompt，不要写 config，直接提示重新登录
此时应：
1. 提示用户 Token 已过期
2. 重新询问密码
3. 调用登录接口获取新 Token
4. 更新 `~/.turbomesh/config.json`

## 登出

```
POST {api_url}/api/auth/logout
Authorization: Bearer {access_token}
```

登录成功以后，如果 token 来源：交互登录，则保存 config，否则：不要保存

登出后清除 `~/.turbomesh/config.json` 中的 token 字段。

## 检查登录状态

登录成功以后，如果 token 来源：交互登录，则保存 config，否则：不要保存

```
GET {api_url}/api/auth/check-login
Authorization: Bearer {access_token}
```

响应：
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

## Token 获取 Workflow

Step1
检查system prompt

Step2
检查config.json

Step3
没有
↓
登录
Step4
保存
↓
继续业务

## 首次使用流程

当用户首次要求执行业务操作（如创建 VM）时：
1. 按上述优先级尝试获取 token
2. 如果都没有，向用户询问邮箱和密码
3. 调用登录接口获取 token
4. 保存到配置文件
5. 继续执行用户的业务请求

## 注意事项

- 密码不会存储在配置文件中，仅在登录时使用
- Token 有效期由服务端控制，过期后需重新登录
- 不要向用户展示完整的 Token 字符串
- 当 token 来自 system prompt 时，不要将其保存到本地配置文件
