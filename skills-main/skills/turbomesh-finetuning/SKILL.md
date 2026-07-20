---
name: turbomesh-finetuning
description: Turbomesh 模型微调 — 管理微调实验、训练任务、效果对比与模型发布
version: 0.1.0
---

# FineTuning 模型微调

帮助用户发现资源、配置实验、启动远程微调任务、查看训练状态、对比模型效果并发布模型。

## 接口路径总览

以下路径以 `handlers.py` 中的实际实现为准。不得缩写、猜测或使用旧路径。

| 分类 | 方法 | HTTP 调用 |
|------|------|-----------|
| **资源发现** | `finetuning_list_models` | `GET /api/finetune/app/asset-refs/models` |
| | `finetuning_list_datasets` | `GET /api/finetune/app/asset-refs/datasets` |
| | `finetuning_preview_dataset` | `GET /api/finetune/app/datasets/{id}/preview?limit=N` |
| | `finetuning_check_worker_node` | `GET /api/finetune/app/execution-nodes/{node_id}` |
| **Experiment** | `finetuning_create_experiment` | `POST /api/finetune/app/experiments` |
| **参数编辑** | `finetuning_get_experiment_parameters` | `GET /api/finetune/app/experiments/{id}/parameters` |
| | `finetuning_update_experiment_parameters` | `PATCH /api/finetune/app/experiments/{id}/parameters` |
| **训练 Job** | `finetuning_launch_training_job` | `POST /api/finetune/app/train-jobs` |
| | `finetuning_get_job` | `GET /api/finetune/app/train-jobs/{id}` |
| | `finetuning_list_jobs` | `GET /api/finetune/app/train-jobs` |
| | `finetuning_stop_job` | `POST /api/finetune/app/train-jobs/{id}/stop` |
| | `finetuning_delete_job` | `DELETE /api/finetune/app/train-jobs/{id}` |
| | `finetuning_get_job_logs` | `GET /api/finetune/app/train-jobs/{id}/logs` |
| **Training Runs** | `finetuning_list_training_runs` | `GET /api/finetune/app/training-runs?page=N&page_size=M` |
| | `finetuning_get_training_run` | `GET /api/finetune/app/training-runs/{run_id}` |
| **Compare Chat** | `finetuning_compare_chat` | `POST /api/finetune/app/training-runs/{run_id}/compare-chat` |
| **发布** | `finetuning_get_publish_status` | `GET /api/finetune/app/experiments/{id}/publish-status` |
| | `finetuning_publish_model` | `POST /api/finetune/app/experiments/{id}/publish` |


禁止编造或调用相似名称的工具。尤其不要调用任何包含以下名称的工具：

- `start_experiment`
- `launch_experiment`
- `run_experiment`
- `get_experiment_logs`
- `compare_models`
- `compare_model_outputs`

## 核心规则

1. 优先通过 `finetuning_list_models` 和 `finetuning_list_datasets`发现资产。
2. 仅使用最近一次资源列表工具真实返回的 ID、名称、样本数和规格。禁止猜测或伪造资源信息。
3. 创建 Experiment 时直接绑定 `model_ref_id`、`primary_dataset_ref_id` 和 `dataset_ref_ids`。
4. 不要向 `finetuning_create_experiment`传入已废弃的 `goal` 字段。
5. 仅通过 Experiment 参数工具读取或修改训练参数。
6. 仅允许修改以下 7 个安全参数：
   - `num_train_epochs`
   - `learning_rate`
   - `per_device_train_batch_size`
   - `cutoff_len`
   - `max_samples`
   - `lora_rank`
   - `warmup_ratio`
7. 统一按 Remote 模式执行。新建 Job 后状态为 `PENDING`，等待 Worker 认领。
8. Job 处于 `PENDING`、`RUNNING` 或 `STOPPED` 时，视为 Experiment 已锁定，不得编辑参数。仅在 `SUCCESS` 或 `FAILED` 后解锁。
9. 启动、停止、删除和发布属于资源变更操作，必须先通过 `clarify` 获得用户明确确认。
10. 列表接口按分页对象理解，字段通常为 `total`、`page`、`page_size` 和 `list`。训练运行列表兼容 `limit`、`offset`。
11. 面向用户提炼展示 ID、状态、时间、错误和下一步，不要堆叠原始 JSON。
12. 用户输入的资源名称与真实资源不完全匹配时，展示最接近的真实选项，并通过 `clarify` 让用户确认。
13. 不需要用到MCP服务

## 完整微调流程

当用户要求微调模型、使用指定数据集训练模型，或完成一次训练并对比效果时：

1. 用户未完整指定模型或数据集时，同时调用：
   - `finetuning_list_models()`
   - `finetuning_list_datasets()`
2. 用户需要查看数据内容时，调用 `finetuning_preview_dataset(...)`。
3. 用一次 `clarify` 让用户选择真实存在的模型和数据集组合。选项中直接展示最近一次列表返回的名称和 ID，避免分多轮询问。
4. 记录选中的 ref ID，后续直接复用，不要重复询问。
5. 调用 `finetuning_create_experiment(...)`创建 Experiment。不要传入 `goal`。
6. 调用 `finetuning_get_experiment_parameters(experiment_id="exp_xxx")`获取当前参数。
7. 生成包含模型、数据集、Experiment ID、Remote 模式和训练参数的 Markdown 表格。
8. 将方案表格直接写入 `clarify` 的 `question`，并使用 `options=["确认", "取消"]`。禁止先用普通回复输出方案，再调用 `clarify`。
9. 用户明确确认后，只调用：

```text
finetuning_launch_training_job(
  experiment_id="exp_xxx",
  confirmed=true
)
```


仅当当前工具契约明确支持时才传 `run_name`。禁止改用其他启动工具。

10. 记录返回的 `job_id`、状态和 `modelcamp_url`。
11. 最终结果必须包含模型、数据集、状态、Experiment ID、Job ID 和 `[查看微调详情](modelcamp_url)`。
12. ModelCamp 链接不要放在 Markdown 表格单元格中，以免影响复制。
13. 用户要求监控时，调用 `finetuning_get_job(job_id=...)` ；需要诊断时调用 `finetuning_get_job_logs(job_id=...)`。

## 对比模型效果

当用户要求比较基座模型和微调模型时：

1. 调用 `finetuning_get_job(job_id=...)`，确认 Job 已处于 `SUCCESS` 或 `FAILED`。
2. 调用 `finetuning_check_worker_node(node_id="worker-1")`，确认 Worker 在线且支持 Compare Chat。
3. 用户未提供测试问题时，通过 `clarify` 询问一个测试问题。
4. 每次只调用一次：

```text
finetuning_compare_chat(
  job_id="job_xxx",
  messages=[{"role":"user","content":"用户指定的问题"}]
)
```

5. 不要传入 `model_ref_id`、`query`、`prompts` 或 `base_model_id`。
6. 不要自动连续测试多个问题。

## 查看日志和诊断失败

1. 不知道 Job ID 时，先调用 `finetuning_list_jobs()`找到真实目标。
2. 调用 `finetuning_get_job_logs(job_id=...)`。
3. 提炼以下关键信息：
   - loss
   - learning rate
   - 当前进度
   - 错误堆栈
   - `error_message`
4. 说明最可能的失败原因和最相关的下一步，不要原样输出整段日志。

## 编辑训练参数

1. 调用 `finetuning_get_experiment_parameters(experiment_id=...)`。
2. 检查 Experiment 是否因 `PENDING`、`RUNNING` 或 `STOPPED` Job 而锁定。
3. 确认所有待修改字段都属于 7 个安全参数。
4. 调用 `finetuning_update_experiment_parameters(...)`，只传发生变化的字段。
5. 向用户展示修改前后的值。

## 管理训练 Job

### 查看列表或详情

- 使用 `finetuning_list_jobs()`查看列表。
- 使用 `finetuning_get_job(job_id=...)`查看详情。

### 停止 Job

1. 确认目标 Job 状态为 `RUNNING`。
2. 通过 `clarify` 告知停止会中断训练，并请求确认。
3. 确认后调用：

```text
finetuning_stop_job(job_id="job_xxx", confirmed=true)
```


### 删除 Job

1. 确认 Job 已处于 `SUCCESS`、`FAILED` 或 `STOPPED`。
2. 通过 `clarify` 说明删除影响并请求确认。
3. 确认后调用：

```text
finetuning_delete_job(job_id="job_xxx", confirmed=true)
```

## 查看训练运行历史

- 使用 `finetuning_list_training_runs(page=..., page_size=...)` 查看列表。
- 兼容流程需要时，可使用 `limit` 和 `offset`。
- 使用 `finetuning_get_training_run(run_id=...)`查看详情。
- 优先用紧凑表格展示 Run ID、模型或 Experiment、状态、开始时间、结束时间和耗时。

## 发布模型

1. 调用 `finetuning_get_publish_status(experiment_id=...)`。
2. 说明是否满足发布条件以及阻塞原因。
3. 将发布摘要直接写入 `clarify` 的 `question`，选项为 `确认` 和 `取消`。
4. 用户确认后调用：

```text
finetuning_publish_model(
  experiment_id="exp_xxx",
  confirmed=true
)
```


5. 返回发布后的模型标识、状态和工具提供的目标地址或链接。

## 输出规范

- 对列表和方案预览优先使用简洁 Markdown 表格。
- ModelCamp 链接放在表格外。
- 明确区分 `experiment_id`、`job_id`、`run_id`、`model_ref_id` 和 dataset ref ID。
- 工具未返回成功前，不要暗示资源变更已经完成。
- 工具返回字段不完整时，明确说明缺失信息，不要补造。

## 工具请求参数说明

只能传入工具声明的公开参数。模型、数据集、Experiment、Job、Run 和 Worker 等 ID 必须来自工具真实返回，不得猜测或编造。

### 参数总表

| 参数                            | 类型/默认值                             | 含义与限制                                                                     |
| ----------------------------- | ---------------------------------- | ------------------------------------------------------------------------- |
| `dataset_id`                  | `integer ≥ 1`                      | 本地数据集 ID，仅用于预览数据集；通常取数据集列表中的 `local_dataset_id`，不要与 DatasetRef 的 `id` 混用。 |
| `limit`                       | `1–50`；预览默认 `10`                   | 在数据集预览中表示样本条数；在训练历史旧分页中表示每页条数，含义由工具决定。                                    |
| `node_id`                     | `string`                           | 执行节点 ID，用于检查 Worker 是否在线及是否支持 `compare_chat`。                             |
| `run_name`                    | `string`                           | 实验或训练任务的显示名称。创建 Experiment 时必填；启动 Job 时可选，不传则使用 Experiment 快照中的名称。        |
| `model_ref_id`                | `string`                           | 模型引用 ID，必须来自 `finetuning_list_models` 返回项的 `id`，不是模型名称或本地模型 ID。           |
| `primary_dataset_ref_id`      | `string`                           | 主数据集引用 ID，必须来自 `finetuning_list_datasets` 返回项的 `id`。                      |
| `dataset_ref_ids`             | `string[]`                         | Experiment 关联的数据集引用 ID 列表，必须包含 `primary_dataset_ref_id`；即使只有一个数据集，也应传数组。  |
| `finetune_strategy`           | `lora/full/freeze`，默认 `lora`       | 微调策略：LoRA 参数高效微调、全量微调或冻结部分参数训练。                                           |
| `experiment_id`               | `string`                           | Experiment ID，用于读取/修改参数、启动训练、查询发布状态和发布模型。                                 |
| `num_train_epochs`            | `number ≥ 1`                       | 训练轮数。数值越大训练时间越长，也更可能过拟合。                                                  |
| `learning_rate`               | `number > 0`                       | 学习率，控制参数更新幅度。                                                             |
| `per_device_train_batch_size` | `integer ≥ 1`                      | 每张训练设备一次处理的样本数，增大后通常需要更多显存。                                               |
| `cutoff_len`                  | `integer ≥ 1`                      | 单条训练样本的最大 Token 长度，超出部分会被截断。                                              |
| `max_samples`                 | `integer ≥ 1`，可选                   | 最大训练样本数；不传或为 `null` 表示使用全部数据。                                             |
| `lora_rank`                   | `integer ≥ 1`                      | LoRA 矩阵秩，越大可训练参数越多，资源占用也通常越高。                                             |
| `warmup_ratio`                | `0–1`                              | 学习率预热阶段占总训练步数的比例。                                                         |
| `job_id`                      | `string`                           | 训练任务 ID，用于任务详情、停止、删除、日志和 Compare Chat；必须来自启动结果或任务列表。                      |
| `confirmed`                   | `boolean`                          | 启动、停止、删除和发布时必须为 `true`；只能在用户通过 `clarify` 明确确认后设置，仅用于工具安全校验。               |
| `page` / `page_size`          | 默认 `1` / `20`；`page_size` 最大 `100` | 训练运行历史的新分页方式。只要传入任意一个，handler 就优先使用该分页方式。                                 |
| `offset`                      | `integer ≥ 0`                      | 训练运行历史的旧分页偏移量；仅在未传 `page`、`page_size` 时与 `limit` 一起生效。                    |
| `run_id`                      | `string`                           | 训练运行 ID，用于查询运行详情；当前实现中通常与对应的 `job_id` 相同，但应使用真实返回值。                       |
| `messages`                    | 对象数组                               | Compare Chat 的对话消息，每项必须包含 `role` 和 `content`。应直接传数组，不要传 JSON 字符串。         |
| `role` / `content`            | `string`                           | 消息角色与内容；角色通常为 `user` 或 `assistant`。                                       |
| `max_tokens`                  | `integer ≥ 1`，默认 `512`             | Base 和微调模型单次对比生成的最大 Token 数。                                              |
| `temperature`                 | `0–2`，默认 `0.7`                     | 采样随机度；越低通常越稳定，越高通常越发散。                                                    |

### 工具参数速查

| 工具                                                                             | 请求参数                                                                                           | 关键要求                                                                                      |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `finetuning_list_models` / `finetuning_list_datasets` / `finetuning_list_jobs` | 无                                                                                              | 返回分页对象，从 `list` 中读取真实资源 ID。                                                               |
| `finetuning_preview_dataset`                                                   | `dataset_id` 必填，`limit` 可选                                                                     | 使用本地 Dataset ID，不要传 DatasetRef ID。                                                        |
| `finetuning_check_worker_node`                                                 | `node_id`                                                                                      | Compare Chat 前确认节点为 `ONLINE` 且包含 `compare_chat` 能力。                                       |
| `finetuning_create_experiment`                                                 | `run_name`、`model_ref_id`、`primary_dataset_ref_id`、`dataset_ref_ids` 必填；`finetune_strategy` 可选 | 不得传旧字段 `goal`；handler 收到该字段也会忽略。                                                          |
| `finetuning_get_experiment_parameters`                                         | `experiment_id`                                                                                | 获取推荐值、覆盖值、最终生效参数和是否可启动。                                                                   |
| `finetuning_update_experiment_parameters`                                      | `experiment_id` 必填；7 个安全训练参数均可选                                                                | handler 只提交本次明确提供的非空字段，并自动包装为 `overrides`。                                                |
| `finetuning_launch_training_job`                                               | `experiment_id`、`confirmed` 必填；`run_name` 可选                                                   | 只以 Experiment 为训练配置快照；`confirmed` 不发送给后端。                                                 |
| `finetuning_get_job` / `finetuning_get_job_logs`                               | `job_id`                                                                                       | 分别查询任务详情和纯文本日志。                                                                           |
| `finetuning_stop_job` / `finetuning_delete_job`                                | `job_id`、`confirmed`                                                                           | 停止通常只用于 `RUNNING`；删除通常只用于 `SUCCESS/FAILED/STOPPED`，且会删除配置、日志和输出目录。                        |
| `finetuning_list_training_runs`                                                | `page/page_size` 或兼容的 `limit/offset`                                                           | 不要混用两套分页；若混用，handler 优先采用 `page/page_size`。                                               |
| `finetuning_get_training_run`                                                  | `run_id`                                                                                       | 获取运行摘要、Job 详情、实验来源和关联 Compare 任务。                                                         |
| `finetuning_compare_chat`                                                      | `job_id`、`messages` 必填；`max_tokens`、`temperature` 可选                                           | Job 必须为 `SUCCESS` 或 `FAILED` 终态；禁止传 `query`、`prompts`、`model_ref_id`、`base_model_id` 等字段。 |
| `finetuning_get_publish_status`                                                | `experiment_id`                                                                                | 发布前检查 `publishable`、审批、产物注册及现有发布模型状态。                                                     |
| `finetuning_publish_model`                                                     | `experiment_id`、`confirmed`                                                                    | 只有发布状态允许时执行；`confirmed` 只用于安全确认。                                                          |

### 统一规则

1. `dataset_id` 是本地数据集 ID，`primary_dataset_ref_id` 和 `dataset_ref_ids` 是数据集引用 ID，不得混用。
2. `experiment_id`、`job_id`、`run_id` 分别代表实验、训练任务和训练运行；即使部分值相同，也按工具声明传参。
3. Experiment 只允许修改 7 个安全训练参数，Job 锁定期间不得编辑。
4. 启动、停止、删除和发布必须先通过 `clarify` 确认，再传 `confirmed=true`。
5. Compare Chat 每次只测试一个用户确认的问题，`messages` 必须为数组。
6. 工具未声明的参数禁止传入；不得使用已废弃的 `goal`，也不得编造工具名称。


