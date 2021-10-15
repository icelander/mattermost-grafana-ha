# -*- mode: ruby -*-
# vi: set ft=ruby :

MATTERMOST_VERSION = "6.0.0"

MYSQL_ROOT_PASSWORD = 'mysql_root_password'
MATTERMOST_PASSWORD = 'really_secure_password'

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-21.04"

  # So we need one big central one to hold all the stuff, like DB, etc
  config.vm.define 'mattermost' do |box|
    box.vm.hostname = 'mattermost'
    box.vm.network :private_network, ip: "192.168.1.100"

    box.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 4
    end

    box.vm.provision :shell, path: 'haproxy.sh'

    box.vm.provision :docker
    box.vm.provision :docker_compose, yml: "/vagrant/docker-compose.yml"
    
    box.vm.provision 'shell',
      path: "mattermost.sh",
      args: [MATTERMOST_VERSION, MYSQL_ROOT_PASSWORD, MATTERMOST_PASSWORD]
  end
  

  # And then two small ones for Grafana and Prometheus
  2.times do |t|
    config.vm.define "metrics#{t}" do |box|
      box.vm.hostname = "metrics#{t}"

      box.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
      end

      box.vm.network "private_network", ip: "192.168.1.10#{t+1}"

      box.vm.provision :file, source: './monitoring', destination: '/home/vagrant/monitoring'
      box.vm.provision :file, source: './grafana.config', destination: '/home/vagrant/monitoring/grafana/config.monitoring'
      box.vm.provision :file, source: "./prometheus#{t}.yml", destination: '/home/vagrant/monitoring/prometheus/prometheus.yml'

      box.vm.provision :shell, inline: 'chown -R vagrant:vagrant /home/vagrant/monitoring'

      box.vm.provision :docker
      box.vm.provision :docker_compose, yml: "/vagrant/metrics-compose.yml"
    end
  end
end
