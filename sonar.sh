#! /bin/bash

# update apt
sudo apt update

# install jdk
sudo apt install openjdk-17-jdk -y

# add postgreSQL GPG key
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null

# add postgreSQL repo
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'

# update apt 
sudo apt update

# install postgreSQL
sudo apt install postgresql postgresql-contrib -y

# create sonarqube user and database
sudo -u postgres psql -c "create role sonarqube createdb createrole login password 'adeyomola'" >> /dev/null
sudo -u postgres createdb -O sonarqube sq >> /dev/null

# download sonarqube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.2.1.78527.zip

# unzip the package
unzip -q sonarqube-10.2.1.78527.zip

# move sonarqube to the /opt directory
sudo mv sonarqube-10.2.1.78527 /opt/sonarqube

# delete zip file
rm sonarqube-10.2.1.78527.zip

# create sonarqube user
sudo adduser --system --no-create-home --group --disabled-login sonarqube

# grant permissions to /opt/sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# configure the server
sudo bash -c 'cat << FOE >> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=adeyomola
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sq
sonar.web.host=127.0.0.1
sonar.web.javaAdditionalOpts=-server
FOE'

# increase memory map dynamically and permanently
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072 
sudo bash -c 'echo -e "vm.max_map_count=524288\nfs.file-max=131072" >> /etc/sysctl.conf'

# apply changes to sysctl.conf
sudo sysctl --system

# create ulimit file for sonarqube
sudo touch /etc/security/limits.d/99-sonarqube.conf

# set ulimits dynamically
ulimit -n 131072
ulimit -u 8192

# add limits to the ulimit file
sudo bash -c 'echo -e "sonarqube   -   nofile   65536\nsonarqube   -   nproc    4096" >> /etc/security/limits.d/99-sonarqube.conf'

# create sonarqube service file
sudo touch /etc/systemd/system/sonarqube.service

# add service configuration
sudo bash -c 'cat << EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=simple
User=sonarqube
Group=sonarqube
PermissionsStartOnly=true
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
StandardOutput=syslog
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5
Restart=always
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF'

# start sonarqube service
sudo systemctl start sonarqube

# enable service on startup
sudo systemctl enable sonarqube

# show status
sudo systemctl status sonarqube

## set up reverse proxy with nginx
# install nginx
sudo apt install nginx -y

# enable on startup
sudo systemctl enable nginx

# create nginx config file for sonarqube
sudo touch /etc/nginx/sites-available/sonarqube.conf

# append configuration for sonarqube
sudo bash -c 'cat << "EOF" > /etc/nginx/sites-available/sonarqube.conf
server {
  listen 80;
  location / {
    proxy_pass http://127.0.0.1:9000;
  }
}
EOF'

# enable the nginx sonarqube config
sudo ln -s /etc/nginx/sites-available/sonarqube.conf /etc/nginx/sites-enabled/

# restart nginx
sudo systemctl restart nginx
