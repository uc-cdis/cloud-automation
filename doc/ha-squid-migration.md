# TL;DR

This Procedure is intended to show the necessary steps to migrate from a single Squid proxy instance, to an HA/Multizone one.


## Overview

Currently, commons are using a single squid proxy to access the internet. Even though it works just file in most cases, sometimes it might fail, or the underlaying Hardware fails and AWS set it for decomision. Further more, the AMI used as image base was created with Packer and tailored for the needs by that time. 

The new HA model will now use official Canonical Ubuntu's 18.04 image and can be easily told to check for the latest release by them.

Moreover, we are placing all instances in an Auto-Scaling group, meaning that if one goes away, it'll be easily replasable, and require little to none supervision.


## Procedure



