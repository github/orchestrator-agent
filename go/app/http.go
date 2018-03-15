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

//
package app

import (
	"errors"
	"fmt"

	"github.com/go-martini/martini"
	"github.com/martini-contrib/auth"
	"github.com/martini-contrib/gzip"
	"github.com/martini-contrib/render"

	nethttp "net/http"

	"github.com/github/orchestrator-agent/go/agent"
	"github.com/github/orchestrator-agent/go/config"
	"github.com/github/orchestrator-agent/go/http"
	"github.com/github/orchestrator-agent/go/ssl"
	"github.com/outbrain/golib/log"
)

// Http starts serving HTTP (api/web) requests
func Http() {
	martini.Env = martini.Prod
	m := martini.Classic()
	if config.Config.HTTPAuthUser != "" {
		m.Use(auth.Basic(config.Config.HTTPAuthUser, config.Config.HTTPAuthPassword))
	}

	m.Use(gzip.All())
	// Render html templates from templates directory
	m.Use(render.Renderer(render.Options{
		Directory:       "resources",
		Layout:          "templates/layout",
		HTMLContentType: "text/html",
	}))
	m.Use(martini.Static("resources/public"))
	if config.Config.UseMutualTLS {
		m.Use(ssl.VerifyOUs(config.Config.SSLValidOUs))
	}

	go agent.ContinuousOperation()

	log.Infof("Starting HTTP on port %d", config.Config.HTTPPort)

	http.API.RegisterRequests(m)

	listenAddress := fmt.Sprintf(":%d", config.Config.HTTPPort)

	// Serve
	if config.Config.UseSSL {
		if len(config.Config.SSLCertFile) == 0 {
			log.Fatale(errors.New("UseSSL is true but SSLCertFile is unspecified"))
		}

		if len(config.Config.SSLPrivateKeyFile) == 0 {
			log.Fatale(errors.New("UseSSL is true but SSLPrivateKeyFile is unspecified"))
		}

		log.Info("Starting HTTPS listener")
		tlsConfig, err := ssl.NewTLSConfig(config.Config.SSLCAFile, config.Config.UseMutualTLS)
		if err != nil {
			log.Fatale(err)
		}
		if err = ssl.AppendKeyPair(tlsConfig, config.Config.SSLCertFile, config.Config.SSLPrivateKeyFile); err != nil {
			log.Fatale(err)
		}
		if err = ssl.ListenAndServeTLS(listenAddress, m, tlsConfig); err != nil {
			log.Fatale(err)
		}
	} else {
		log.Info("Starting HTTP listener")
		if err := nethttp.ListenAndServe(listenAddress, m); err != nil {
			log.Fatale(err)
		}
	}
	log.Info("Web server started")
}
