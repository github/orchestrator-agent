#!/bin/sh
if [ ! -e /etc/orchestrator-agent.conf.json ] ; then
cat <<EOF > /etc/orchestrator-agent.conf.json
{
    "SnapshotMountPoint": "/tmp",
    "AgentsServer": "http://localhost",
    "AgentsServerPort": ":3001",
    "ContinuousPollSeconds" : 60,
    "ResubmitAgentIntervalMinutes": 60,
    "CreateSnapshotCommand": "echo 'no action'",
    "AvailableLocalSnapshotHostsCommand": "echo 127.0.0.1",
    "AvailableSnapshotHostsCommand": "echo localhost\n127.0.0.1",
    "SnapshotVolumesFilter": "-my-snapshot-",
    "MySQLDatadirCommand": "echo '~/tmp'",
    "MySQLPortCommand": "echo '3306'",
    "MySQLDeleteDatadirContentCommand": "echo 'will not do'",
    "MySQLServiceStopCommand":      "/etc/init.d/mysqld stop",
    "MySQLServiceStartCommand":     "/etc/init.d/mysqld start",
    "MySQLServiceStatusCommand":    "/etc/init.d/mysqld status",
    "ReceiveSeedDataCommand":       "echo 'not implemented here'",
    "SendSeedDataCommand":          "echo 'not implemented here'",
    "PostCopyCommand":              "echo 'post copy'",
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
