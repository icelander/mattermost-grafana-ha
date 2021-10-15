#!/bin/bash

mattermost_version=$1
root_password=$2
mysql_password=$3

rm -rf /opt/mattermost

archive_filename="mattermost-$mattermost_version-linux-amd64.tar.gz"
archive_path="/vagrant/mattermost_archives/$archive_filename"
archive_url="https://releases.mattermost.com/$mattermost_version/$archive_filename"

if [[ ! -f $archive_path ]]; then
	wget --quiet $archive_url -O $archive_path
fi

if [[ ! -f $archive_path ]]; then
	echo "Could not find archive file, aborting"
	echo "Path: $archive_path"
	exit 1
fi

cp $archive_path ./

tar -xzf mattermost*.gz

rm mattermost*.gz
mv mattermost /opt

mkdir /opt/mattermost/data

mv /opt/mattermost/config/config.json /opt/mattermost/config/config.orig.json
cat /vagrant/config.json | sed "s/MATTERMOST_PASSWORD/$mysql_password/g" > /tmp/config.json
jq -s '.[0] * .[1]' /opt/mattermost/config/config.orig.json /tmp/config.json > /opt/mattermost/config/config.json
rm /tmp/config.json

useradd --system --user-group mattermost
chown -R mattermost:mattermost /opt/mattermost
chmod -R g+w /opt/mattermost

cat /vagrant/MM_LICENSE.env >> /opt/mattermost/config/mm.environment
cp /vagrant/mattermost.service /lib/systemd/system/mattermost.service
systemctl daemon-reload

chown -R mattermost:mattermost /opt/mattermost

service mattermost start

cd /opt/mattermost
runuser mattermost -c './bin/mmctl --local user create --email admin@planetexpress.com --username admin --password admin --system-admin'
runuser mattermost -c './bin/mmctl --local team create --name planet-express --display-name "Planet Express" --email "professor@planetexpress.com"'
runuser mattermost -c './bin/mmctl --local team users add planet-express admin@planetexpress.com'

printf '=%.0s' {1..80}
echo 
echo '                     VAGRANT UP!'
echo "GO TO http://mattermost.planex.com and log in with \`admin\`"
echo
printf '=%.0s' {1..80}
