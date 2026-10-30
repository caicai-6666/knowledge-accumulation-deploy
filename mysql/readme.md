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
| [init/003-personnel.sql](init/003-personnel.sql) | 创建顶级部门、员工、任职资料、多部门及平台权限 JSON 存储。 |
| [init/004-platform-admins.sql](init/004-platform-admins.sql) | 创建子平台管理员列表，通过外键关联员工。 |
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

部门和员工定义见[公司部门与员工契约](../../registry-be/description/architecture/data/employee.md)。已有数据库补建这两张新表时，可在 `knowledge-accumulation-deploy` 目录执行以下命令；该脚本只补建缺失表，不修改资源数据或升级已有同名表：

```bash
docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" exec mysql --user="$MYSQL_USER" --database="$MYSQL_DATABASE" --default-character-set=utf8mb4' < mysql/init/003-personnel.sql
```

已有员工表后，补建子平台管理员表：

```bash
docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" exec mysql --user="$MYSQL_USER" --database="$MYSQL_DATABASE" --default-character-set=utf8mb4' < mysql/init/004-platform-admins.sql
```

已使用旧版员工表、尚未添加姓名和头像列的数据库，应先确认 `SHOW COLUMNS FROM employees` 结果，再一次性执行以下补列操作。当前开发库已补齐，不要重复执行；现有员工资料保持为空，不重置权限：

```sql
ALTER TABLE employees
    ADD COLUMN name VARCHAR(200) NULL COMMENT '钉钉员工姓名，历史未补全时为空' AFTER userid,
    ADD COLUMN avatar_url VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL
        COMMENT '头像相对 data 的地址，未设置头像时为空' AFTER name,
    ADD CONSTRAINT chk_employees_name CHECK (name IS NULL OR CHAR_LENGTH(TRIM(name)) > 0),
    ADD CONSTRAINT chk_employees_avatar_url CHECK (
        avatar_url IS NULL OR REGEXP_LIKE(avatar_url, '^user/avatar/[a-f0-9]{32}[.]webp$', 'c')
    );
```

新空卷直接使用更新后的 `003-personnel.sql`，已包含知识后端 `015` 的 `work_profile` 和 `019` 的 `department_ids` 字段与检查约束，不重复执行这两项迁移。已有卷先检查列及约束，仅对缺失项显式执行知识后端对应迁移；不能用重跑建表脚本升级同名表。部门全文索引 `020` 与知识后端其他业务表仍独立维护。头像文件由后端存储于 data 数据卷，MySQL 只保存相对地址。

---

## 文件等级字段

`init/001-resources.sql` 的最终定义增加 `resources.file_level BIGINT NULL`，新批准存入审核员明确给出的等级，已有未知等级保持 NULL。有符号 64 位整数范围与后端审核参数及 SQLite 一致，不在存储层定义具体等级枚举。

已有卷不会重新执行初始化；先检查列是否存在，缺失时仅执行：

```sql
ALTER TABLE resources
    ADD COLUMN file_level BIGINT NULL
    COMMENT '入库审核确定的文件等级，历史未知时为空；有符号 64 位整数'
    AFTER embedding;
```

该操作不清空原表，不更新历史行的等级值；后端不在启动时执行 MySQL 建表或 ALTER。SQLite 审核表由后端升级至版本 9，审核决定、历史与恢复语义见[入库审核契约](../../registry-be/description/api/ingestion-review.md)。
