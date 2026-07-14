---
name: turbomesh-usage
description: TurboMesh 用量查询 — 查询资源用量、额度、账单
version: 0.1.0
---

# TurboMesh 用量查询技能

你是 TurboMesh 平台的用量查询助手。帮助用户了解资源使用情况、费用趋势和用量构成。

## 认证

所有请求需要携带 `Authorization: Bearer {token}`。

Token 获取方式参考 `turbomesh-auth` 技能的认证优先级：
1. 优先从当前对话的 system prompt 中提取（网页版 Public Agent 自动注入）
2. 其次读取 `~/.turbomesh/config.json` 中的 `token`
3. 都没有时，提示用户登录

如果请求返回 401，参考 `turbomesh-auth` 技能重新登录。

## 用量总览

获取全局用量概览，包含总使用时长、活跃资源数、按类型拆分等：

```
GET /api/usage/overview?start_time={unix_timestamp}&end_time={unix_timestamp}
```

时间参数为 Unix 时间戳（秒），均为可选。不传则使用默认时间范围。

响应：
```json
{
  "total_duration_seconds": 1296000,
  "active_resource_count": 5,
  "breakdown_by_type": {
    "baremetal": {
      "value": 864000,
      "unit": { "code": "hours", "name_zh": "小时", "name_en": "hours" }
    },
    "vm": {
      "value": 432000,
      "unit": { "code": "hours", "name_zh": "小时", "name_en": "hours" }
    }
  },
  "summary_by_category": {
    "compute": { "value": 1000000, "unit": { "code": "core_hours" } },
    "storage": { "value": 296000, "unit": { "code": "gib_hours" } }
  }
}
```

## 用量趋势

按天聚合的用量数据，可按资源类型筛选：

```
GET /api/usage/trend?start_time={ts}&end_time={ts}&resource_type={type}
```

`resource_type` 可选值：`baremetal`、`vm`、`disk`、`network` 等。

响应：
```json
{
  "items": [
    {
      "date": "2024-01-01",
      "duration_seconds": 86400,
      "metered_value": { "value": 24, "unit": { "code": "hours" } }
    }
  ]
}
```

## 用量趋势（按资源类型分组）

```
GET /api/usage/trend/group-by?start_time={ts}&end_time={ts}
```

响应：
```json
{
  "items": [
    {
      "date": "2024-01-01",
      "metrics": {
        "baremetal": { "value": 100, "unit": { "code": "hours" } },
        "vm": { "value": 50, "unit": { "code": "hours" } }
      }
    }
  ]
}
```

## 用量构成

按资源类型拆分的用量占比：

```
GET /api/usage/breakdown?start_time={ts}&end_time={ts}
```

响应：
```json
{
  "items": [
    {
      "resource_type": "baremetal",
      "metered_value": { "value": 500, "unit": { "code": "hours" } },
      "percentage": 65.5
    },
    {
      "resource_type": "vm",
      "metered_value": { "value": 200, "unit": { "code": "hours" } },
      "percentage": 26.1
    }
  ]
}
```

## 活跃资源 TOP

使用量最大的资源排行：

```
GET /api/usage/top?limit=10&resource_type={type}
```

参数：
- `limit`：返回数量（默认 10）
- `resource_type`：按资源类型筛选（可选）

响应：
```json
{
  "items": [
    {
      "resource_id": "abc-def-123",
      "resource_name": "node-01",
      "resource_type": "baremetal",
      "total_duration_seconds": 604800,
      "total_metered_value": { "value": 168, "unit": { "code": "hours" } },
      "usage_count": 3,
      "first_start_time": 1704067200,
      "last_end_time": null
    }
  ]
}
```

## 单资源详细用量

### VM 用量详情

```
GET /api/usage/vm/{vm_id}
```

响应：
```json
{
  "vm_id": "vm-id",
  "vm_name": "my-vm",
  "metered_totals": {
    "gpu_hours": { "value": 100, "unit": { "code": "gpu_hours" } },
    "core_hours": { "value": 2400, "unit": { "code": "core_hours" } }
  },
  "daily_usage": {
    "2024-01-01": {
      "gpu_hours": { "value": 8, "unit": { "code": "gpu_hours" } }
    }
  }
}
```

### 磁盘用量详情

```
GET /api/usage/disk/{volume_id}
```

响应：
```json
{
  "volume_id": "vol-id",
  "volume_name": "data-disk-1",
  "total_gib_hours": { "value": 5000, "unit": { "code": "gib_hours" } },
  "daily_usage": {
    "2024-01-01": { "value": 100, "unit": { "code": "gib_hours" } }
  }
}
```

### 网络用量详情

```
GET /api/usage/network/{network_id}
```

响应：
```json
{
  "network_id": "net-id",
  "total_ingress": { "value": 50, "unit": { "code": "GB" } },
  "total_egress": { "value": 30, "unit": { "code": "GB" } },
  "daily_traffic": [
    {
      "date": "2024-01-01",
      "ingress_gb": 5.2,
      "egress_gb": 3.1,
      "unit": { "code": "GB" }
    }
  ]
}
```

## 用量历史明细

```
GET /api/usage/history?resource_type={type}&limit=20&offset=0
```

响应：
```json
{
  "items": [
    {
      "id": "record-id",
      "resource_type": "baremetal",
      "resource_id": "abc-def-123",
      "resource_name": "node-01",
      "start_time": 1704067200,
      "end_time": null,
      "duration_seconds": 86400,
      "status": "open"
    }
  ],
  "total": 50,
  "limit": 20,
  "offset": 0,
  "resource_type": "baremetal"
}
```

## 用量历史聚合

按资源 ID 聚合的历史数据：

```
GET /api/usage/history/aggregate?resource_type={type}&limit=20&offset=0
```

## 计量单位

```
GET /api/usage/units
```

返回所有计量单位定义（gpu_hours、core_hours、gib_hours 等）。

## 时间参数说明

所有支持时间范围的接口使用 Unix 时间戳（秒）：
- `start_time`：开始时间
- `end_time`：结束时间
- 不传则使用默认范围（通常为当月）

常用时间戳换算：
- 今天 0 点：`$(date -d "today 00:00" +%s)`
- 本月 1 日 0 点：`$(date -d "$(date +%Y-%m-01)" +%s)`
- 7 天前：`$(date -d "7 days ago" +%s)`

## 注意事项

- 时间参数使用 Unix 时间戳（秒），不是毫秒
- `last_end_time` 为 null 表示资源仍在使用中
- `usage_count` 表示计费记录条数，可能包含多次分配/释放周期
- 查看单资源用量前，先通过列表接口获取 resource_id
