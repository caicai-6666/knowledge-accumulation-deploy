# 注册中心统一部署

本机 IDE 开发使用 [docker-compose.dev.yml](docker-compose.dev.yml)，只启动独立的 MySQL/MyVector，当前宿主机端口为 13306，避免占用已有系统 MySQL。问答及助理表初始化、各项目环境文件与统一管理命令见[本机开发基础设施](../dev-infra/README.md)。

本项目通过 Docker Compose 管理知识沉淀注册中心的服务部署，集中维护服务配置、网络和数据持久化。

> **当前范围：** Compose 已配置 MySQL、registry 后端（`backend`）、知识后端（`knowledge-backend`）、注册中心前端（`registry-frontend`）和知识统一前端（`knowledge-frontend`）。registry 管理接口要求中央用户登录有效且具备注册中心管理员权限；普通用户原件下载按文件等级授权，可信后台原件下载使用平台令牌及任务所属员工的实时权限。用户注册、登录、头像和探索问答由 knowledge-accumulation-be 负责；消息中间件仍由对应项目部署。

---

## 目录与依赖

部署目录结构如下：

```text
knowledge-accumulation-deploy/
├── registry-be/
├── registry-fe/
├── knowledge-accumulation-be/
├── knowledge-accumulation-fe/
├── mysql/
│   ├── Dockerfile
│   ├── myvector-options.cnf
│   └── init/
│       ├── 000-myvector-config.sh
│       ├── 001-schema.sql
│       └── 020-myvector-access.sh
├── docker-compose.yaml
├── docker-compose.dev.yml
└── .env.example
```

四个子项目作为独立 Git 仓库克隆到 deploy 根目录内，不把源码重复提交到 deploy，也不使用同级目录作为构建上下文。在 deploy 根目录执行：

```bash
git clone https://github.com/caicai-6666/registry-be.git registry-be
git clone https://github.com/caicai-6666/registry-fe.git registry-fe
git clone https://github.com/caicai-6666/knowledge-accumulation-be.git knowledge-accumulation-be
git clone https://github.com/caicai-6666/knowledge-accumulation-fe.git knowledge-accumulation-fe
```

已有目录时进入各子仓库更新到配套版本，不重复克隆。部署只维护根目录 `.env`，不需要创建四个子项目的 `.env`，也不需要 Compose 覆盖文件。本机 IDE 的同级工作区无需搬迁，正式部署按上述布局单独准备。

需要 Docker Engine 或 Docker Desktop，以及 Docker Compose v2。本配置使用显式 `environment` 注入，不再使用 `env_file.format: raw` 或 `.env` 文件挂载。数据库镜像从[MySQL 镜像项目](mysql/readme.md)构建，后端范围见[项目总览](./registry-be/description/project.md)。

---

## 配置与启动

在 `knowledge-accumulation-deploy` 目录执行：

```bash
cp .env.example .env
chmod 600 .env
```

已有实际配置时不要覆盖。按照 [.env.example](.env.example) 补齐全部配置项：数据库 root 与业务密码、两个平台各自的中间件密钥、钉钉应用凭据和模型地址。模板中可选值可以显式留空；Compose 对未定义项报错，数据库密码还要求非空。应用按启用功能校验其他必需凭据。

```bash
docker compose config --quiet
docker compose up -d --build --wait mysql
# 新空卷初始化全部业务表；完成人员数据与外部服务准备后启动后端。
docker compose up -d --build --wait backend knowledge-backend
docker compose ps
```

两个后端的配置均从进程环境读取，源码无需修改。Compose 只注入本服务使用的变量，不把整份 `.env` 交给所有容器；MySQL root 密码仅传给 MySQL，前端构建仅传公开 CorpId。不要公开 `docker compose config` 的完整展开结果，语法校验使用 `--quiet`。

| deploy `.env` 配置 | 注入位置或用途 |
| --- | --- |
| `MYSQL_VERSION`、`MYSQL_DATABASE`、`MYSQL_USER`、`MYSQL_ROOT_PASSWORD`、`MYSQL_PASSWORD` | 共用数据库配置；两个后端和文件检索复用同一业务库，root 密码不进入后端。 |
| `MYSQL_PORT` | 宿主机 MySQL 端口，模板为 `13306`；容器连接固定 `mysql:3306`。 |
| `BACKEND_PORT`、`REGISTRY_FRONTEND_PORT` | 注册中心后端/前端端口，模板为 `16000` / `16080`。 |
| `KNOWLEDGE_BACKEND_PORT`、`KNOWLEDGE_FRONTEND_PORT` | 知识后端/前端端口，模板为 `15000` / `15080`。 |
| `MIDDLEWARE_BASE_URL` | 共用中间件地址，模板为 `http://host.docker.internal:22000`。 |
| `DINGTALK_CORP_ID` | 知识后端与知识前端共用的公开企业标识。 |
| `KNOWLEDGE_ACCUMULATION_BASE_URL` | 注册中心访问知识后端的地址，模板为 `http://knowledge-backend:8000`。 |
| `REGISTRY_MIDDLEWARE_SECRET`、`KNOWLEDGE_MIDDLEWARE_SECRET` | 两个平台分别使用的中间件密钥，对应平台白名单中的 `registry` / `knowledge-accumulation`。 |
| `REGISTRY_DINGTALK_APP_KEY`、`REGISTRY_DINGTALK_APP_SECRET` | 注册中心通讯录刷新凭据，映射为该容器的 `DINGTALK_APP_KEY` / `DINGTALK_APP_SECRET`。 |
| `KNOWLEDGE_DINGTALK_APP_KEY`、`KNOWLEDGE_DINGTALK_APP_SECRET`、`KNOWLEDGE_DINGTALK_ROBOT_CODE` | 知识后端钉钉登录及机器人凭据，不传给前端。 |
| `REGISTRY_VLLM_*`、`KNOWLEDGE_VLLM_*` | 各后端独立的模型连接、推理、并发与预算参数，映射时去除服务前缀。 |
| 其他 `REGISTRY_*`、`KNOWLEDGE_*` | 对应后端示例配置中的业务参数，完整清单和说明见根目录 `.env.example`。 |

例如 `REGISTRY_VLLM_MLLM_ENABLE_THINKING=false` 与 `KNOWLEDGE_VLLM_MLLM_ENABLE_THINKING=true` 可同时生效，两者均映射为各自容器内的 `VLLM_MLLM_ENABLE_THINKING`。共享连接和容器拓扑是例外：数据库地址固定 `mysql:3306`，两后端 `APP_PATH_PREFIX` 固定为空，文件检索复用共用数据库参数；不把发布端口误作容器内部端口。容器数据路径默认位于持久卷 `/workspace/data` 下。

含 `$`、`#`、空格或 JSON 的值用单引号包裹，例如 `KNOWLEDGE_AUTH_DEVELOPER_PERMISSIONS='{"registry":0}'`。Compose 解析外层引号后注入原值，应用无需再剥离引号。真实 `.env` 使用 `0600`，保留在 Git 忽略范围内，不进入构建上下文。变更运行参数后执行 `docker compose up -d --no-build --wait backend knowledge-backend` 重新创建受影响容器；单纯 restart 不会更新环境变量。变更 CorpId 后还需重建知识前端。

### 从旧的分散配置迁移

1. 保留原实际配置作为迁移依据，将两个后端 `.env` 的业务键分别加 `REGISTRY_`、`KNOWLEDGE_` 前缀写入 deploy `.env`；按模板处理共享数据库和 CorpId，保持两个平台密钥独立。
2. 移除根 `.env` 的 `REGISTRY_BACKEND_ENV_FILE`、`KNOWLEDGE_BACKEND_ENV_FILE`。原子项目 `.env` 不再由部署读取，IDE 独立运行仍可保留原文件。
3. 对照新模板补齐全部项并执行 `docker compose config --quiet`。升级不会自动迁移其他服务器的真实凭据，也不会修改既有数据卷。

所有发布端口只绑定 `127.0.0.1`，供宿主机 FRP 或代理访问。中间件采用宿主机端口方案，调用方已有 `host.docker.internal:host-gateway`；中间件的 `22000` 还必须绑定宿主机 Docker 网关地址，仅绑定回环不足以供 bridge 容器访问。无需公共 Docker 网络。

---

## 知识后端配置与启动

知识后端的全部部署配置位于根目录 `.env` 的 `KNOWLEDGE_*` 分组，由主 Compose 映射为原应用变量名，不挂载 `/workspace/.env`，也不需要文件附加组权限。独立源码运行仍可参考[知识后端 Docker 说明](./knowledge-accumulation-be/description/capability/application/docker.md)，统一部署以本文件和根 `.env.example` 为准。

知识后端使用自己的 `knowledge-accumulation` 平台密钥。`KNOWLEDGE_APP_ENV` 模板值为 `production`；CorpId 读取共享 `DINGTALK_CORP_ID`，AppKey/AppSecret 读取 `KNOWLEDGE_DINGTALK_APP_KEY` / `KNOWLEDGE_DINGTALK_APP_SECRET`。统一前端固定生产免登，应保持后端模式一致。模型地址必须容器可达。两后端共用权威 MySQL 人员表，知识后端会自动发布用户/管理员全表，因此启动前应完成完整人员数据准备、外部授权及跨后端覆盖协调，并停止旧的同身份本机实例。

注册中心原件服务地址由 `KNOWLEDGE_REGISTRY_BASE_URL` 配置，模板为 `http://backend:8000`；文件查询直接复用 `mysql:3306` 和共享业务数据库身份，不另维护一份密码。

首次空卷由 [mysql/init/001-schema.sql](mysql/init/001-schema.sql) 一次创建当前全部业务结构，覆盖注册中心与知识后端 `001–029` 的最终表、索引和约束，以及画像序号初值。无需再执行知识后端历史迁移或工作区数据迁移器；完整边界见 [MySQL 初始化说明](mysql/readme.md#初始化与数据边界)。已有卷不会重新初始化，禁止把此脚本作为升级脚本。

### 助理、转换钩子与平台协作

以下变量统一维护在 deploy 根目录 `.env`；完整模板见 [.env.example](.env.example)。表中采用 deploy 键名，注入后去除 `KNOWLEDGE_` 前缀。

| 配置项 | 缺省值 | 部署含义 |
| --- | --- | --- |
| `KNOWLEDGE_ASSISTANT_ENABLED` | `false` | 启用个人助理消费、钉钉 Stream 入站、提醒及心跳；启用前准备机器人凭据和助理表。 |
| `KNOWLEDGE_ASSISTANT_MODEL_RETRY_SECONDS` | `30` | 尚未开始生成时，模型准备暂不可用的重试间隔；不重试已经执行后失败的任务。 |
| `KNOWLEDGE_ASSISTANT_RENDERING_THINKING_EFFORT` | `medium` | finish_task 转换默认开启 medium 推理；可选 none / low / medium / xhigh，与主助理独立。 |
| `KNOWLEDGE_ASSISTANT_HEARTBEAT_INTERVAL_SECONDS` | `-1` | 全局个人助理心跳间隔；-1 关闭，正整数统一应用于所有已启用助理。 |
| `KNOWLEDGE_PLATFORM_A2A_ENABLED` | `false` | 启用跨平台协作；需中间件平台会话及 018 表。 |
| `KNOWLEDGE_PLATFORM_A2A_RESPONSE_BUFFER_SECONDS` | `5` | 广播发布后的响应缓冲，必须小于整轮等待预算。 |
| `KNOWLEDGE_PLATFORM_A2A_WAIT_SECONDS` | `90` | 整轮等待预算。 |
| `KNOWLEDGE_PLATFORM_A2A_POLL_SECONDS` | `1` | 反馈轮询间隔。 |
| `KNOWLEDGE_PLATFORM_A2A_HTTP_TIMEOUT_SECONDS` | `10` | 单次中间件请求超时。 |
| `KNOWLEDGE_PLATFORM_A2A_MAX_CONCURRENT_REQUESTS` | `16` | 平台协作请求并发上限。 |

启用助理后，转换钩子只注册在助理 `finish_task` 上，工具执行完成后、正常提交前做一次 JSON 正文生成并由本地 Pydantic 严格校验，不发送接口级 `response_format`；转换后的正文统一用于答案、后续上下文和钉钉交付。主助理与转换器共用后端 `VLLM_MLLM_*` 模型服务配置，转换默认开启 medium 推理，服务须支持 `/tokenize`，且地址必须容器可达。转换失败会终止当前任务，不提交原文或自动重跑。该钩子没有新增迁移、独立模型容器或独立服务端口；详见[转换契约](./knowledge-accumulation-be/description/architecture/workflow/question-answering/assistant-message-rendering.md)。

新部署的完整初始化已包含助理、跨平台 A2A、当前工作区、员工在职状态、上传文件与个人备忘、独立名称/摘要全文索引、附件交付，以及入站顺序和取消状态。默认关闭的功能仍由配置开关控制，建表不代表启用。

钉钉引用用户/助理消息及富文本适配无需新增环境变量、服务或端口。代码通过镜像打包，更新时执行 `docker compose up -d --build --wait knowledge-backend`，仅重启旧容器不会更新代码。已有数据库的结构升级需按实际状态另行安排，不能重跑空库初始化。

缺失配置项可按模板补齐；本次开启转换推理须将 deploy `.env` 中的 `KNOWLEDGE_ASSISTANT_RENDERING_THINKING_EFFORT` 显式设为 `medium`，仅更新模板不会覆盖已有 `none`。其余开关、地址、凭据和自定义值应保留。修改文件后需重新创建/启动知识后端才能加载；执行前停止使用同一平台身份的 IDE 进程，避免双实例争用。Docker HTTP 健康检查只证明 Web 入口可用，不能证明模型、机器人及中间件已联通。

### 启动与数据卷

准备完成后：

```bash
docker compose config --quiet
docker compose up -d --build --wait knowledge-backend
docker compose logs -f knowledge-backend
```

入口为 `http://127.0.0.1:15000/knowledge-accumulation/api`；HTTP 健康检查使用 `/openapi.json`。固定单 worker，不开启 reload，不直接扩为多实例。SSE 反向代理需要关闭缓冲并保留用户 Authorization，容器停止宽限为 1 分钟。

知识后端数据使用独立卷 `knowledge-backend-data`（默认完整名称 `registry_knowledge-backend-data`），挂载 `/workspace/data`。头像与 PDF 分别在 `user/avatar`、`user/upload-file`；该卷不自动导入本机已有数据，正式切换需单独迁移并核对文件引用与权限。保持 Compose 项目名 `registry`，避免既有 MySQL 与 registry 数据卷因项目改名变成新卷。

registry 头像代理默认改为同网络内的 `http://knowledge-backend:8000`。已有部署 `.env` 的显式旧值会覆盖此默认值，实际切换时需单独调整并重建 `backend`；应核对实际配置。registry 无需挂载知识后端数据卷。

---

## 连接与日常操作

### 知识统一前端

`knowledge-frontend` 从部署目录内的 `knowledge-accumulation-fe` 构建，使用该项目的 Dockerfile 和 Nginx 配置。先在部署 `.env` 填写 `DINGTALK_CORP_ID`；Compose 同时将它映射到前端构建参数 `VITE_DINGTALK_CORP_ID` 和知识后端环境变量 `DINGTALK_CORP_ID`，不再维护两份企业标识。该值公开，AppKey、AppSecret 和开发固定凭据不进入前端构建参数。构建上下文不包含前端实际 `.env`，镜像固定使用生产免登。

已有部署配置中的 `VITE_DINGTALK_CORP_ID` 需在实际切换时改名为 `DINGTALK_CORP_ID`；本次不自动修改真实 `.env`。Compose 将共享值直接注入知识后端，留空不能回退到子项目文件；独立运行前端/后端时仍按各自示例配置。修改共享值后重建 `knowledge-frontend` 并重新创建 `knowledge-backend`，保持浏览器构建与服务端一致。

在知识后端已运行的情况下，仅构建和更新前端：

```bash
docker compose config --quiet
docker compose build knowledge-frontend
docker compose up -d --no-deps knowledge-frontend
```

前端访问 `http://127.0.0.1:15080/knowledge-accumulation/`，生产路径不含 `/dev`。容器内 API 保留 `/knowledge-accumulation/api/` 转发至 `knowledge-backend:8000`，不通过宿主机端口；SSE 关闭响应缓冲和缓存，读取空闲超时 3600 秒。`/healthz` 仅检查静态 Web 入口。

前端带哈希构建资源（含图标）缓存一年，无哈希公共图标缓存 7 天；首页和图标缓存脚本每次校验更新。外站链接图标继续使用浏览器 Service Worker 的 7 天、48 项缓存。头像与附件等鉴权 API 不进入公共缓存。完整规则见[前端部署说明](./knowledge-accumulation-fe/description/platform/deployment.md)。

统一前端的管理平台按需加载、目录后台复核和静态资源压缩随前端镜像发布，不需要修改 Compose 服务、端口或增加环境变量，也不涉及数据库迁移。Vite 的 gzip/Brotli 与预热仅用于开发；生产容器使用 Nginx gzip 压缩静态文本，API/SSE 显式关闭压缩并保留无缓冲转发。前端新增的 Vite 配置模块已纳入 Git 和 Docker 构建上下文；应同时更新前端仓库与部署文档，不能只拉取 deploy。

发布前先在两个仓库确认工作区状态，再分别执行 `git pull --ff-only`，核对部署 `.env` 已有公开 `DINGTALK_CORP_ID`，通过 `docker compose config --quiet`；不要输出完整展开配置。仅更新统一前端时按上述命令构建并用 `--no-deps` 替换前端，其他服务无需重建。

如已有运行中的统一前端，构建前记录其镜像 ID，并为该 ID 添加一个本次发布专用的本地回滚标签。保留旧镜像直到验收完成；需要回滚时，将旧镜像重新标记为 `knowledge-accumulation-fe:dev`，再运行 `docker compose up -d --no-deps --no-build --force-recreate knowledge-frontend`。回滚只替换前端容器，不操作数据卷。

更新后确认容器健康及 `/healthz` 返回 200；从首页实际引用的带哈希 JS/CSS URL 检查 `Accept-Encoding: gzip` 请求返回 `Content-Encoding: gzip` 和 `Vary`，缺失资源应返回 404。随后验证生产路径下的钉钉登录、管理平台首次打开与切页缓存，以及问答 SSE 首条事件即时到达。静态健康检查不能代替这些业务验收，公网与钉钉实机仍须在目标环境完成。

外层网关需保留路径并将 `/knowledge-accumulation/` 转发至前端端口，同时为 SSE 关闭缓冲。注册中心和合同平台的更深前缀需优先路由到各自前端；注册中心前端由下节的 `registry-frontend` 提供，合同平台仍由其独立部署提供，统一入口容器对这两个前缀返回 404。Compose 正常启动前端会等待知识后端健康；更新现有前端使用上面的 `--no-deps` 命令，避免连带启动后端生命周期。

### 注册中心前端

`registry-frontend` 从部署目录内的 `registry-fe` 构建，容器 Nginx 通过 `backend:8000` 原样代理 `/knowledge-accumulation/registry/api/`，不向浏览器注入平台密钥或模型配置。启动或更新：

```bash
docker compose config --quiet
docker compose up -d --build --wait registry-frontend
```

访问 `http://127.0.0.1:16080/knowledge-accumulation/registry/`，`/healthz` 只检查静态入口。外层 HTTPS 网关需将更具体的 `/knowledge-accumulation/registry/` 优先转发到此端口，保留完整路径和鉴权头；页面与知识统一入口须共用同一源，才能读取统一入口保存的 `access_token`。本机不同端口直连仅适合静态检查，不共享浏览器存储。

若此前已通过 `registry-fe/docker-compose.yaml` 独立运行前端，启用本服务前先停止该前端容器，核对其实际发布端口是否与本部署 `REGISTRY_FRONTEND_PORT` 冲突；也可继续独立部署，不启动本服务。网关配置见[注册中心前端部署](./registry-fe/description/platform/deployment.md#域名网关与映射)。

### 其他服务

宿主机使用 `127.0.0.1` 和 `MYSQL_PORT` 连接数据库；后端在 Compose 网络中使用 `mysql:3306`。后端接口入口为 `http://127.0.0.1:16000/knowledge-accumulation/registry/api`，Swagger 文档位于 `/docs`，端口可通过 `BACKEND_PORT` 修改。

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

后端 `/workspace/data` 挂载到 `backend-data`，默认卷名为 `registry_backend-data`，持久化审核数据库、暂存附件和正式资源。该卷不会自动复制本机 `registry-be/data` 中已有记录；迁移开发数据需要停止写入、备份并显式迁移。认证凭据保存在 deploy 根目录 `.env`，不通过人员名单挂载，备份时单独保护实际环境配置。

> **数据边界：** `docker compose down -v` 会删除数据库数据卷，仅在明确需要清空数据时使用。

官方镜像只在空数据目录上创建数据库和账号，并执行镜像内 `mysql/init/` 的 SQL 建立 `resources` 表及 MyVector 索引缓存，安装插件。后端不负责建表。已有数据卷时，修改 `.env` 中的初始化变量不会自动修改现有数据库或密码，需要通过数据库管理操作完成变更。

统一初始化脚本同时创建共享人员、部门、子平台管理员以及知识后端业务表；见 [MySQL 镜像说明](mysql/readme.md#初始化与数据边界)。员工状态字段统一采用 `employment_status`，默认 `employed`，离职为 `resigned`。

---

## 管理员认证与人员数据

`backend` 通过显式 `environment` 接收根 `.env` 中的 `REGISTRY_*` 配置，管理路由先以用户 token 查询中间件 `POST /user/login-cache`，再以 registry 平台会话查询 `GET /platform/admins/list`。未登录返回 401，普通用户返回 403，认证或管理员依赖故障返回 503；文件访问等级不能替代注册中心管理员资格。

用户先在知识后端登录；开发固定凭据、钉钉免登参数、用户/管理员 full-table 注册、用户 token 签发与头像存储目录由知识后端管理。registry 自身的钉钉通讯录刷新读取 deploy `.env` 的 `REGISTRY_DINGTALK_APP_KEY` / `REGISTRY_DINGTALK_APP_SECRET`；该能力不负责登录。后端镜像不再设置 `APP_ENV`，Compose 不再传入 `AVATAR_ROOT` 或挂载头像目录；旧用户配置不应作为 registry 部署环境注入。

| 后端变量 | 默认值 | 说明 |
| --- | --- | --- |
| `AUTH_REQUEST_TIMEOUT_SECONDS` | `5` | 中央用户查询及人员资料读取的总超时。 |

配置唯一入口为 deploy `.env` 的 `REGISTRY_AUTH_REQUEST_TIMEOUT_SECONDS`。管理员全表发布已迁到知识后端，registry 不再启动同步或使用 `MIDDLEWARE_ADMIN_SYNC_ENABLED`；中间件该写接口授权由维护方调整，未在本部署执行真实发布。不再配置旧 `MIDDLEWARE_USER_SYNC_*` 或管理员全表同步开关。

MySQL 的 departments、employees 和 platform_admins 仍需保留：首次员工初始化由知识后端写入，registry 查询同一权威人员源并负责后续权限与管理关系维护。知识后端应连接此处同一人员表/schema（账号可以不同），不能建立互相分叉的权限副本。当前未增加独立人员库连接配置，也未替知识后端改动实际数据库地址或执行生产数据迁移；知识后端旧全表快照覆盖并发权限更新的边界仍需在真实切换前处理。

可信后台原件下载还依赖中间件 `POST /middleware-service/api/platform/token/verify` 只读校验能力，调用方固定为 `knowledge-accumulation` 平台；知识后端通过 Compose 注入的 `REGISTRY_BASE_URL=http://backend:8000` 访问。接口缺失或校验依赖故障时拒绝下载，不需要另设共享文件密钥。完整边界见[原件接口](./registry-be/description/api/resource.md)。

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

头像代理通过 `KNOWLEDGE_ACCUMULATION_BASE_URL` 访问知识后端，转发用户 Bearer token，不挂载知识后端头像目录。当前默认使用同一 Compose 网络的 `knowledge-backend:8000`；若显式改为宿主机服务，须监听容器可达接口，只监听 `127.0.0.1` 可能导致代理 503。头像缓存时长等参数读取 deploy `.env` 的 `REGISTRY_KNOWLEDGE_ACCUMULATION_*` 配置，见[头像代理配置](./registry-be/description/capability/infrastructure/avatar.md#配置与生命周期)。

知识后端镜像另包含模型工具模板，不再携带历史 SQL 迁移文件，详见[知识后端构建边界](./knowledge-accumulation-be/description/capability/application/docker.md)。两个后端均不将真实数据和实际配置复制进镜像。

摘要向量采用固定中文指令“检索与这份摘要语义相关的文本。”，候选 HNSW 缓存会基于现有摘要重新生成向量；首次搜索可能产生模型调用并增加等待时间，不要求部署时执行实验或迁移脚本。具体行为见[向量服务](./registry-be/description/capability/infrastructure/myvector.md)。

---

## 正式资源表与审核存储

`resources` 仅保存已入库文件及已通过的申请、审核备注，不保存 status 和推荐列表。入库暂存、删除申请、审核状态及推荐列表保存在后端 SQLite，通过资源 ID 关联。

MySQL 业务库仅保留 [mysql/init/001-schema.sql](mysql/init/001-schema.sql) 一份最新初始化定义；插件配置、安装与授权保持独立，随空卷首次初始化完成。SQLite 的建表与自动升级由后端独立负责。

已移除历史 MySQL 迁移目录及对应升级工具。部署不需要依次执行旧版本变更；已有卷不会因修改初始化文件或重建镜像而自动变更表结构。旧结构如需继续使用，先备份并单独制定转换方案，不直接对含数据的旧库执行当前建表 SQL 作为升级。


---

## 员工资料初始化

新空卷已包含 `work_profile`、`department_ids`、`employment_status` 和相应检查约束、人员及部门全文索引。`department_id` 保留旧客户端兼容；新代码写完整部门列表，历史 NULL 列表读取时回退旧单值。初始化不创建真实员工，不重置权限；正式启用前仍需准备权威人员数据。
