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

package main

import (
	"flag"
	"io/ioutil"
	"os"
	"os/signal"
	"syscall"

	"github.com/github/orchestrator-agent/go/agent"
	"github.com/github/orchestrator-agent/go/app"
	"github.com/github/orchestrator-agent/go/config"
	"github.com/outbrain/golib/log"
)

var AppVersion string

func acceptSignal() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, os.Kill, syscall.SIGHUP)

	// Block until a signal is received.
	sig := <-c
	log.Fatalf("Got signal: %+v", sig)
}

// main is the application's entry point. It will either spawn a CLI or HTTP itnerfaces.
func main() {
	configFile := flag.String("config", "", "config file name")
	verbose := flag.Bool("verbose", false, "verbose")
	debug := flag.Bool("debug", false, "debug mode (very verbose)")
	stack := flag.Bool("stack", false, "add stack trace upon error")
	flag.Parse()

	log.SetLevel(log.ERROR)
	if *verbose {
		log.SetLevel(log.INFO)
	}
	if *debug {
		log.SetLevel(log.DEBUG)
	}
	if *stack {
		log.SetPrintStackTrace(*stack)
	}

	if AppVersion == "" {
		AppVersion = "local-build"
	}

	log.Info("starting orchestrator-agent %s", AppVersion)

	if len(*configFile) > 0 {
		config.ForceRead(*configFile)
	} else {
		config.Read("/etc/orchestrator-agent.conf.json", "conf/orchestrator-agent.conf.json", "orchestrator-agent.conf.json")
	}

	if len(config.Config.AgentsServer) == 0 {
		log.Fatal("AgentsServer unconfigured. Please set to the HTTP address orchestrator serves agents (port is by default 3001)")
	}

	log.Debugf("Process token: %s", agent.ProcessToken.Hash)
	if config.Config.TokenHintFile != "" {
		log.Debugf("Writing token to TokenHintFile: %s", config.Config.TokenHintFile)
		err := ioutil.WriteFile(config.Config.TokenHintFile, []byte(agent.ProcessToken.Hash), 0644)
		log.Errore(err)
	}

	go acceptSignal()

	app.Http()
}
