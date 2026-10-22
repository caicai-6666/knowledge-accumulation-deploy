-- 每行关联一名员工，同平台的多行记录共同组成管理员列表，确保数据库能校验员工存在。
CREATE TABLE IF NOT EXISTS platform_admins (
    platform_code VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '子平台代码，同一平台允许关联多位管理员',
    employee_userid VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL COMMENT '管理员的钉钉 userid，关联员工表',
    PRIMARY KEY (platform_code, employee_userid),
    KEY idx_platform_admins_employee (employee_userid),
    CONSTRAINT fk_platform_admins_employee FOREIGN KEY (employee_userid)
        REFERENCES employees (userid) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_platform_admins_code CHECK (
        REGEXP_LIKE(platform_code, '^[a-z][a-z0-9]*(-[a-z0-9]+)*$', 'c')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
    COMMENT='子平台管理员列表，每行关联一位员工';
