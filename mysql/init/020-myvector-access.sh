# 为业务账号开放索引管理过程；仅首次空卷初始化时执行。
if [[ -n "$MYSQL_USER" ]]; then
    if [[ ! "$MYSQL_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "MyVector 初始化要求 MYSQL_USER 仅含字母、数字、下划线或连字符" >&2
        exit 1
    fi
    docker_process_sql <<SQL
GRANT EXECUTE ON PROCEDURE mysql.myvector_index_build TO '$MYSQL_USER'@'%';
GRANT EXECUTE ON PROCEDURE mysql.myvector_index_status TO '$MYSQL_USER'@'%';
SQL
fi
# 当前首次安装过程中动态加载插件，显式指定路径；后续启动由 cnf 保持。
docker_process_sql --execute="SET GLOBAL myvector_index_dir='/var/lib/mysql'"
