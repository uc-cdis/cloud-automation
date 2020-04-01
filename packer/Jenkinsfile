#!groovy

pipeline {
  agent any

  stages {
    stage('FetchCode'){
      steps {
        checkout scm
        //git url: 'https://github.com/uc-cdis/images.git', branch: 'fix/whitelist'
      }
    }
    stage('PackerCheck') {
      steps {
        sh 'set -e; for i in images/*; do echo --------; echo $i; packer inspect $i; packer validate -var source_ami=ami-0dcc6477 $i; done;'
      }
    }
  }
  post {
    success {
      slackSend color: 'good', message: "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/images pipeline succeeded"
    }
    failure {
      slackSend color: 'bad', message: "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/images pipeline failed"
    }
    unstable {
      slackSend color: 'bad', message: "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/images pipeline unstable"
    }
  }
}
