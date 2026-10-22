CREATE TABLE IF NOT EXISTS departments (
    id BIGINT UNSIGNED NOT NULL COMMENT '公司顶级部门 ID，使用钉钉部门 ID',
    name VARCHAR(200) NOT NULL COMMENT '公司顶级部门名称',
    PRIMARY KEY (id),
    CONSTRAINT chk_departments_name CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
    COMMENT='公司顶级部门表';

CREATE TABLE IF NOT EXISTS employees (
    userid VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL COMMENT '钉钉用户 userid，员工唯一标识，区分大小写',
    name VARCHAR(200) NULL COMMENT '钉钉员工姓名，历史未补全时为空',
    avatar_url VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL COMMENT '头像相对 data 的地址，格式为 user/avatar/随机标识.webp，未设置头像时为空',
    department_id BIGINT UNSIGNED NOT NULL COMMENT '员工所属的唯一顶级部门 ID',
    platform_permissions JSON NOT NULL DEFAULT (JSON_OBJECT()) COMMENT '平台权限等级对象，以平台代码为键、非负整数等级为值，未配置的平台无授权',
    PRIMARY KEY (userid),
    KEY idx_employees_department (department_id),
    CONSTRAINT fk_employees_department FOREIGN KEY (department_id)
        REFERENCES departments (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_employees_userid CHECK (
        CHAR_LENGTH(TRIM(userid)) > 0 AND userid = TRIM(userid)
    ),
    CONSTRAINT chk_employees_name CHECK (name IS NULL OR CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_employees_avatar_url CHECK (
        avatar_url IS NULL OR REGEXP_LIKE(avatar_url, '^user/avatar/[a-f0-9]{32}[.]webp$', 'c')
    ),
    -- 平台代码格式与现有消息契约一致；等级含义由后续授权规则定义。
    CONSTRAINT chk_employees_platform_permissions CHECK (
        JSON_SCHEMA_VALID(
            '{"type":"object","patternProperties":{"^[a-z][a-z0-9]*(-[a-z0-9]+)*$":{"type":"integer","minimum":0}},"additionalProperties":false}',
            platform_permissions
        )
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
    COMMENT='钉钉员工及各平台权限表';
