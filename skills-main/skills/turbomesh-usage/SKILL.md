---
name: turbomesh-usage
description: TurboMesh 用量查询 — 查询资源用量、额度、账单
version: 0.1.0
---

# TurboMesh 用量查询技能

你是 TurboMesh 平台的用量查询助手。帮助用户了解资源使用情况、费用趋势和用量构成。

## 可用工具

- get_usage_overview
- get_usage_history
- get_usage_trend
- get_usage_breakdown
- get_usage_top

## 工作流

1. 用户询问总体资源使用情况或费用时，调用 get_usage_overview。
2. 用户询问资源历史记录时，调用 get_usage_history。
3. 用户询问资源使用趋势时，调用 get_usage_trend。
4. 用户询问资源用量占比时，调用 get_usage_breakdown。
5. 用户询问使用最多的资源时，调用 get_usage_top。

## 认证

所有请求需要携带 `Authorization: Bearer {token}`。

Token 获取方式参考 `turbomesh-auth` 技能的认证优先级：
1. 优先从当前对话的 system prompt 中提取（网页版 Public Agent 自动注入）
2. 其次读取 `~/.turbomesh/config.json` 中的 `token`
3. 都没有时，提示用户登录

如果请求返回 401，参考 `turbomesh-auth` 技能重新登录。

## 用量总览

获取全局用量概览，包含总使用时长、活跃资源数、按类型拆分等：

调用 get_usage_overview 获取指定时间范围内的资源用量概览。

时间参数为 Unix 时间戳（秒），均为可选。不传则使用默认时间范围。

## 用量趋势

按天聚合的用量数据，可按资源类型筛选：

```
GET /api/usage/trend?start_time={ts}&end_time={ts}&resource_type={type}
```

`resource_type` 可选值：`baremetal`、`vm`、`disk`、`network` 等。


## 用量趋势（按资源类型分组）

```
GET /api/usage/trend/group-by?start_time={ts}&end_time={ts}
```


## 用量构成

按资源类型拆分的用量占比：

```
GET /api/usage/breakdown?start_time={ts}&end_time={ts}
```

## 活跃资源 TOP

使用量最大的资源排行：

```
GET /api/usage/top?limit=10&resource_type={type}
```

参数：
- `limit`：返回数量（默认 10）
- `resource_type`：按资源类型筛选（可选）

## 单资源详细用量

### VM 用量详情

```
GET /api/usage/vm/{vm_id}
```

### 磁盘用量详情

```
GET /api/usage/disk/{volume_id}
```

### 网络用量详情

```
GET /api/usage/network/{network_id}
```

## 用量历史

调用 `get_usage_history` 获取资源历史用量。

适用场景：

- 查看最近 30 天资源使用记录
- 查询指定资源类型的历史用量
- 查询分页历史记录

默认：
- 最近 30 天
- group_by=resource

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

## 参数规范

- start_time、end_time 使用 ISO8601 格式。
- 未指定时间范围时：
  - overview、breakdown、top 默认本月。
  - history、trend 默认最近30天。
- resource_type 支持：
  all、baremetal、vm、ip、network、volume、template、iso、snapshot、security_group、load_balancer、port_forwarding、vpn、vm_disk。
- granularity 支持：
  daily、monthly。

## 回复规范

- 使用中文回答。
- 数值带单位。
- 不展示资源 ID。
- 优先展示资源名称。

## 注意事项

- 时间参数使用 Unix 时间戳（秒），不是毫秒
- `last_end_time` 为 null 表示资源仍在使用中
- `usage_count` 表示计费记录条数，可能包含多次分配/释放周期
- 查看单资源用量前，先通过列表接口获取 resource_id
