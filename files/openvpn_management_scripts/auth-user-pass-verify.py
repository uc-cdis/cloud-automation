#!/usr/bin/env python
# Copyright 2015 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu
#  This script assumes that openvpn is santizing inputs
#     like it should. Converting to underscores.
#  It checks the passwd hash table to ensure user supplied
#     password is correct

import os
import sys
import csv
import bcrypt
import pyotp


# Read in the username and password for  ENV variables openvpn uses
username = os.environ['username']
password = os.environ['password']
passwd_csv_file = os.environ['USER_PW_FILE']
try:
    totp_window = int(os.environ['totp_window'])
except KeyError as e:
    totp_window = 2

f = open(passwd_csv_file, 'r')
reader = csv.reader(f)
for row in reader:
    if row[0] == username:
        hashed = row[1]
        try:
            # If bcryt hashes detected, check user supplied password hash
            if (hashed.startswith('$2a$') or hashed.startswith('$2b$') or hashed.startswith('$2y$')):
                if (bcrypt.hashpw(password, hashed) == hashed):
                    f.close()
                    sys.exit(0)
                else:
                    f.close()
                    sys.exit(1)
            # TOTP code detected, verify TOTP tokens match window
            elif (hashed.startswith('$TOTP$')):
                secret = hashed.split('$')[2]
                token = pyotp.TOTP(secret)
                # if TOTP code within totp_window+1 "tics" allow
                #    (1 tic = 30sec)
                if token.verify(otp=password, valid_window=totp_window):
                    sys.exit(0)
                else:
                    sys.exit(1)
                sys.exit(5)
        except ValueError as e:
            f.close()
            sys.exit(1)
            pass

# Fail closed
f.close()
sys.exit(1)
