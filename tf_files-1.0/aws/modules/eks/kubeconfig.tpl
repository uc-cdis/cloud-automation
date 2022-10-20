apiVersion: v1
clusters:
- cluster:
    server: ${eks_endpoint}
    certificate-authority-data: ${eks_cert}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws-${vpc_name}
current-context: aws-${vpc_name}
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${eks_name}"
        #- "-r"
        #- "<role ARN>"
      #env:
        #- name: AWS_PROFILE
        #  value: "<profile>"
