#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# lib -----------------------------------

gen3_access_frontend_help() {
  gen3 help acccess_frontend
}


gen3_access_frontend_create() {
  local url
  local cert
  local react_app_api_host
  local react_app_auth_host
  local react_app_client_id
  if [[ $# -lt 4 || -z "$4" ]]; then
    gen3_log_err "gen3_db_reset" "must specify the url, cert and react app api host, auth host and client id"
    return 1
  fi

  url="$1"
  cert="$2"
  react_app_api_host="https://$3/access-backend"
  react_app_auth_host="https://$3"
  react_app_client_id="$4"
  gen3 workon default default__access
  gen3 cd
  mv config.tfvars config.bckup
  echo 'access_url="'$url'"' >> config.tfvars
  echo 'access_cert="'$cert'"' >> config.tfvars
  gen3 tfplan
  gen3 tfapply
  if [[ ! -d $WORKSPACE ]]; then
    git clone https://github.com/uc-cdis/ACCESS.git $WORKSPACE
  fi
  cd $WORKSPACE/ACCESS
  #find a way to export these or include them in command as env variables
  export REACT_APP_API_HOST=$react_app_api_host
  export REACT_APP_AUTH_HOST=$react_app_auth_host
  export REACT_APP_CLIENT_ID=$react_app_client_id
  export REACT_APP_REDIRECT_URL="https://$url/login"
  npm ci && npm run build
  cd $WORKSPACE/ACCESS
  ls -al; cd build; ls -al; mkdir ../access-art && mv * ../access-art/. && mv ../access-art/* .; aws s3 sync . s3://$url --delete --acl public-read
  gen3_log_info "ACCESS Frontend has been installed at $url. Please setup route 53 dns record to point at the cloudfront distribution"

}

gen3_access_frontend_update() {
  local url
  local react_app_api_host
  local react_app_auth_host
  local react_app_client_id
  if [[ $# -lt 3 || -z "$3" ]]; then
    gen3_log_err "gen3_db_reset" "must specify the url and react app api host, auth host and client id"
    return 1
  fi

  url="$1"
  react_app_api_host="https://$2/access-backend"
  react_app_auth_host="https://$2"
  react_app_client_id="$3"
  if [[ ! -d $WORKSPACE ]]; then
    git clone https://github.com/uc-cdis/ACCESS.git $WORKSPACE
  fi
  cd $WORKSPACE/ACCESS
  #find a way to export these or include them in command as env variables
  export REACT_APP_API_HOST=$react_app_api_host
  export REACT_APP_AUTH_HOST=$react_app_auth_host
  export REACT_APP_CLIENT_ID=$react_app_client_id
  export REACT_APP_REDIRECT_URL="https://$url/login"
  npm ci && npm run build
  cd $WORKSPACE/ACCESS
  ls -al; cd build; ls -al; mkdir ../access-art && mv * ../access-art/. && mv ../access-art/* .; aws s3 sync . s3://$url --delete --acl public-read
  gen3_log_info "ACCESS Frontend has been updated"
}


gen3_access_frontend_delete() {
  gen3 workon default default__access
  gen3 cd
  gen3_load "gen3/lib/terraform"
  gen3_terraform destroy
  gen3 trash --apply
  gen3_log_info "ACCESS Frontend has been removed"
}


# main -----------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then

  command="$1"
  shift
  case "$command" in
    "create")
      gen3_access_frontend_create "$@"
      ;;
    "update")
      gen3_access_frontend_update "$@";
      ;;
    "delete")
      gen3_access_frontend_delete "$@";
      ;;
    *)
      gen3_access_frontend_help
      ;;
  esac
  exit $?
fi