-- 统一部署最新业务库初始化（MySQL 8.4）。仅用于全新空库，不是升级脚本。
-- 合并注册中心既有结构及知识后端 001–029；后续修改数据库契约须同步此文件。
-- 使用入口脚本选定的 MYSQL_DATABASE；不硬编码库名，不删除表，不关闭外键检查。
-- 按外键依赖顺序建表；全文检索使用 MySQL 内置 ngram。
-- MyVector 插件及权限仍由独立安装脚本管理，向量索引由应用按需构建。
SET NAMES utf8mb4;

-- assistant_portrait_sequence
CREATE TABLE `assistant_portrait_sequence` (
  `id` tinyint unsigned NOT NULL,
  `next_key` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `assistant_portrait_sequence_chk_1` CHECK (((`id` = 1) and (`next_key` > 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_robot_inbox
CREATE TABLE `assistant_robot_inbox` (
  `request_id` varchar(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `fingerprint` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `message` text NOT NULL,
  `files` json NOT NULL,
  `status` enum('received','publish_pending','publish_unknown','publish_blocked','published','reply_pending','reply_unknown','rejected','cancelled') NOT NULL DEFAULT 'received',
  `reply_text` varchar(1000) DEFAULT NULL,
  `publish_started_at` datetime(6) DEFAULT NULL,
  `next_attempt_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `arrival_sequence` bigint unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`request_id`),
  UNIQUE KEY `uq_robot_inbox_arrival` (`arrival_sequence`),
  KEY `idx_robot_inbox_retry` (`status`,`next_attempt_at`,`request_id`),
  KEY `idx_robot_inbox_user_arrival` (`userid`,`arrival_sequence`,`status`),
  CONSTRAINT `assistant_robot_inbox_chk_1` CHECK ((json_type(`files`) = _utf8mb4'ARRAY')),
  CONSTRAINT `assistant_robot_inbox_chk_2` CHECK ((char_length(`message`) between 1 and 10000)),
  CONSTRAINT `chk_robot_inbox_cancellation` CHECK (((`status` <> _utf8mb4'cancelled') or ((`publish_started_at` is null) and (`reply_text` is not null) and (char_length(trim(`reply_text`)) > 0))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- departments
CREATE TABLE `departments` (
  `id` bigint unsigned NOT NULL COMMENT '公司顶级部门 ID，使用钉钉部门 ID',
  `name` varchar(200) NOT NULL COMMENT '公司顶级部门名称',
  PRIMARY KEY (`id`),
  FULLTEXT KEY `ft_department_name` (`name`) /*!50100 WITH PARSER `ngram` */ ,
  CONSTRAINT `chk_departments_name` CHECK ((char_length(trim(`name`)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='公司顶级部门表';

-- myvector_documents
CREATE TABLE `myvector_documents` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `node_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT 'LlamaIndex 文件节点标识',
  `model_name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT '文件向量生成模型，检索时隔离不同模型',
  `dimensions` smallint unsigned NOT NULL COMMENT '文件向量维度',
  `ref_doc_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin DEFAULT NULL COMMENT '文件文档标识',
  `source_platform` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin DEFAULT NULL COMMENT '文件来源平台',
  `status` varchar(32) DEFAULT NULL COMMENT '文件审核状态',
  `metadata` json NOT NULL COMMENT 'LlamaIndex 文件节点内容及元数据',
  `embedding` blob NOT NULL COMMENT 'MYVECTOR COLUMN |type=HNSW,dim=4096,size=10000,dist=Cosine,M=16,ef=100,idcol=id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_myvector_node_model` (`node_id`,`model_name`),
  KEY `idx_myvector_filter` (`model_name`,`dimensions`,`source_platform`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- platform_a2a_calls
CREATE TABLE `platform_a2a_calls` (
  `broadcast_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `request_json` json NOT NULL,
  `targets` json NOT NULL,
  `published` json DEFAULT NULL,
  `replies` json NOT NULL,
  `result_json` json DEFAULT NULL,
  `state` enum('pending','waiting','completed','abandoned') NOT NULL DEFAULT 'pending',
  `accepted` tinyint(1) NOT NULL DEFAULT '0',
  `close_pending` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `deadline_at` datetime(6) NOT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`broadcast_id`),
  KEY `idx_platform_a2a_pending` (`state`,`deadline_at`),
  KEY `idx_platform_a2a_context` (`userid`,`tree_id`,`accepted`),
  CONSTRAINT `platform_a2a_calls_chk_1` CHECK ((json_type(`request_json`) = _utf8mb4'OBJECT')),
  CONSTRAINT `platform_a2a_calls_chk_2` CHECK ((json_type(`targets`) = _utf8mb4'ARRAY')),
  CONSTRAINT `platform_a2a_calls_chk_3` CHECK ((json_type(`replies`) = _utf8mb4'OBJECT')),
  CONSTRAINT `platform_a2a_calls_chk_4` CHECK (((`accepted` in (0,1)) and (`close_pending` in (0,1)))),
  CONSTRAINT `platform_a2a_calls_chk_5` CHECK ((`deadline_at` > `created_at`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_memory_index
CREATE TABLE `question_memory_index` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `memory_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `kind` enum('question','intermediate','final') NOT NULL,
  `embedding` blob NOT NULL COMMENT 'MYVECTOR COLUMN |type=HNSW,dim=4096,size=10000,dist=Cosine,M=16,ef=100,idcol=id',
  `text` longtext NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_memory_index` (`memory_id`),
  KEY `idx_question_memory_index_scope` (`owner_userid`,`tree_id`,`kind`),
  FULLTEXT KEY `ft_question_memory_text` (`text`) /*!50100 WITH PARSER `ngram` */
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_tree_deletions
CREATE TABLE `question_tree_deletions` (
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `attachments` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`tree_id`),
  CONSTRAINT `question_tree_deletions_chk_1` CHECK ((json_type(`attachments`) = _utf8mb4'ARRAY'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_trees
CREATE TABLE `question_trees` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `name` varchar(200) NOT NULL,
  `kind` enum('assistant','exploration') NOT NULL DEFAULT 'exploration' COMMENT 'assistant：个人助理；exploration：复杂任务探索；共用树结构',
  `main_leaf_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `revision` bigint unsigned NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_tree_identity` (`id`,`owner_userid`,`kind`),
  UNIQUE KEY `uq_question_assistant_owner` (((case when (`kind` = _utf8mb4'assistant') then `owner_userid` else NULL end))),
  KEY `idx_question_trees_owner_updated` (`owner_userid`,`updated_at`,`id`),
  KEY `idx_question_trees_owner_kind_updated` (`owner_userid`,`kind`,`updated_at`,`id`),
  CONSTRAINT `question_trees_chk_1` CHECK ((char_length(trim(`name`)) > 0)),
  CONSTRAINT `question_trees_chk_2` CHECK ((char_length(trim(`owner_userid`)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- resources
CREATE TABLE `resources` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '注册中心文件记录 ID',
  `source_platform` varchar(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '文件来源平台代号',
  `source_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin DEFAULT NULL COMMENT '文件在来源子平台中的数据 ID，历史文件申请可能缺失',
  `file_url` varchar(146) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '平台目录内的文件名，格式为 file_id.extension，不带斜线',
  `name` varchar(200) DEFAULT NULL COMMENT '文件名称，不用于磁盘路径',
  `abstract` text COMMENT '文件摘要',
  `applicant` varchar(200) DEFAULT NULL COMMENT '文件入库申请人，未提供时为空',
  `applicant_note` text NOT NULL COMMENT '已通过入库审核的申请人备注，允许空字符串',
  `reviewer` varchar(200) DEFAULT NULL COMMENT '入库审核通过的注册中心审核人，历史未知时为空',
  `reviewer_note` text COMMENT '入库审核通过时的审核人备注，历史未知时为空',
  `requested_at` datetime(6) NOT NULL COMMENT '文件入库申请时间，UTC',
  `embedding` json DEFAULT NULL COMMENT '文件相似度匹配的向量数组，未生成时为空',
  `file_level` bigint DEFAULT NULL COMMENT '入库审核确定的文件等级，历史未知时为空；有符号 64 位整数',
  `passport` json DEFAULT NULL COMMENT '文件通行证字符串数组，一份文件可持有多个通行证，历史未知时为空',
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '注册中心文件记录创建时间，UTC',
  `updated_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '文件记录更新时间，UTC',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_resources_platform_file` (`source_platform`,`file_url`),
  UNIQUE KEY `uq_resources_platform_source` (`source_platform`,`source_id`),
  CONSTRAINT `chk_resources_embedding_array` CHECK (((`embedding` is null) or ((json_type(`embedding`) = _utf8mb4'ARRAY') and (json_length(`embedding`) > 0)))),
  CONSTRAINT `chk_resources_passport_array` CHECK (((`passport` is null) or (json_type(`passport`) = _utf8mb4'ARRAY')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- uploaded_files
CREATE TABLE `uploaded_files` (
  `id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '现有附件的完整小写 UUID',
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT '文件上传者，由可信上传身份确定',
  `type` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '附件类型：images、audio 或 video，与附件引用一致',
  `visibility` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'public' COMMENT '文件可见范围：public 公开，private 私密，仅上传者可修改',
  `uploaded_at` datetime(6) NOT NULL COMMENT '真实上传时间，UTC，由可信上传流程提供',
  `updated_at` datetime(6) NOT NULL COMMENT '文件元信息最近更新时间，UTC，由程序维护',
  PRIMARY KEY (`id`),
  KEY `idx_uploaded_files_owner_uploaded` (`owner_userid`,`uploaded_at`,`id`),
  CONSTRAINT `chk_uploaded_files_id` CHECK (regexp_like(`id`,_utf8mb4'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',_utf8mb4'c')),
  CONSTRAINT `chk_uploaded_files_owner` CHECK (regexp_like(`owner_userid`,_utf8mb4'[^[:space:]]')),
  CONSTRAINT `chk_uploaded_files_time` CHECK ((`updated_at` >= `uploaded_at`)),
  CONSTRAINT `chk_uploaded_files_type` CHECK ((cast(`type` as char charset binary) in (_utf8mb4'images',_utf8mb4'audio',_utf8mb4'video'))),
  CONSTRAINT `chk_uploaded_files_visibility` CHECK ((cast(`visibility` as char charset binary) in (_utf8mb4'public',_utf8mb4'private')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户上传文件元信息，与个人备忘独立';

-- assistant_file_notes
CREATE TABLE `assistant_file_notes` (
  `file_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '关联 uploaded_files.id 的附件 UUID',
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT '备忘记录者所属用户，由当前助理的可信用户身份确定',
  `name` varchar(200) NOT NULL COMMENT '模型拟定或与用户协商的文件名称',
  `summary` text NOT NULL COMMENT '文件摘要，用于后续定位与查找',
  `updated_at` datetime(6) NOT NULL COMMENT '备忘最近更新时间，UTC，由程序维护',
  PRIMARY KEY (`owner_userid`,`file_id`),
  KEY `idx_assistant_file_notes_owner_updated` (`owner_userid`,`updated_at`,`file_id`),
  KEY `idx_assistant_file_notes_file` (`file_id`),
  FULLTEXT KEY `ft_assistant_file_notes_name_summary` (`name`,`summary`) /*!50100 WITH PARSER `ngram` */ ,
  FULLTEXT KEY `ft_assistant_file_notes_name` (`name`) /*!50100 WITH PARSER `ngram` */ ,
  FULLTEXT KEY `ft_assistant_file_notes_summary` (`summary`) /*!50100 WITH PARSER `ngram` */ ,
  CONSTRAINT `fk_assistant_file_notes_file` FOREIGN KEY (`file_id`) REFERENCES `uploaded_files` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_assistant_file_notes_name` CHECK (regexp_like(`name`,_utf8mb4'[^[:space:]]')),
  CONSTRAINT `chk_assistant_file_notes_owner` CHECK (regexp_like(`owner_userid`,_utf8mb4'[^[:space:]]')),
  CONSTRAINT `chk_assistant_file_notes_summary` CHECK (regexp_like(`summary`,_utf8mb4'[^[:space:]]'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='个人助理附件备忘，每位用户对同一文件最多一条记录';

-- assistant_workspaces
CREATE TABLE `assistant_workspaces` (
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `content` json NOT NULL,
  `summary` mediumtext,
  `first_sequence` bigint unsigned NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`tree_id`),
  UNIQUE KEY `uq_assistant_workspace_id` (`id`),
  CONSTRAINT `assistant_workspaces_ibfk_1` FOREIGN KEY (`tree_id`) REFERENCES `question_trees` (`id`),
  CONSTRAINT `assistant_workspaces_chk_1` CHECK ((json_type(`content`) = _utf8mb4'OBJECT')),
  CONSTRAINT `assistant_workspaces_chk_2` CHECK ((`first_sequence` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistants
CREATE TABLE `assistants` (
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `tree_kind` enum('assistant','exploration') NOT NULL DEFAULT 'assistant',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`userid`),
  UNIQUE KEY `uq_assistant_tree` (`tree_id`),
  UNIQUE KEY `uq_assistant_identity` (`userid`,`tree_id`),
  KEY `idx_assistant_enabled` (`enabled`,`userid`),
  KEY `fk_assistant_tree_identity` (`tree_id`,`userid`,`tree_kind`),
  CONSTRAINT `fk_assistant_tree_identity` FOREIGN KEY (`tree_id`, `userid`, `tree_kind`) REFERENCES `question_trees` (`id`, `owner_userid`, `kind`),
  CONSTRAINT `assistants_chk_1` CHECK ((`tree_kind` = _utf8mb4'assistant')),
  CONSTRAINT `assistants_chk_2` CHECK ((`enabled` in (0,1))),
  CONSTRAINT `assistants_chk_3` CHECK ((char_length(trim(`userid`)) > 0)),
  CONSTRAINT `assistants_chk_4` CHECK ((`updated_at` >= `created_at`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- employees
CREATE TABLE `employees` (
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT '钉钉用户 userid，员工唯一标识，区分大小写',
  `name` varchar(200) DEFAULT NULL COMMENT '钉钉员工姓名，历史未补全时为空',
  `avatar_url` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL COMMENT '头像相对 data 的地址，格式为 user/avatar/随机标识.webp，未设置头像时为空',
  `department_id` bigint unsigned NOT NULL COMMENT '旧版兼容部门 ID，不代表唯一或主要部门',
  `department_ids` json DEFAULT NULL COMMENT '全部一级部门 ID；NULL 时兼容读取 department_id',
  `work_profile` json NOT NULL DEFAULT (json_object(_utf8mb4'manager_userid',NULL,_utf8mb4'title',NULL)) COMMENT '任职资料：直属主管 userid、职位名称',
  `platform_permissions` json NOT NULL DEFAULT (json_object()) COMMENT '平台权限等级对象，以平台代码为键、非负整数等级为值，未配置的平台无授权',
  `employment_status` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'employed' COMMENT '员工在职状态：employed在职，resigned离职',
  PRIMARY KEY (`userid`),
  KEY `idx_employees_department` (`department_id`),
  FULLTEXT KEY `ft_employee_name` (`name`) /*!50100 WITH PARSER `ngram` */ ,
  CONSTRAINT `fk_employees_department` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_employees_avatar_url` CHECK (((`avatar_url` is null) or regexp_like(`avatar_url`,_ascii'^user/avatar/[a-f0-9]{32}[.]webp$',_utf8mb4'c'))),
  CONSTRAINT `chk_employees_department_ids` CHECK (((`department_ids` is null) or json_schema_valid(_utf8mb4'{"type":"array","minItems":1,"uniqueItems":true,"items":{"type":"integer","minimum":0}}',`department_ids`))),
  CONSTRAINT `chk_employees_employment_status` CHECK ((cast(`employment_status` as char charset binary) in (_utf8mb4'employed',_utf8mb4'resigned'))),
  CONSTRAINT `chk_employees_name` CHECK (((`name` is null) or (char_length(trim(`name`)) > 0))),
  CONSTRAINT `chk_employees_platform_permissions` CHECK (json_schema_valid(_utf8mb4'{"type":"object","patternProperties":{"^[a-z][a-z0-9]*(-[a-z0-9]+)*$":{"type":"integer","minimum":0}},"additionalProperties":false}',`platform_permissions`)),
  CONSTRAINT `chk_employees_userid` CHECK (((char_length(trim(`userid`)) > 0) and (`userid` = trim(`userid`)))),
  CONSTRAINT `chk_employees_work_profile` CHECK (json_schema_valid(_utf8mb4'{"type":"object","properties":{"manager_userid":{"type":["string","null"],"maxLength":128},"title":{"type":["string","null"],"maxLength":200}},"required":["manager_userid","title"],"additionalProperties":false}',`work_profile`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='钉钉员工及各平台权限表';

-- question_workspaces
CREATE TABLE `question_workspaces` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `content` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_workspace_tree` (`tree_id`,`id`),
  CONSTRAINT `question_workspaces_ibfk_1` FOREIGN KEY (`tree_id`) REFERENCES `question_trees` (`id`),
  CONSTRAINT `question_workspaces_chk_1` CHECK ((json_type(`content`) = _utf8mb4'OBJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_portraits
CREATE TABLE `assistant_portraits` (
  `key` bigint unsigned NOT NULL AUTO_INCREMENT,
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `subject_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `preference` text NOT NULL,
  PRIMARY KEY (`key`),
  KEY `idx_portraits_owner_subject` (`owner_userid`,`subject_userid`,`key`),
  KEY `fk_portraits_subject` (`subject_userid`),
  CONSTRAINT `fk_portraits_owner` FOREIGN KEY (`owner_userid`) REFERENCES `employees` (`userid`),
  CONSTRAINT `fk_portraits_subject` FOREIGN KEY (`subject_userid`) REFERENCES `employees` (`userid`),
  CONSTRAINT `chk_portraits_preference` CHECK ((char_length(trim(`preference`)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- platform_admins
CREATE TABLE `platform_admins` (
  `platform_code` varchar(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '子平台代码，同一平台允许关联多位管理员',
  `employee_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL COMMENT '管理员的钉钉 userid，关联员工表',
  PRIMARY KEY (`platform_code`,`employee_userid`),
  KEY `idx_platform_admins_employee` (`employee_userid`),
  CONSTRAINT `fk_platform_admins_employee` FOREIGN KEY (`employee_userid`) REFERENCES `employees` (`userid`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_platform_admins_code` CHECK (regexp_like(`platform_code`,_utf8mb4'^[a-z][a-z0-9]*(-[a-z0-9]+)*$',_utf8mb4'c'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='子平台管理员列表，每行关联一位员工';

-- question_nodes
CREATE TABLE `question_nodes` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `parent_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `kind` enum('task','summary') NOT NULL,
  `path_type` enum('main','branch') NOT NULL DEFAULT 'main' COMMENT 'main：主干节点；branch：分支节点；与任务/摘要类型独立',
  `status` enum('generating','complete','cancelled','superseded','failed') NOT NULL,
  `sequence` bigint unsigned NOT NULL,
  `workspace_version_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  `superseded_by_node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_node_tree` (`tree_id`,`id`),
  UNIQUE KEY `uq_question_node_sequence` (`tree_id`,`sequence`),
  UNIQUE KEY `uq_question_node_replacement` (`tree_id`,`superseded_by_node_id`),
  KEY `idx_question_node_parent` (`tree_id`,`parent_id`),
  KEY `tree_id` (`tree_id`,`workspace_version_id`),
  CONSTRAINT `question_nodes_ibfk_1` FOREIGN KEY (`tree_id`) REFERENCES `question_trees` (`id`),
  CONSTRAINT `question_nodes_ibfk_2` FOREIGN KEY (`tree_id`, `parent_id`) REFERENCES `question_nodes` (`tree_id`, `id`),
  CONSTRAINT `question_nodes_ibfk_3` FOREIGN KEY (`tree_id`, `workspace_version_id`) REFERENCES `question_workspaces` (`tree_id`, `id`),
  CONSTRAINT `question_nodes_ibfk_4` FOREIGN KEY (`tree_id`, `superseded_by_node_id`) REFERENCES `question_nodes` (`tree_id`, `id`),
  CONSTRAINT `question_nodes_chk_1` CHECK ((`sequence` > 0)),
  CONSTRAINT `question_nodes_chk_2` CHECK (((`parent_id` is null) or (`parent_id` <> `id`))),
  CONSTRAINT `question_nodes_chk_3` CHECK (((`kind` <> _utf8mb4'summary') or ((`status` = _utf8mb4'complete') and (`parent_id` is not null)))),
  CONSTRAINT `question_nodes_chk_4` CHECK (((`status` = _utf8mb4'superseded') = (`superseded_by_node_id` is not null))),
  CONSTRAINT `question_nodes_chk_5` CHECK (((`superseded_by_node_id` is null) or (`superseded_by_node_id` <> `id`))),
  CONSTRAINT `question_nodes_chk_6` CHECK (((`finished_at` is null) or ((`status` <> _utf8mb4'generating') and (`finished_at` >= `created_at`))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_task_executions
CREATE TABLE `assistant_task_executions` (
  `task_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `tree_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `task_type` enum('reminder','user_message','assistant_message','heartbeat') NOT NULL,
  `input_payload` json NOT NULL COMMENT 'pull 冻结的任务快照，不存平台 token 或交付凭证',
  `file_bindings` json NOT NULL COMMENT '中间件文件引用到本地任务附件的映射，原始消息归属在 input_payload',
  `processing_status` enum('received','prepared','running','completed','failed') NOT NULL DEFAULT 'received',
  `error_code` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `received_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `finished_at` datetime(6) DEFAULT NULL,
  `acknowledged_at` datetime(6) DEFAULT NULL,
  `delivery_token` varchar(128) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL COMMENT '仅用于恢复 ack，不进入业务输入/模型上下文/日志',
  `lease_expires_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`task_id`),
  UNIQUE KEY `uq_assistant_execution_identity` (`task_id`,`userid`),
  UNIQUE KEY `uq_assistant_execution_node` (`node_id`),
  UNIQUE KEY `uq_assistant_active` (((case when (`processing_status` in (_utf8mb4'received',_utf8mb4'prepared',_utf8mb4'running')) then `userid` else NULL end))),
  KEY `idx_assistant_execution_user` (`userid`,`received_at`,`task_id`),
  KEY `idx_assistant_execution_recovery` (`acknowledged_at`,`processing_status`,`updated_at`),
  KEY `fk_assistant_execution_owner` (`userid`,`tree_id`),
  KEY `fk_assistant_execution_node` (`tree_id`,`node_id`),
  CONSTRAINT `fk_assistant_execution_node` FOREIGN KEY (`tree_id`, `node_id`) REFERENCES `question_nodes` (`tree_id`, `id`),
  CONSTRAINT `fk_assistant_execution_owner` FOREIGN KEY (`userid`, `tree_id`) REFERENCES `assistants` (`userid`, `tree_id`),
  CONSTRAINT `assistant_task_executions_chk_1` CHECK ((char_length(trim(`task_id`)) > 0)),
  CONSTRAINT `assistant_task_executions_chk_10` CHECK (((`finished_at` is null) or ((`finished_at` >= `received_at`) and (`finished_at` <= `updated_at`)))),
  CONSTRAINT `assistant_task_executions_chk_11` CHECK (((`processing_status` not in (_utf8mb4'running',_utf8mb4'completed')) or (`node_id` is not null) or (`processing_status` = _utf8mb4'completed' and `task_type` = _utf8mb4'heartbeat'))),
  CONSTRAINT `assistant_task_executions_chk_12` CHECK (((`acknowledged_at` is null) or ((`finished_at` is not null) and (`acknowledged_at` >= `finished_at`) and (`acknowledged_at` <= `updated_at`)))),
  CONSTRAINT `assistant_task_executions_chk_13` CHECK (((`error_code` is null) or (char_length(trim(`error_code`)) > 0))),
  CONSTRAINT `assistant_task_executions_chk_2` CHECK ((json_type(`input_payload`) = _utf8mb4'OBJECT')),
  CONSTRAINT `assistant_task_executions_chk_3` CHECK ((json_contains_path(`input_payload`,_utf8mb4'all',_utf8mb4'$.task_id',_utf8mb4'$.userid',_utf8mb4'$.task_type',_utf8mb4'$.files',_utf8mb4'$.user_messages') = 1)),
  CONSTRAINT `assistant_task_executions_chk_4` CHECK (((json_unquote(json_extract(`input_payload`,_utf8mb4'$.task_id')) collate utf8mb4_0900_bin) = `task_id`)),
  CONSTRAINT `assistant_task_executions_chk_5` CHECK (((json_unquote(json_extract(`input_payload`,_utf8mb4'$.userid')) collate utf8mb4_0900_bin) = `userid`)),
  CONSTRAINT `assistant_task_executions_chk_6` CHECK ((json_unquote(json_extract(`input_payload`,_utf8mb4'$.task_type')) = `task_type`)),
  CONSTRAINT `assistant_task_executions_chk_7` CHECK ((json_type(`file_bindings`) = _utf8mb4'ARRAY')),
  CONSTRAINT `assistant_task_executions_chk_8` CHECK ((`updated_at` >= `received_at`)),
  CONSTRAINT `assistant_task_executions_chk_9` CHECK (((`processing_status` in (_utf8mb4'completed',_utf8mb4'failed')) = (`finished_at` is not null))),
  CONSTRAINT `chk_assistant_lease_pair` CHECK (((`delivery_token` is null) = (`lease_expires_at` is null)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_node_contents
CREATE TABLE `question_node_contents` (
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `content` json NOT NULL,
  `display_history` json DEFAULT NULL,
  PRIMARY KEY (`node_id`),
  CONSTRAINT `question_node_contents_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `question_nodes` (`id`),
  CONSTRAINT `chk_question_display_object` CHECK (((`display_history` is null) or (json_type(`display_history`) = _utf8mb4'OBJECT'))),
  CONSTRAINT `question_node_contents_chk_1` CHECK ((json_type(`content`) = _utf8mb4'OBJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_node_generations
CREATE TABLE `question_node_generations` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `status` enum('complete','failed','cancelled') NOT NULL,
  `payload` json NOT NULL COMMENT '完整原生响应、推理与流式片段，仅供私有恢复和审计',
  `sequence` bigint unsigned NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_generation_sequence` (`node_id`,`sequence`),
  CONSTRAINT `question_node_generations_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `question_nodes` (`id`),
  CONSTRAINT `question_node_generations_chk_1` CHECK ((`sequence` > 0)),
  CONSTRAINT `question_node_generations_chk_2` CHECK ((json_type(`payload`) = _utf8mb4'OBJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_node_memories
CREATE TABLE `question_node_memories` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `source_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `kind` enum('question','intermediate','final') NOT NULL,
  `embedding` mediumblob COMMENT '小端连续 float32；模型及维度由统一配置约束',
  `embedding_status` enum('pending','success','failed') NOT NULL DEFAULT 'pending',
  `created_at` datetime(6) NOT NULL,
  `embedded_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_memory_source` (`node_id`,`kind`,`source_id`),
  KEY `idx_question_memory_status` (`embedding_status`,`created_at`,`id`),
  CONSTRAINT `question_node_memories_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `question_nodes` (`id`),
  CONSTRAINT `question_node_memories_chk_1` CHECK ((char_length(trim(`source_id`)) > 0)),
  CONSTRAINT `question_node_memories_chk_2` CHECK ((((`embedding_status` = _utf8mb4'success') and (`embedding` is not null) and (`embedded_at` is not null) and (length(`embedding`) > 0) and ((length(`embedding`) % 4) = 0)) or ((`embedding_status` in (_utf8mb4'pending',_utf8mb4'failed')) and (`embedding` is null) and (`embedded_at` is null))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- question_node_messages
CREATE TABLE `question_node_messages` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `node_id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `kind` enum('question','intermediate','final') NOT NULL,
  `status` enum('completed','interrupted') NOT NULL DEFAULT 'completed',
  `text` longtext NOT NULL,
  `sequence` bigint unsigned NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_question_message_sequence` (`node_id`,`sequence`),
  KEY `idx_question_message_source` (`node_id`,`kind`,`id`),
  CONSTRAINT `question_node_messages_ibfk_1` FOREIGN KEY (`node_id`) REFERENCES `question_nodes` (`id`),
  CONSTRAINT `question_node_messages_chk_1` CHECK ((`sequence` > 0)),
  CONSTRAINT `question_node_messages_chk_2` CHECK ((char_length(trim(`text`)) > 0)),
  CONSTRAINT `question_node_messages_chk_3` CHECK (((`kind` <> _utf8mb4'question') or (`status` = _utf8mb4'completed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_portrait_actions
CREATE TABLE `assistant_portrait_actions` (
  `task_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `owner_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `operation_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `fingerprint` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (`task_id`,`operation_hash`),
  KEY `fk_portrait_action_task` (`task_id`,`owner_userid`),
  CONSTRAINT `fk_portrait_action_task` FOREIGN KEY (`task_id`, `owner_userid`) REFERENCES `assistant_task_executions` (`task_id`, `userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_reminders
CREATE TABLE `assistant_reminders` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `content` text NOT NULL,
  `schedule_type` enum('once','interval','calendar') NOT NULL,
  `schedule_config` json NOT NULL COMMENT '按 schedule_type 严格验证的一次性、固定间隔或日历规则',
  `timezone` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'Asia/Shanghai',
  `next_fire_at` datetime(6) DEFAULT NULL,
  `end_at` datetime(6) DEFAULT NULL,
  `status` enum('enabled','paused','completed','cancelled') NOT NULL DEFAULT 'enabled',
  `created_by_task_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_assistant_reminder_identity` (`id`,`userid`),
  KEY `idx_assistant_reminder_due` (`status`,`next_fire_at`,`id`),
  KEY `idx_assistant_reminder_user` (`userid`,`status`,`id`),
  KEY `fk_assistant_reminder_source` (`created_by_task_id`,`userid`),
  CONSTRAINT `fk_assistant_reminder_owner` FOREIGN KEY (`userid`) REFERENCES `assistants` (`userid`),
  CONSTRAINT `fk_assistant_reminder_source` FOREIGN KEY (`created_by_task_id`, `userid`) REFERENCES `assistant_task_executions` (`task_id`, `userid`),
  CONSTRAINT `assistant_reminders_chk_1` CHECK ((char_length(trim(`content`)) between 1 and 10000)),
  CONSTRAINT `assistant_reminders_chk_2` CHECK ((json_type(`schedule_config`) = _utf8mb4'OBJECT')),
  CONSTRAINT `assistant_reminders_chk_3` CHECK ((char_length(trim(`timezone`)) > 0)),
  CONSTRAINT `assistant_reminders_chk_4` CHECK (((`status` <> _utf8mb4'enabled') or (`next_fire_at` is not null))),
  CONSTRAINT `assistant_reminders_chk_5` CHECK (((`status` not in (_utf8mb4'completed',_utf8mb4'cancelled')) or (`next_fire_at` is null))),
  CONSTRAINT `assistant_reminders_chk_6` CHECK (((`end_at` is null) or (`next_fire_at` is null) or (`next_fire_at` <= `end_at`))),
  CONSTRAINT `assistant_reminders_chk_7` CHECK ((`updated_at` >= `created_at`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- assistant_deliveries
CREATE TABLE `assistant_deliveries` (
  `id` char(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `task_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin DEFAULT NULL,
  `reminder_id` char(32) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `action_key` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `scheduled_for` datetime(6) DEFAULT NULL,
  `destination` enum('user','assistant') NOT NULL,
  `recipient_userid` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
  `task_type` enum('assistant_message','reminder') DEFAULT NULL,
  `message` longtext NOT NULL,
  `status` enum('pending','sent','failed') NOT NULL DEFAULT 'pending',
  `attempt_count` int unsigned NOT NULL DEFAULT '0',
  `next_attempt_at` datetime(6) DEFAULT NULL,
  `sent_at` datetime(6) DEFAULT NULL,
  `external_receipt` json DEFAULT NULL,
  `error_code` varchar(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `file_id` char(36) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_assistant_delivery_action` (`task_id`,`action_key`),
  UNIQUE KEY `uq_assistant_reminder_occurrence` (`reminder_id`,`scheduled_for`),
  KEY `idx_assistant_delivery_pending` (`status`,`next_attempt_at`,`id`),
  KEY `idx_assistant_delivery_user` (`userid`,`created_at`,`id`),
  KEY `fk_assistant_delivery_task` (`task_id`,`userid`),
  KEY `fk_assistant_delivery_reminder` (`reminder_id`,`userid`),
  CONSTRAINT `fk_assistant_delivery_owner` FOREIGN KEY (`userid`) REFERENCES `assistants` (`userid`),
  CONSTRAINT `fk_assistant_delivery_reminder` FOREIGN KEY (`reminder_id`, `userid`) REFERENCES `assistant_reminders` (`id`, `userid`),
  CONSTRAINT `fk_assistant_delivery_task` FOREIGN KEY (`task_id`, `userid`) REFERENCES `assistant_task_executions` (`task_id`, `userid`),
  CONSTRAINT `assistant_deliveries_chk_1` CHECK ((((`task_id` is not null) + (`reminder_id` is not null)) = 1)),
  CONSTRAINT `assistant_deliveries_chk_10` CHECK (((`status` = _utf8mb4'sent') = (`sent_at` is not null))),
  CONSTRAINT `assistant_deliveries_chk_11` CHECK (((`sent_at` is null) or ((`sent_at` >= `created_at`) and (`sent_at` <= `updated_at`)))),
  CONSTRAINT `assistant_deliveries_chk_12` CHECK (((`status` <> _utf8mb4'sent') or (`next_attempt_at` is null))),
  CONSTRAINT `assistant_deliveries_chk_13` CHECK (((`external_receipt` is null) or (json_type(`external_receipt`) = _utf8mb4'OBJECT'))),
  CONSTRAINT `assistant_deliveries_chk_14` CHECK (((`error_code` is null) or (char_length(trim(`error_code`)) > 0))),
  CONSTRAINT `assistant_deliveries_chk_15` CHECK ((`updated_at` >= `created_at`)),
  CONSTRAINT `assistant_deliveries_chk_2` CHECK (((`reminder_id` is not null) = (`scheduled_for` is not null))),
  CONSTRAINT `assistant_deliveries_chk_3` CHECK ((char_length(trim(`action_key`)) > 0)),
  CONSTRAINT `assistant_deliveries_chk_4` CHECK ((char_length(trim(`recipient_userid`)) > 0)),
  CONSTRAINT `assistant_deliveries_chk_5` CHECK ((char_length(trim(`message`)) > 0)),
  CONSTRAINT `assistant_deliveries_chk_6` CHECK (((`destination` <> _utf8mb4'assistant') or (char_length(`message`) <= 10000))),
  CONSTRAINT `assistant_deliveries_chk_7` CHECK ((((`destination` = _utf8mb4'user') and (`task_type` is null)) or ((`destination` = _utf8mb4'assistant') and (`task_type` is not null)))),
  CONSTRAINT `assistant_deliveries_chk_8` CHECK (((`reminder_id` is null) or ((`destination` = _utf8mb4'assistant') and (`task_type` = _utf8mb4'reminder') and (`recipient_userid` = `userid`)))),
  CONSTRAINT `assistant_deliveries_chk_9` CHECK (((`task_id` is null) or (`destination` = _utf8mb4'user') or (`task_type` = _utf8mb4'assistant_message'))),
  CONSTRAINT `chk_assistant_delivery_file` CHECK (((`file_id` is null) or ((`destination` = _utf8mb4'user') and (`task_id` is not null) and (`recipient_userid` = `userid`) and regexp_like(`file_id`,_utf8mb4'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',_utf8mb4'c'))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 空库画像序号从 1 开始；业务运行后不得重置。
INSERT INTO assistant_portrait_sequence (id, next_key) VALUES (1, 1);
