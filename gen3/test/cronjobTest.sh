
test_jenkins_cron() {
  bash "${GEN3_HOME}/files/scripts/jenkins-cronjob.sh" 'test';
    because $? "jenkins-cronjob.sh test should run ok"
}

shunit_runtest "test_jenkins_cron" "cron"
