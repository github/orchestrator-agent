/*
   Copyright 2014 Outbrain Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package config

import (
	"encoding/json"
	"os"

	"github.com/outbrain/golib/log"
)

// Configuration makes for orchestrator-agent configuration input, which can be provided by user via JSON formatted file.
type Configuration struct {
	SnapshotMountPoint                 string            // The single, agreed-upon mountpoint for logical volume snapshots
	ContinuousPollSeconds              uint              // Poll interval for continuous operation
	ResubmitAgentIntervalMinutes       uint              // Poll interval for resubmitting this agent on orchestrator agents API
	LogicalVolumesCommand              string            // Command which list logical volumes, default implementation used lvs
	GetMountCommand                    string            // Command which get mount point parameters by mount point name, default implementation over cat %s/etc/mtab
	UnmountCommand                     string            // Command which unmount current mount point, default implementation just execute `umount %s`
	MountLVCommand                     string            // Command which mount selected snapshot into mount point
	RemoveLVCommand                    string            // Command which remove selected snapshot from disk
	MySQLTailErrorLogCommand           string            // Command which return last 20 lines from @@log_error file
	GetLogicalVolumeFSTypeCommand      string            // Command which return logical volume filesystem type
	CreateSnapshotCommand              string            // Command which creates a snapshot logical volume. It's a "do it yourself" implementation
	AvailableLocalSnapshotHostsCommand string            // Command which returns list of hosts (one host per line) with available snapshots in local datacenter
	AvailableSnapshotHostsCommand      string            // Command which returns list of hosts (one host per line) with available snapshots in any datacenter
	SnapshotVolumesFilter              string            // text pattern filtering agent logical volumes that are valid snapshots
	MySQLDatadirCommand                string            // command expected to present with @@datadir
	MySQLPortCommand                   string            // command expected to present with @@port
	MySQLDeleteDatadirContentCommand   string            // command which deletes all content from MySQL datadir (does not remvoe directory itself)
	MySQLServiceStopCommand            string            // Command to stop mysql, e.g. /etc/init.d/mysql stop
	MySQLServiceStartCommand           string            // Command to start mysql, e.g. /etc/init.d/mysql start
	MySQLServiceStatusCommand          string            // Command to check mysql status. Expects 0 return value when running, non-zero when not running, e.g. /etc/init.d/mysql status
	ReceiveSeedDataCommand             string            // Accepts incoming data (e.g. tarball over netcat)
	SendSeedDataCommand                string            // Sends date to remote host (e.g. tarball via netcat)
	PostCopyCommand                    string            // command that is executed after seed is done and before MySQL starts
	MySQLClientCommand                 string            // the `mysql` command, including ny neccesary credentials, to apply relay logs. This would be a fully-privileged account entry. Example: "mysql -uroot -p123456" or "mysql --defaults-file=/root/.my.cnf"
	AgentsServer                       string            // HTTP address of the orchestrator agents server
	AgentsServerPort                   string            // HTTP port of the orchestrator agents server
	HTTPPort                           uint              // HTTP port on which this service listens
	SeedTransferPort                   uint              // TCP port for data seed transfer
	HTTPAuthUser                       string            // Username for HTTP Basic authentication (blank disables authentication)
	HTTPAuthPassword                   string            // Password for HTTP Basic authentication
	UseSSL                             bool              // If true, service will serve HTTPS only
	UseMutualTLS                       bool              // If true, service will serve HTTPS only
	SSLSkipVerify                      bool              // When using SSL, should we ignore SSL certification error
	SSLPrivateKeyFile                  string            // Name of SSL private key file, applies only when UseSSL = true
	SSLCertFile                        string            // Name of SSL certification file, applies only when UseSSL = true
	SSLCAFile                          string            // Name of SSL certificate authority file, applies only when UseSSL = true
	SSLValidOUs                        []string          // List of valid OUs that should be allowed for mutual TLS verification
	StatusEndpoint                     string            // The endpoint for the agent status check.  Defaults to /api/status
	StatusOUVerify                     bool              // If true, try to verify OUs when Mutual TLS is on.  Defaults to false
	StatusBadSeconds                   uint              // Report non-200 on a status check if we've failed to communicate with the main server in this number of seconds
	HttpTimeoutSeconds                 int               // Number of idle seconds before HTTP GET request times out (when accessing orchestrator)
	ExecWithSudo                       bool              // If true, run os commands that need privileged access with sudo. Usually set when running agent with a non-privileged user
	CustomCommands                     map[string]string // Anything in this list of options will be exposed as an API callable options
	TokenHintFile                      string            // If defined, token will be stored in this file
	TokenHttpHeader                    string            // If defined, name of HTTP header where token is presented (as alternative to query param)
}

var Config = NewConfiguration()
var configFileNames []string

func NewConfiguration() *Configuration {
	return &Configuration{
		SnapshotMountPoint:                 "",
		ContinuousPollSeconds:              60,
		ResubmitAgentIntervalMinutes:       60,
		CreateSnapshotCommand:              "",
		LogicalVolumesCommand:              "lvs --noheading -o lv_name,vg_name,lv_path,snap_percent",
		GetMountCommand:                    "grep %s /etc/mtab",
		UnmountCommand:                     "umount %s",
		MountLVCommand:                     "mount %s %s %s",
		RemoveLVCommand:                    "lvremove --force %s",
		MySQLTailErrorLogCommand:           `tail -n 20 $(egrep "log[-_]error" /etc/my.cnf | cut -d "=" -f 2)`,
		GetLogicalVolumeFSTypeCommand:      "blkid %s",
		AvailableLocalSnapshotHostsCommand: "",
		AvailableSnapshotHostsCommand:      "",
		SnapshotVolumesFilter:              "",
		MySQLDatadirCommand:                "",
		MySQLPortCommand:                   "",
		MySQLDeleteDatadirContentCommand:   "",
		MySQLServiceStopCommand:            "",
		MySQLServiceStartCommand:           "",
		MySQLServiceStatusCommand:          "",
		ReceiveSeedDataCommand:             "",
		SendSeedDataCommand:                "",
		PostCopyCommand:                    "",
		MySQLClientCommand:                 "mysql",
		AgentsServer:                       "",
		AgentsServerPort:                   "",
		HTTPPort:                           3002,
		SeedTransferPort:                   21234,
		HTTPAuthUser:                       "",
		HTTPAuthPassword:                   "",
		UseSSL:                             false,
		UseMutualTLS:                       false,
		SSLSkipVerify:                      false,
		SSLPrivateKeyFile:                  "",
		SSLCertFile:                        "",
		SSLCAFile:                          "",
		SSLValidOUs:                        []string{},
		StatusEndpoint:                     "/api/status",
		StatusOUVerify:                     false,
		StatusBadSeconds:                   300,
		HttpTimeoutSeconds:                 10,
		ExecWithSudo:                       false,
		CustomCommands:                     make(map[string]string),
		TokenHintFile:                      "",
		TokenHttpHeader:                    "",
	}
}

// read reads configuration from given file, or silently skips if the file does not exist.
// If the file does exist, then it is expected to be in valid JSON format or the function bails out.
func read(file_name string) (*Configuration, error) {
	file, err := os.Open(file_name)
	if err == nil {
		decoder := json.NewDecoder(file)
		err := decoder.Decode(Config)
		if err == nil {
			log.Infof("Read config: %s", file_name)
		} else {
			log.Fatal("Cannot read config file:", file_name, err)
		}
	}
	return Config, err
}

// Read reads configuration from zero, either, some or all given files, in order of input.
// A file can override configuration provided in previous file.
func Read(file_names ...string) *Configuration {
	for _, file_name := range file_names {
		read(file_name)
	}
	configFileNames = file_names
	return Config
}

// Reload
func Reload() *Configuration {
	return Read(configFileNames...)
}

// ForceRead reads configuration from given file name or bails out if it fails
func ForceRead(file_name string) *Configuration {
	_, err := read(file_name)
	if err != nil {
		log.Fatal("Cannot read config file:", file_name, err)
	}
	return Config
}
