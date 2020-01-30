#!/bin/bash 

##
#
# the purpose of this script is to create a report of users and their certificate expiration dates
# for openvpn services running in CTDS.
# it'll just create a static html file and put it in the folder of choice, in which our defalt is
# /var/www/qrcode/users_report.html. CTDS openvpn servers also run an http service we can use to
# show the report.
#
# this script is intended to be put on /etc/cron.daily and let is run daily
#
##

CERTS_PATH="/etc/openvpn/easy-rsa/keys/"
USERS_FILE="/etc/openvpn/user_passwd.csv"

if ! [ -z $1 ];
then
  REPOR_LOCA="$1"
else
  REPOR_LOCA="/var/www/qrcode/users_report.html"
fi

function get_active_users(){
  local active_users="$(awk -F, '{print $1}'  ${USERS_FILE})"
  echo "${active_users}"
}
  
function print_header(){

  echo "<!DOCTYPE html>"
  echo "<html>"
  echo "  <head>"
  echo "    <meta charset=\"UTF-8\">"
  echo "      <title>$(hostname -s) users report</title>"
  echo "    </meta>"
  echo "    <style>thead {color:white;}
                   tbody {color:#4d4d4d;}
                   tfoot {color:red;}
                   table{
                     border-collapse: collapse;
                     width: 100%;
                   }
                   th,td{
                     text-align: left;
                     padding: 8px;
                   }
                   tr:nth-child(even){background-color: #f2f2f2}
                   th {
                     background-color: #800000;
                     color: white;
                   }
                   #soon {
                     color: red;
                     font-weight: bold;
                   }
            </style>"
  echo "  </head>"
}


function print_body(){

  echo "<body>"
  echo "$(get_body)"
  echo "</body>"
}


function get_user_info(){
  local user="${1}"
  local file="${CERTS_PATH}${user}.crt"

  local user_email
  local cert_start
  local cert_expir

  local table_output

  get_email(){
    user_email=$(openssl x509 -in ${file} -noout -text  |grep Subject: |egrep -o "[a-z0-9._-]+@[a-z0-9.-]+\.[a-z]{2,4}$" | sed -e "s/[a-z0-9._-]*/********/")
  }
  get_cert_start(){
    cert_start=$(openssl x509 -in ${file} -noout -text |grep "Not Before"  |sed -e "s/.*Before: //")
  }
  get_cert_expri(){
    cert_expir=$(openssl x509 -in ${file} -noout -text |grep "Not After" | sed -e "s/.*After : //")
  }

  get_email
  get_cert_start
  get_cert_expri

  local days_remaining=$(( ($(date --date="${cert_expir}" +%s) - $(date +%s) )/(60*60*24) ))

  table_output="<td>${user}</td><td>${user_email}</td><td>${cert_start}</td><td>${cert_expir}</td><td $(if [ ${days_remaining} -lt 30 ]; then echo 'id="soon"'; fi)>${days_remaining}</td>"
  
  echo ${table_output}
}

function get_body(){

  local output
  local active_users=$(get_active_users)

  output="<table><thead><tr><th>Username</th><th>Email</th><th>Cert Start</th><th>Cert Expire</th><th>Days remaining</th></tr></thead>"
  for user in ${active_users};
  do
      output="${output}<tr>$(get_user_info ${user})</tr>"
  done
  output="${output}</table>"

  echo "${output}"

}

function print_additional_information() {
  echo "</br>"
  echo "Last update: $(date)"
  echo "</br>"
}


function print_footer() {
  echo "</html>"
}

function main() {
  print_header > ${REPOR_LOCA}
  print_body >> ${REPOR_LOCA}
  print_additional_information >> ${REPOR_LOCA}
  print_footer >> ${REPOR_LOCA}
}

main
