#!/bin/bash
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on
sudo chmod 666 /var/run/docker.sock
sudo yum install -y git
docker pull vraj0073/market_place:v1
docker run -p 80:3000 vraj0073/market_place:v1