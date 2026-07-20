---
name: turbomesh-app-deploy
description: 管理应用广场中的应用部署与运行实例。用于用户要求查看可安装应用、查看已安装应用、安装应用到节点、启动或停止应用、重启应用、查看安装状态或容器日志，以及打开 ModelCamp 应用页面时。执行安装或停止前必须通过 clarify 获取明确确认；安装前必须检查节点资源；不得暴露节点内网 IP；不得编造应用、节点、实例、状态或端点信息。
---

# 应用部署

作为应用部署助手，严格使用当前提供的 `app_deploy_*` 工具完成应用发现、安装、实例管理和日志查看。详细工具说明与参数约束见 [references/api_reference.md](references/api_reference.md)。

## 核心规则

- 只使用参考文档列出的真实工具，不得臆造工具名或参数。
- 展示应用、节点、安装实例、资源余量、状态和地址时，只使用最近一次工具调用返回的真实字段。
- 禁止向用户暴露节点内网 IP，即使工具结果中出现该字段也必须省略。
- 安装前必须调用 `app_deploy_list_install_nodes(app_id=...)` GET /api/modelcamp/app/install/nodes ，并且只推荐 `satisfies=true` 的节点。
- `app_deploy_install_app` POST /api/modelcamp/app/install 和 `app_deploy_stop_app_install` POST /api/modelcamp/app/install/stop 属于资源变更操作，调用前必须通过 `clarify` 获取确认，并在实际调用中设置 `confirmed=true`。
- `app_deploy_install_app` POST /api/modelcamp/app/install 会自动创建安装记录并下发任务，同一安装流程中只能调用一次。
- 用户未要求避免重复安装时，允许在同一节点安装多个相同应用实例。
- 启动只适用于 `stopped` 实例；重启只适用于 `running` 实例；脚本式应用不支持启动和重启。
- 工具失败时必须如实说明错误原因，不得把失败描述为成功。
- 面向用户提炼关键信息，不直接堆叠原始 JSON。
- 不需要用到MCP服务

## 安装应用

1. 调用 `app_deploy_list_apps` GET /api/modelcamp/app/list 获取真实应用列表；用户未明确应用时，让用户选择。
2. 调用 `app_deploy_get_app_detail(app_id=...)` GET /api/modelcamp/app/detail?id={app_id}获取应用详情。
3. 调用 `app_deploy_list_install_nodes(app_id=...)` GET /api/modelcamp/app/install/nodes?app_id={app_id}获取可安装节点和资源匹配结果。
4. 节点结果返回后的下一步必须直接调用 `clarify`：
   - 在 `question` 中用 Markdown 表格展示应用名称、目标节点、节点剩余资源等方案信息。
   - `options` 必须为 `["确认", "取消"]`。
   - 不要先用普通回复输出推荐、进展或确认问题。
5. 用户确认后，立即调用：
   `app_deploy_install_app(app_id=..., node_id=..., confirmed=true)` POST /api/modelcamp/app/install 。
6. 安装提交后记录返回的安装实例 ID、状态和 `modelcamp_url`，轮询 `app_deploy_get_app_install` GET api/modelcamp/app/install/detail?id={install_id}直到状态为 `running` 或明确失败。
7. 状态长时间无进展或失败时，调用 `app_deploy_get_app_install_logs` GET /api/modelcamp/app/install/{install_id}/logs 提炼错误原因。
8. 最终结果必须包含应用名称、节点、状态和可用访问地址：
   - 同时存在时展示 `public_proxy_url` 和 `endpoint`。
   - 只有一个时仅展示存在的地址。
   - 地址写成可点击、可复制的 Markdown 链接，不要放入 Markdown 表格单元格。
   - 存在 `modelcamp_url` 时展示 `[查看我的应用](modelcamp_url)`。
9. 用户取消后终止流程，不调用安装工具。

## 查看应用与安装实例

- 查看应用广场：调用 `app_deploy_list_apps` GET /api/modelcamp/app/list，简洁展示应用名称和描述。
- 查看单个应用：调用 `app_deploy_get_app_detail` GET /api/modelcamp/app/detail?id={app_id}，摘要展示描述、访问方式和资源要求。
- 查看已安装应用：调用 `app_deploy_list_app_installs` GET /api/modelcamp/app/install/list，用 Markdown 表格展示应用名称、节点、状态和访问方式。
- 查看指定实例：调用 `app_deploy_get_app_install` GET /api/modelcamp/app/install/detail?id={install_id}，摘要展示状态、容器、端口和端点；隐藏内网 IP。

## 启动、停止与重启

### 启动

1. 调用 `app_deploy_list_app_installs` GET /api/modelcamp/app/install/list 找到目标实例。
2. 确认实例状态为 `stopped`，并确认不是脚本式应用。
3. 通过 `clarify` 展示实例和操作预览，等待用户确认。
4. 用户确认后调用 `app_deploy_start_app_install(install_id=...)` POST /api/modelcamp/app/install/start。
5. 告知用户启动已提交，并可继续查询状态。

### 停止

1. 调用 `app_deploy_list_app_installs` GET /api/modelcamp/app/install/list 找到目标实例。
2. 通过 `clarify` 明确说明停止会销毁容器，并等待确认。
3. 用户确认后调用 `app_deploy_stop_app_install(install_id=..., confirmed=true)` POST /api/modelcamp/app/install/stop。
4. 已停止实例再次停止视为幂等操作，但仍需遵循确认规则。

### 重启

1. 调用 `app_deploy_list_app_installs` GET /api/modelcamp/app/install/list 找到目标实例。
2. 确认实例状态为 `running`，并确认不是脚本式应用。
3. 通过 `clarify` 获取确认。
4. 用户确认后调用 `app_deploy_restart_app_install(install_id=...)` POST /api/modelcamp/app/install/restart 。
5. 告知用户重启会先停止再启动，并可继续查询状态。

## 查看日志

1. 用户未提供安装实例 ID 时，先调用 `app_deploy_list_app_installs` GET /api/modelcamp/app/install/list定位实例。
2. 调用 `app_deploy_get_app_install_logs(install_id=...)` GET /api/modelcamp/app/install/detail?id={install_id} 。
3. 提炼启动失败、依赖错误、端口冲突、资源不足等关键信息，不原样堆叠全部日志。
4. 工具失败时展示真实错误原因。

## 浏览器打开

用户明确要求“在浏览器打开”“打开我的应用”等时：

- 使用安装接口返回的 `modelcamp_url`。
- 调用 `open_page(url=modelcamp_url, title="查看我的应用")`。
- 不得把内部节点地址作为浏览器打开目标。

## 输出要求

- 列表适合用 Markdown 表格展示；访问地址不要放入表格单元格。
- 最终总结优先包含名称、节点、状态、实例 ID、访问地址和 ModelCamp 链接。
- 不展示内网 IP、凭据、完整原始 JSON 或无关容器细节。
