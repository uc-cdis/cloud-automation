#compdef gen3

#
# See 
# https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org
# http://www.linux-mag.com/id/1106/
#
# Originally copied from:
#  https://github.com/zsh-users/zsh-completions/blob/master/src/_bower
#
_gen3_zsh_completions() {    
  local curcontext="$curcontext" state line _opts ret=1

  _arguments -C \
    '(- 1 *)'{-v,--version}'[display version information]' \
    '1: :->cmds' \
    '*:: :->args' && ret=0

  case $state in
    cmds)
      local -a gen3cmds
      local subname
      local entry
        
      for subname in $(/bin/ls -1 "$GEN3_HOME/gen3/bin" | sed -e 's/.sh$//'); do
        gen3cmds+=("$subname")
      done

      _values "gen3 commands" "${gen3cmds[@]}" \
         && ret=0
      _arguments \
        '(--help)--help[show help message]' && ret=0      
      ;;
    args)
      case $line[1] in
        gitops)
          _values "gitops commands" configmaps rsync sshlist sync repolist taglist dotag tfplan tfapply && ret=0
          ;;
        job)
          if [[ "$line[2]" == "run" ]]; then
            _values "available jobs" \
              $(/bin/ls "${GEN3_HOME}/kube/services/jobs" | grep -e yaml | sed -e 's/\.yaml$//' | grep -e '-job' -e '-cronjob' | sed -e 's/-job.*$//') \
              && ret=0
          elif [[ "$line[2]" != "logs" ]]; then
            _values "job commands" logs run && ret=0
          fi
          ;;
        klock)
          _values "klock commands" list lock unlock && ret=0
          ;;
        roll)
          _values "roll services" all $(/bin/ls "${GEN3_HOME}/kube/services" | grep -v -e job -e netpolicy) && ret=0
          ;;        
        *)
          ;;
      esac
      ;;
  esac

  return ret
}

compdef _gen3_zsh_completions gen3
