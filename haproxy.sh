#!/bin/bash

apt-get -qq -y update
apt-get install -y -q mariadb-client ldapscripts jq haproxy xmlsec1

# Install haproxy
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.orig.cfg
cp /vagrant/haproxy.cfg /etc/haproxy/haproxy.cfg
service haproxy restart