This Dockerfile was created to run Chef Inspec test using Centos7 image. 
There is a profile directory that has all the test to run the audit, which are underneath the controls directory.
There is a bash script that is used to execute the test using the profile name. That information would need to be updated for your environment 

You can build this Docker Image Inspec test will executes jus as long as the correct credentials are granted for the pod either with an IAM role or Kubernetes Secret with the 
