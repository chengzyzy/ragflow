# ARM64 镜像

基于上游 `v0.27.2`（`a024bea0c`），维护分支为 `arm64-native`。保留原生依赖、Chrome/driver、网页转 PDF 和动态库路径补丁，构建 Python 后端与 Web 前端；另提供独立 MinerU 3.4.5 CPU 镜像。

## GitHub 构建

启用 fork 的 Actions，并将默认分支设为 `arm64-native`，便于手动运行工作流。

| 操作 | 行为 |
| --- | --- |
| 向 `arm64-native` 提交 PR | 仅检查工作流、相关 Python/Bash 语法和 CI Compose 配置，Token 只读 |
| 合入或推送到 `arm64-native` | 预检后构建 RAGFlow 镜像、启动服务并检查健康，通过才推送 GHCR |
| Actions → ARM64 images → Run workflow | 选择 `arm64-native`；`component=ragflow` 构建主镜像，`mineru` 单独构建可选解析镜像 |

所有任务使用免费的 GitHub 托管 `ubuntu-24.04-arm` runner。PR 不执行镜像构建或服务验收；需要在合入前完整验证时，可手动选择仓库内的候选分支运行工作流，只检查、不发布。合入后的完整验收失败会阻止运行镜像推送。

发布使用内置 `GITHUB_TOKEN`。首次推送后，在 [Packages](https://github.com/chengzyzy?tab=packages) 将运行镜像包设为 Public，部署主机即可匿名拉取。

镜像位于 `ghcr.io/chengzyzy/ragflow` 和 `ghcr.io/chengzyzy/ragflow-mineru`。标签格式为 `sha-<提交前12位>-<运行编号>-<重跑次数>`；每次运行使用新标签。Actions 运行摘要提供完整的 `镜像@sha256:摘要`，部署侧保存并使用该引用。

构建使用独立的 `ghcr.io/chengzyzy/ragflow-buildcache:arm64` 和 `ghcr.io/chengzyzy/ragflow-mineru-buildcache:arm64` 缓存，按 `mode=max` 复用中间构建层。只有维护分支的发布任务写缓存；首次产生后将这两个缓存包也设为 Public，其他分支的手动检查即可匿名读取。首次无缓存时正常构建，缓存导出失败不影响后续验收；缓存可能在服务验收前更新，本机不拉取或运行缓存。参见 [Docker registry cache](https://docs.docker.com/build/cache/backends/registry/)。

运行检查覆盖 ARM64 架构、源码标签、原生库导入、浏览器/驱动匹配及网页转 PDF。随后在 GitHub 临时启动 MySQL、Elasticsearch、MinIO 和 Redis，通过镜像正常入口启动 RAGFlow，检查 API、管理接口、Web 前端、依赖服务和持续更新的任务执行器心跳；全部通过后才推送 GHCR。

MinerU 独立检查依赖和 CLI，并通过正常入口下载模型、启动 API，检查解析接口是否就绪。本阶段不做完整 PDF 推理或入库检索验收。CI 使用临时凭据和空数据，结束时清理测试容器和数据卷，服务日志保留 7 天；不连接本机部署。两个组件共用构建工作流，构建、验收和运行镜像推送使用同一份本地镜像。

## 手工更新上游

确认新的正式 tag 后，将下面的 `vX.Y.Z` 替换为该 tag，在干净工作区执行：

```bash
git switch arm64-native
git fetch upstream tag vX.Y.Z
git merge --no-ff vX.Y.Z
```

解决冲突并核对 ARM64 补丁，删除上游已解决的本地修改，再推送维护分支，由 GitHub 重新构建。需要更新 MinerU 时修改其 Dockerfile 固定版本，手动选择 `component=mineru` 构建。

本机只负责部署。镜像默认 `API_PROXY_SCHEME=python`；数据库、存储、模型服务和凭据由部署侧配置。MinerU 首次启动下载模型到 `/data`，部署侧负责该持久卷和下载源。
