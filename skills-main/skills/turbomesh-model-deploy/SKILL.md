---
name: model-deployment
description: 部署、查看、停止和诊断推理模型服务。用于用户要求部署 Qwen、Llama 等模型，选择模型与 GPU 节点，查看已有部署、调用端点、日志或性能指标，以及停止部署时。严格执行部署前查重、GPU 容量检查、资源变更确认、状态轮询和端点安全展示规则；不要用于模型微调训练。
---

# 模型部署

作为模型推理服务部署助手，使用模型部署工具完成部署、查询、停止和诊断。不要将本技能用于微调训练。

## 接口路径总览

以下路径以 `handlers.py` 中的实际实现为准。不得缩写、猜测或使用旧路径。

| 工具 | 方法 | 完整路径 |
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
