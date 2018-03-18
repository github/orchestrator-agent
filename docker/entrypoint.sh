#!/bin/sh
if [ ! -e /etc/orchestrator-agent.conf.json ] ; then
# @TODO think about full customization of orchestrator-agent.conf.json via ENV variables
# @TODO think about mysql running not inside this docker
cat <<EOF > /etc/orchestrator-agent.conf.json
{
    "SnapshotMountPoint": "${SnapshotMountPoint:-/mysql-data}",
    "AgentsServer": "${AgentsServer:-http://localhost}",
    "AgentsServerPort": "${AgentsServerPort:-:3001}",
    "ContinuousPollSeconds" : ${ContinuousPollSeconds:-60},
    "ResubmitAgentIntervalMinutes": ${ResubmitAgentIntervalMinutes:-10},
    "LogicalVolumesCommand": "${LogicalVolumesCommand:-lvs --noheading -o lv_name,vg_name,lv_path,snap_percent}",
    "GetMountCommand":       "${GetMountCommand:-grep %s /etc/mtab}",
    "UnmountCommand":        "${UnmountCommand:-umount %s}",
    "MountLVCommand":        "${MountLVCommand:-mount %s %s %s}",
    "RemoveLVCommand":       "${RemoveLVCommand:-lvremove --force %s}",
    "MySQLTailErrorLogCommand": "${MySQLTailErrorLogCommand:-tail -n 20 \$(mysql -B --skip-column-names -e \"SELECT @@log_error\")}",
    "GetLogicalVolumeFSTypeCommand": "${GetLogicalVolumeFSTypeCommand:-blkid %s}",
    "CreateSnapshotCommand": "${CreateSnapshotCommand:-echo \'no action\'}",
    "AvailableLocalSnapshotHostsCommand": "${AvailableLocalSnapshotHostsCommand:-echo 127.0.0.1}",
    "AvailableSnapshotHostsCommand": "${AvailableSnapshotHostsCommand:-printf \'localhost\n127.0.0.1\'}",
    "SnapshotVolumesFilter": "${SnapshotVolumesFilter:--mysql-snapshot-}",
    "MySQLDatadirCommand": "mysql -B --skip-column-names -e 'SELECT @@datadir'",
    "MySQLPortCommand": "echo '3306'",
    "MySQLDeleteDatadirContentCommand": "echo 'will not do'",
    "MySQLServiceStopCommand":      "/etc/init.d/mysqld stop",
    "MySQLServiceStartCommand":     "/etc/init.d/mysqld start",
    "MySQLServiceStatusCommand":    "/etc/init.d/mysqld status",
    "ReceiveSeedDataCommand":       "${ReceiveSeedDataCommand:-echo \'not implemented here\'}",
    "SendSeedDataCommand":          "${SendSeedDataCommand:-echo \'not implemented here\'}",
    "PostCopyCommand":              "${PostCopyCommand:-echo \'post copy\'}",
    "HTTPPort": 3002,
    "HTTPAuthUser": "",
    "HTTPAuthPassword": "",
    "UseSSL": false,
    "SSLCertFile": "",
    "SSLPrivateKeyFile": "",
    "HttpTimeoutSeconds": 10,
    "ExecWithSudo": false,
    "CustomCommands": {
        "true": "/bin/true"
    },
    "TokenHintFile": ""
}
EOF
fi

exec /usr/local/orchestrator-agent/orchestrator-agent
