# High Availability Performance Metrics with Grafana & Prometheus

## Problem

You want to collect performance metrics about your Mattermost server using a highly available metrics stack.

## Solution

Thankfully, Grafana and Prometheus can be easily configured to run in a high availability mode. For Grafana, this just means balancing traffic between instances and connecting them to the same database. Prometheus offers 

### 0. Set up your environment.

First, install Mattermost and configuring metrics reporting in the System Console. Then, create a new database for the Grafana instances. You can either use a separate database server, or create a new database in your existing one with these commands:

**MySQL**

```sql
CREATE USER 'grafana-user'@'%' IDENTIFIED BY 'really_secure_password';
CREATE DATABASE grafana;
GRANT ALL PRIVILEGES ON grafana.* TO 'grafana-user'@'%';
```

**PostgreSQL**

```sql
CREATE USER grafana_user WITH PASSWORD 'really_secure_password';
CREATE DATABASE grafana;
GRANT ALL PRIVILEGES ON DATABASE grafana to grafana_user;
```

### 1. Set up two Grafana/Prometheus Servers

I started with [this great Grafana/Prometheus stack from Brian Christner](https://github.com/vegasbrianc/prometheus) and removed the alertmanager and cadvisor services to create `metrics-compose.yml`, which spins up Grafana, Prometheus, and Node Exporter instances on each metrics machine:

```yaml
version: '3.7'

volumes:
    prometheus_data: {}
    grafana_data: {}

networks:
  back-tier:

services:
  prometheus:
    image: prom/prometheus
    volumes:
      - /home/vagrant/monitoring/prometheus/:/etc/prometheus/
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - 9090:9090
    networks:
      - back-tier
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command: 
      - '--path.procfs=/host/proc' 
      - '--path.sysfs=/host/sys'
      - --collector.filesystem.ignored-mount-points
      - "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
    ports:
      - 9100:9100
    networks:
      - back-tier
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    user: "472"
    depends_on:
      - prometheus
    ports:
      - 3000:3000
    volumes:
      - grafana_data:/var/lib/grafana
      - /home/vagrant/monitoring/grafana/provisioning/:/etc/grafana/provisioning/
    env_file:
      - /home/vagrant/monitoring/grafana/config.monitoring
    networks:
      - back-tier
    restart: unless-stopped
``` 

Grafana can be set up to be high availability by using the same database configuration, which is located in `grafana.config`. This file is deployed to all Grafana servers:

```
GF_DATABASE_TYPE=mysql
GF_DATABASE_HOST=192.168.1.100:3306
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=grafana
GF_DATABASE_PASSWORD=really_secure_password
```

To use Prometheus in high availability you add this to your configuration. This tells the server to request the `/federate` endpoint on other Prometheus servers to ensure metrics are shared across both instances:

```yaml
global:
  scrape_interval:     5s
  evaluation_interval: 5s

  external_labels:
      monitor: 'mattermost-monitoring'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mattermost-server'
    static_configs:
      - targets: ['192.168.1.100:9100']
  
  - job_name: 'mattermost'
    static_configs:
      - targets: ['192.168.1.100:8067']

  - job_name: 'federate'
    scrape_interval: 5s

    honor_labels: true
    metrics_path: '/federate'

    params:
      'match[]':
        - '{job="prometheus"}'
        - '{__name__=~"job:.*"}'

    static_configs:
      - targets:
        - '192.168.1.102:9090'
```

### 2. Connect it all with a reverse proxy

The reverse proxy will provide access to the Grafana and Prometheus web interfaces. In my case I used [haproxy](https://www.haproxy.com/), which also gives you a status page so you can see which services are working.

![Screenshot of status page](./images/haproxy-status-page.png)

Here are the additions I made to my HAProxy config:

```
frontend http
  # ...
  
  acl grafana-acl hdr(host) -i grafana.planex.com
  acl prometheus-acl hdr(host) -i prometheus.planex.com
  
  use_backend grafana-backend if grafana-acl
  use_backend prometheus-backend if prometheus-acl

   # ...

backend grafana-backend
  mode http
  balance roundrobin
  cookie HA_BACKEND_ID insert indirect nocache
  default-server maxconn 256 maxqueue 128 weight 100
  server metrics0 192.168.1.101:3000 check cookie 1
  server metrics1 192.168.1.102:3000 check cookie 2

backend prometheus-backend
  mode http
  balance roundrobin
  server metrics0 192.168.1.101:9090 check
  server metrics1 192.168.1.102:9090 check
```

## How to use this Vagrant installation

If your local network runs on `192.168.1.0/24`, change the IP addresses in the `Vagrantfile` to suit your environment. Then, add these entries to your hosts file or local DNS:

```
192.168.1.100   mattermost.planex.com
192.168.1.100   stats.planex.com
192.168.1.100   grafana.planex.com
192.168.1.100   prometheus.planex.com
```

