---
name: turbomesh-elastic
description: 管理现有弹性服务，并执行安全的查看、扩缩容、配置更新、YAML 编辑、Ingress 调整、日志排查和资源选择辅助。用于用户询问弹性部署列表或详情、修改副本和弹性策略、更新运行配置、编辑部署 YAML、配置域名/TLS、查看 Pod 日志或生命周期事件时。此技能不创建、删除或释放部署；所有资源变更必须先展示方案并获得明确确认。
---

# 弹性服务管理

帮助用户安全地查看和管理现有弹性部署。严格遵循工具白名单、确认机制、信息脱敏和页面跳转规则。

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

1. 调用 `list_elastic_apps` GET /api/elastic 获取当前部署。
2. 用简洁表格展示名称、状态、ready/total、副本范围和策略。
3. 调用 `open_page(url="/console/elastic", title="弹性部署列表")` 打开列表页。
4. 用户指定部署后，调用 `get_elastic_app` GET /api/elastic/{id_or_name} 获取详情。
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
5. 确认后调用 `scale_elastic_app(..., confirmed=true)` 1.GET /api/elastic/{id_or_name} 2.PUT /api/elastic/{deploy_id}。
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

1. 调用 `get_elastic_app` GET /api/elastic/{id_or_name} 获取当前配置。
2. 根据用户要求形成新配置。
3. 调用 `preview_elastic_app_config_update` POST /api/elastic/preview 生成预览。
4. 只向用户展示参数级差异，例如镜像、命令、环境变量、资源规格、端口或挂载变化；不要展示完整 YAML。
5. 在 `clarify` 中展示变更摘要并获取确认。
6. 确认后调用 `update_elastic_app_config(..., confirmed=true)` PUT /api/elastic/{deploy_id}。
7. 说明配置将异步下发，可调用 `get_events` 查看进度。
8. 打开部署详情页并调用 `task_done`。

## 编辑 YAML

1. 仅当用户明确要求查看或编辑 YAML 时进入该流程。
2. 调用 `get_elastic_app` GET /api/elastic/{id_or_name} 获取 `generated_yaml` 。
3. 围绕用户指定的 YAML 修改进行说明，提醒手工 YAML 会覆盖系统生成结果。
4. 用户确认最终内容后，再调用 `update_elastic_app_manual_yaml(..., confirmed=true)` PUT /api/elastic/{name} (manual_yaml)。
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

1. 调用 `get_elastic_app` GET /api/elastic/{id_or_name} 获取 Pod 列表。
2. 目标 Pod 不明确时让用户选择；只有一个 Pod 时可直接使用。
3. 调用 `get_elastic_app_logs` GET /api/elastic/{name}/logs/{pod_name}。
4. 提炼错误、重启、OOM、探针失败、启动耗时等关键信息，不堆叠全部日志。
5. 工具失败时如实说明后端返回，并引导用户到控制台。

### 生命周期事件

1. 调用 `get_events` GET /api/events (resource_id={resource_id}) 获取部署事件。
2. 按时间整理关键事件，突出调度失败、镜像拉取失败、探针异常、扩缩容和配置下发状态。
3. 不展示原始内部对象或敏感字段。

## 资源选择辅助

- 可用区：调用 `list_zones` GET /api/zone。
- 计算方案：调用 `list_compute_offerings` GET /api/offerings/vm (zone_id={zone_id}, keyword={keyword!r})，默认用于弹性服务或 K8s workload 规格建议。
- Kubernetes 集群：调用 `list_k8s_clusters` GET /api/k8s。
- Kubernetes 版本：调用 `list_k8s_versions`GET /api/offerings/k8s-version (zone_id={zone_id})。
- 节点模板：调用 `list_templates` GET /api/templates (zone_id={zone_id}, filter={template_filter})。
- 共享文件系统：调用 `list_sharedfs` GET /api/sharedfs (zone_id={zone_id})。

只提供解释和建议，不尝试创建新部署或用更新工具模拟创建操作。

## 不支持的请求

用户要求新建、创建、删除、释放弹性部署时：

1. 明确说明当前技能不提供创建和删除能力。
2. 引导用户前往控制台操作。
3. 不调用任何更新、扩缩容或 YAML 工具替代创建或删除。
4. 可调用 `open_page(url="/console/elastic", title="弹性部署列表")` 帮助用户进入控制台。
