---
name: finetuning-orchestrator
description: 面向 FineTuning 平台的大模型微调与实验编排技能。用于发现可用模型与数据集、预览数据集、创建 Experiment、查看或修改安全训练参数、启动和监控远程训练 Job、查看日志与训练历史、对比基座模型和微调模型、停止或删除 Job，以及发布训练后的模型。必须遵循 Ref-First 资产选择、Remote 执行、资源变更前确认、精确工具契约、Experiment 锁定规则和面向用户的精炼结果展示。
---

# FineTuning 微调编排

帮助用户发现资源、配置实验、启动远程微调任务、查看训练状态、对比模型效果并发布模型。

## 仅使用以下工具

- `finetuning_list_models`
- `finetuning_list_datasets`
- `finetuning_preview_dataset`
- `finetuning_check_worker_node`
- `finetuning_create_experiment`
- `finetuning_get_experiment_parameters`
- `finetuning_update_experiment_parameters`
- `finetuning_launch_training_job`
- `finetuning_get_job`
- `finetuning_list_jobs`
- `finetuning_stop_job`
- `finetuning_delete_job`
- `finetuning_get_job_logs`
- `finetuning_list_training_runs`
- `finetuning_get_training_run`
- `finetuning_compare_chat`
- `finetuning_get_publish_status`
- `finetuning_publish_model`

禁止编造或调用相似名称的工具。尤其不要调用任何包含以下名称的工具：

- `start_experiment`
- `launch_experiment`
- `run_experiment`
- `get_experiment_logs`
- `compare_models`
- `compare_model_outputs`

需要确认接口映射、参数限制、状态规则或精确调用形式时，读取 [references/api_reference.md](references/api_reference.md)。

## 核心规则

1. 优先通过 `finetuning_list_models` GET /app/asset-refs/models 和 `finetuning_list_datasets` GET /app/asset-refs/datasets 发现资产。
2. 仅使用最近一次资源列表工具真实返回的 ID、名称、样本数和规格。禁止猜测或伪造资源信息。
3. 创建 Experiment 时直接绑定 `model_ref_id`、`primary_dataset_ref_id` 和 `dataset_ref_ids`。
4. 不要向 `finetuning_create_experiment` POST /app/experiments 传入已废弃的 `goal` 字段。
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

## 完整微调流程

当用户要求微调模型、使用指定数据集训练模型，或完成一次训练并对比效果时：

1. 用户未完整指定模型或数据集时，同时调用：
   - `finetuning_list_models()` GET /app/asset-refs/models
   - `finetuning_list_datasets()` GET /app/asset-refs/datasets
2. 用户需要查看数据内容时，调用 `finetuning_preview_dataset(...)` GET /app/datasets/{id}/preview?limit=N 。
3. 用一次 `clarify` 让用户选择真实存在的模型和数据集组合。选项中直接展示最近一次列表返回的名称和 ID，避免分多轮询问。
4. 记录选中的 ref ID，后续直接复用，不要重复询问。
5. 调用 `finetuning_create_experiment(...)` POST /app/experiments 创建 Experiment。不要传入 `goal`。
6. 调用 `finetuning_get_experiment_parameters(experiment_id="exp_xxx")` GET /app/experiments/{id}/parameters 获取当前参数。
7. 生成包含模型、数据集、Experiment ID、Remote 模式和训练参数的 Markdown 表格。
8. 将方案表格直接写入 `clarify` 的 `question`，并使用 `options=["确认", "取消"]`。禁止先用普通回复输出方案，再调用 `clarify`。
9. 用户明确确认后，只调用：

```text
finetuning_launch_training_job(
  experiment_id="exp_xxx",
  confirmed=true
)
```
POST /app/train-jobs

仅当当前工具契约明确支持时才传 `run_name`。禁止改用其他启动工具。

10. 记录返回的 `job_id`、状态和 `modelcamp_url`。
11. 最终结果必须包含模型、数据集、状态、Experiment ID、Job ID 和 `[查看微调详情](modelcamp_url)`。
12. ModelCamp 链接不要放在 Markdown 表格单元格中，以免影响复制。
13. 用户要求监控时，调用 `finetuning_get_job(job_id=...)` GET /app/train-jobs/{id} ；需要诊断时调用 `finetuning_get_job_logs(job_id=...)` GET /app/train-jobs/{id}/logs 。

## 对比模型效果

当用户要求比较基座模型和微调模型时：

1. 调用 `finetuning_get_job(job_id=...)` GET /app/train-jobs/{id} ，确认 Job 已处于 `SUCCESS` 或 `FAILED`。
2. 调用 `finetuning_check_worker_node(node_id="worker-1")` GET /app/execution-nodes/{node_id} ，确认 Worker 在线且支持 Compare Chat。
3. 用户未提供测试问题时，通过 `clarify` 询问一个测试问题。
4. 每次只调用一次：

```text
finetuning_compare_chat(
  job_id="job_xxx",
  messages=[{"role":"user","content":"用户指定的问题"}]
)
```
POST /app/training-runs/{run_id}/compare-chat

5. 不要传入 `model_ref_id`、`query`、`prompts` 或 `base_model_id`。
6. 不要自动连续测试多个问题。

## 查看日志和诊断失败

1. 不知道 Job ID 时，先调用 `finetuning_list_jobs()` GET /app/train-jobs 找到真实目标。
2. 调用 `finetuning_get_job_logs(job_id=...)` GET /app/train-jobs/{id}/logs 。
3. 提炼以下关键信息：
   - loss
   - learning rate
   - 当前进度
   - 错误堆栈
   - `error_message`
4. 说明最可能的失败原因和最相关的下一步，不要原样输出整段日志。

## 编辑训练参数

1. 调用 `finetuning_get_experiment_parameters(experiment_id=...)` GET /app/experiments/{id}/parameters。
2. 检查 Experiment 是否因 `PENDING`、`RUNNING` 或 `STOPPED` Job 而锁定。
3. 确认所有待修改字段都属于 7 个安全参数。
4. 调用 `finetuning_update_experiment_parameters(...)` PATCH /app/experiments/{id}/parameters ，只传发生变化的字段。
5. 向用户展示修改前后的值。

## 管理训练 Job

### 查看列表或详情

- 使用 `finetuning_list_jobs()` GET /app/train-jobs查看列表。
- 使用 `finetuning_get_job(job_id=...)` GET /app/train-jobs/{id}查看详情。

### 停止 Job

1. 确认目标 Job 状态为 `RUNNING`。
2. 通过 `clarify` 告知停止会中断训练，并请求确认。
3. 确认后调用：

```text
finetuning_stop_job(job_id="job_xxx", confirmed=true)
```
POST /app/train-jobs/{id}/stop

### 删除 Job

1. 确认 Job 已处于 `SUCCESS`、`FAILED` 或 `STOPPED`。
2. 通过 `clarify` 说明删除影响并请求确认。
3. 确认后调用：

```text
finetuning_delete_job(job_id="job_xxx", confirmed=true)
```
DELETE /app/train-jobs/{id}

## 查看训练运行历史

- 使用 `finetuning_list_training_runs(page=..., page_size=...)` GET /app/training-runs?page=N&page_size=M 查看列表。
- 兼容流程需要时，可使用 `limit` 和 `offset`。
- 使用 `finetuning_get_training_run(run_id=...)` GET /app/training-runs/{run_id}查看详情。
- 优先用紧凑表格展示 Run ID、模型或 Experiment、状态、开始时间、结束时间和耗时。

## 发布模型

1. 调用 `finetuning_get_publish_status(experiment_id=...)` GET /app/experiments/{id}/publish-status。
2. 说明是否满足发布条件以及阻塞原因。
3. 将发布摘要直接写入 `clarify` 的 `question`，选项为 `确认` 和 `取消`。
4. 用户确认后调用：

```text
finetuning_publish_model(
  experiment_id="exp_xxx",
  confirmed=true
)
```
POST /app/experiments/{id}/publish

5. 返回发布后的模型标识、状态和工具提供的目标地址或链接。

## 输出规范

- 对列表和方案预览优先使用简洁 Markdown 表格。
- ModelCamp 链接放在表格外。
- 明确区分 `experiment_id`、`job_id`、`run_id`、`model_ref_id` 和 dataset ref ID。
- 工具未返回成功前，不要暗示资源变更已经完成。
- 工具返回字段不完整时，明确说明缺失信息，不要补造。
