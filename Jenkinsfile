#!groovy

// See 'Loading libraries dynamically' here: https://jenkins.io/doc/book/pipeline/shared-libraries/
library 'cdis-jenkins-lib@master'

import org.jenkinsci.plugins.pipeline.modeldefinition.Utils


def config = [:]

// Our CI Pipeline is heavily parameterized based on Pull Request labels
// giving a chance for auto-label gh actions to catch up
sleep(30)
def prLabels = githubHelper.fetchLabels()
config['prLabels'] = prLabels

def pipeConfig = pipelineHelper.setupConfig(config)

List<String> namespaces = []
List<String> listOfSelectedTests = []
skipUnitTests = false
skipQuayImgBuildWait = false
doNotRunTests = false
runParallelTests = false
isGen3Release = "false"
isNightlyBuild = "false"
kubectlNamespace = null
kubeLocks = []
testedEnv = "" // for manifest pipeline
regexMatchRepoOwner = "" // to track the owner of the github repository

def AVAILABLE_NAMESPACES = ciEnvsHelper.fetchCIEnvs()
pipelineHelper.cancelPreviousRunningBuilds()

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: ephemeral-ci-run
    netnolimit: "yes"
  annotations:
    karpenter.sh/do-not-evict: true
    "cluster-autoscaler.kubernetes.io/safe-to-evict": "false"
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: eks.amazonaws.com/capacityType
            operator: In
            values:
            - ONDEMAND
        - matchExpressions:
          - key: karpenter.sh/capacity-type
            operator: In
            values:
            - on-demand
  initContainers:
  - name: wait-for-jenkins-connection
    image: quay.io/cdis/gen3-ci-worker:master
    command: ["/bin/sh","-c"]
    args: ["while [ $(curl -sw '%{http_code}' http://jenkins-master-service:8080/tcpSlaveAgentListener/ -o /dev/null) -ne 200 ]; do sleep 5; echo 'Waiting for jenkins connection ...'; done"]
  containers:
  - name: jnlp
    command: ["/bin/sh","-c"]
    args: ["sleep 30; /usr/local/bin/jenkins-agent"]
    resources:
      requests:
        cpu: 500m
        memory: 500Mi
        ephemeral-storage: 500Mi
  - name: selenium
    image: selenium/standalone-chrome:112.0
    imagePullPolicy: Always
    ports:
    - containerPort: 4444
    readinessProbe:
      httpGet:
        path: /status
        port: 4444
      timeoutSeconds: 60
    resources:
      requests:
        cpu: 500m
        memory: 500Mi
        ephemeral-storage: 500Mi
  - name: shell
    image: quay.io/cdis/gen3-ci-worker:master
    imagePullPolicy: Always
    command:
    - sleep
    args:
    - infinity
    resources:
      requests:
        cpu: 0.2
        memory: 400Mi
        ephemeral-storage: 1Gi
    env:
    - name: AWS_DEFAULT_REGION
      value: us-east-1
    - name: JAVA_OPTS
      value: "-Xmx3072m"
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: jenkins-secret
          key: aws_access_key_id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: jenkins-secret
          key: aws_secret_access_key
    - name: GOOGLE_APP_CREDS_JSON
      valueFrom:
        secretKeyRef:
          name: jenkins-g3auto
          key: google_app_creds.json
    volumeMounts:
    - name: "cert-volume"
      readOnly: true
      mountPath: "/mnt/ssl/service.crt"
      subPath: "service.crt"
    - name: "cert-volume"
      readOnly: true
      mountPath: "/mnt/ssl/service.key"
      subPath: "service.key"
    - name: "ca-volume"
      readOnly: true
      mountPath: "/usr/local/share/ca-certificates/cdis/cdis-ca.crt"
      subPath: "ca.pem"
    - name: dockersock
      mountPath: "/var/run/docker.sock"
  serviceAccount: jenkins-service
  serviceAccountName: jenkins-service
  volumes:
  - name: cert-volume
    secret:
      secretName: "cert-jenkins-service"
  - name: ca-volume
    secret:
      secretName: "service-ca"
  - name: dockersock
    hostPath:
      path: /var/run/docker.sock
'''
        defaultContainer 'shell'
        }
    }

    stages {
        stage('CleanWorkspace') {
            steps {
                script {
                    try {
	                cleanWs()
	            } catch (e) {
	                pipelineHelper.handleError(ex)
	            }
	        }
	    }
        }

        stage('FetchCode') {
            steps {
	        script {
		    try {
		        gitHelper.fetchAllRepos(pipeConfig['currentRepoName'])
		    } catch (e) {
		        pipelineHelper.handleError(ex)
		    }
	        }
	    }
        }

        stage('CheckPRLabels') {
	    steps {
	        script {
		    try {
		        // if the changes are doc-only, automatically skip the tests
		        doNotRunTests = doNotRunTests || docOnlyHelper.checkTestSkippingCriteria()

		        // prLabels are added to the config map in vars/testPipeline.groovy
		        for(label in config.prLabels) {
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
                                case "parallel-testing":
         			    println('Run labelled test suites in parallel')
         			    runParallelTests = true
         			    break
         		        case "gen3-release":
         			    println('Enable additional tests and automation')
         			    isGen3Release = "true"
         			    break
         		        case "debug":
         			    println("Call npm test with --debug")
         			    println("leverage CodecepJS feature require('codeceptjs').output.debug feature")
         			    break
         		        case "not-ready-for-ci":
         			    currentBuild.result = 'ABORTED'
         			    error('This PR is not ready for CI yet, aborting...')
         			    break
         		        case ~/^jenkins-.*/:
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
                        pipelineHelper.handleError(ex)
         	    }
         	    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
	        }
            }
        }

        stage('gen3 helper test suite') {
            steps {
                script {
                    try {
                        println("namespaces: ${namespaces}")
                        if(!skipUnitTests) {
                            sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome bash cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('gen3 helper test suite with zsh') {
            steps {
                script {
                    try {
                        if(!skipUnitTests) {
                             sh 'GEN3_HOME=$WORKSPACE/cloud-automation XDG_DATA_HOME=$WORKSPACE/dataHome zsh cloud-automation/gen3/bin/testsuite.sh --profile jenkins'
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('pytest') {
            steps {
                script {
                    try {
                        if(!skipUnitTests) {
                            sh '/usr/bin/pip3 install boto3 --upgrade --user'
                            sh '/usr/bin/pip3 install kubernetes --upgrade --user'
                            sh 'python3 -m pytest cloud-automation/apis_configs/'
                            sh 'python3 -m pytest cloud-automation/gen3/lib/dcf/'
                            sh 'cd cloud-automation/tf_files/aws/modules/common-logging && python3 -m pytest testLambda.py'
                            sh 'cd cloud-automation/files/lambda && python3 -m pytest test-security_alerts.py'
                            sh 'cd cloud-automation/kube/services/jupyterhub && python3 -m pytest test-jupyterhub_config.py'
                            sh 'bash cloud-automation/files/scripts/es-secgroup-sync.sh test'
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('nginx helper test suite') {
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('python 2 base image dockerrun.sh test') {
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('python 3 legacy alpine base image dockerrun.sh test') {
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('python 3.6 buster base image dockerrun.sh test') {
            steps {
                script {
                    try {
                        if(!skipUnitTests) {
                            dir('cloud-automation/Docker/python-nginx/python3.6-buster') {
                                sh 'sh dockerrun.sh --dryrun=True'
                            }
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('python 3.9 buster base image dockerrun.sh test') {
            steps {
                script {
                    try {
                        if(!skipUnitTests) {
                            dir('cloud-automation/Docker/python-nginx/python3.9-buster') {
                                sh 'sh dockerrun.sh --dryrun=True'
                            }
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('python 3.10 buster base image dockerrun.sh test') {
            steps {
                script {
                    try {
                        if(!skipUnitTests) {
                            dir('cloud-automation/Docker/python-nginx/python3.10-buster') {
                                sh 'sh dockerrun.sh --dryrun=True'
                            }
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('WaitForQuayBuild') {
	    options {
                timeout(time: 30, unit: 'MINUTES')   // timeout on this stage
            }
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('SelectNamespace') {
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            (kubectlNamespace, lock) = kubeHelper.selectAndLockNamespace(pipeConfig['UID'], namespaces)
                            kubeLocks << lock
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${kubectlNamespace}"
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('ModifyManifest') {
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('K8sReset') {
	    options {
                timeout(time: 1, unit: 'HOURS')   // timeout on this stage
            }
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            // adding the reset-lock lock in case reset fails before unlocking
                            kubeLocks << kubeHelper.newKubeLock(kubectlNamespace, "gen3-reset", "reset-lock")
                            kubeHelper.reset(kubectlNamespace)
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        // ignore aborted pipelines (not a failure, just some subsequent commit that initiated a new build)
                        if (ex.getClass().getCanonicalName() != "hudson.AbortException" &&
                        ex.getClass().getCanonicalName() != "org.jenkinsci.plugins.workflow.steps.FlowInterruptedException") {
                            metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                            kubeHelper.sendSlackNotification(kubectlNamespace, "false")
                            kubeHelper.saveLogs(kubectlNamespace)
                        }
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('VerifyClusterHealth') {
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            kubeHelper.waitForPods(kubectlNamespace)
                            testHelper.checkPodHealth(kubectlNamespace, "")
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                   }
                   metricsHelper.writeMetricWithResult(STAGE_NAME, true)
               }
           }
        }


        stage('GenerateData') {
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            testHelper.simulateData(kubectlNamespace)
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('FetchDataClient') {
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            testHelper.fetchDataClient("master")
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('RunTests') {
	    options {
                timeout(time: 3, unit: 'HOURS')   // timeout on this stage
            }
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            testHelper.soonToBeLegacyRunIntegrationTests(
                                kubectlNamespace,
                                pipeConfig.serviceTesting.name,
                                testedEnv,
                                isGen3Release,
                                isNightlyBuild,
                                listOfSelectedTests
                            )
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('CleanS3') {
            steps {
                script {
                    try {
                        if(!doNotRunTests) {
                            testHelper.cleanS3(kubectlNamespace)
                        } else {
                            Utils.markStageSkippedForConditional(STAGE_NAME)
                        }
                    } catch (ex) {
                        metricsHelper.writeMetricWithResult(STAGE_NAME, false)
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }

        stage('authzTest') {
            steps {
                script {
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
                        pipelineHelper.handleError(ex)
                    }
                    metricsHelper.writeMetricWithResult(STAGE_NAME, true)
                }
            }
        }
    }
    post {
        always {
            script {
                kubeHelper.teardown(kubeLocks)
                testHelper.teardown(doNotRunTests)
                pipelineHelper.teardown(currentBuild.result)
                if(!skipUnitTests) {
                    // tear down network policies deployed by the tests
                    kubeHelper.kube(kubectlNamespace, {
                        sh(script: 'kubectl --namespace="' + kubectlNamespace + '" delete networkpolicies --all', returnStatus: true);
                    });
                }
            }
        }
    }
}

