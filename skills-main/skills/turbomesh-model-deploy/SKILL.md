---
name: turbomesh-model-deploy
description: Turbomesh 模型微调 — 部署、查看、停止和诊断模型推理服务
version: 0.1.0
---

# 模型部署

作为模型推理服务部署助手，使用模型部署工具完成部署、查询、停止和诊断。不要将本技能用于微调训练。

## 接口路径总览

以下路径以 `handlers.py` 中的实际实现为准。不得缩写、猜测或使用旧路径。

| 方法 | 请求方式 | 完整路径 |
|---|---|---|
| `model_deploy_list_models` | GET | `/api/modelcamp/model/info/list` |
| `model_deploy_list_nodes` | GET | `/api/modelcamp/node/deploy-list` |
| `model_deploy_list_deployments` | GET | `/api/modelcamp/model/deploy/list` |
| `model_deploy_get_deployment` | GET | `/api/modelcamp/model/deploy/monitor?id={deploy_id}` |
| `model_deploy_deploy_model` | POST | `/api/modelcamp/model/deploy/create` |
| `model_deploy_stop_deployment` | POST | `/api/modelcamp/model/deploy/stop` |
| `model_deploy_get_deployment_logs` | POST | `/api/modelcamp/model/deploy/{deploy_id}/logs` |
| `model_deploy_get_deployment_metrics` | GET | `/api/modelcamp/model/{deploy_id}/metrics/current` |
| `model_deploy_get_deployment_endpoint` | GET | `/api/modelcamp/model/deploy/monitor?id={deploy_id}` |
| `model_deploy_get_deployment_detail` | GET | `/api/modelcamp/model/deploy/detail?id={deploy_id}` |


## 强制规则

1. 不直接展示节点内网 IP，即使工具返回该字段。
2. 部署前检查 GPU 容量，不允许超分。将“单卡已用显存不超过总显存的 10%”视为空闲标准，并确认目标节点有足够空闲显存和 GPU 数量。
3. `model_deploy_deploy_model` 会同时创建部署记录并下发任务，同一方案只调用一次。
4. 部署和停止均属于资源变更操作。调用相应工具前，必须通过 `clarify` 获取明确确认，并在工具调用中设置 `confirmed=true`。
5. 已停止部署再次停止应按幂等操作处理。
6. 不在 Markdown 表格单元格中放置端点地址，以免影响复制。

## 端点展示规则

部署成功后按以下优先级展示可用地址：

1. 展示 `public_proxy_url`（外网访问地址），如果存在。
2. 展示 VE 地址，优先读取 `tokenbill_ve_url`，兼容旧字段 `ve_url`。
3. 当上述地址均不存在时，展示 `endpoint` 直连地址。
4. 当只有部分字段存在时，仅展示存在的字段。
5. 将所有地址写成可点击、可复制的 Markdown 链接，例如 `<http://...>` 或 `[http://...](http://...)`。
6. 若部署结果包含 `modelcamp_url`，展示 `[查看我的部署](modelcamp_url)`。
7. 用户要求“在浏览器打开”或同义表达时，调用 `open_page(url=modelcamp_url, title="查看我的部署")`。

## 部署模型

1. 先调用 `model_deploy_list_deployments` ，检查用户是否已有同一模型的运行中部署。
2. 若已有运行中部署，优先返回其状态和调用端点。仅当用户明确坚持新增部署时继续。
3. 若没有合适的现有部署，调用 `model_deploy_list_models`获取候选模型，并让用户选择具体模型。
4. 用户选定模型后，调用 `model_deploy_list_nodes`检查节点、空闲卡数和显存余量，推荐满足要求的节点。
5. 直接在 `clarify` 的 `question` 中使用 Markdown 表格展示方案预览，至少包含模型名、节点名和所需 GPU 数。不要先用普通回复展示该预览。
6. 使用类似 `clarify(question=..., options=["确认", "取消"])` 的方式等待确认。
7. 用户确认后，调用 `model_deploy_deploy_model(model_id=..., node_id=..., confirmed=true)`，且只调用一次。
8. 提交后立即返回 `task_id`，说明任务已提交；不要把预估完成时间表述为保证。
9. 轮询 `model_deploy_get_deployment`，直到状态为 `running`，或出现明确失败状态。
10. 状态为 `running` 后，调用 `model_deploy_get_deployment_endpoint`获取端点。
11. 用户需要调用示例时，调用 `model_deploy_get_deployment_detail`，优先直接使用返回的 `snippets`。
12. 使用 `task_done(summary="...")` 返回最终结果。摘要必须包含模型名称、节点、状态、端点地址和 ModelCamp 部署链接（若存在）。

## 查看已有部署

1. 调用 `model_deploy_list_deployments`。
2. 使用 Markdown 表格汇总模型名称、节点和状态。
3. 将端点地址放在表格外，按“端点展示规则”输出。
4. 使用 `task_done(summary="...")` 返回结果。

## 停止部署

1. 调用 `model_deploy_list_deployments`定位目标部署。
2. 若目标不唯一，基于模型名、节点和状态帮助用户消歧。
3. 调用 `clarify` 展示停止确认，明确说明容器将被销毁且不可恢复。
4. 用户确认后，调用 `model_deploy_stop_deployment(deploy_id=..., confirmed=true)`。
5. 使用 `task_done(summary="...")` 返回停止结果。

## 查看日志或指标

1. 调用 `model_deploy_list_deployments`定位目标部署。
2. 查看日志时调用 `model_deploy_get_deployment_logs(deploy_id=...)` 。
3. 查看指标时调用 `model_deploy_get_deployment_metrics(deploy_id=...)`。
4. 对日志提炼关键错误、时间点和可能原因；不要仅原样倾倒大量日志。
5. 对指标突出请求量、延迟、吞吐量和异常变化。
6. 使用 `task_done(summary="...")` 返回结果。

## 失败处理

- 模型不存在时，重新调用模型列表并提供可选项。
- 节点资源不足时，不提交部署；推荐其他满足条件的节点或更小模型。
- 部署失败时，报告工具返回的失败状态和错误信息，并在需要时获取日志辅助定位。
- 缺少 `modelcamp_url` 时，不尝试调用 `open_page`。
- 缺少所有可用端点字段时，明确说明尚未获得可调用地址，不要构造地址。

## 工具请求参数说明

只传入工具声明的公开参数。模型、节点和部署 ID 必须来自工具真实返回，不得根据名称自行编造。

### 参数总表

| 参数          | 类型/默认值                              | 含义与限制                                                                                          |
| ----------- | ----------------------------------- | ---------------------------------------------------------------------------------------------- |
| `model_id`  | `string`，部署时必填                      | 模型唯一 ID，必须来自 `model_deploy_list_models`，不要使用模型名称代替。                                            |
| `node_id`   | `string`，部署时必填                      | 目标 GPU 节点 ID，必须来自 `model_deploy_list_nodes`。选择前确认节点状态、空闲卡数和剩余显存满足模型要求。                         |
| `deploy_id` | `string`                            | 模型部署实例 ID，必须来自部署结果或 `model_deploy_list_deployments`，用于查询监控、端点、详情、日志、指标和停止部署。不要与 `model_id` 混用。 |
| `vram_gb`   | `integer`，可选                        | 按所需显存（GB）筛选可用节点；不传时查询全部节点。它表示模型部署所需显存，不是节点总显存。                                                 |
| `status`    | `running/pending/failed/stopped`，可选 | 按状态筛选部署列表；不传时返回全部状态。`running` 为运行中，`pending` 为处理中，`failed` 为失败，`stopped` 为已停止。                 |
| `confirmed` | `boolean`，部署和停止时必填                  | 用户通过 `clarify` 明确确认后才能设为 `true`。该参数只用于工具侧安全检查，不会发送给后端业务接口。                                     |
| `lines`     | `integer`，默认 `300`                  | 获取容器日志时返回的尾部行数，只控制日志数量，不表示时间范围。                                                                |

### 工具参数速查

| 工具                                     | 请求参数                                | 关键要求                                                                                               |
| -------------------------------------- | ----------------------------------- | -------------------------------------------------------------------------------------------------- |
| `model_deploy_list_models`             | 无                                   | 查询可部署模型。handler 内部固定使用 `page=1`、`page_size=100`，分页值不是公开参数。                                         |
| `model_deploy_list_nodes`              | `vram_gb` 可选                        | 查询 GPU 节点；不得展示节点内网 IP。推荐节点前检查剩余显存和空闲 GPU 是否满足模型需求。                                                 |
| `model_deploy_list_deployments`        | `status` 可选                         | 查询已有部署。handler 内部固定使用 `page=1`、`page_size=50`，不得传分页参数。                                             |
| `model_deploy_get_deployment`          | `deploy_id`                         | 获取部署监控信息，包括状态、容器、端口、GPU 分配和端点。handler 会将 `deploy_id` 映射为后端参数 `id`。                                 |
| `model_deploy_deploy_model`            | `model_id`、`node_id`、`confirmed` 必填 | 部署前必须确认模型、检查节点资源并通过 `clarify` 展示方案。handler 实际发送的业务字段只有 `model_id` 和 `node_id`；部署为异步任务，提交成功后禁止重复调用。 |
| `model_deploy_stop_deployment`         | `deploy_id`、`confirmed` 必填          | 停止后容器会被销毁，调用前必须确认。handler 将 `deploy_id` 映射为业务字段 `id`，`confirmed` 不发送给后端。                           |
| `model_deploy_get_deployment_logs`     | `deploy_id` 必填，`lines` 可选           | 获取容器日志，`lines` 默认 `300`。失败时如实说明错误，不得声称已成功。                                                         |
| `model_deploy_get_deployment_metrics`  | `deploy_id`                         | 获取并发数、排队数、KV Cache 使用率、吞吐量和延迟等实时指标。                                                                |
| `model_deploy_get_deployment_endpoint` | `deploy_id`                         | 获取调用端点。优先展示 `public_proxy_url` 和 `tokenbill_ve_url`/`ve_url`；均不存在时再展示 `endpoint`。                  |
| `model_deploy_get_deployment_detail`   | `deploy_id`                         | 获取端点配置、模型属性及 Python、curl、JavaScript 调用代码。                                                          |

### 统一规则

1. `model_id`、`node_id`、`deploy_id` 含义不同，不得混用。
2. 所有 ID 必须来自最近一次工具查询或部署结果。
3. 工具未声明的参数禁止传入；`page`、`page_size` 和后端字段 `id` 均由 handler 内部处理。
4. 部署和停止必须先通过 `clarify` 确认，再传 `confirmed=true`。
5. 部署前必须检查 GPU 资源，不得超分或推荐显存不足的节点。
6. 禁止展示节点内网 IP；端点只展示工具真实返回的可访问地址。
7. 部署是异步操作，提交成功后通过部署查询工具轮询状态，不得重复创建。

