# 由官方 entrypoint source，配置插件内部的本机连接；凭据不写入镜像。
if [[ "$MYSQL_ROOT_PASSWORD" == *$'\n'* || "$MYSQL_ROOT_PASSWORD" == *$'\r'* ]]; then
    echo "MyVector 内部连接密码不支持换行" >&2
    exit 1
fi
(
    umask 077
    printf 'myvector_host=127.0.0.1\nmyvector_port=3306\nmyvector_user_id=root\nmyvector_user_password=%s\n' "$MYSQL_ROOT_PASSWORD" > /var/lib/mysql/myvector.cnf
)
chown mysql:mysql /var/lib/mysql/myvector.cnf
