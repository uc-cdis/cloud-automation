# TL;DR

Setup a demolab with 20 VM's setup for ssh access.

## 1. QuickStart

```
gen3 workon <profile> <name>_demolab
```

Ex.
```
$ gen3 workon cdistest april2019_demolab
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly. However, assuming you used the example above, you may not need to. You must check the file nonetheless.

Ex.
```
fauziv1@cdistest_admin ~/cloud-automation
 % cat ~/.local/share/gen3/cdistest/fauziv1_es/config.tfvars
vpc_name   = "april2019_demolab"
```

## 4. Variables

By default the vpc_name would be configured properly at the moment workon is executed. There are no more variables for this module.

