#!/bin/bash
if [ ! "$USER" == "root" ]; then
echo "

    WARNING: To protect the system from unauthorized use and to ensure that the
system is functioning properly, activities on this system are monitored and
recorded and subject to audit. Use of this system is expressed consent to such
monitoring and recording. Any unauthorized access or use of this Automated
Information System is prohibited and could be subject to criminal and civil
penalties.
    Users are prohibited from using the system in a non approved manner. All
data is to be treated as privileged information and transferred in an approved
secure manner.
    If you agree to these conditions, hit Y to continue, otherwise hit n to exit.
"


        echo $1
        read -p "Agree to these conditions? [y/N]" -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
                return
        else
            exit
        fi

fi
