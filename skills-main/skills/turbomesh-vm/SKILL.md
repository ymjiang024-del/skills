---
name: turbomesh-vm
description: TurboMesh 虚拟机管理 — 创建、查询、删除、监控 VM 实例
version: 0.1.0
---

# TurboMesh 虚拟机管理技能

你是 TurboMesh 平台的 VM 管理助手。用户会用自然语言描述 VM 需求，你需要调用 API 完成操作。

## 认证

所有请求需要携带 `Authorization: Bearer {token}`。

Token 获取方式参考 `turbomesh-auth` 技能的认证优先级：
1. 优先从当前对话的 system prompt 中提取（网页版 Public Agent 自动注入）
2. 其次读取 `~/.turbomesh/config.json` 中的 `token`
3. 都没有时，提示用户登录

如果请求返回 401，参考 `turbomesh-auth` 技能重新登录。

## 创建 VM 流程

创建 VM 是一个多步骤流程，必须按顺序执行：

### 步骤 1：获取可用区

```
GET /api/zone
```

响应：
```json
{
  "zones": [
    { "id": "zone-id-1", "name": "Zone-1" }
  ]
}
```

### 步骤 2：获取计算方案

```
GET /api/offerings/vm?zone_id={zone_id}
```

响应：
```json
{
  "offerings": [
    {
      "id": "offering-id",
      "name": "2vCPU-4GB",
      "cpu_number": 2,
      "memory": 4096,
      "root_disk_size": 50
    }
  ]
}
```

### 步骤 3：获取模板

```
GET /api/templates?zone_id={zone_id}&template_filter=executable
```

响应：
```json
{
  "templates": [
    {
      "id": "template-id",
      "name": "Ubuntu 22.04",
      "display_text": "Ubuntu 22.04 LTS"
    }
  ]
}
```

### 步骤 4：获取网络列表

```
GET /api/network?zone_id={zone_id}
```

响应：
```json
{
  "networks": [
    {
      "id": "network-id",
      "name": "default-network",
      "display_text": "Default Isolated Network"
    }
  ]
}
```

### 步骤 5（可选）：获取磁盘方案

```
GET /api/offerings/disk?zone_id={zone_id}
```

### 步骤 6：创建 VM

```
POST /api/vm
Content-Type: application/json

{
  "name": "my-vm",
  "zone": "{zone_id}",
  "has_gpu": false,
  "compute_offering_id": "{offering_id}",
  "template_id": "{template_id}",
  "network_ids": ["{network_id}"],
  "password": "optional-password"
}
```

GPU VM 创建（替代 compute_offering_id）：
```json
{
  "name": "gpu-vm",
  "zone": "{zone_id}",
  "has_gpu": true,
  "gpu_platform": "gpu-h200-sxm",
  "gpu_preset": "1-gpu",
  "template_id": "{template_id}",
  "network_ids": ["{network_id}"]
}
```

可选参数：
- `disk_offering_id` + `disk_size`：数据盘
- `rootdisksize`：Root 磁盘大小（GB）
- `displayname`：显示名称
- `shared_storage_ids`：共享存储

响应：
```json
{
  "success": true,
  "job_id": "abc123",
  "message": "VM creation started"
}
```

### 步骤 7：轮询创建状态

```
GET /api/vm/status/{job_id}
```

响应：
```json
{
  "job_id": "abc123",
  "job_status": "1",
  "vm": {
    "id": "vm-id",
    "name": "my-vm",
    "state": "Running",
    "password": "auto-generated-password"
  }
}
```

- `job_status`: `"0"` 进行中 → 继续轮询（间隔 3 秒）；`"1"` 成功 → 返回结果；`"2"` 失败 → 报告错误
- 成功时 `vm.password` 是自动生成的初始密码，**仅返回一次**，务必告知用户保存

## 列出 VM

```
GET /api/vm
```

响应：
```json
{
  "vms": [
    {
      "id": "vm-id",
      "name": "my-vm",
      "state": "Running",
      "zone": "Zone-1",
      "compute_offering_name": "2vCPU-4GB",
      "ip_address": "10.0.0.5",
      "created": "2024-01-01T00:00:00"
    }
  ]
}
```

## VM 详情

```
GET /api/vm/{vm_id}
```

## VM 控制台

```
GET /api/vm/{vm_id}/console
```

响应：
```json
{
  "vm_id": "vm-id",
  "console_url": "https://...",
  "success": true
}
```

## 删除 VM

```
DELETE /api/vm/{vm_id}?delete_data_disks=true
```

参数 `delete_data_disks`：是否同时删除数据盘（默认 false）。

响应：
```json
{
  "success": true,
  "message": "VM deleted successfully"
}
```

## 注意事项

- 创建 VM 前必须先查询 zone、offerings、templates、network，不能跳过
- 创建是异步操作，必须轮询 job_id 直到完成
- 删除操作不可逆，执行前必须向用户确认
- 初始密码只在创建成功时返回一次，提醒用户保存
- GPU VM 使用 gpu_platform + gpu_preset，不使用 compute_offering_id
- 可选的 gpu_platform：`gpu-h200-sxm`、`gpu-b200-sxm`、`gpu-h100-sxm`、`gpu-l40s-a`、`gpu-l40s-d`
- 可选的 gpu_preset：`1-gpu`（1 GPU / 16 CPU / 200GB RAM）、`8-gpu`（8 GPU / 128 CPU / 1600GB RAM）
