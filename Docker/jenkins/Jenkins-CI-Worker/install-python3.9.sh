#!/bin/bash
wget https://www.python.org/ftp/python/3.9.19/Python-3.9.19.tar.xz
tar xf Python-3.9.19.tar.xz
rm Python-3.9.19.tar.xz
cd Python-3.9.19
./configure 
make 
make altinstall
