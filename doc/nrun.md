# TL;DR

Helper for installing and running nodejs scripts under gen3.
Add modules to the gen3 repo like this:
```
(
  cd cloud-automation
  npm install your-module --save
  git add package*.json
  git commit -m 'adding my module, baby!'
)
```

## Use

* `gen3 nrun your command`

Ex:
```
gen3 nrun elasticdump --help
```

Note: this is similar to:
```
gen3 arun ${GEN3_HOME}/node_modules/.bin/elasticdump --help
```

* `gen3 nrun install`

Shortcut for 
```
(
  cd $GEN3_HOME && npm install
)
```
