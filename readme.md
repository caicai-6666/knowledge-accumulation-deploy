# 注册中心统一部署

本项目通过 Docker Compose 管理知识沉淀注册中心的服务部署，集中维护服务配置、网络和数据持久化。

> **当前范围：** Compose 已配置 MySQL 和后端服务。人员名单采用与合同部署一致的独立文件只读挂载；消息中间件仍由对应项目部署。

---

## 目录与依赖

部署目录结构如下：

```text
知识沉淀注册中心/
├── registry-be/
└── registry-deploy/
    ├── mysql/
    │   ├── Dockerfile
    │   ├── myvector-options.cnf
    │   └── init/
    │       ├── 000-myvector-config.sh
    │       ├── 001-resources.sql
    │       ├── 002-myvector-documents.sql
    │       └── 020-myvector-access.sh
    ├── docker-compose.yaml
    ├── user.yaml.example
    ├── user.yaml              # 实际人员名单，不提交
    └── .env.example
```

需要 Docker Engine 或 Docker Desktop，以及支持长格式 bind 和 `env_file.format: raw` 的现代 Compose 插件。数据库镜像从[MySQL 镜像项目](mysql/readme.md)构建，后端范围见[项目总览](../registry-be/description/project.md)。

---

## 配置与启动

在 `registry-deploy` 目录执行：

```bash
cp .env.example .env
test -f user.yaml || cp user.yaml.example user.yaml
chmod 600 .env user.yaml
```

已有实际配置时不要覆盖。编辑 `.env`，设置 `MYSQL_ROOT_PASSWORD` 和 `MYSQL_PASSWORD`；编辑 `user.yaml`，替换示例密钥。后端其他配置读取 `../registry-be/.env`，该文件需事先准备好，并设置平台和模型服务凭据。然后执行：

```bash
docker compose config --quiet
docker compose up -d --build --wait
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
| `MIDDLEWARE_BASE_URL` | `http://host.docker.internal:22000` | 中间件地址，覆盖后端本机配置中的 localhost。 |

Compose 把 MySQL 地址固定为 `mysql:3306`，数据库名、账号和密码取部署目录 `.env`；SQLite、正式资源和审核暂存目录固定在 `/workspace/data` 下。其他后端环境变量从 `../registry-be/.env` 原样传入，避免密钥中的 `$` 被插值；该文件中的值不要添加外围引号，规则与后端 Docker 运行说明一致。不要公开 `docker compose config` 的完整展开结果，语法校验使用 `--quiet`。

---

## 连接与日常操作

宿主机使用 `127.0.0.1` 和 `MYSQL_PORT` 连接数据库；后端在 Compose 网络中使用 `mysql:3306`。后端接口入口为 `http://127.0.0.1:23000/registry/api`，Swagger 文档位于 `/docs`，端口可通过 `BACKEND_PORT` 修改。

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

后端 `/workspace/data` 挂载到 `backend-data`，默认卷名为 `registry_backend-data`，持久化审核数据库、暂存附件和正式资源。该卷不会自动复制本机 `registry-be/data` 中已有记录；迁移开发数据需要停止写入、备份并显式迁移。人员名单单独挂载，不写入该卷，备份时需单独保留 `user.yaml`。

> **数据边界：** `docker compose down -v` 会删除数据库数据卷，仅在明确需要清空数据时使用。

官方镜像只在空数据目录上创建数据库和账号，并执行镜像内 `mysql/init/` 的 SQL 建立 `resources` 表及 MyVector 索引缓存，安装插件。后端不负责建表。已有数据卷时，修改 `.env` 中的初始化变量不会自动修改现有数据库或密码，需要通过数据库管理操作完成变更。

---

## 人员名单挂载

与合同项目相同，部署目录 `./user.yaml` 只读挂载到 `/workspace/data/user/users.yaml`，并显式设置 `REVIEWER_USER_FILE` 为此路径。名单结构见[审核人员定义](../registry-be/description/architecture/data/reviewer-user-definition.md)，`user.yaml.example` 仅为模板，真实文件由 Git 忽略。

`bind.create_host_path: false` 防止缺少文件时被 Docker 自动创建为目录；不存在或内容不合法时启动失败。文件必须允许容器 UID/GID `10001` 读取，Linux 部署可通过文件所有权或 ACL 授权，并保持凭据访问范围受限。

名单在启动时加载，不支持热更新。编辑器可能原子替换文件，因此修改后重新创建后端容器：

```bash
docker compose up -d --build --force-recreate backend
```

此操作保留数据卷，但会使原免登码失效。后端构建上下文为 `../registry-be`，只启动单 worker；避免与本机直接运行的后端同时使用同一个中间件平台注册凭据。

Compose 配置与依赖启动行为参考 [Docker Compose 官方文档](https://docs.docker.com/compose/how-tos/startup-order/)；数据库初始化行为参考 [MySQL 官方镜像说明](https://hub.docker.com/_/mysql)。

---

## 正式资源表与审核存储

`resources` 仅保存已入库文件及已通过的申请、审核备注，不保存 status 和推荐列表。入库暂存、删除申请、审核状态及推荐列表保存在后端 SQLite，通过资源 ID 关联。

MySQL 只保留当前初始化定义：`mysql/init/001-resources.sql` 创建最终版本的正式资源表，`mysql/init/002-myvector-documents.sql` 创建索引缓存；插件配置、安装与授权随空卷首次初始化完成。SQLite 的建表与自动升级由后端独立负责。

已移除历史 MySQL 迁移目录及对应升级工具。部署不需要依次执行旧版本变更；已有卷不会因修改初始化文件或重建镜像而自动变更表结构。旧结构如需继续使用，先备份并单独制定转换方案，不直接对含数据的旧库执行当前建表 SQL 作为升级。
