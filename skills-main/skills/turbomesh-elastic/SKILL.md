---
name: turbomesh-elastic
description: 管理现有弹性服务，并执行安全的查看、扩缩容、配置更新、YAML 编辑、Ingress 调整、日志排查和资源选择辅助。用于用户询问弹性部署列表或详情、修改副本和弹性策略、更新运行配置、编辑部署 YAML、配置域名/TLS、查看 Pod 日志或生命周期事件时。此技能不创建、删除或释放部署；所有资源变更必须先展示方案并获得明确确认。
version: 0.1.0
---

# 弹性服务管理

帮助用户安全地查看和管理现有弹性部署。严格遵循工具白名单、确认机制、信息脱敏和页面跳转规则。

## 接口路径总览

以下路径以 `handlers.py` 中的实际实现为准。不得缩写、猜测或使用旧路径。

| 方法 | 请求方式 | 完整路径 |
|---|---|---|
| `get_elastic_app` | GET | `/api/elastic/{id_or_name}` |
| `scale_elastic_app` | GET/PUT | `/api/elastic/{id_or_name}` `/api/elastic/{deploy_id}`|
| `preview_elastic_app_config_update` | POST | `/api/elastic/preview` |
| `update_elastic_app_config` | PUT | `/api/elastic/{deploy_id}` |
| `update_elastic_app_manual_yaml` | PUT | `/api/elastic/{name} (manual_yaml)` |
| `get_elastic_app_logs` | GET | `/api/elastic/{name}/logs/{pod_name}` |
| `update_elastic_app_ingress` | PUT | `/api/elastic/{name}/ingress` |
| `list_zones` | GET | `/api/zone` |
| `list_compute_offerings` | GET | `/api/offerings/vm?zone_id={zone_id}&keyword={keyword!r}` |
| `list_k8s_clusters` | GET | `/api/k8s` |
| `list_k8s_versions` | GET | `/api/offerings/k8s-version?zone_id={zone_id}` |
| `list_templates` | GET | `/api/templates?zone_id={zone_id}&filter={template_filter}` |
| `list_sharedfs` | GET | `/api/sharedfs?zone_id={zone_id}` |
| `get_events` | GET | `/api/events (resource_id={resource_id})` |


## 核心原则

1. 只管理现有部署，不创建、删除或释放弹性部署。
2. 仅调用当前可用工具中明确存在的工具，不猜测或构造工具名。
3. 扩缩容、配置更新、手工 YAML 提交和 Ingress 更新都属于资源变更，必须先展示方案，再通过 `clarify` 获取明确确认，确认后传入 `confirmed=true`。
4. 不直接暴露内部 IP、kubeconfig、凭据、密钥或完整原始 JSON。
5. 普通配置场景只展示参数级差异，不粘贴整段 YAML；仅当用户明确查看或编辑 YAML 时讨论 `generated_yaml` 或 `manual_yaml`。
6. 工具调用失败时如实说明错误原因。任何变更工具失败后都不得声称操作成功。
7. 将工具返回整理为面向用户的摘要，优先展示名称、状态、副本、策略、时间和关键配置。

## 工具边界

可用工具及参数规则见 [references/api_reference.md](references/api_reference.md)。需要确认工具名、策略参数或页面路径时先读取该文件。

## 页面跳转

- 用户查看部署列表时，调用：
  `open_page(url="/console/elastic", title="弹性部署列表")`
- 用户查看单个部署详情，或完成扩缩容、配置更新、YAML 编辑、Ingress 更新后，调用：
  `open_page(url="/console/elastic/{deployment_id}", title="弹性部署详情")`
- 只有用户明确要求在浏览器打开外部访问地址时，才对外部 Ingress 地址调用 `open_page(url=<外部地址>, title="访问地址")`。

## 查看部署

1. 调用 `list_elastic_apps`获取当前部署。
2. 用简洁表格展示名称、状态、ready/total、副本范围和策略。
3. 调用 `open_page(url="/console/elastic", title="弹性部署列表")` 打开列表页。
4. 用户指定部署后，调用 `get_elastic_app` 获取详情。
5. 摘要展示状态、当前副本、扩缩容策略、Pod 概况、公开访问配置和最近事件；隐藏内部地址和敏感数据。
6. 调用部署详情页跳转并使用 `task_done` 总结。

## 调整扩缩容

1. 先调用 `list_elastic_apps` GET /api/elastic 确认目标：
   - 没有部署：直接告知用户。
   - 只有一个部署：可直接选用。
   - 多个部署且目标不明确：通过 `clarify` 让用户选择。
2. 调用 `get_elastic_app` GET /api/elastic/{id_or_name} 获取当前副本和 scaling 配置。
3. 根据用户意图生成方案，包括 `strategy`、`min_replicas`、`max_replicas` 和对应 target。
4. 直接在 `clarify` 的问题中展示方案预览和关键变化，等待“确认/取消”。不要在普通回复中默认用户同意。
5. 确认后调用 `scale_elastic_app(..., confirmed=true)` 。
6. 如实展示提交结果，并说明变更通常异步执行，可调用 `get_events` 查看进度。
7. 打开部署详情页并调用 `task_done`。

### 策略映射

- 固定副本：`strategy=manual`，并确保 `min_replicas == max_replicas`。
- CPU：`strategy=cpu`，使用 `target_cpu_utilization`。
- 内存：`strategy=memory`，使用 `target_memory_utilization`。
- RPS/QPS：`strategy=rps`，使用 `target_rps`。说明该值表示 KEDA HTTP pending/in-flight 阈值，不是严格业务 QPS。
- 队列：`strategy=queue`，使用 `target_queue_size`。
- TPS、TTFT、延迟、并发请求数不能直接传给扩缩容工具。用户只提供这些指标时，先解释可用策略，再让用户选择和确认。

## 更新表单配置

1. 调用 `get_elastic_app`获取当前配置。
2. 根据用户要求形成新配置。
3. 调用 `preview_elastic_app_config_update`生成预览。
4. 只向用户展示参数级差异，例如镜像、命令、环境变量、资源规格、端口或挂载变化；不要展示完整 YAML。
5. 在 `clarify` 中展示变更摘要并获取确认。
6. 确认后调用 `update_elastic_app_config(..., confirmed=true)`。
7. 说明配置将异步下发，可调用 `get_events` 查看进度。
8. 打开部署详情页并调用 `task_done`。

## 编辑 YAML

1. 仅当用户明确要求查看或编辑 YAML 时进入该流程。
2. 调用 `get_elastic_app`获取 `generated_yaml` 。
3. 围绕用户指定的 YAML 修改进行说明，提醒手工 YAML 会覆盖系统生成结果。
4. 用户确认最终内容后，再调用 `update_elastic_app_manual_yaml(..., confirmed=true)` 。
5. 不在未确认时提交，也不要自动修复后直接提交。
6. 打开部署详情页并调用 `task_done`。

## 更新 Ingress

1. 先确认目标部署、服务端口、域名、路径和 TLS 配置。
2. 展示规则预览，并通过 `clarify` 获取确认。
3. 确认后调用 `update_elastic_app_ingress(..., confirmed=true)` PUT /api/elastic/{name}/ingress。
4. 工具失败时原样解释可理解的失败原因，并引导用户到控制台查看；不得称更新成功。
5. 打开部署详情页并调用 `task_done`。

## 查看日志和事件

### 日志

1. 调用 `get_elastic_app`获取 Pod 列表。
2. 目标 Pod 不明确时让用户选择；只有一个 Pod 时可直接使用。
3. 调用 `get_elastic_app_logs`。
4. 提炼错误、重启、OOM、探针失败、启动耗时等关键信息，不堆叠全部日志。
5. 工具失败时如实说明后端返回，并引导用户到控制台。

### 生命周期事件

1. 调用 `get_events`获取部署事件。
2. 按时间整理关键事件，突出调度失败、镜像拉取失败、探针异常、扩缩容和配置下发状态。
3. 不展示原始内部对象或敏感字段。

## 资源选择辅助

- 可用区：调用 `list_zones`e。
- 计算方案：调用 `list_compute_offerings`，默认用于弹性服务或 K8s workload 规格建议。
- Kubernetes 集群：调用 `list_k8s_clusters` 。
- Kubernetes 版本：调用 `list_k8s_versions`。
- 节点模板：调用 `list_templates` 。
- 共享文件系统：调用 `list_sharedfs`。

只提供解释和建议，不尝试创建新部署或用更新工具模拟创建操作。

## 不支持的请求

用户要求新建、创建、删除、释放弹性部署时：

1. 明确说明当前技能不提供创建和删除能力。
2. 引导用户前往控制台操作。
3. 不调用任何更新、扩缩容或 YAML 工具替代创建或删除。
4. 可调用 `open_page(url="/console/elastic", title="弹性部署列表")` 帮助用户进入控制台。

## 工具请求参数说明

只传入工具定义中声明的公开参数。部署 ID、名称、Pod 名、可用区和资源 ID 必须来自工具真实返回，不得猜测或编造。

### 参数总表

| 参数                              | 类型/默认值                                            | 含义与限制                                                                                             |
| ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `id_or_name`                    | `string`                                          | 弹性部署 ID 或名称，用于查询详情和扩缩容；存在重名风险时优先使用 ID。                                                            |
| `id`                            | `string`                                          | 弹性部署 ID，仅用于提交完整配置更新，必须来自部署详情或列表。                                                                  |
| `name`                          | `string`                                          | 弹性部署名称，用于 YAML、日志和 Ingress 操作，不要使用 ID 代替。                                                         |
| `confirmed`                     | `boolean`                                         | 扩缩容、配置更新、YAML 提交和 Ingress 更新时必须为 `true`；只能在用户通过确认流程明确同意后设置，不发送为业务配置。                              |
| `strategy`                      | `manual/cpu/memory/rps/queue`                     | 扩缩容策略：`manual` 固定副本；其余分别按 CPU、内存、RPS 或队列长度自动扩缩。                                                   |
| `min_replicas` / `max_replicas` | `integer ≥ 0`                                     | 最小和最大副本数。`manual` 要求二者相等；自动扩缩容要求 `min_replicas < max_replicas`。                                   |
| `target_cpu_utilization`        | `1–100`                                           | CPU 目标利用率，仅在 `strategy=cpu` 时使用。                                                                  |
| `target_memory_utilization`     | `1–100`                                           | 内存目标利用率，仅在 `strategy=memory` 时使用。                                                                 |
| `target_rps`                    | `integer ≥ 1`                                     | RPS 扩缩容阈值，仅在 `strategy=rps` 时使用；表示 KEDA HTTP pending/in-flight 阈值，不等同于严格业务 QPS。                   |
| `target_queue_size`             | `integer ≥ 1`                                     | 队列长度阈值，仅在 `strategy=queue` 时使用。                                                                   |
| `cooldown_period`               | `integer ≥ 0`，通常默认 `300` 秒                        | 缩容前的冷却或空闲等待时间；不传时保留部署当前配置或后端默认值。                                                                  |
| `execution_timeout`             | `1–86400` 秒，通常默认 `600`                            | 弹性任务执行超时；不传时保留当前配置或后端默认值。                                                                         |
| `payload`                       | `object`                                          | 完整弹性部署配置对象。预览和正式更新应使用同一份完整配置，不能只传局部变更；应基于 `get_elastic_app` 当前配置修改，避免覆盖未修改字段。                     |
| `manual_yaml`                   | 非空 `string`                                       | 用户编辑后的完整 K8s YAML，会覆盖系统生成 YAML；提交前必须明确说明覆盖风险。                                                     |
| `pod_name`                      | `string`                                          | 目标 Pod 名，通常来自部署详情中的实例列表，不得自行拼接。                                                                   |
| `namespace`                     | `string`，默认 `turbomesh`                           | Kubernetes namespace，用于日志和 Ingress；未明确使用其他 namespace 时保持默认值。                                      |
| `tail_lines`                    | `1–10000`，默认 `500`                                | 返回的日志尾部行数，只控制行数，不代表时间范围。                                                                          |
| `enabled`                       | `boolean`，handler 默认 `true`                       | 是否启用 Ingress。工具未传时 handler 会按 `true` 处理。                                                          |
| `enable_tls`                    | `boolean`，默认 `false`                              | 是否启用 TLS；启用前应确认域名和证书条件。                                                                           |
| `rules`                         | `array`                                           | Ingress 规则列表。每项包含 `domain`、`service_port`，可选 `path` 和 `path_type`。                                |
| `domain`                        | `string`                                          | Ingress 域名，必须由用户提供或来自已确认配置。                                                                       |
| `service_port`                  | `integer`                                         | Ingress 转发的服务端口，必须与部署实际暴露端口一致。                                                                    |
| `path`                          | `string`，默认 `/`                                   | Ingress URL 路径。                                                                                   |
| `path_type`                     | `Prefix/Exact/ImplementationSpecific`，默认 `Prefix` | Kubernetes Ingress 路径匹配方式。                                                                        |
| `zone_id`                       | `string`                                          | 可用区 ID，必须来自 `list_zones`，用于计算方案、K8s 版本、模板和共享文件系统查询。                                               |
| `keyword`                       | `string`，可选                                       | 计算方案名称过滤词。`tools.json` 描述建议默认使用 `k8s`，但 handler 未自动补该默认值；需要 K8s 规格时应明确传 `k8s`，不传或传空字符串时按后端实际结果处理。 |
| `template_filter`               | `string`，默认 `executable`                          | 模板过滤类型；未传时 handler 使用 `executable`。                                                               |
| `resource_id`                   | `string`                                          | 查询事件的资源 ID，通常为弹性部署 ID。                                                                            |
| `resource_type`                 | `string`，默认 `elastic`                             | 事件资源类型；弹性部署场景保持 `elastic`。                                                                        |

### 工具参数速查

| 工具                                  | 请求参数                                                                                                                    | 关键要求                                                    |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `list_elastic_apps`                 | 无                                                                                                                       | 返回部署摘要列表。                                               |
| `get_elastic_app`                   | `id_or_name`                                                                                                            | 查询单个部署；返回内容会过滤 `kubeconfig` 和节点内部 IP。                   |
| `scale_elastic_app`                 | `id_or_name`、`strategy`、`min_replicas`、`max_replicas`、`confirmed` 必填；各类 target、`cooldown_period`、`execution_timeout` 可选 | 只修改 scaling 配置，其余配置由 handler 从当前部署中保留；参数关系不满足要求时不得静默修正。 |
| `preview_elastic_app_config_update` | `payload`                                                                                                               | 仅生成配置预览，不提交；`payload` 必须为完整配置对象。                        |
| `update_elastic_app_config`         | `id`、`payload`、`confirmed`                                                                                              | 提交完整配置并重新生成 K8s YAML；应使用确认过的预览配置。                       |
| `update_elastic_app_manual_yaml`    | `name`、`manual_yaml`、`confirmed`                                                                                        | `manual_yaml` 必须是非空完整 YAML，会覆盖系统生成结果。                   |
| `get_elastic_app_logs`              | `name`、`pod_name` 必填；`namespace`、`tail_lines` 可选                                                                        | Pod 名应来自部署详情；默认 namespace 为 `turbomesh`、日志行数为 `500`。    |
| `update_elastic_app_ingress`        | `name`、`rules`、`confirmed` 必填；`namespace`、`enabled`、`enable_tls` 可选                                                     | `rules` 必须为数组；handler 默认启用 Ingress、关闭 TLS。              |
| `list_zones`                        | 无                                                                                                                       | 获取后续资源查询所需的真实 `zone_id`。                                |
| `list_compute_offerings`            | `zone_id` 必填；`keyword` 可选                                                                                               | `keyword` 只做名称过滤；需要弹性服务规格时建议明确传 `k8s`。                  |
| `list_k8s_clusters`                 | 无                                                                                                                       | 查询用户已有 Kubernetes 集群。                                   |
| `list_k8s_versions`                 | `zone_id`                                                                                                               | 查询指定可用区支持的 Kubernetes 版本。                               |
| `list_templates`                    | `zone_id` 必填；`template_filter` 可选                                                                                       | `template_filter` 默认 `executable`。                      |
| `list_sharedfs`                     | `zone_id`                                                                                                               | 查询指定可用区的共享文件系统。                                         |
| `get_events`                        | `resource_id` 必填；`resource_type` 可选                                                                                     | 弹性部署场景中 `resource_type` 默认并保持为 `elastic`。               |

### 统一规则

1. `id_or_name`、`id` 和 `name` 用途不同，不得随意互换。
2. `payload` 必须是完整配置，不要只传用户要求修改的局部字段。
3. 扩缩容、配置更新、YAML 提交和 Ingress 更新必须先确认，再传 `confirmed=true`。
4. TPS、TTFT、延迟和并发数不是扩缩容工具参数，不能直接映射后提交。
5. 工具未声明的参数不得传入，也不得暴露 `kubeconfig`、内部 IP、凭据或完整敏感原始数据。
6. 更新操作失败时必须如实返回错误，不得声称已成功。


