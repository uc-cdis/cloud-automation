# TL;DR

Build CTDS Jenkins image

## Notes

* The build context should be the root of the repo, so:

```
docker build -t jenkins:reuben -f ./Dockerfile ../../
```

* Periodically update the base image with the latest tagged release from https://hub.docker.com/r/jenkins/jenkins
