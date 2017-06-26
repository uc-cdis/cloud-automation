#!/bin/bash
sudo apt-get update
sudo apt-get install nginx
sudo mkdir /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj "/C=US/ST=Chicago/L=Chicago/O=Global Security/OU=IT Department/CN=example.com"
sudo rm /etc/nginx/sites-enabled/*
sudo cp proxy.conf /etc/nginx/sites-enabled/
sudo service nginx restart
