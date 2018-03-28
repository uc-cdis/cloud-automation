#!groovy

pipeline {
  agent any

  stages {
    stage('FetchCode'){
      steps {
        checkout scm
        sh '/bin/rm -rf Secrets SecretsNoPlan dataHome'
        dir('Secrets') {
            sh 'aws s3 cp s3://cdis-terraform-state/planx-pla.net/v1/config.tfvars config.tfvars'
            sh 'aws s3 cp s3://cdis-terraform-state/planx-pla.net/v1/backend.tfvars backend.tfvars'
        }
      }
    }
    stage('Prep') {
      steps {
        dir('Secrets') {
          sh 'terraform init -backend-config access_key=$AWS_ACCESS_KEY_ID -backend-config secret_key=$AWS_SECRET_ACCESS_KEY -backend-config backend.tfvars ../tf_files/aws'
        }
        dir('SecretsNoPlan') {
          sh 'cp ../Secrets/*.tfvars .'
          sh 'echo \'key = "noplan/terraform.tfstate"\' > noplan.tfvars'
          sh 'terraform init -backend-config access_key=$AWS_ACCESS_KEY_ID -backend-config secret_key=$AWS_SECRET_ACCESS_KEY -backend-config backend.tfvars --backend-config noplan.tfvars ../tf_files/aws'
        }
      }
    }
    stage('Plan - no state') {
      steps {
        dir('SecretsNoPlan') {
          echo 'Planning - no state ...'
          sh 'terraform plan --var aws_access_key=$AWS_ACCESS_KEY_ID --var aws_secret_key=$AWS_SECRET_ACCESS_KEY --var-file config.tfvars ../tf_files/aws'
        }
      }
    }
    stage('Plan planx-pla.net/v1 state') {
      steps {
        dir('Secrets') {
          echo 'Planning ...'
          sh 'terraform plan --var aws_access_key=$AWS_ACCESS_KEY_ID --var aws_secret_key=$AWS_SECRET_ACCESS_KEY --var-file config.tfvars -out plan.terraform ../tf_files/aws'
        }
      }
    }
    stage('gen3 helper test suite') {
      steps {
        sh 'GEN3_HOME=$WORKSPACE XDG_DATA_HOME=$WORKSPACE/dataHome bash gen3/bin/testsuite.sh --profile jenkins'
      }
    }
    stage('lamda test') {
      steps {
        sh 'pip3 install boto3 --upgrade'
        sh 'cd tf_files/modules/cdis-aws-common-logging && python3 -m pytest testLambda.py'
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
  }
}
