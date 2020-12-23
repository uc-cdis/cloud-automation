default["adminvm"]["devUsers"] = []

default["adminvm"]["qaUsers"] = []

default["adminvm"]["adminUsers"] = []

default["adminvm"]["aptPackages"] = ["git", "jq", "pwgen", "python-dev", "python-pip", "unzip", "python3-dev", "python3-pip", "nodejs","postgresql-client-9.6", "google-cloud-sdk", "google-cloud-sdk-cbt", "kubectl"]

default["adminvm"]["pythonPackages"] = ["awscli", "jinja2", "yq"]

default["adminvm"]["aptRepos"] = {
  "cloud-sdk-bionic": {
    "repo": "http://packages.cloud.google.com/apt/", 
    "keyserver": "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
  },
  "bionic-pgdg": {
    "repo": "http://apt.postgresql.org/pub/repos/apt/",
    "keyserver": "https://www.postgresql.org/media/keys/ACCC4CF8.asc"
  }
}

default["adminvm"]["remotePackages"] = {
  "terraform": {
    "repo": "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz",
    "fileName": "helm.tar.gz",
    "exName": "helm"
  },
  "terraform12": {
    "repo": "https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip",
    "fileName": "terraform12.zip"
  },
  "packer": {
    "repo": "https://releases.hashicorp.com/packer/1.2.1/packer_1.2.1_linux_amd64.zip",
    "fileName": "packer.zip"
  },
  "heptio-authenticator-aws": {
    "repo": "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.3.0/heptio-authenticator-aws_0.3.0_linux_amd64"
  },
  "helm": {
    "repo": "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz",
    "fileName": "helm.tar.gz"
  }
}