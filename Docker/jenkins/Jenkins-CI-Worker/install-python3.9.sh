#!/bin/bash
wget https://www.python.org/ftp/python/3.9.16/Python-3.9.16.tar.xz
tar xf Python-3.9.16.tar.xz
rm Python-3.9.16.tar.xz
cd Python-3.9.16
./configure 
make 
make altinstall
