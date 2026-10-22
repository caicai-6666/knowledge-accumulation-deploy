CREATE TABLE IF NOT EXISTS resources (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '注册中心文件记录 ID',
    source_platform VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '文件来源平台代号',
    source_id VARCHAR(128) COLLATE utf8mb4_0900_bin NULL COMMENT '文件在来源子平台中的数据 ID，历史文件申请可能缺失',
    file_url VARCHAR(146) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '平台目录内的文件名，格式为 file_id.extension，不带斜线',
    name VARCHAR(200) NULL COMMENT '文件名称，不用于磁盘路径',
    abstract TEXT NULL COMMENT '文件摘要',
    applicant VARCHAR(200) NULL COMMENT '文件入库申请人，未提供时为空',
    applicant_note TEXT NOT NULL COMMENT '已通过入库审核的申请人备注，允许空字符串',
    reviewer VARCHAR(200) NULL COMMENT '入库审核通过的注册中心审核人，历史未知时为空',
    reviewer_note TEXT NULL COMMENT '入库审核通过时的审核人备注，历史未知时为空',
    requested_at DATETIME(6) NOT NULL COMMENT '文件入库申请时间，UTC',
    embedding JSON NULL COMMENT '文件相似度匹配的向量数组，未生成时为空',
    file_level BIGINT NULL COMMENT '入库审核确定的文件等级，历史未知时为空；有符号 64 位整数',
    passport JSON NULL COMMENT '文件通行证字符串数组，一份文件可持有多个通行证，历史未知时为空',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '注册中心文件记录创建时间，UTC',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '文件记录更新时间，UTC',
    PRIMARY KEY (id),
    UNIQUE KEY uq_resources_platform_file (source_platform, file_url),
    UNIQUE KEY uq_resources_platform_source (source_platform, source_id),
    CONSTRAINT chk_resources_passport_array CHECK (passport IS NULL OR JSON_TYPE(passport) = 'ARRAY'),
    CONSTRAINT chk_resources_embedding_array CHECK (
        embedding IS NULL OR (JSON_TYPE(embedding) = 'ARRAY' AND JSON_LENGTH(embedding) > 0)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
