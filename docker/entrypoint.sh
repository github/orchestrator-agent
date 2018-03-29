#!/bin/sh
if [ ! -e /etc/orchestrator-agent.conf.json ] ; then
cat <<EOF > /etc/orchestrator-agent.conf.json
{
    "SnapshotMountPoint": "${SNAPSHOT_MOUNT_POINT:-/mysql-data}",
    "AgentsServer": "${AGENTS_SERVER:-http://localhost}",
    "AgentsServerPort": "${AGENTS_SERVER_PORT:-:3001}",
    "ContinuousPollSeconds" : ${CONTINUOUS_POLL_SECONDS:-60},
    "ResubmitAgentIntervalMinutes": ${RESUBMIT_AGENTINTERVAL_MINUTES:-10},
    "LogicalVolumesCommand": "${LOGICAL_VOLUMES_COMMAND:-lvs --noheading -o lv_name,vg_name,lv_path,snap_percent}",
    "GetMountCommand":       "${GET_MOUNT_COMMAND:-grep %s /etc/mtab}",
    "UnmountCommand":        "${UNMOUNT_COMMAND:-umount %s}",
    "MountLVCommand":        "${MOUNT_LV_COMMAND:-mount %s %s %s}",
    "RemoveLVCommand":       "${REMOVE_LV_COMMAND:-lvremove --force %s}",
    "MySQLTailErrorLogCommand": "${MYSQL_TAIL_ERROR_LOG_COMMAND:-tail -n 20 \$(mysql -B --skip-column-names -e \"SELECT @@log_error\")}",
    "GetLogicalVolumeFSTypeCommand": "${GET_LOGICAL_VOLUME_FS_TYPE_COMMAND:-blkid %s}",
    "CreateSnapshotCommand": "${CREATE_SNAPSHOT_COMMAND:-echo \'no action\'}",
    "AvailableLocalSnapshotHostsCommand": "${AVAILABLE_LOCAL_SNAPSHOT_HOSTS_COMMAND:-echo 127.0.0.1}",
    "AvailableSnapshotHostsCommand": "${AVAILABLE_SNAPSHOT_HOSTS_COMMAND:-printf \'localhost\n127.0.0.1\'}",
    "SnapshotVolumesFilter": "${SNAPSHOT_VOLUMES_FILTER:--mysql-snapshot-}",
    "MySQLDatadirCommand": "${MYSQL_DATADIR_COMMAND:-mysql -B --skip-column-names -e 'SELECT @@datadir'}",
    "MySQLPortCommand": "${MYSQL_PORT_COMMAND:-echo '3306'}",
    "MySQLDeleteDatadirContentCommand": "${MYSQL_DELETE_DATADIR_CONTENT_COMMAND:-echo 'will not do'}",
    "MySQLServiceStopCommand":      "${MYSQL_SERVICE_STOP_COMMAND:-/etc/init.d/mysqld stop}",
    "MySQLServiceStartCommand":     "${MYSQL_SERVICE_START_COMMAND:-/etc/init.d/mysqld start}",
    "MySQLServiceStatusCommand":    "${MYSQL_SERVICE_STATUS_COMMAND:-/etc/init.d/mysqld status}",
    "ReceiveSeedDataCommand":       "${RECEIVE_SEED_DATA_COMMAND:-echo \'not implemented here\'}",
    "SendSeedDataCommand":          "${SEND_SEED_DATA_COMMAND:-echo \'not implemented here\'}",
    "PostCopyCommand":              "${POST_COPY_COMMAND:-echo \'post copy\'}",
    "HTTPPort": ${HTTP_PORT:-3002},
    "HTTPAuthUser": "${HTTP_AUTH_USER}",
    "HTTPAuthPassword": "${HTTP_AUTH_PASSWORD}",
    "UseSSL": ${USE_SSL:-false},
    "SSLCertFile": "${SSL_CERT_FILE}",
    "SSLPrivateKeyFile": "${SSL_PRIVATE_KEY_FILE}",
    "HttpTimeoutSeconds": ${HTTP_TIMEOUT_SECONDS:-10},
    "ExecWithSudo": ${EXEC_WITH_SUDO:-false},
    "CustomCommands": {
        "true": "/bin/true"
    },
    "TokenHintFile": "${TOKEN_HINT_FILE}"
}
EOF
fi

exec /usr/local/orchestrator-agent/orchestrator-agent
