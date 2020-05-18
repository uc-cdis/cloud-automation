# TL;DR
Configure continuous integration (test, build, deploy) of a Gen3 dictionary with Travis CI.
## Prerequisites
* Public dictionary repository (e.g. [bioteam/dictionaryutils](https://github.com/bioteam/dictionaryutils.git))
* Public S3 bucket ([how-to](https://www.simplified.guide/aws/create-public-s3-bucket))
* Travis CI account ([sign up free for public repos](https://travis-ci.com/))
* Development Environment ([for Mac](#development-environment))
## Configure Dictionary
### Clone dictionary repository
```bash
git clone https://github.com/bioteam/dictionaryutils.git
cd dictionaryutils
python setup.py develop
```
### Create IAM Policy for travis-ci user
From within the AWS console, create an IAM policy e.g. *travis-ci-policy* granting access to **only** your public bucket.
```bash
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::bms-gen3-dev"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::bms-gen3-dev/*"
        }
    ]
}
```
### Create IAM user for travis-ci
From within the AWS console, create an IAM user e.g. *travis-ci* with `Programmatic access`, adding the above inline policy.
### Modify travis.yml
```bash
access_key_id: <Travis_AWS_Access_Key_ID>
...
bucket: <your-public-s3-bucket>
...
upload-dir: <folder-within-s3-bucket>/$TRAVIS_BRANCH
...
repo: <your-git-org/your-public-repo>
```
### Encrypt AWS Secret Access Key
```bash
travis login
# Username: <github_user@example.com>
# Password for <github_user@example.com>: ***************
travis encrypt <travis_aws_secret_access_key> --add deploy.secret_access_key
```
### Development Cycle
1. Modify `gdcdictionary/schemas/*.yaml`
2. Test (iterate until tests pass)
3. Commit
4. Tag
5. Push
6. Observe
7. Verify
```bash
testdict
git commit -am "tagged release 1.0.0"
git tag -a 1.0.0
git push origin master --follow-tags
open https://travis-ci.com/github/bioteam/dictionaryutils
open https://bms-gen3-dev.s3.amazonaws.com/datadictionary/1.0.0/schema.json
```

## Development Environment
### Install CLI tools
```bash
xcode-select --install
```
### Install homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```
### Install python 3.6
```bash
brew install pyenv
pyenv install 3.6.10
echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.zshrc
```
### Install travis
```bash
brew install travis
```
### Install Docker ([Mac](https://hub.docker.com/editions/community/docker-ce-desktop-mac/))
### Install tesdict
```bash
echo -e '\ntestdict() { docker run --rm -v $(pwd):/dictionary quay.io/cdis/dictionaryutils:master; }\n' >> ~/.zshrc
```
