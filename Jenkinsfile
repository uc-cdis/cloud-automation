#!groovy

// See 'Loading libraries dynamically' here: https://jenkins.io/doc/book/pipeline/shared-libraries/
library 'cdis-jenkins-lib@master'

import org.jenkinsci.plugins.pipeline.modeldefinition.Utils

node {
  def AVAILABLE_NAMESPACES = ['jenkins-blood', 'jenkins-brain', 'jenkins-niaid', 'jenkins-dcp', 'jenkins-genomel']
  List<String> namespaces = []
  List<String> listOfSelectedTests = []
  skipUnitTests = false
  skipQuayImgBuildWait = false
  doNotRunTests = false
  kubectlNamespace = null
  kubeLocks = []
  testedEnv = "" // for manifest pipeline
  pipeConfig = pipelineHelper.setupConfig([:])
  pipelineHelper.cancelPreviousRunningBuilds()
  prLabels = githubHelper.fetchLabels()

  try {
    stage('CleanWorkspace') {
      cleanWs()
    }
    stage('FetchCode'){
      gitHelper.fetchAllRepos(pipeConfig['currentRepoName'])
    }
    stage('CheckPRLabels') {
     try {
      // giving a chance for auto-label gh actions to catch up
      // sleep(10)
      for(label in prLabels) {
        println(label['name']);
        switch(label['name']) {
          case ~/^test-.*/:
            println('Select a specific test suite and feature')
            selectedTestLabel = label['name'].split("-")
            println "selected test: suites/" + selectedTestLabel[1] + "/" + selectedTestLabel[2] + ".js"
            selectedTest = "suites/" + selectedTestLabel[1] + "/" + selectedTestLabel[2] + ".js"
            listOfSelectedTests.add(selectedTest)
            break
          case "skip-gen3-helper-tests":
            println('Skipping unit tests assuming they have been verified in a previous PR check iteration...')
            skipUnitTests = true
            break
          case "skip-awshelper-build-wait":
            println('Skipping the WaitForQuayBuild stage as it is not necessary for every PR...')
            skipQuayImgBuildWait = true
            break
          case "doc-only":
            println('Skip tests if git diff matches expected criteria')
            doNotRunTests = docOnlyHelper.checkTestSkippingCriteria()
            skipUnitTests = true
            skipQuayImgBuildWait = true
            break
          case "debug":
            println("Call npm test with --debug")
            println("leverage CodecepJS feature require('codeceptjs').output.debug feature")
            break
          case "not-ready-for-ci":
            currentBuild.result = 'ABORTED'
            error('This PR is not ready for CI yet, aborting...')
            break
          case AVAILABLE_NAMESPACES:
            println('found this namespace label! ' + label['name']);
            namespaces.add(label['name'])
            break
          case "qaplanetv2":
            println('This PR check will run in a qaplanetv2 environment! ');
            namespaces.add('ci-env-1')
            break
          default:
            println('no-effect label')
            break
        }
      }
      // If none of the jenkins envs. have been selected pick one at random
      if (namespaces.isEmpty()) {
        println('populating namespaces with list of available namespaces...')
        namespaces = AVAILABLE_NAMESPACES
      }
      // If a specific test suite is not specified, run them all
      if (listOfSelectedTests.isEmpty()) {
	  listOfSelectedTests.add("all")
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)  
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('gen3 helper test suite') {
     try {
      println("namespaces: ${namespaces}")
      if(!skipUnitTests) {
        sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome bash cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('gen3 helper test suite with zsh') {
     try {
      if(!skipUnitTests) {
        sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome zsh cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('pytest') {
     try {
      if(!skipUnitTests) {
        sh 'pip3 install boto3 --upgrade'
        sh 'pip3 install kubernetes --upgrade'
        sh 'python -m pytest cloud-automation/apis_configs/'
        sh 'python -m pytest cloud-automation/gen3/lib/dcf/'
        sh 'cd cloud-automation/tf_files/aws/modules/common-logging && python3 -m pytest testLambda.py'
        sh 'cd cloud-automation/files/lambda && python3 -m pytest test-security_alerts.py'
        sh 'cd cloud-automation/kube/services/jupyterhub && python3 -m pytest test-jupyterhub_config.py'
        sh 'bash cloud-automation/files/scripts/es-secgroup-sync.sh test'
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('nginx helper test suite') {
     try {
      if(!skipUnitTests) {
        dir('cloud-automation/kube/services/revproxy') {
          sh 'npx jasmine helpersTest.js'
        }
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('python 2 base image dockerrun.sh test') {
     try {
      if(!skipUnitTests) {
        dir('cloud-automation/Docker/python-nginx/python2.7-alpine3.7') {
          sh 'sh dockerrun.sh --dryrun=True'
        }
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('python 3 base image dockerrun.sh test') {
     try {
      if(!skipUnitTests) {
        dir('cloud-automation/Docker/python-nginx/python3.6-alpine3.7') {
          sh 'sh dockerrun.sh --dryrun=True'
        }
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('WaitForQuayBuild') {
     try {
      if(!skipQuayImgBuildWait) {
        quayHelper.waitForBuild(
          "awshelper",
          pipeConfig['currentBranchFormatted']
        )
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('SelectNamespace') {
     try {
      if(!doNotRunTests) {
        (kubectlNamespace, lock) = kubeHelper.selectAndLockNamespace(pipeConfig['UID'], namespaces)
        kubeLocks << lock
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('ModifyManifest') {
     try {
      if(!doNotRunTests) {
        manifestHelper.editService(
          kubeHelper.getHostname(kubectlNamespace),
          "awshelper",
          pipeConfig.serviceTesting.branch
        )
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    
    stage('K8sReset') {
     try {
      if(!doNotRunTests) {
        // adding the reset-lock lock in case reset fails before unlocking
        kubeLocks << kubeHelper.newKubeLock(kubectlNamespace, "gen3-reset", "reset-lock")
        kubeHelper.reset(kubectlNamespace)
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('VerifyClusterHealth') {
     try {
      if(!doNotRunTests) {
        kubeHelper.waitForPods(kubectlNamespace)
        testHelper.checkPodHealth(kubectlNamespace, "")
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('GenerateData') {
     try {
      if(!doNotRunTests) {    
        testHelper.simulateData(kubectlNamespace)
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('FetchDataClient') {
     try {
      if(!doNotRunTests) {
        // we get the data client from master, unless the service being
        // tested is the data client itself, in which case we get the
        // executable for the current branch
        dataCliBranch = "master"
        if (pipeConfig.currentRepoName == "cdis-data-client") {
          dataCliBranch = env.CHANGE_BRANCH
        }
        testHelper.fetchDataClient(dataCliBranch)
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('RunTests') {
     try {
      if(!doNotRunTests) {
        testHelper.runIntegrationTests(
            kubectlNamespace,
            pipeConfig.serviceTesting.name,
            testedEnv,
            "true",
            listOfSelectedTests
        )
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
    }
    stage('CleanS3') {
     try {
      if(!doNotRunTests) {
        testHelper.cleanS3(kubectlNamespace)
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true) 
    }
    stage('authzTest') {
     try {
      if(!doNotRunTests) {
        // test revproxy+arborist /gen3-authz stuff
        kubeHelper.kube(kubectlNamespace, {
          sh('bash cloud-automation/gen3/bin/testsuite.sh --filter authz');
        });
      } else {
        Utils.markStageSkippedForConditional(STAGE_NAME)
      }
     } catch (ex) {
        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
        throw ex
     }
     metricsHelper.writeMetricWithResult(STAGE_NAME, true)
   }
  }
  catch (e) {
    pipelineHelper.handleError(e)
    throw e
  }
  finally {
    stage('Post') {
      kubeHelper.teardown(kubeLocks)
      testHelper.teardown()
      if(!skipUnitTests) {
        // tear down network policies deployed by the tests
        kubeHelper.kube(kubectlNamespace, {
          sh(script: 'kubectl --namespace="' + kubectlNamespace + '" delete networkpolicies --all', returnStatus: true);
        });
        pipelineHelper.teardown(currentBuild.result)
      }
    }
  }
}

