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

package agent

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/github/orchestrator-agent/go/config"
	"github.com/github/orchestrator-agent/go/osagent"
	"github.com/github/orchestrator-agent/go/ssl"
	"github.com/outbrain/golib/log"
)

var httpTimeout = time.Duration(time.Duration(config.Config.HttpTimeoutSeconds) * time.Second)

var httpClient = &http.Client{}

var LastTalkback time.Time

func dialTimeout(network, addr string) (net.Conn, error) {
	return net.DialTimeout(network, addr, httpTimeout)
}

// httpGet is a convenience method for getting http response from URL, optionaly skipping SSL cert verification
func httpGet(url string) (resp *http.Response, err error) {
	tlsConfig, _ := buildTLS()
	httpTransport := &http.Transport{
		TLSClientConfig: tlsConfig,
		Dial:            dialTimeout,
		ResponseHeaderTimeout: httpTimeout,
	}
	httpClient.Transport = httpTransport
	return httpClient.Get(url)
}

func buildTLS() (*tls.Config, error) {
	tlsConfig, err := ssl.NewTLSConfig(config.Config.SSLCAFile, config.Config.UseMutualTLS)
	if err != nil {
		return tlsConfig, log.Errore(err)
	}
	_ = ssl.AppendKeyPair(tlsConfig, config.Config.SSLCertFile, config.Config.SSLPrivateKeyFile)
	tlsConfig.InsecureSkipVerify = config.Config.SSLSkipVerify
	return tlsConfig, nil
}

func SubmitAgent() error {
	hostname, err := osagent.Hostname()
	if err != nil {
		return log.Errore(err)
	}

	url := fmt.Sprintf("%s/api/submit-agent/%s/%d/%s", config.Config.AgentsServer+config.Config.AgentsServerPort, hostname, config.Config.HTTPPort, ProcessToken.Hash)
	log.Debugf("Submitting this agent: %s", url)

	response, err := httpGet(url)
	if err != nil {
		return log.Errore(err)
	}
	defer response.Body.Close()

	log.Debugf("response: %+v", response)
	return err
}

// Just check connectivity back to the server.  This just calls an endpoint that returns 200 OK
func PingServer() error {
	url := fmt.Sprintf("%s/api/agent-ping", config.Config.AgentsServer+config.Config.AgentsServerPort)
	response, err := httpGet(url)
	if err != nil {
		return log.Errore(err)
	}
	defer response.Body.Close()
	return nil
}

// ContinuousOperation starts an asynchronuous infinite operation process where:
// - agent is submitted into orchestrator
func ContinuousOperation() {
	log.Infof("Starting continuous operation")
	tick := time.Tick(time.Duration(config.Config.ContinuousPollSeconds) * time.Second)
	resubmitTick := time.Tick(time.Duration(config.Config.ResubmitAgentIntervalMinutes) * time.Minute)

	SubmitAgent()
	for range tick {
		// Do stuff
		if err := PingServer(); err != nil {
			log.Warning("Failed to ping orchestrator server")
		} else {
			LastTalkback = time.Now()
		}

		// See if we should also forget instances/agents (lower frequency)
		select {
		case <-resubmitTick:
			SubmitAgent()
		default:
		}
	}
}
