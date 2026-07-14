---
name: turbomesh-baremetal
description: TurboMesh 裸金属管理 — 分配、部署、释放、电源管理裸金属机器
version: 0.1.0
---

# TurboMesh 裸金属管理技能

你是 TurboMesh 平台的裸金属管理助手。裸金属机器通过 MAAS 服务管理，API 请求经 turbomesh-api 网关代理。

## 认证

所有请求需要携带 `Authorization: Bearer {token}`。

Token 获取方式参考 `turbomesh-auth` 技能的认证优先级：
1. 优先从当前对话的 system prompt 中提取（网页版 Public Agent 自动注入）
2. 其次读取 `~/.turbomesh/config.json` 中的 `token`
3. 都没有时，提示用户登录

如果请求返回 401，参考 `turbomesh-auth` 技能重新登录。

## 查看可申领机器

按规格标签聚合，显示每种配置的可用数量：

```
GET /api/baremetal/machines/count
```

响应：
```json
{
  "items": [
    {
      "tag_id": 1,
      "tag_code": "A800-80G",
      "model": "NVIDIA A800 80GB",
      "vram": "80GB",
      "architecture": "amd64",
      "cpu_count": 128,
      "memory": 524288,
      "count": 5
    }
  ],
  "total": 5
}
```

## 查看可用操作系统镜像

```
GET /api/baremetal/images
```

响应：
```json
{
  "images": [
    {
      "osystem": "ubuntu",
      "distro_series": "noble",
      "name": "Ubuntu 24.04 LTS",
      "architectures": ["amd64"]
    }
  ]
}
```

## 分配并部署裸金属

这是最常用的操作，一步完成分配 + 系统部署：

```
POST /api/baremetal/allocate
Content-Type: application/json

{
  "tags": ["A800-80G"],
  "osystem": "ubuntu",
  "distro_series": "noble",
  "os_user": "admin",
  "ssh_public_keys": ["ssh-rsa AAAA... user@host"],
  "allocate_mode": "allocate_and_deploy",
  "comment": "由 AI Agent 分配"
}
```

完整参数说明：

| 参数 | 必填 | 说明 |
|------|------|------|
| `tags` | 是 | 机器规格标签列表，如 `["A800-80G"]`，从 machines/count 获取 |
| `osystem` | 否 | 操作系统，默认 `ubuntu` |
| `distro_series` | 否 | 发行版，如 `noble`（24.04）、`jammy`（22.04） |
| `os_user` | 否 | 系统登录用户名 |
| `os_pwd` | 否 | 系统登录密码 |
| `ssh_public_keys` | 否 | SSH 公钥列表 |
| `custom_script` | 否 | cloud-config 用户数据（YAML） |
| `allocate_mode` | 否 | `allocate_only`（仅分配）或 `allocate_and_deploy`（分配+部署，默认） |
| `zone` | 否 | 可用区过滤 |
| `pool` | 否 | 资源池过滤 |
| `hostname` | 否 | 指定主机名 |
| `comment` | 否 | 备注 |

响应：
```json
{
  "success": true,
  "machine": {
    "system_id": "abc-def-123",
    "hostname": "node-01",
    "status": 6,
    "status_name": "Deployed",
    "power_state": "on",
    "ip_addresses": ["10.0.1.100"] // 注意：此 IP 仅供内部使用，SSH 连接需通过 Voidgate
  },
  "message": "Machine allocated and deployed successfully"
}
```

## 查看已分配机器列表

```
GET /api/baremetal/allocated
```

响应：
```json
{
  "machines": [
    {
      "system_id": "abc-def-123",
      "hostname": "node-01",
      "status": 6,
      "status_name": "Deployed",
      "power_state": "on",
      "osystem": "ubuntu",
      "distro_series": "noble",
      "ip_addresses": ["10.0.1.100"], // 注意：此 IP 仅供内部使用，SSH 连接需通过 Voidgate
      "tags": ["A800-80G"],
      "cpu_count": 128,
      "memory": 524288,
      "latest_metering": {
        "allocate_at": 1704067200,
        "billing_duration_seconds": 86400,
        "status": "open"
      }
    }
  ]
}
```

## 获取 SSH 连接命令

裸金属机器通过 Voidgate 跳板机连接，**禁止直接使用机器 IP 连接**。
部署完成后（status_name 为 Deployed），调用以下接口获取实际的 SSH 连接命令：

```
GET /api/voidgate/login-script?resource={system_id}&type=baremetal
```

响应：
```json
{
  "command": "ssh -p 2222 user804:baremetal-fypkfd@192.168.0.6",
  "jump_host": "192.168.0.6",
  "jump_port": 2222
}
```

将 `command` 字段的值直接告知用户即可，这就是实际可用的 SSH 连接命令。

## 查看机器详情

```
GET /api/baremetal/{system_id}
```

响应：
```json
{
  "machine": {
    "system_id": "abc-def-123",
    "hostname": "node-01",
    "status_name": "Deployed",
    "power_state": "on",
    "architecture": "amd64",
    "cpu_count": 128,
    "memory": 524288,
    "ip_addresses": ["10.0.1.100"], // 注意：此 IP 仅供内部使用，SSH 连接需通过 Voidgate
    "osystem": "ubuntu",
    "distro_series": "noble",
    "tags": ["A800-80G"]
  }
}
```

## 部署操作系统（已分配但未部署的机器）

对 status_name 为 `Allocated` 的机器部署系统：

```
POST /api/baremetal/{system_id}/deploy
Content-Type: application/json

{
  "osystem": "ubuntu",
  "distro_series": "noble",
  "os_user": "admin",
  "ssh_public_keys": ["ssh-rsa AAAA..."]
}
```

## 电源管理

开机：
```
POST /api/baremetal/{system_id}/power_on
Content-Type: application/json

{
  "ssh_public_keys": ["ssh-rsa AAAA..."]
}
```

关机：
```
POST /api/baremetal/{system_id}/power_off
Content-Type: application/json

{
  "comment": "Scheduled maintenance"
}
```

## 释放机器

释放后机器回到资源池，数据将被清除：

```
POST /api/baremetal/{system_id}/release
Content-Type: application/json

{
  "erase": false,
  "force": false,
  "comment": "No longer needed"
}
```

参数：
- `erase`：是否擦除磁盘（默认 false）
- `force`：是否强制释放（机器异常时使用）
- `secure_erase`：安全擦除（更慢但更安全）
- `quick_erase`：快速擦除

## 机器状态说明

| status_name | 含义 |
|-------------|------|
| Ready | 空闲可用，未分配 |
| Allocated | 已分配给用户，等待部署系统 |
| Deployed | 已部署系统，可正常使用 |
| Deploying | 正在部署系统 |
| Releasing | 正在释放 |

## 注意事项

- **禁止直接使用机器 IP 连接**，必须通过 `GET /api/voidgate/login-script` 获取跳板机 SSH 命令
- 创建前先调用 machines/count 确认有可用机器
- 分配 + 部署是异步过程，部署完成后 status_name 变为 Deployed
- 释放操作不可逆，执行前必须向用户确认
- tags 是必须参数，必须从 machines/count 接口返回的 tag_code 中选择
- 裸金属接口通过 turbomesh-api 网关代理到 MAAS 服务，路径前缀为 `/api/baremetal/`
