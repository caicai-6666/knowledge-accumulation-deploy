# 注册中心 MySQL 镜像

本目录维护知识沉淀注册中心使用的 MySQL 8.4 与 MyVector 镜像，仅保留当前版本的构建配置、插件配置和首次初始化脚本。服务、账号、网络与数据卷由[统一部署项目](../readme.md)管理。

---

## 目录与职责

| 文件 | 用途 |
| --- | --- |
| `Dockerfile` | 使用 MySQL 8.4，从固定摘要的 MyVector 镜像提取插件及安装 SQL。 |
| `.dockerignore` | 构建上下文仅包含镜像与初始化所需文件。 |
| `myvector-options.cnf` | 将插件索引目录设置到 `/var/lib/mysql`，与数据卷一起保留。 |
| `init/000-myvector-config.sh` | 首次启动时生成插件内部连接配置，权限为 600、属主为 mysql。 |
| [init/001-schema.sql](init/001-schema.sql) | 唯一业务库初始化：注册中心、共享人员、探索问答、个人助理、A2A、文件备忘与向量缓存，共 26 张表。 |
| `init/020-myvector-access.sh` | 授权业务账号执行索引构建、状态查询，并设置插件索引目录。 |

镜像还从固定插件镜像复制 `010-myvector-plugin.sql`，安装插件、UDF 和索引管理存储过程，无需在项目中另存副本。

正式资源表只保存审核通过的文件，包含最终申请、审核信息及 JSON 数组通行证；不包含审核状态、推荐列表或消息消费字段。MySQL 不保存待审记录，待审与历史由后端 SQLite 管理，字段定义见[资源表契约](../../registry-be/description/architecture/data/resource.md)。

---

## 构建与启动

在本目录单独构建：

```bash
docker build --build-arg MYSQL_VERSION=8.4 -t registry-mysql:8.4 .
```

`MYSQL_VERSION` 可指定经过验证的 MySQL 8.4 补丁版本。实际运行通过上级 Compose 管理，在 `knowledge-accumulation-deploy` 中准备 `.env` 后执行：

```bash
docker compose config --quiet
docker compose up -d --build --wait mysql
```

使用 `utf8mb4` 字符集和 `utf8mb4_0900_ai_ci` 默认排序规则。业务账号只允许字母、数字、下划线或连字符；插件内部连接使用容器 root 密码，该密码不能包含换行。

---

## 初始化与数据边界

Dockerfile 将 `init/` 复制到 `/docker-entrypoint-initdb.d/`；官方入口仅在空数据目录首次启动时，按文件名顺序执行初始化。目标数据库由 `MYSQL_DATABASE` 指定，后端只连接和使用表，不执行 MySQL 建表。

当前目录不再保留历史迁移文件，也不提供旧版 MySQL 表结构的升级命令。新部署直接使用当前初始化定义；已有数据卷不会重新执行脚本，重新构建镜像不修改已有表。旧结构如需继续使用，应先备份并单独制定数据转换方案，不通过删除数据卷更新表结构。

SQLite 的初始化和自动升级由后端独立维护，本次精简不改变其行为。向量查询、快照同步及能力边界见[MyVector 与 vLLM](../../registry-be/description/capability/infrastructure/myvector.md)。

## 当前结构与维护

唯一业务库脚本为 `init/001-schema.sql`，直接创建最终结构，不串联历史 ALTER，也不禁用外键检查。覆盖知识后端 `schema/001–029` 的最终结果，以及原有资源、向量缓存、共享人员和管理员表。画像私有序号初始化为 `(id=1, next_key=1)`，其余业务表为空。

- 员工包含任职资料、多部门和 `employment_status`（默认 `employed`，离职为 `resigned`）。
- 问答包含生命周期、消息、生成记录、记忆、全文及向量缓存。
- 个人助理包含工作区、画像、提醒、交付、入站顺序与取消约束、上传文件和个人备忘；名称与摘要具有独立 ngram 全文索引。
- 资源保留有符号 `file_level BIGINT NULL`，SQLite 审核状态仍由 registry 后端管理。
- 两张 MyVector 缓存使用 4096 维、HNSW/Cosine、容量 10,000；建表不调用模型，不自动构建向量索引。运行配置须与维度一致。

后续数据库契约变更须同步此脚本。知识后端不再保留历史 SQL，新部署只使用本脚本，也不运行旧工作区数据迁移器；结构演进仅通过 Git 历史追溯。此脚本不包含真实员工、权限、消息或附件，不从开发数据库导出业务数据。

首次部署先执行 `docker compose up -d --build --wait mysql`，完成初始化后再启动后端。已有数据目录不会重新执行；不要为了更新结构删除现有数据卷。现有开发库及数据保持不变。

---

## 验证

2026-11-09 在无网络、临时内存数据目录的 MySQL 8.4 容器中，以原部署定义及知识后端历史迁移构建基准，再向另一空库执行合并脚本。逐表比较 26 张表的 `SHOW CREATE TABLE`（字段、索引、外键、检查约束）及初始记录，全部一致，画像序号初值为 1。此验证不代表生产模型、钉钉或中间件已联通。

另使用现有 MySQL 8.4.13 镜像的官方入口，在隔离空数据目录中装入最新 SQL，完成插件配置、全部业务建表、插件安装及业务账号授权；验证 26 张表可由业务账号访问，画像序号为 1，MyVector 状态为 `ACTIVE`。生产及开发 Compose 均通过 `config --quiet`。未重建正式镜像或启动正式服务。
