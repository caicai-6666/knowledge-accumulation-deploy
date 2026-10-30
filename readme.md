# 注册中心统一部署

本机 IDE 开发使用 [docker-compose.dev.yml](docker-compose.dev.yml)，只启动独立的 MySQL/MyVector，当前宿主机端口为 13306，避免占用已有系统 MySQL。问答及助理表初始化、各项目环境文件与统一管理命令见[本机开发基础设施](../dev-infra/README.md)。

本项目通过 Docker Compose 管理知识沉淀注册中心的服务部署，集中维护服务配置、网络和数据持久化。

> **当前范围：** Compose 已配置 MySQL、registry 后端（`backend`）、知识后端（`knowledge-backend`）、注册中心前端（`registry-frontend`）和知识统一前端（`knowledge-frontend`）。registry 管理接口要求中央用户登录有效且具备注册中心管理员权限；普通用户原件下载按文件等级授权，可信后台原件下载使用平台令牌及任务所属员工的实时权限。用户注册、登录、头像和探索问答由 knowledge-accumulation-be 负责；消息中间件仍由对应项目部署。

---

## 目录与依赖

部署目录结构如下：

```text
知识沉淀注册中心/
├── registry-be/
├── registry-fe/
├── knowledge-accumulation-be/
├── knowledge-accumulation-fe/
└── knowledge-accumulation-deploy/
    ├── mysql/
    │   ├── Dockerfile
    │   ├── myvector-options.cnf
    │   └── init/
    │       ├── 000-myvector-config.sh
    │       ├── 001-resources.sql
    │       ├── 002-myvector-documents.sql
    │       ├── 003-personnel.sql
    │       ├── 004-platform-admins.sql
    │       └── 020-myvector-access.sh
    ├── docker-compose.yaml
    └── .env.example
```

需要 Docker Engine 或 Docker Desktop，以及支持长格式 bind 和 `env_file.format: raw` 的现代 Compose 插件。数据库镜像从[MySQL 镜像项目](mysql/readme.md)构建，后端范围见[项目总览](../registry-be/description/project.md)。

---

## 配置与启动

在 `knowledge-accumulation-deploy` 目录执行：

```bash
cp .env.example .env
chmod 600 .env
```

已有实际配置时不要覆盖。编辑 `.env`，设置 `MYSQL_ROOT_PASSWORD` 和 `MYSQL_PASSWORD`。后端配置读取 `REGISTRY_BACKEND_ENV_FILE`（默认 `../registry-be/.env`），该文件需事先准备好，并设置 registry 平台和模型服务凭据，按需配置 AUTH_REQUEST_TIMEOUT_SECONDS。无需开发登录或本地头像存储配置；头像代理需核对下表中的知识后端地址，手动刷新已有员工资料时，在后端 `.env` 配置 `DINGTALK_APP_KEY`、`DINGTALK_APP_SECRET`。然后执行：

```bash
docker compose config --quiet
docker compose up -d --build --wait mysql
# 首次部署先完成下方知识后端配置、问答表迁移及数据准备，再启动后端。
docker compose up -d --build --wait backend knowledge-backend
docker compose ps
```

密码为空时，Compose 配置校验会失败。后端等待 MySQL 健康检查通过后启动，镜像内的 HTTP 健康检查验证 Web 入口。只启动开发数据库时使用 `docker compose up -d --build --wait mysql`。

| 配置项 | 默认值 | 用途 |
| --- | --- | --- |
| `MYSQL_VERSION` | `8.4` | MySQL 基础镜像版本。 |
| `MYSQL_DATABASE` | `registry` | 首次初始化创建的业务数据库。 |
| `MYSQL_USER` | `registry` | 首次初始化创建的业务账号，不能使用 `root`。 |
| `MYSQL_ROOT_PASSWORD` | 无，必填 | 管理员密码。 |
| `MYSQL_PASSWORD` | 无，必填 | 业务账号密码。 |
| `MYSQL_PORT` | `3306` | 宿主机访问端口，仅绑定 `127.0.0.1`。 |
| `BACKEND_PORT` | `23000` | 后端宿主机端口，仅绑定 `127.0.0.1`；容器内部为 `8000`。 |
| `REGISTRY_BACKEND_ENV_FILE` | `../registry-be/.env` | registry 实际配置，按 raw 模式注入容器环境。 |
| `REGISTRY_FRONTEND_PORT` | `23080` | 注册中心前端端口，仅绑定 `127.0.0.1`，容器内为 `80`。 |
| `KNOWLEDGE_BACKEND_PORT` | `24000` | 知识后端宿主机端口，仅绑定 `127.0.0.1`；容器内部为 `8000`。 |
| `KNOWLEDGE_BACKEND_ENV_FILE` | `../knowledge-accumulation-be/.env` | 知识后端实际配置文件，只读挂载，必须可由容器 UID/GID 10001 读取。 |
| `KNOWLEDGE_FRONTEND_PORT` | `24080` | 统一前端宿主机端口，仅绑定 `127.0.0.1`，容器内 Nginx 为 `80`。 |
| `DINGTALK_CORP_ID` | 无，前端构建及生产登录必填 | 前后端唯一共用的企业公开 CorpId，修改后须重建前端并重新创建知识后端。 |
| `KNOWLEDGE_ACCUMULATION_BASE_URL` | `http://knowledge-backend:8000` | registry 头像代理的知识后端服务根地址，不包含 API 路径。 |
| `MIDDLEWARE_BASE_URL` | `http://host.docker.internal:22000` | 中间件地址，覆盖后端本机配置中的 localhost。 |

Compose 把两个后端的 MySQL 地址固定为 `mysql:3306`，数据库名、账号和密码取部署目录 `.env`。registry 的 SQLite、正式资源和审核暂存目录固定在其 `/workspace/data` 下；其他 registry 环境变量从 `REGISTRY_BACKEND_ENV_FILE` 原样传入，避免密钥中的 `$` 被插值，该文件中的值不要添加外围引号。知识后端采用下节的只读文件挂载，解析方式不同。两个后端的 `APP_PATH_PREFIX` 均固定为空，生产业务路径不带 `/dev`；本机 IDE 开发入口仍使用 `/dev`。不要公开 `docker compose config` 的完整展开结果，语法校验使用 `--quiet`。

---

## 知识后端配置与启动

先按 [知识后端 Docker 说明](../knowledge-accumulation-be/description/capability/application/docker.md)准备 `KNOWLEDGE_BACKEND_ENV_FILE` 指定的配置。它只读挂载到 `/workspace/.env`，由应用以 `python-dotenv` 解析，保留带引号 JSON 及密钥的语义，不使用 registry 的 raw 环境变量模式。配置不进入镜像，路径缺失时不自动创建目录。Linux 上需为运行 UID/GID `10001:10001` 提供读取权限，例如使用仅部署用户及该组可读的 `0640` 配置副本；不要直接假设属于其他用户的 `0600` 文件可读。

知识后端使用自己的 `knowledge-accumulation` 平台凭据。`APP_ENV=production` 时，CorpId 统一取部署 `.env` 的 `DINGTALK_CORP_ID`，AppKey、AppSecret 只从知识后端配置文件读取；开发模式需固定登录凭据。MLLM/Embedding 配置保留在知识后端配置文件，地址必须容器可达。两后端共用权威 MySQL 人员表，知识后端会自动发布用户/管理员全表，因此启动前应完成完整人员数据准备、外部授权及跨后端覆盖协调，并停止旧的同身份本机实例。

知识后端的注册中心文件读取地址由 Compose 固定为 `REGISTRY_BASE_URL=http://backend:8000`。文件查询的 `FILE_SOURCE_MYSQL_HOST/PORT` 覆盖为 `mysql:3306`，`FILE_SOURCE_MYSQL_DATABASE/USER/PASSWORD` 复用本部署的 `MYSQL_DATABASE/USER/PASSWORD`，不需要新增一组配置。上述环境变量覆盖挂载后端配置中的本机地址及连接项，保证文件查询、权限校验和 registry 使用同一权威源；不创建额外检索表或修改数据库权限。

首次 MySQL 初始化只含部署项目已有人员和资源表。问答表仍需显式执行知识后端 `schema/` 的 `001`、`002`、`004`、`006`、`007`、`008`、`009`、`010`；可选索引 `003`、`005` 及旧库回填前提见知识后端文档。先构建 `docker compose build knowledge-backend`，镜像中的 `/workspace/schema/` 提供迁移源；构建或启动不会自动执行迁移。已有表不能重复执行新库初始化，健康检查也不验证业务表结构。

### 助理、转换钩子与平台协作

以下变量统一维护在 `KNOWLEDGE_BACKEND_ENV_FILE` 指向的后端配置文件中，完整模板为[知识后端 .env.example](../knowledge-accumulation-be/.env.example)。不要把它们直接复制到 deploy `.env`：Compose 只读挂载后端文件，由应用加载这些变量，不再设置第二份默认值覆盖已有部署选择。

| 配置项 | 缺省值 | 部署含义 |
| --- | --- | --- |
| `ASSISTANT_ENABLED` | `false` | 启用个人助理消费、钉钉 Stream 入站、提醒及心跳；启用前准备机器人凭据和助理表。 |
| `ASSISTANT_MODEL_RETRY_SECONDS` | `30` | 尚未开始生成时，模型准备暂不可用的重试间隔；不重试已经执行后失败的任务。 |
| `ASSISTANT_RENDERING_THINKING_EFFORT` | `medium` | finish_task 转换子智能体独立推理档位：low / medium / xhigh；始终启用原生推理。 |
| `PLATFORM_A2A_ENABLED` | `false` | 启用跨平台协作；需中间件平台会话及 018 表。 |
| `PLATFORM_A2A_RESPONSE_BUFFER_SECONDS` | `5` | 广播发布后的响应缓冲，必须小于整轮等待预算。 |
| `PLATFORM_A2A_WAIT_SECONDS` | `90` | 整轮等待预算。 |
| `PLATFORM_A2A_POLL_SECONDS` | `1` | 反馈轮询间隔。 |
| `PLATFORM_A2A_HTTP_TIMEOUT_SECONDS` | `10` | 单次中间件请求超时。 |
| `PLATFORM_A2A_MAX_CONCURRENT_REQUESTS` | `16` | 平台协作请求并发上限。 |

启用助理后，转换钩子只注册在助理 `finish_task` 上，工具执行完成后、正常提交前做一次 JSON Schema 生成；转换后的正文统一用于答案、后续上下文和钉钉交付。主助理与转换器共用后端 `VLLM_MLLM_*` 模型服务配置，服务须支持原生推理、JSON Schema 和 `/tokenize`，且地址必须容器可达。转换失败会终止当前任务，不提交原文或自动重跑。该钩子没有新增迁移、独立模型容器或独立服务端口；详见[转换契约](../knowledge-accumulation-be/description/architecture/workflow/question-answering/assistant-message-rendering.md)。

升级已有助理部署时，按部署环境实际结构确认以下前提；不要因为本机已完成迁移而跳过其他环境，也不要盲目重复执行建表 SQL：

- 助理、消费、目录、入站及员工背景/画像依赖 `011`—`017`；详见[助理存储](../knowledge-accumulation-be/description/architecture/data/assistant-storage.md)及[个人背景与画像](../knowledge-accumulation-be/description/architecture/workflow/question-answering/assistant-personal-context.md)。
- 当前 `003-personnel.sql` 已包含 `015` 任职资料和 `019` 多部门字段，新空卷跳过这两项；旧卷先检查列和约束，缺失时分别显式执行 `015`、`019`，不要重复补列。其他 `011`—`017` 表仍按需迁移；部门全文索引 `020` 仍需单独执行，均作用于共享人员库。
- 当前助理工作区依赖 `021`，旧部署须先备份并停止所有助理写入，再显式执行 DDL 和 `python -m app.repository.assistant_memory_migration`。迁移涉及旧工作区快照清理，按[助理记忆迁移说明](../knowledge-accumulation-be/description/architecture/workflow/question-answering/assistant-memory.md#显式迁移与部署)执行，Compose 不代为执行。
- 启用 A2A 时另需 `018`；见[跨平台协作](../knowledge-accumulation-be/description/architecture/workflow/question-answering/platform-a2a.md)。

缺失配置项可按模板补齐，已有开关、地址、凭据和自定义值应保留。修改文件后需重新创建/启动知识后端才能加载；执行前停止使用同一平台身份的 IDE 进程，避免双实例争用。Docker HTTP 健康检查只证明 Web 入口可用，不能证明模型、机器人及中间件已联通。

### 启动与数据卷

准备完成后：

```bash
docker compose config --quiet
docker compose up -d --build --wait knowledge-backend
docker compose logs -f knowledge-backend
```

入口为 `http://127.0.0.1:24000/knowledge-accumulation/api`；HTTP 健康检查使用 `/openapi.json`。固定单 worker，不开启 reload，不直接扩为多实例。SSE 反向代理需要关闭缓冲并保留用户 Authorization，容器停止宽限为 1 分钟。

知识后端数据使用独立卷 `knowledge-backend-data`（默认完整名称 `registry_knowledge-backend-data`），挂载 `/workspace/data`。头像与 PDF 分别在 `user/avatar`、`user/upload-file`；该卷不自动导入本机已有数据，正式切换需单独迁移并核对文件引用与权限。保持 Compose 项目名 `registry`，避免既有 MySQL 与 registry 数据卷因项目改名变成新卷。

registry 头像代理默认改为同网络内的 `http://knowledge-backend:8000`。已有部署 `.env` 的显式旧值会覆盖此默认值，实际切换时需单独调整并重建 `backend`；本次不改实际配置。registry 无需挂载知识后端数据卷。

---

## 连接与日常操作

### 知识统一前端

`knowledge-frontend` 从同级 `knowledge-accumulation-fe` 构建，使用该项目的 Dockerfile 和 Nginx 配置。先在部署 `.env` 填写 `DINGTALK_CORP_ID`；Compose 同时将它映射到前端构建参数 `VITE_DINGTALK_CORP_ID` 和知识后端环境变量 `DINGTALK_CORP_ID`，不再维护两份企业标识。该值公开，AppKey、AppSecret 和开发固定凭据不进入前端构建参数。构建上下文不包含前端实际 `.env`，镜像固定使用生产免登。

已有部署配置中的 `VITE_DINGTALK_CORP_ID` 需在实际切换时改名为 `DINGTALK_CORP_ID`；本次不自动修改真实 `.env`。Compose 的共享值覆盖知识后端文件中的同名项，留空不能回退到另一份值；独立运行前端/后端时仍按各自示例配置。修改共享值后重建 `knowledge-frontend` 并重新创建 `knowledge-backend`，保持浏览器构建与服务端一致。

在知识后端已运行的情况下，仅构建和更新前端：

```bash
docker compose config --quiet
docker compose build knowledge-frontend
docker compose up -d --no-deps knowledge-frontend
```

前端访问 `http://127.0.0.1:24080/knowledge-accumulation/`，生产路径不含 `/dev`。容器内 API 保留 `/knowledge-accumulation/api/` 转发至 `knowledge-backend:8000`，不通过宿主机端口；SSE 关闭响应缓冲和缓存，读取空闲超时 3600 秒。`/healthz` 仅检查静态 Web 入口。

前端带哈希构建资源（含图标）缓存一年，无哈希公共图标缓存 7 天；首页和图标缓存脚本每次校验更新。外站链接图标继续使用浏览器 Service Worker 的 7 天、48 项缓存。头像与附件等鉴权 API 不进入公共缓存。完整规则见[前端部署说明](../knowledge-accumulation-fe/description/platform/deployment.md)。

外层网关需保留路径并将 `/knowledge-accumulation/` 转发至前端端口，同时为 SSE 关闭缓冲。注册中心和合同平台的更深前缀需优先路由到各自前端；注册中心前端由下节的 `registry-frontend` 提供，合同平台仍由其独立部署提供，统一入口容器对这两个前缀返回 404。Compose 正常启动前端会等待知识后端健康；更新现有前端使用上面的 `--no-deps` 命令，避免连带启动后端生命周期。

### 注册中心前端

`registry-frontend` 从同级 `registry-fe` 构建，容器 Nginx 通过 `backend:8000` 原样代理 `/knowledge-accumulation/registry/api/`，不向浏览器注入平台密钥或模型配置。启动或更新：

```bash
docker compose config --quiet
docker compose up -d --build --wait registry-frontend
```

访问 `http://127.0.0.1:23080/knowledge-accumulation/registry/`，`/healthz` 只检查静态入口。外层 HTTPS 网关需将更具体的 `/knowledge-accumulation/registry/` 优先转发到此端口，保留完整路径和鉴权头；页面与知识统一入口须共用同一源，才能读取统一入口保存的 `access_token`。本机不同端口直连仅适合静态检查，不共享浏览器存储。

若此前已通过 `registry-fe/docker-compose.yaml` 独立运行前端，启用本服务前先停止该前端容器，避免默认 `23080` 端口冲突；也可继续独立部署，不启动本服务。网关配置见[注册中心前端部署](../registry-fe/description/platform/deployment.md#域名网关与映射)。

### 其他服务

宿主机使用 `127.0.0.1` 和 `MYSQL_PORT` 连接数据库；后端在 Compose 网络中使用 `mysql:3306`。后端接口入口为 `http://127.0.0.1:23000/knowledge-accumulation/registry/api`，Swagger 文档位于 `/docs`，端口可通过 `BACKEND_PORT` 修改。

查看数据库日志：

```bash
docker compose logs -f mysql
```

使用业务账号进入数据库，按提示输入 `.env` 中设置的业务密码：

```bash
docker compose exec mysql sh -c 'exec mysql -u "$MYSQL_USER" -p "$MYSQL_DATABASE"'
```

停止服务并保留数据：

```bash
docker compose down
```

---

## 持久化与初始化边界

MySQL 数据目录 `/var/lib/mysql` 挂载到命名卷 `mysql-data`，默认完整卷名为 `registry_mysql-data`。普通停止、删除容器和重新构建镜像不会删除该卷。

后端 `/workspace/data` 挂载到 `backend-data`，默认卷名为 `registry_backend-data`，持久化审核数据库、暂存附件和正式资源。该卷不会自动复制本机 `registry-be/data` 中已有记录；迁移开发数据需要停止写入、备份并显式迁移。认证凭据保存在后端 `.env`，不通过人员名单挂载，备份时单独保护实际环境配置。

> **数据边界：** `docker compose down -v` 会删除数据库数据卷，仅在明确需要清空数据时使用。

官方镜像只在空数据目录上创建数据库和账号，并执行镜像内 `mysql/init/` 的 SQL 建立 `resources` 表及 MyVector 索引缓存，安装插件。后端不负责建表。已有数据卷时，修改 `.env` 中的初始化变量不会自动修改现有数据库或密码，需要通过数据库管理操作完成变更。

同目录的 `003-personnel.sql` 创建供知识后端初始化、registry 管理权限时共用的 `departments` 与 `employees` 表，`004-platform-admins.sql` 随后创建关联员工的子平台管理员表；已有卷的结构处理边界见 [MySQL 镜像说明](mysql/readme.md#初始化与数据边界)。字段与权限映射见[公司部门与员工契约](../registry-be/description/architecture/data/employee.md)。

---

## 管理员认证与人员数据

`backend` 原样读取 `REGISTRY_BACKEND_ENV_FILE`，管理路由先以用户 token 查询中间件 `POST /user/login-cache`，再以 registry 平台会话查询 `GET /platform/admins/list`。未登录返回 401，普通用户返回 403，认证或管理员依赖故障返回 503；文件访问等级不能替代注册中心管理员资格。

用户先在知识后端登录；开发固定凭据、钉钉免登参数、用户/管理员 full-table 注册、用户 token 签发与头像存储目录由知识后端管理。registry 自身的钉钉通讯录刷新仍需在后端 `.env` 配置 AppKey/AppSecret；该能力不负责登录。后端镜像不再设置 `APP_ENV`，Compose 不再传入 `AVATAR_ROOT` 或挂载头像目录；旧用户配置不应继续留在 registry `.env`。

| 后端变量 | 默认值 | 说明 |
| --- | --- | --- |
| `AUTH_REQUEST_TIMEOUT_SECONDS` | `5` | 中央用户查询及人员资料读取的总超时。 |

配置唯一入口为 `REGISTRY_BACKEND_ENV_FILE` 指向的文件，不要在部署 `.env` 重复维护此项。管理员全表发布已迁到知识后端，registry 不再启动同步或使用 `MIDDLEWARE_ADMIN_SYNC_ENABLED`；中间件该写接口授权由维护方调整，未在本部署执行真实发布。不再配置旧 `MIDDLEWARE_USER_SYNC_*` 或管理员全表同步开关。

MySQL 的 departments、employees 和 platform_admins 仍需保留：首次员工初始化由知识后端写入，registry 查询同一权威人员源并负责后续权限与管理关系维护。知识后端应连接此处同一人员表/schema（账号可以不同），不能建立互相分叉的权限副本。当前未增加独立人员库连接配置，也未替知识后端改动实际数据库地址或执行生产数据迁移；知识后端旧全表快照覆盖并发权限更新的边界仍需在真实切换前处理。

可信后台原件下载还依赖中间件 `POST /middleware-service/api/platform/token/verify` 只读校验能力，调用方固定为 `knowledge-accumulation` 平台；知识后端通过 Compose 注入的 `REGISTRY_BASE_URL=http://backend:8000` 访问。接口缺失或校验依赖故障时拒绝下载，不需要另设共享文件密钥。完整边界见[原件接口](../registry-be/description/api/resource.md)。

修改后重建后端，不删除数据卷：

```bash
docker compose config --quiet
docker compose up -d --build --force-recreate backend
```

registry 重建不自行撤销中央用户 token；平台会话重新建立前，业务鉴权可能暂时返回 503。只启动单 worker，避免与本机后端同时使用同一平台凭据。HTTP 健康检查继续请求公开 OpenAPI，只检查 Web 入口；不以管理员业务接口作为探针。

本次更新部署声明和文档，不启动、重建容器或迁移数据卷。用户头像已在本地迁至知识后端，但旧 backend-data 卷可能仍含历史头像，不自动删除该卷中的任何文件。

---

## 构建与文件追踪边界

后端 Git 仅保留运行源码、SQLite 初始化定义、依赖和构建配置、描述文档，以及固定数据目录的 `.gitkeep`。`tests/`、`scripts/`、`experiment/` 和真实运行数据不进入版本管理；部署不依赖这些本地工具。后端 Dockerfile 只复制 `requirement.txt` 与 `app/`，`.dockerignore` 同时排除测试、脚本、实验、文档及运行数据。

目录占位不进入镜像，也不替代数据卷；后端运行时会创建正式文件和审核暂存目录，SQLite 启动时创建或升级。不能通过提交数据库或原件来预置部署数据。

头像代理通过 `KNOWLEDGE_ACCUMULATION_BASE_URL` 访问知识后端，转发用户 Bearer token，不挂载知识后端头像目录。当前默认使用同一 Compose 网络的 `knowledge-backend:8000`；若显式改为宿主机服务，须监听容器可达接口，只监听 `127.0.0.1` 可能导致代理 503。头像缓存时长等参数读取 registry 后端 `.env`，见[头像代理配置](../registry-be/description/capability/infrastructure/avatar.md#配置与生命周期)。

知识后端镜像另包含模型工具模板和 SQL 迁移文件，详见[知识后端构建边界](../knowledge-accumulation-be/description/capability/application/docker.md)。两个后端均不将真实数据和实际配置复制进镜像。

摘要向量采用固定中文指令“检索与这份摘要语义相关的文本。”，候选 HNSW 缓存会基于现有摘要重新生成向量；首次搜索可能产生模型调用并增加等待时间，不要求部署时执行实验或迁移脚本。具体行为见[向量服务](../registry-be/description/capability/infrastructure/myvector.md)。

---

## 正式资源表与审核存储

`resources` 仅保存已入库文件及已通过的申请、审核备注，不保存 status 和推荐列表。入库暂存、删除申请、审核状态及推荐列表保存在后端 SQLite，通过资源 ID 关联。

MySQL 只保留当前初始化定义：`mysql/init/001-resources.sql` 创建最终版本的正式资源表，`mysql/init/002-myvector-documents.sql` 创建索引缓存；插件配置、安装与授权随空卷首次初始化完成。SQLite 的建表与自动升级由后端独立负责。

已移除历史 MySQL 迁移目录及对应升级工具。部署不需要依次执行旧版本变更；已有卷不会因修改初始化文件或重建镜像而自动变更表结构。旧结构如需继续使用，先备份并单独制定转换方案，不直接对含数据的旧库执行当前建表 SQL 作为升级。


---

## 员工多部门迁移

当前新空卷的 `003-personnel.sql` 已包含 `work_profile`、`department_ids` 及对应约束，不再执行知识后端 `015`、`019` 补列迁移。已有卷在部署新代码前检查共享人员库结构，缺少任职资料时执行一次 `../knowledge-accumulation-be/schema/015-employee-work-profile.sql`，缺少多部门字段时执行一次 `../knowledge-accumulation-be/schema/019-employee-departments.sql`；应用启动不会自动迁移。新增可空JSON列 `employees.department_ids` 和检查约束，不覆盖已有员工数据，NULL历史记录读取时回退旧单值。新代码写完整列表；`department_id`仅作旧客户端兼容，展示全部部门须使用新列表字段。
