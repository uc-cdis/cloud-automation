#!/bin/bash
# Tab-completions for bash
#

gen3_completions() {
  if [[ $COMP_CWORD -lt 2 ]]; then
    COMPREPLY=($(compgen -W "roll update_config $(/bin/ls -1 "$GEN3_HOME/gen3/bin" | sed -e 's/.sh$//')" "${COMP_WORDS[1]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "es" ]]; then
    COMPREPLY=($(compgen -W "filter configmaps alias indices delete dump export import mapping port-forward" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "gitops" ]]; then
    COMPREPLY=($(compgen -W "filter configmaps rsync sshlist sync repolist taglist dotag" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "job" ]]; then
    COMPREPLY=($(compgen -W "run logs" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "klock" ]]; then
    COMPREPLY=($(compgen -W "list lock unlock" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "logs" ]]; then
    COMPREPLY=($(compgen -W "list job raw" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 2 && "${COMP_WORDS[1]}" == "roll" ]]; then
    COMPREPLY=($(compgen -W "$(/bin/ls "${GEN3_HOME}/kube/services" | grep -v -e job -e netpolicy)" "${COMP_WORDS[2]}"))
  elif [[ ${COMP_CWORD} -eq 3 && "${COMP_WORDS[1]}" == "job" && ("${COMP_WORDS[2]}" == "run" || "${COMP_WORDS[2]}" == "logs") ]]; then
    COMPREPLY=($(compgen -W "$(/bin/ls "${GEN3_HOME}/kube/services/jobs" | grep -e yaml | sed -e 's/\.yaml$//' | grep -e '-job' -e '-cronjob' | sed -e 's/-job.*$//')" "${COMP_WORDS[3]}"))
  else
    COMPREPLY=("${COMP_CWORD}" "${COMP_WORDS[2]}")
  fi
}

complete -F gen3_completions gen3