#!/bin/bash

server_index=$1

cd /home/vagrant

git clone https://github.com/vegasbrianc/prometheus.git

# Configure Grafana
cp /home/vagrant/prometheus/grafana/config.monitoring /home/vagrant/prometheus/grafana/config.monitoring.orig
cp /vagrant/grafana.config /home/vagrant/prometheus/grafana/config.monitoring

# Configure Prometheus
cp /home/vagrant/prometheus/prometheus/prometheus.yml /home/vagrant/prometheus/grafana/prometheus.yml.orig
cp /vagrant/prometheus$server_index.yml /home/vagrant/prometheus/prometheus/prometheus.yml