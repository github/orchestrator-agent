# old images https://atlas.hashicorp.com
ENV['VAGRANT_SERVER_URL'] = "https://vagrantcloud.com" if ENV['VAGRANT_SERVER_URL'].nil? || ENV['VAGRANT_SERVER_URL'].empty?
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox' if ENV['VAGRANT_DEFAULT_PROVIDER'].nil? || ENV['VAGRANT_DEFAULT_PROVIDER'].empty?
BOX = ENV['VAGRANT_BOX'].nil? || ENV['VAGRANT_BOX'].empty? ? 'ubuntu/xenial64' : ENV['VAGRANT_BOX']

VAGRANTFILE_API_VERSION = "2"

system("
    if [[ #{ARGV[0]} = 'up' ]] && [[ ! -e 'vagrant/vagrant-ssh-key' ]]; then
      ssh-keygen -t rsa -b 768 -N '' -q -f vagrant/vagrant-ssh-key
    fi
")

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = BOX
    config.vm.box_download_insecure = true
    config.vm.box_check_update = false
    config.vm.synced_folder '.', '/orchestrator-agent'
    #, type: 'rsync', rsync__auto: true

    config.vm.hostname = "orchestrator-agent"
    config.vm.network "private_network", ip: "192.168.57.211", virtualbox__inet: true
    config.vm.provision "shell", path: "vagrant/agent-build.sh"
end
