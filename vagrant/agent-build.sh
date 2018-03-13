#!/bin/bash
set -x
if [[ -e /etc/redhat-release ]]; then
  # Percona's Yum Repository
  yum -d 0 -y install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm epel-release

  # All the project dependencies to build plus some utilities
  # No reason not to install this stuff in all the places :)
  yum -d 0 -y install Percona-Server-server-56 Percona-Server-shared-56 Percona-Server-client-56 Percona-Server-shared-compat percona-toolkit percona-xtrabackup ruby-devel gcc rpm-build git vim-enhanced golang jq make
  # newest versions of java aren't compatable with the installed version of ruby (1.8.7)
  gem install json --version 1.8.6
  # Pin to 1.4 due to 1.5 no longer working on EL6
  gem install fpm --version 1.4

  # Build orchestrator agent
  mkdir -p /home/vagrant/go/{bin,pkg,src} /tmp/orchestrator-agent-release
  mkdir -p /home/vagrant/go/src/github.com/github/orchestrator-agent
  mount --verbose --bind /orchestrator-agent /home/vagrant/go/src/github.com/github/orchestrator-agent

  # Build Orchestrator agent
  export GOPATH=/home/vagrant/go
  export GO15VENDOREXPERIMENT=1
  cd ${GOPATH}/src/github.com/github/orchestrator-agent
  /usr/bin/go get ./...
  ${GOPATH}/src/github.com/github/orchestrator-agent/build.sh
  chown -R vagrant.vagrant /home/vagrant /tmp/orchestrator-agent-release

  # Setup mysql
  /sbin/chkconfig mysql on

  if [[ -e "/orchestrator-agent/vagrant/${HOSTNAME}-my.cnf" ]]; then
    rm -f /etc/my.cnf
    cp /orchestrator-agent/vagrant/${HOSTNAME}-my.cnf /etc/my.cnf
  fi

  /sbin/service mysql start

elif [[ -e /etc/debian_version ]]; then
  sudo echo exit 101 > /usr/sbin/policy-rc.d
  sudo chmod +x /usr/sbin/policy-rc.d


  # Percona's Apt Repository
  sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A 9334A25F8507EFA5
  echo "deb http://repo.percona.com/apt "$(lsb_release -sc)" main" | sudo tee /etc/apt/sources.list.d/percona.list
  sudo apt-get -y update
  sudo apt-get -y install debconf-utils
  echo "golang-go golang-go/dashboard boolean true" | sudo debconf-set-selections
  echo percona-server-server-5.6 percona-server-server/root_password password "" | sudo debconf-set-selections
  echo percona-server-server-5.6 percona-server-server/root_password_again password "" | sudo debconf-set-selections
  export DEBIAN_FRONTEND=noninteractive

  # No reason not to install this stuff in all the places :)
  #sudo apt-get -y install percona-server-server-5.6 percona-server-common-5.6 percona-server-client-5.6
  #sudo apt-get -y install percona-toolkit percona-xtrabackup

  # add the mysql community packages
  # from https://dev.mysql.com/doc/mysql-apt-repo-quick-guide/en/
  sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5 8C718D3B5072E1F5
  export CODENAME=$(/usr/bin/lsb_release -c | cut -f2)
  echo "deb http://repo.mysql.com/apt/ubuntu/ ${CODENAME} mysql-5.7" | sudo tee /etc/apt/sources.list.d/mysql.list
  apt-get -y update
  echo mysql-community-server mysql-community-server/root-pass password "" | sudo debconf-set-selections
  echo mysql-community-server mysql-community-server/re-root-pass password "" | sudo debconf-set-selections
  apt-get -y --force-yes install mysql-server
  chmod a+w /var/log

  # All the project dependencies to build
  sudo apt-get -y install ruby-dev gcc git rubygems rpm jq make
  # Jump though some hoops to get a non-decrepit version of golang
  sudo apt-get remove golang-go
  cd /tmp
  wget --quiet "https://redirector.gvt1.com/edgedl/go/go1.9.4.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf go1.9.4.linux-amd64.tar.gz
  echo "PATH=$PATH:/usr/local/go/bin" | sudo tee -a /etc/environment
  export PATH="PATH=$PATH:/usr/local/go/bin"

  # newest versions of java aren't compatable with the installed version of ruby (1.8.7)
  gem install json --version 1.8.6
  gem install fpm --version 1.4

  # Build orchestrator agent
  mkdir -p /home/vagrant/go/{bin,pkg,src} /tmp/orchestrator-agent-release
  mkdir -p /home/vagrant/go/src/github.com/github/orchestrator-agent
  mount --verbose --bind /orchestrator-agent /home/vagrant/go/src/github.com/github/orchestrator-agent

  # Build Orchestrator
  export GOPATH=/home/vagrant/go
  export GO15VENDOREXPERIMENT=1
  cd ${GOPATH}/src/github.com/github/orchestrator-agent
  /usr/local/go/bin/go get ./...
  ${GOPATH}/src/github.com/github/orchestrator-agent/build.sh
  chown -R vagrant.vagrant /home/vagrant /tmp/orchestrator-agent-release


  # Go
  sudo apt-get -y install golang-go

  update-rc.d mysql defaults
  /usr/sbin/service mysql start
fi

sudo mysql -e "grant all on *.* to 'root'@'localhost' identified by ''"
cat <<-EOF | mysql -u root
CREATE DATABASE IF NOT EXISTS orchestrator;
GRANT ALL PRIVILEGES ON orchestrator.* TO 'orc_client_user'@'%' IDENTIFIED BY 'orc_client_password';
GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orc_client_user'@'%';
GRANT ALL PRIVILEGES ON orchestrator.* TO 'orc_client_user'@'localhost' IDENTIFIED BY 'orc_client_password';
GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO 'orc_client_user'@'localhost';
GRANT ALL PRIVILEGES ON orchestrator.* TO 'orc_server_user'@'localhost' IDENTIFIED BY 'orc_server_password';
EOF

cat <<-EOF >> /etc/hosts
  192.168.57.211   orchestrator-agent
EOF

if [[ -e /etc/redhat-release ]]; then
  sudo service iptables stop
fi

gem install packagecloud-ruby

echo "Vagrant Provisioning orchestrator-agent DONE"