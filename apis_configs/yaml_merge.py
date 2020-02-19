'''
Little helper that merges a couple input yaml files,
and spits out the output to stdout.
Gets inlined into fence-deploy.yaml to merge
public and private config files.

Use: python yaml_merge.py a.yaml b.yaml

Overrides b.yaml keys with values from a.yaml
pip install -u json
pip install -u yaml

See gen3/test/yamlMergeTest.sh - gen3 testsuite --filter yamlMerge

'''

import sys
import json
from yaml import safe_load as yaml_load

config1 = yaml_load(open(sys.argv[1]))
config2 = yaml_load(open(sys.argv[2]))

if config1 != None:
  for key in config1.keys():
    config2[key] = config1[key]

print(json.dumps(config2, indent=2))
