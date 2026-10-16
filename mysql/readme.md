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
| [init/001-resources.sql](init/001-resources.sql) | 创建最终版本的正式资源表。 |
| [init/002-myvector-documents.sql](init/002-myvector-documents.sql) | 创建 4096 维 HNSW/Cosine 索引缓存，容量为 10,000。 |
| `init/020-myvector-access.sh` | 授权业务账号执行索引构建、状态查询，并设置插件索引目录。 |

镜像还从固定插件镜像复制 `010-myvector-plugin.sql`，安装插件、UDF 和索引管理存储过程，无需在项目中另存副本。

正式资源表只保存审核通过的文件，包含最终申请、审核信息及 JSON 数组通行证；不包含审核状态、推荐列表或消息消费字段。MySQL 不保存待审记录，待审与历史由后端 SQLite 管理，字段定义见[资源表契约](../../registry-be/description/architecture/data/resource.md)。

---

## 构建与启动

在本目录单独构建：

```bash
docker build --build-arg MYSQL_VERSION=8.4 -t registry-mysql:8.4 .
```

`MYSQL_VERSION` 可指定经过验证的 MySQL 8.4 补丁版本。实际运行通过上级 Compose 管理，在 `registry-deploy` 中准备 `.env` 后执行：

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
