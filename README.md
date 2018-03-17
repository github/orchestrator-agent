orchestrator-agent
==================

MySQL topology agent (daemon)

**orchestrator-agent** is a sub-project of [orchestrator](https://github.com/github/orchestrator).
It is a service that runs on MySQL hosts and communicates with *orchestrator*.

**orchestrator-agent** is capable of proving operating system, file system and LVM information to *orchestrator*, as well
as invoke certain commands and scripts.

The primary drive for developing **orchestrator-agent** was [Outbrain](https://github.com/outbrain)'s need for a controlled
seeding mechanism, where MySQL instances would duplicate onto new/corrupt installations. 
As such, **orchestrator-agent**'s functionality is tightly coupled with the backup/seed mechanisms used by Outbrain, 
as described following. Though easily extendible, **orchestrator-agent** was not developed with a general purpose
backup/restore/orchestration capabilities in mind.

Whether or not **orchestrator-agent** is useful to you depends on your needs.

##### Generic functionality offered by **orchestrator-agent**:

- Detection of the MySQL service, starting and stopping (start/stop/status commands provided via configuration)
- Detection of MySQL port, data directory (assumes configuration is `/etc/my.cnf`)
- Calculation of disk usage on data directory mount point
- Tailing the error log file
- Discovery (the mere existence of the *orchestrator-agent* service on a host may suggest the existence or need of existence of a MySQL service)
 
##### Specialized functionality offered by **orchestrator-agent**:

- Detection of LVM snapshots on MySQL host (snapshots that are MySQL specific)
- Creation of new snapshots
- Mounting/umounting of LVM snapshots
- Detection of DC-local and DC-agnostic snapshots available for a given cluster
- Transmitting/receiving seed data

### The Outbrain seed method

The following does not discuss hard-backups where binary/logical data is written to an external/remote disk or a tape.

At Outbrain we use LVM snapshots. Each MySQL replication topology has designated slaves which serve as snapshot servers.
These servers do LVM snapshots daily, and keep such snapshots open for a few days. Thus it is possible that a server
has, say, 5 open (and unmounted) LVM snapshots at a given time.  

Upon need, we are able to mount any such snapshot in near zero time and restart MySQL on the host using mounted data directory.
We are thus able to recover any one of few days back at speed of InnoDB crash-recovery.

This serves two purposes: an immediate recovery/sanity check for destructive operations (unintentional or malicious `UPDATE` or `DROP`)
as well as a seed source for new/corrupt servers.

The choice of snapshot slaves is not random; we have multiple data centers and we keep at least one snapshot server per topology per data center,
such that upon need we can make DC-local copies. For this purpose, the daily snapshot process reports, upon success, the
availability of the snapshot along with any metadata required on cluster/DC.

**orchestrator-agent** thus depends on external (configurable) commands to:

- Detect where in local and remote DCs it can find an appropriate snapshot
- Find said snapshot on server, mount it
- Stop MySQL on target host, clear data on MySQL data directory
- Initiate send/receive process
- Cleanup data after copy (e.g. remove `.pid` files if any)
- Unmount snapshot
- etc.
  
  
### The orchestrator & orchestrator-agent architecture

**orchestrator** is a standalone, centralized service/command line tool. When acting as a service, it provides with web API
and web interface to allow replication topology refactoring, long query control, and more.

Coupled with **orchestrator-agent**, **orchestrator** is further able to assist in seeding new/corrupt servers. 
**orchestrator-agent** does not initiate anything by itself, but is in fact controlled by **orchestrator**.

When started, **orchestrator-agent** chooses a random, secret *token* and attempts to connect to the centralized **orchestrator**
service API (location configurable). It then registers at the **orchestrator** service with its secret token. 

**orchestrator-agent** then serves via HTTP API, and for all but the simplest commands requires the secret token.

At this point **orchestrator** becomes the major player; having multiple **orchestrator-agent** registered it is able to
coordinate operations such as snapshot mounting, space cleanup, send and receive so as to establish a successful seed
(a binary copy of a MySQL data directory).
 
**orchestrator-agent** only provides the minimal and required operating system functionality and does not interact
with the MySQL service directly (i.e. no credentials required and no SQL queries invoked). Any and all queries are
invoked by the centralized **orchestrator** service.
  

### Configuration

_Orchestrator-agent_ uses a configuration file, located in either `/etc/orchestrator-agent.conf.json` or 
relative path to binary `conf/orchestrator-agent.conf.json` or `orchestrator-agent.conf.json`. 

Note that the agent will use the config file in its relative conf path first.

The following is a complete list of configuration parameters:

* `SnapshotMountPoint`                 (string), a known mountpoint onto which a `mount` command will mount snapshot volumes
* `ContinuousPollSeconds`              (uint), internal clocking interval (default 60 seconds)
* `ResubmitAgentIntervalMinutes`       (uint), interval at which the agent re-submits itself to *orchestrator* daemon
* `LogicalVolumesCommand`              (string), command which list logical volumes, default implementation used lvs
* `GetMountCommand`                    (string), command which get mount point parameters by mount point name, default implementation over cat /etc/mtab
* `UnmountCommand`                     (string), command which unmount current mount point, default implementation just execute umount
* `MountLVCommand`                     (string), command which mount selected snapshot, default implementation execute mount selected LVM snapshot 
* `RemoveLVCommand`                    (string), command which remove selected snapshot, default implementation execute lvremove selected LVM snapshot 
* `CreateSnapshotCommand`              (string), command which creates new LVM snapshot of MySQL data
* `AvailableLocalSnapshotHostsCommand` (string), command which returns list of hosts in local DC on which recent snapshots are available
* `AvailableSnapshotHostsCommand`      (string), command which returns list of hosts in all DCs on which recent snapshots are available
* `SnapshotVolumesFilter`              (string), free text which identifies MySQL data snapshots (as opposed to other, unrelated snapshots)
* `MySQLDatadirCommand`                (string), command which returns the data directory (e.g. `grep datadir /etc/my.cnf | head -n 1 | awk -F= '{print $2}'`)
* `MySQLPortCommand`                   (string), command which returns the MySQL port
* `MySQLDeleteDatadirContentCommand`   (string), command which purges the MySQL data directory
* `MySQLServiceStopCommand`            (string), command which stops the MySQL service (e.g. `service mysql stop`)
* `MySQLServiceStartCommand`           (string), command which starts the MySQL service
* `MySQLServiceStatusCommand`          (string), command that checks status of service (expecting exit code 1 when service is down)
* `ReceiveSeedDataCommand`             (string), command which listen on data, must accept arguments: target directory, listen port
* `SendSeedDataCommand`                (string), command which sends data, must accept arguments: source directory, target host, target port 
* `PostCopyCommand`                    (string), command to be executed after the seed is complete (cleanup)
* `AgentsServer`                       (string), **Required** URL of your **orchestrator** daemon, You must add the port the orchestrator server expects to talk to agents to (see below, e.g. `https://my.orchestrator.daemon:3001`)
* `HTTPPort`                           (uint),   Port to listen on  
* `HTTPAuthUser`                       (string), Basic auth user (default empty, meaning no auth)
* `HTTPAuthPassword`                   (string), Basic auth password
* `UseSSL`                             (bool),   If `true` then serving via `https` protocol
* `SSLSkipVerify`                      (bool),   When connecting to **orchestrator** via SSL, whether to ignore certification error  
* `SSLPrivateKeyFile`                  (string), When serving via `https`, location of SSL private key file
* `SSLCertFile`                        (string), When serving via `https`, location of SSL certification file
* `HttpTimeoutSeconds`                 (int),    HTTP GET request timeout (when connecting to _orchestrator_)

An example configuration file may be:

```json
{
    "SnapshotMountPoint": "/var/tmp/mysql-mount",
    "AgentsServer": "https://my.orchestrator.daemon:3001",
    "ContinuousPollSeconds" : 60,
    "ResubmitAgentIntervalMinutes": 60,
    "LogicalVolumesCommand": "lvs --noheading -o lv_name,vg_name,lv_path,snap_percent",
    "GetMountCommand":       "grep %s /etc/mtab", 
    "CreateSnapshotCommand":                "/path/to/snapshot-command.bash",
    "AvailableLocalSnapshotHostsCommand":   "/path/to/snapshot-local-availability-command.bash",
    "AvailableSnapshotHostsCommand":        "/path/to/snapshot-availability-command.bash",
    "SnapshotVolumesFilter":                "mysql-snap",
    "MySQLDatadirCommand":                  "set $(grep datadir /etc/my.cnf | head -n 1 | awk -F= '{print $2}') ; echo $1",
    "MySQLPortCommand":                     "set $(grep ^port /etc/my.cnf | head -n 1 | awk -F= '{print $2}') ; echo $1",
    "MySQLDeleteDatadirContentCommand":     "set $(grep datadir /etc/my.cnf | head -n 1 | awk -F= '{print $2}') ; rm --preserve-root -rf $1/*",
    "MySQLServiceStopCommand":      "/etc/init.d/mysql stop",
    "MySQLServiceStartCommand":     "/etc/init.d/mysql start",
    "MySQLServiceStatusCommand":    "/etc/init.d/mysql status",
    "ReceiveSeedDataCommand":       "/path/to/data-receive.bash",
    "SendSeedDataCommand":          "/path/to/data-send.bash",
    "PostCopyCommand":              "set $(grep datadir /etc/my.cnf | head -n 1 | awk -F= '{print $2}') ; rm -f $1/*.pid",
    "HTTPPort": 3002,
    "HTTPAuthUser": "",
    "HTTPAuthPassword": "",
    "UseSSL": false,
    "SSLSkipVerify": false,
    "SSLCertFile": "",
    "SSLPrivateKeyFile": "",
    "HttpTimeoutSeconds": 10
}
```

#### Necessary matching configuration on the Orchestrator Server side

If you initially deployed orchestrator with a minimally working configuration, you will need to make some changes on the server side to prepare it for newly deployed agents. The configuration lines needed on the server side to support agents are

*  `ServeAgentsHttp`      (bool), Must be set to `true` to get the orchestrator server listening for agents
*  `AgentsServerPort`     (String), The port on which the server should listen to agents. Shoult match the port you define for agents in `AgentsServer`.

### Requirements:

- Linux, 64bit. Tested on CentOS 5 and Ubuntu Server 12.04+
- MySQL 5.1+
- LVM, free space in volume group, if snapshot functionality is required
- **orchestrator-agent** assumes a single MySQL running on the machine


### Extending orchestrator-agent

Yes please. **orchestrator-agent** is open to pull-requests. Desired functionality is for example
the initiation and immediate transfer of backup data via `xtrabackup`. 
The same can be done via `mysqldump` or `mydumper` etc. 

Authored by [Shlomi Noach](https://github.com/shlomi-noach) at [GitHub](http://github.com). Previously at [Booking.com](http://booking.com) and [Outbrain](http://outbrain.com)



 
