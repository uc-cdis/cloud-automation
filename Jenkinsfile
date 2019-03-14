#!groovy

// See 'Loading libraries dynamically' here: https://jenkins.io/doc/book/pipeline/shared-libraries/
library identifier: "cdis-jenkins-lib@master"

pipeline {
  agent any

  script {
    kubectlNamespace = null
    kubeLocks = []
    pipeConfig = pipelineHelper.setupConfig({})
    pipelineHelper.cancelPreviousRunningBuilds()
  }

  stages {
    stage('FetchCode'){
      script {
        gitHelper.fetchAllRepos(pipeConfig['currentRepoName'])
      }
    }
    stage('gen3 helper test suite') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome bash cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
      }
    }
    stage('gen3 helper test suite with zsh') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome zsh cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
      }
    }

    stage('k8s configs test') {
      steps {
        sh 'pytest apis_configs/'
      }
    }
    stage('pytest') {
      steps {
        sh 'pip3 install boto3 --upgrade'
        sh 'cd cloud-automation/tf_files/aws/modules/common-logging && python3 -m pytest testLambda.py'
        sh 'cd cloud-automation/kube/services/jupyterhub && python3 -m pytest test-jupyterhub_config.py'
      }
    }
    stage('nginx helper test suite') {
      steps {
        dir('cloud-automation/kube/services/revproxy') {
          sh 'npx jasmine helpersTest.js'
        }
      }
    }
    stage('base image dockerrun.sh test') {
      steps {
        dir('cloud-automation/Docker/python-nginx/python2.7-alpine3.7') {
          sh 'sh dockerrun.sh --dryrun=True'
        }
      }
    }
    // The following stages are copied from the cdis-jenkins-lib pipeline
    stage('SelectNamespace') {
      steps {
        script {
          String[] namespaces = ['default']  // cloud-automation always runs in default qa.planx-pla.net ...
          uid = "cloudautomation-"+"$env.GIT_BRANCH".replaceAll("/", "_")+"-"+env.BUILD_NUMBER
          int lockStatus = 1;

          // try to find an unlocked namespace
          for (int i=0; i < namespaces.length && lockStatus != 0; ++i) {
            env.KUBECTL_NAMESPACE = namespaces[i]
            println "selected namespace $env.KUBECTL_NAMESPACE (qa.planx-pla.net) on executor $env.EXECUTOR_NUMBER"
            println "attempting to lock namespace $env.KUBECTL_NAMESPACE with a wait time of 10 minutes"
            withEnv(['GEN3_NOPROXY=true', "GEN3_HOME=$env.WORKSPACE/cloud-automation"]) {
              lockStatus = sh( script: "bash cloud-automation/gen3/bin/klock.sh lock jenkins "+uid+" 3600 -w 600", returnStatus: true)
            }
          }
          if (lockStatus != 0) {
            error("aborting - no available workspace")
          }
        }
      }
    }
    stage('K8sDeploy') {
      steps {
        withEnv(['GEN3_NOPROXY=true', "vpc_name=$env.KUBECTL_NAMESPACE", "GEN3_HOME=$env.WORKSPACE/cloud-automation"]) {
          echo "GEN3_HOME is $env.GEN3_HOME"
          echo "GIT_BRANCH is $env.GIT_BRANCH"
          echo "GIT_COMMIT is $env.GIT_COMMIT"
          echo "KUBECTL_NAMESPACE is $env.KUBECTL_NAMESPACE"
          echo "WORKSPACE is $env.WORKSPACE"
          sh "bash cloud-automation/gen3/bin/kube-roll-all.sh"
          // wait for portal to startup ...
          sh "bash cloud-automation/gen3/bin/kube-wait4-pods.sh || true"
        }
      }
    }
    stage('VerifyClusterHealth') {
      steps {
        withEnv(['GEN3_NOPROXY=true', "vpc_name=$env.KUBECTL_NAMESPACE", "GEN3_HOME=$env.WORKSPACE/cloud-automation"]) {
          sh "bash cloud-automation/gen3/bin/kube-wait4-pods.sh"
        }
      }
    }
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
    always {
      script {
        uid = "cloudautomation-"+"$env.GIT_BRANCH".replaceAll("/", "_")+"-"+env.BUILD_NUMBER
        withEnv(['GEN3_NOPROXY=true', "GEN3_HOME=$env.WORKSPACE/cloud-automation"]) {         
          sh("bash cloud-automation/gen3/bin/klock.sh unlock jenkins "+uid)
        }
      }
      echo "done"
    }
  }
}
