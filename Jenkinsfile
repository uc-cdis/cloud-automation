#!groovy

// See 'Loading libraries dynamically' here: https://jenkins.io/doc/book/pipeline/shared-libraries/
library 'cdis-jenkins-lib@master'

node {
  kubectlNamespace = null
  kubeLocks = []
  pipeConfig = pipelineHelper.setupConfig([:])
  pipelineHelper.cancelPreviousRunningBuilds()

  try {
    stage('FetchCode'){
      gitHelper.fetchAllRepos(pipeConfig['currentRepoName'])
    }
    stage('gen3 helper test suite') {
      sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome bash cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
    }
    stage('gen3 helper test suite with zsh') {
      sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome zsh cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
    }

    stage('pytest') {
      sh 'pip3 install boto3 --upgrade'
      sh 'pip3 install kubernetes --upgrade'
      sh 'python -m pytest cloud-automation/apis_configs/'
      sh 'python -m pytest cloud-automation/gen3/lib/dcf/'
      sh 'cd cloud-automation/tf_files/aws/modules/common-logging && python3 -m pytest testLambda.py'
      sh 'cd cloud-automation/kube/services/jupyterhub && python3 -m pytest test-jupyterhub_config.py'
      sh 'bash cloud-automation/files/scripts/es-secgroup-sync.sh test'
    }
    stage('nginx helper test suite') {
      dir('cloud-automation/kube/services/revproxy') {
        sh 'npx jasmine helpersTest.js'
      }
    }
    stage('base image dockerrun.sh test') {
      dir('cloud-automation/Docker/python-nginx/python2.7-alpine3.7') {
        sh 'sh dockerrun.sh --dryrun=True'
      }
    }
    stage('SelectNamespace') {
      (kubectlNamespace, lock) = kubeHelper.selectAndLockNamespace(pipeConfig['UID'])
      kubeLocks << lock
    }
    stage('K8sReset') {
        // adding the reset-lock lock in case reset fails before unlocking
        kubeLocks << kubeHelper.newKubeLock(kubectlNamespace, "gen3-reset", "reset-lock")
        kubeHelper.reset(kubectlNamespace)
      }
      stage('VerifyClusterHealth') {
        kubeHelper.waitForPods(kubectlNamespace)
        testHelper.checkPodHealth(kubectlNamespace)
      }
      stage('GenerateData') {
        testHelper.simulateData(kubectlNamespace)
      }
      stage('FetchDataClient') {
        // we get the data client from master, unless the service being
        // tested is the data client itself, in which case we get the
        // executable for the current branch
        dataCliBranch = "master"
        if (pipeConfig.currentRepoName == "cdis-data-client") {
          dataCliBranch = env.CHANGE_BRANCH
        }
        testHelper.fetchDataClient(dataCliBranch)
      }
      stage('RunTests') {
        testHelper.runIntegrationTests(
          kubectlNamespace,
          pipeConfig.serviceTesting.name,
          ""
        )
      }
      stage('CleanS3') {
        testHelper.cleanS3()
      }
      stage('authzTest') {
        // test revproxy+arborist /gen3-authz stuff
        kubeHelper.kube(kubectlNamespace, {
          sh('bash cloud-automation/gen3/bin/testsuite.sh --filter authz');
        });
      }
    }
  catch (e) {
    pipelineHelper.handleError(e)
  }
  finally {
    stage('Post') {
      kubeHelper.teardown(kubeLocks)
      testHelper.teardown()
      // tear down network policies deployed by the tests
      kubeHelper.kube(kubectlNamespace, {
          sh(script: 'kubectl --namespace="' + kubectlNamespace + '" delete networkpolicies --all', returnStatus: true);
        });
      pipelineHelper.teardown(currentBuild.result)
    }
  }
}

