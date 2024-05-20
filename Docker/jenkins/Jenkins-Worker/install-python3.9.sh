#!/bin/bash
wget https://www.python.org/ftp/python/3.9.0/Python-3.9.0.tar.xz
tar xf Python-3.9.0.tar.xz
rm Python-3.9.0.tar.xz
cd Python-3.9.0
./configure 
make 
make altinstall
