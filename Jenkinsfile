#!groovy

pipeline {
  agent any

  stages {
    stage('FetchCode'){
      steps {
        checkout scm
        sh '/bin/rm -rf Secrets SecretsNoPlan dataHome'
      }
    }
    stage('gen3 helper test suite') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE XDG_DATA_HOME=$WORKSPACE/dataHome bash gen3/bin/testsuite.sh --profile jenkins'
      }
    }
    stage('gen3 helper test suite with zsh') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE XDG_DATA_HOME=$WORKSPACE/dataHome zsh gen3/bin/testsuite.sh --profile jenkins'
      }
    }

    stage('k8s configs test') {
      steps {
        sh 'pytest apis_configs/'
      }
    }
    stage('lamda test') {
      steps {
        sh 'pip3 install boto3 --upgrade'
        sh 'cd tf_files/aws/modules/common-logging && python3 -m pytest testLambda.py'
      }
    }
    stage('g3k helper test suite') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE XDG_DATA_HOME=$WORKSPACE/dataHome bash gen3/bin/g3k_testsuite.sh --profile jenkins'
      }
    }
    stage('nginx helper test suite') {
      steps {
        sh 'cd kube/services/revproxy && npx jasmine helpersTest.js'
      }
    }
    /* ... this not working yet - will finish later ...
    stage('gen3 roll all in current namespace') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE XDG_DATA_HOME=$WORKSPACE/dataHome bash gen3/bin/kube-roll-all.sh'
      }
    }
    */
  }
  post {
    success {
      echo "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/cloud-automation pipeline succeeded"
    }
    failure {
      slackSend color: 'bad', message: "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/cloud-automation pipeline failed"
    }
    unstable {
      slackSend color: 'bad', message: "https://jenkins.planx-pla.net/job/$env.JOB_NAME/\nuc-cdis/cloud-automation pipeline unstable"
    }
  }
}
