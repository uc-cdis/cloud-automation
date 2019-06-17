#!/bin/bash
#
# Helper to query elastic search logs database
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/logs/utils"
gen3_load "gen3/lib/logs/raw"
gen3_load "gen3/lib/logs/daily"
gen3_load "gen3/lib/logs/ubh"

if [[ -z "$vpc_name" ]]; then
  vpc_name="$(g3kubectl get configmap global -o json | jq -r .data.environment)"
fi

gen3_logs_help() {
  gen3 help logs
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi
  command="$1"
  shift
  case "$command" in
    "curl")
      gen3_logs_curl "$@"
      ;;
    "curl200")
      gen3_logs_curl200 "$@"
      ;;
    "curljson")
      gen3_logs_curljson "$@"
      ;;
    "history")
      subcommand=""
      if [[ $# -gt 0 ]]; then
        subcommand="$1"
        shift
      fi
      case "$subcommand" in
        "daily")
          gen3_logs_history_daily "$@"
          ;;
        "ubh") # users by hour
          gen3_logs_ubh_history "$@"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand"
          ;;
      esac
      ;;
    "job")
      gen3_logs_rawlog_search qtype=job "$@"
      ;;
    "raw")
      gen3_logs_rawlog_search "$@"
      ;;
    "jobq")  # echo raw query - mostly for test suite
      gen3_logs_joblog_query "$@"
      ;;
    "rawq")  # echo raw query - mostly for test suite
      gen3_logs_rawlog_query "$@"
      ;;
    "save")
      subcommand=""
      if [[ $# -gt 0 ]]; then
        subcommand="$1"
        shift
      fi
      case "$subcommand" in
        "daily")
          gen3_logs_save_daily "$@"
          ;;
        "ubh")
          gen3_logs_ubh_save "$@"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid save subcommand $subcommand"
          exit 1
          ;;
      esac
      ;;
    "user")
      gen3_logs_user_list "$@"
      ;;
    "vpc")
      gen3_logs_vpc_list "$@"
      ;;
    *)
      gen3_log_err "gen3_logs" "invalid command $command"
      gen3_logs_help
      ;;
  esac
fi
