#! /bin/bash

# update apt
sudo apt update

# install jdk
sudo apt install openjdk-11-jdk -y

# add postgreSQL GPG key
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null

# add postgreSQL repo
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'

# update apt 
sudo apt update

# install postgreSQL
sudo apt install postgresql postgresql-contrib -y

# create sonarqube user and database
sudo -u postgres psql -c "create role sonarqube createdb createrole login password 'adeyomola'"
sudo -u postgres createdb -O sonarqube sq >> /dev/null

# download sonarqube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.6.1.59531.zip

# unzip the package
unzip -q sonarqube-9.6.1.59531.zip

# move sonarqube to the /opt directory
sudo mv sonarqube-9.6.1.59531 /opt/sonarqube

# delete zip file
rm sonarqube-9.6.1.59531.zip

# create sonarqube user
sudo useradd -b /opt/sonarqube -s /bin/bash sonarqube

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

# increase memory map
sudo bash -c 'echo -e "vm.max_map_count=262144\nfs.file-max=65536" >> /etc/sysctl.conf'

# apply changes to sysctl.conf
sudo sysctl --system

# create ulimit file for sonarqube
sudo touch /etc/security/limits.d/99-sonarqube.conf

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
ExecStart=/bin/nohup /usr/lib/jvm/java-11-openjdk-amd64/bin/java -Xms32m -Xmx32m -Djava.net.preferIPv4Stack=true -jar /opt/sonarqube/lib/sonar-application-8.5.jar
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

    listen 9000;
    access_log /var/log/nginx/sonar.access.log;
    error_log /var/log/nginx/sonar.error.log;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
EOF'

# enable the nginx sonarqube config
sudo ln -s /etc/nginx/sites-available/sonarqube.conf /etc/nginx/sites-enabled/

# restart nginx
sudo systemctl restart nginx
