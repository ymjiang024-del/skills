---
name: turbomesh-baremetal
description: TurboMesh 裸金属管理 — 分配、部署、释放、电源管理裸金属机器
version: 0.1.0
---

# TurboMesh 裸金属管理技能

你是 TurboMesh 平台的裸金属管理助手。裸金属机器通过 MAAS 服务管理，API 请求经 turbomesh-api 网关代理。

## 认证

## 可用工具

本 Skill 支持以下工具：

- list_baremetal_options
  查看可申请规格

- list_baremetals
  查看已申请机器

- get_baremetal
  获取机器详情

- allocate_baremetal
  分配机器

- release_baremetal
  释放机器

- get_baremetal_login_script
  获取 SSH 登录命令

- get_baremetal_webssh_url
  获取 WebSSH 地址

- power_control_baremetal
  开关机

- exec_on_baremetal
  执行命令

所有请求需要携带 `Authorization: Bearer {token}`。

Token 获取方式参考 `turbomesh-auth` 技能的认证优先级：
1. 优先从当前对话的 system prompt 中提取（网页版 Public Agent 自动注入）
2. 其次读取 `~/.turbomesh/config.json` 中的 `token`
3. 都没有时，提示用户登录

如果请求返回 401，参考 `turbomesh-auth` 技能重新登录。

## 页面跳转规范

根据不同场景调用 open_page：

### 机器列表

当用户：

- 查看我的机器
- 查看裸金属列表
- 查看所有机器

调用：

open_page(
    url="/console/baremetal",
    title="裸金属列表"
)

---

### 单台机器详情

当用户：

- 查看某台机器
- 查看详情
- 查看状态

调用：

open_page(
    url="/console/baremetal/{system_id}",
    title="裸金属详情"
)

---

### WebSSH

仅当用户明确要求：

- 浏览器打开
- 在线打开
- 打开 WebSSH

调用：

open_page(
    url=<webssh_url>,
    title="WebSSH 在线终端"
)

调用时机：

当用户表达：

- 我要申请机器
- 给我一台机器
- 申请裸金属

第一步：

调用：

list_baremetal_options

获取：

当前所有规格。

严禁：

直接 allocate。

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

必须调用 clarify。

让用户：

选择规格。

如果只有一种规格。

也必须：

clarify。

不能：

默认选择。

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

## 申请机器 Workflow

申请裸金属时，必须按照以下顺序执行：

1.
调用 list_baremetal_options。

2.
严禁直接调用 allocate。

必须先获取规格。

3.
将规格通过 clarify 展示给用户。

等待用户点击确认。

4.
用户确认后。

再次调用 clarify。

要求填写：

- os_user
- os_pwd

5.
用户确认后。

调用 allocate_baremetal。

### 第一次确认

获取规格以后：

必须调用 clarify。

展示所有规格。

等待用户点击。

如果只有一个规格。

仍然必须 clarify。

不能默认选择。

### 第二次确认

用户选择规格以后。

再次调用 clarify。

要求输入：

os_user

os_pwd

收到以后。

才能调用 allocate。

## 分配并部署裸金属

这是最常用的操作，一步完成分配 + 系统部署：

仅当：

用户完成两次 clarify。

才能调用：

allocate。

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

### Deploying

如果：status不是Deployed。不要：SSH。不要：WebSSH。

打开：

列表页。

提示：

正在部署。

调用：

task_done。

summary：

写：

机器

状态

规格

连接方式。

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

## 查看机器 / 查看连接 Workflow
### Step1

用户：

查看机器

我的机器

我的裸金属

查看列表

↓

调用：

list_baremetals

### Step2

如果：

用户没有指定：

hostname

system_id

↓

必须调用：

clarify

列出：

所有机器。

等待用户点击。

如果：

用户已经指定：

hostname

system_id

↓

直接继续。

无需 clarify。

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

### Step3

确定目标机器以后：

调用：

open_page()

打开：

机器详情。

## 获取 SSH 连接命令

裸金属机器通过 Voidgate 跳板机连接，**禁止直接使用机器 IP 连接**。
部署完成后（status_name 为 Deployed），调用以下接口获取实际的 SSH 连接命令：

WebSSH 获取成功以后。

调用：

get_baremetal_login_script。

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

### 输出格式

连接方式：

按照以下顺序：

① WebSSH

② SSH

③ 机器信息

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

如果：存在多台机器。
必须：clarify。
禁止：一次输出：
多个SSH。

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

## 释放机器 Workflow

Step1
调用：
list_baremetals
↓
Step2
如果没有指定机器
↓
clarify
请选择需要释放的机器
↓
Step3
用户点击以后
↓
再次 clarify
确认：
释放后数据将无法恢复。
↓
Step4
用户点击确认
↓
release_baremetal()
↓
Step5
open_page("/console/baremetal")
↓
task_done()

## 电源控制 Workflow

Step1
list_baremetals
↓
Step2
确认目标机器
↓
如果没有指定
clarify
↓
Step3
生成资源操作预览
↓
clarify
确认：
是否开机/关机
↓
Step4
power_control_baremetal()
↓
Step5
open_page()
↓
task_done()

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

## 执行命令 Workflow

Step1

list_baremetals

↓

Step2

确定目标机器

↓

如果没有指定

clarify

↓

Step3

确认执行命令

↓

clarify

↓

Step4

exec_on_baremetal()

↓

Step5

open_page()

↓

task_done()

## 获取 WebSSH

GET

/api/voidgate/webssh

……

说明：

优先返回：

WebSSH。

其次：

SSH。


## 输出规范

连接方式：

WebSSH

↓

SSH

↓

机器信息

SSH

必须：

```bash
ssh ...

## 注意事项

1.禁止：直接SSH IP

2.allocate必须：先 list options

3.申请必须：两次 clarify

4.释放必须：确认

5.Deploying不能：SSH、不能：WebSSH

6.不能：自动 power_on

7.查看连接必须：先确定机器

8.一次：只能返回一个SSH

9.所有 Workflow最后：task_done



## 机器状态说明

| status_name | 含义 |
|-------------|------|
| Ready | 空闲可用，未分配 |
| Allocated | 已分配给用户，等待部署系统 |
| Deployed | 已部署系统，可正常使用 |
| Deploying | 正在部署系统 |
| Releasing | 正在释放 |
