import json
import yaml
import os
import pathlib
import base64
import argparse
import boto3
import botocore
import subprocess
import sys
from copy import deepcopy
from pathlib import Path

SECRETS_MANAGER_CLIENT = None

def find_manifest_path():
    # Check if environment variable is set
    env_path = os.environ.get('GEN3_MANIFEST_HOME')
    if env_path:
        return env_path
    
    # Check if ~/cdis-manifest exists and is a directory
    home_dir = pathlib.Path.home()
    manifest_path = home_dir / 'cdis-manifest'
    if manifest_path.exists() and manifest_path.is_dir():
        return str(manifest_path)
    
    # Ask user for path if neither option is available
    user_path = input("Could not find cdis-manifest. Please provide a path to a local copy: ")
    return user_path

def find_manifest_hostname(manifest_path):
    # Check if ~/Gen3Secrets/00configmap.yaml exists
    home_dir = pathlib.Path.home()
    config_path = home_dir / 'Gen3Secrets' / '00configmap.yaml'
    
    if config_path.exists():
        try:
            with open(config_path, 'r') as config_file:
                config_data = yaml.safe_load(config_file)
                if config_data and 'hostname' in config_data["data"]:
                    return config_data["data"]['hostname']
        except Exception as e:
            print(f"Error reading config file: {e}")
    
    # If we get here, either file doesn't exist or hostname wasn't found
    # List directories in manifest_path
    try:
        directories = [d for d in os.listdir(manifest_path) 
                      if os.path.isdir(os.path.join(manifest_path, d))]
        
        if not directories:
            return None
        
        print("Available environments:")
        for i, directory in enumerate(directories, 1):
            print(f"{i}. {directory}")
        
        # Ask user to select
        while True:
            try:
                selection = int(input("Please select an environment (enter number): "))
                if 1 <= selection <= len(directories):
                    return directories[selection-1]
                else:
                    print(f"Please enter a number between 1 and {len(directories)}")
            except ValueError:
                print("Please enter a valid number")
    except Exception as e:
        print(f"Error listing directories in {manifest_path}: {e}")
        return None

def output(final_output, print_flag=False, filename="values.yaml"):
  if print_flag:
    print(yaml.dump(final_output))
  else:
    with open(filename, 'w') as file:
      file.write(yaml.dump(final_output))

def read_manifest(manifest_path):
  try:
    with open(f"{manifest_path}/manifest.json", 'r') as file:
      data = json.load(file)
    return data
  except FileNotFoundError:
    print("Error: manifest.json file not found!")
    exit(1)
  except json.JSONDecodeError:
    print("Error: Failed to decode JSON.")
    exit(1)

def read_manifest_data(manifest_json_data, manifest_path, service_name):
    result = {}
    
    # Step 1: Check if service_name exists as a key in manifest_json_data
    if service_name in manifest_json_data:
        result = deepcopy(manifest_json_data[service_name])
    
    # Step 2: Check if service_name is a directory in manifest_path/manifests
    service_dir_path = os.path.join(manifest_path, "manifests", service_name)
    if os.path.isdir(service_dir_path):
        service_json_path = os.path.join(service_dir_path, f"{service_name}.json")
        if os.path.exists(service_json_path):
            try:
                with open(service_json_path, 'r') as file:
                    service_data = json.load(file)
                    
                    # Step 3: Merge the results
                    # If result is empty, just use service_data
                    if not result:
                        result = service_data
                    # Otherwise merge service_data into result
                    else:
                        for key, value in service_data.items():
                            result[key] = value
            except json.JSONDecodeError as e:
                print(f"Error parsing {service_json_path}: {e}")
            except Exception as e:
                print(f"Error reading {service_json_path}: {e}")
    
    return result

def read_base64_data(img_path):
  if os.path.exists(img_path):
    with open(img_path, 'rb') as file:
      binary = file.read()

      return base64.b64encode(binary).decode("utf-8")
  else:
    return None

def read_scaling_data(manifest_path, manifest_data):
  return read_manifest_data(manifest_data, manifest_path, "scaling")

def split_version_statement(version_statement):
  # Expects an argument like: quay.io/datawire/ambassador:1.4.2, which we can split up into it's component parts
  # and return. This is based on the string format, so while it is fragile, we can assume that all the input data
  # has these version statements set correctly, since they're already in prod
  last_slash = version_statement.rfind('/')
  first_colon = version_statement.find(':')

  # Handle case when no slash or colon exists
  if last_slash == -1 or first_colon == -1:
      return None, None, None
  
  repo = version_statement[:first_colon]
  tag = version_statement[first_colon + 1::]

  return repo, tag

def to_camel_case(s):
  # Split the string by underscores and capitalize the first letter of each word except the first one
  parts = s.split('_')
  return parts[0] + ''.join(word.capitalize() for word in parts[1:])

def template_global_section(manifest_data):
  # These are keys that have a directly corresponding value in values.yaml that we need to translate by converting 
  # to camel case
  DIRECT_TRANSLATE_KEYS = [
    "environment", 
    "hostname", 
    "revproxy_arn", 
    "dictionary_url", 
    "dispatcher_job_num",
    "portal_app",
    "frontend_root"
    ]
  
  # These are keys that we do not want to move over, since they don't apply to gen3-helm for whatever reason
  # If a key is not in this, or in DIRECT_TRANSLATE_KEYS, it goes into `manifestGlobalExtraValues` under 
  # its original name
  DEPRECATED_KEYS = [
    "argocd",
    "waf_enabled",
    "pdb",
    "karpenter"
  ]
  # Check if the 'global' section exists in the dictionary
  if "global" in manifest_data:
    global_data = manifest_data["global"]
    global_yaml_data = {"manifestGlobalExtraValues": {}, "dev": False, "postgres": {"dbCreate": False}, "externalSecrets": {"deploy": True}}

    for key in global_data:
      if key in DIRECT_TRANSLATE_KEYS:
        global_yaml_data[to_camel_case(key)] = global_data[key]
      elif key == "netpolicy":
        if global_data[key] == "on":
          global_yaml_data["netPolicy"] = {"enabled": True}
      elif key not in DEPRECATED_KEYS:
        global_yaml_data["manifestGlobalExtraValues"][key] = global_data[key]

    return {"global": global_yaml_data}

  else:
    print("The 'global' section is not found in the provided data.")
    exit(1)

def template_guppy_section(manifest_data, manifest_path):
    guppy_data = read_manifest_data(manifest_data, manifest_path, "guppy")
    guppy_yaml_data = {}

    for key in guppy_data:
      guppy_yaml_data[to_camel_case(key)] = guppy_data[key]

    return {"guppy": guppy_yaml_data}

def template_metdata_section(manifest_data, manifest_path):
  metadata_data = read_manifest_data(manifest_data, manifest_path, "metadata")
  metadata_yaml_data = {}

  if "USE_AGG_MDS" in metadata_data.keys():
    metadata_yaml_data["useAggMds"] = manifest_data["USE_AGG_MDS"]
  if "AGG_MDS_NAMESPACE" in metadata_data.keys():
    metadata_yaml_data["addMdsNamespace"] = manifest_data["AGG_MDS_NAMESPACE"]
  
  return { "metadata": metadata_yaml_data }

def template_portal_section(manifest_data, manifest_path):
  portal_data = read_manifest_data(manifest_data, manifest_path, "portal")
  portal_yaml_data = {"gitops": {}}

  if "GEN3_BUNDLE" in portal_data.keys():
     portal_yaml_data["gitops"]["gen3Bundle"] = portal_data["GEN3_BUNDLE"]

  # This is where we make our money converting portal
  portal_manifest_path = f"{manifest_path}/portal"

  gitops_json_path = f"{portal_manifest_path}/gitops.json" 
  if os.path.exists(gitops_json_path):
     with open(gitops_json_path, 'r') as gitops:
        gitops_json_string = gitops.read()

        portal_yaml_data["gitops"]["json"] = gitops_json_string

  gitops_css_path = f"{portal_manifest_path}/gitops.css" 
  if os.path.exists(gitops_css_path):
     with open(gitops_css_path, 'r') as gitops:
        gitops_css_string = gitops.read()

        portal_yaml_data["gitops"]["css"] = gitops_css_string

  gitops_favicon_path = f"{portal_manifest_path}/gitops-favicon.ico" 
  gitops_favicon_b64 = read_base64_data(gitops_favicon_path)
  if gitops_favicon_b64 is not None:
    portal_yaml_data["gitops"]["favicon"] = gitops_favicon_b64

      
  gitops_logo_path = f"{portal_manifest_path}/gitops-logo.png" 
  gitops_logo_b64 = read_base64_data(gitops_logo_path)
  if gitops_logo_b64 is not None:
    portal_yaml_data["gitops"]["logo"] = gitops_logo_b64

  gitops_createdby_path = f"{portal_manifest_path}/gitops-createdby.png" 
  gitops_createdby_b64 = read_base64_data(gitops_createdby_path)
  if gitops_createdby_b64 is not None:
    portal_yaml_data["gitops"]["createdby"] = gitops_createdby_b64

  gitops_sponsors_path = f"{portal_manifest_path}/gitops-sponsors"
  if os.path.exists(gitops_sponsors_path) and os.path.isdir(gitops_sponsors_path):
    files = []

    for f in os.listdir(gitops_sponsors_path):
      if os.path.isfile(os.path.join(gitops_sponsors_path, f)):
         files.append(os.path.join(gitops_sponsors_path, f))
    
    files_b64 = []

    for file in files:
      files_b64.append(read_base64_data(file))

    portal_yaml_data["gitops"]["sponsors"] = files_b64

  return {"portal": portal_yaml_data}

def template_sower_section(manifest_data, manifest_path):
  sower_data = read_manifest_data(manifest_data, manifest_path, "sower")
  sower_yaml_data = {}

  if sower_data != {}:
    sower_yaml_data["sowerConfig"] = sower_data

  return sower_yaml_data

def template_ssjdispatcher_section(manifest_data, manifest_path):
  ssjdispatcher_data = read_manifest_data(manifest_data, manifest_path, "ssjdispatcher")
  ssjdispatcher_yaml_data = {}

  if ssjdispatcher_data != {}:
    ssjdispatcher_yaml_data["indexing"] = ssjdispatcher_data["job_images"]["indexing"]

  return ssjdispatcher_yaml_data
  
def template_versions_section(manifest_data, scaling_data):
  versions_data = manifest_data["versions"]

  versions_yaml_data = {}

  for key in versions_data:
    repo, tag = split_version_statement(versions_data[key])

    versions_yaml_data[key] = {
      "enabled": True,
      "image": {
        "repository": repo,
        "tag": tag
      }
    }

    if key in scaling_data.keys():
      service_scaling_data = scaling_data[key]
      if service_scaling_data["strategy"] == "pin":
        versions_yaml_data[key]["replicas"] = service_scaling_data["num"]
      elif service_scaling_data["strategy"] == "auto":
        versions_yaml_data[key]["autoscaling"] = {}
        versions_yaml_data[key]["autoscaling"]["enabled"] = True
        versions_yaml_data[key]["autoscaling"]["minReplicas"] = service_scaling_data["min"]
        versions_yaml_data[key]["autoscaling"]["maxReplicas"] = service_scaling_data["max"]
        if "targetCpu" in service_scaling_data.keys():
          versions_yaml_data[key]["autoscaling"]["targetCPUUtilizationPercentage"] = service_scaling_data["targetCpu"]
        else:
          versions_yaml_data[key]["autoscaling"]["targetCPUUtilizationPercentage"] = 40

  return versions_yaml_data

def merge_service_section(final_output, yaml_data, service_name):
  if yaml_data != {}:
    if service_name in final_output.keys():
      final_output[service_name] = {**final_output[service_name], **yaml_data}
    else:
      final_output[service_name] = yaml_data[service_name]
  return final_output

def translate_manifest(manifest_path):
  manifest = read_manifest(manifest_path)
  scaling_data = read_scaling_data(manifest_path, manifest)

  global_yaml_data = template_global_section(manifest)
  versions_yaml_data = template_versions_section(manifest, scaling_data)

  guppy_yaml_data = template_guppy_section(manifest, manifest_path)
  portal_yaml_data = template_portal_section(manifest, manifest_path)
  ssjdispatcher_yaml_data = template_ssjdispatcher_section(manifest, manifest_path)
  sower_yaml_data = template_sower_section(manifest, manifest_path)

  final_output = {**global_yaml_data, **versions_yaml_data}

  final_output = merge_service_section(final_output, guppy_yaml_data, "guppy")
  final_output = merge_service_section(final_output, portal_yaml_data, "portal")
  final_output = merge_service_section(final_output, sower_yaml_data, "sower")
  final_output = merge_service_section(final_output, ssjdispatcher_yaml_data, "ssjdispatcher")

  return final_output

def process_g3auto_secrets(gen3_secrets_path: str):
  G3AUTO_PATH = os.path.join(gen3_secrets_path, "g3auto")

  if not os.path.exists(G3AUTO_PATH):
    print(f"G3AUTO_PATH directory does not exist: {G3AUTO_PATH}")
    sys.exit(1)

  # Get all items in the directory
  all_items = os.listdir(G3AUTO_PATH)

  # Filter only directories
  directories = [item for item in all_items if os.path.isdir(os.path.join(G3AUTO_PATH, item))]

  for dir in directories:
    if dir == "requestor":
      return
    elif dir == "metadata":
      return
    #... etc, etc
    else:
      print(f"Don't know what to do with {dir}, so just skipping it.")

# Dear god, is this fragile. We're all but locked into running on admin VMs (which is fine)
def get_commons_name():
  commons_name = subprocess.run("kubectl config view --minify | yq .contexts[0].context.namespace | tr -d '\"'", 
                                shell=True, stdout=open(os.devnull, 'wb')).stdout
  if commons_name == "default":
     commons_name = subprocess.run("kubectl get configmap global -o yaml | yq .data.environment | tr -d '\"'", 
                                   shell=True, stdout=open(os.devnull, 'wb')).stdout
     print(f"Why?: {commons_name}")

  return commons_name

def translate_secrets():
  home = Path.home()
  GEN3_SECRETS_FOLDER = os.path.join(home, "Gen3Secrets")

  commons_name = get_commons_name()

  print(commons_name)
  exit(1)

  creds_data = read_creds_file(GEN3_SECRETS_FOLDER)

  if creds_data is not None:
    for key in creds_data.keys():
      if key in ["fence", "indexd"]:
        # TODO we have to fix the hardcoding on that, we should be able to read the environment somehow
        upload_secret(f"{commons_name}-{key}-db-creds", json.dumps(creds_data[key]))

  process_g3auto_secrets(GEN3_SECRETS_FOLDER)

def upload_secret(secret_name: str, secret_data: str, description: str = "A secret for Gen3" ):
  '''
  Given the name of a secret and a string containing the secret's data, uploads it as a plain-text secret to AWS
  '''
  global SECRETS_MANAGER_CLIENT

  if SECRETS_MANAGER_CLIENT is None:
     SECRETS_MANAGER_CLIENT = boto3.client('secretsmanager')

  try:
    response = SECRETS_MANAGER_CLIENT.create_secret(
      Name = secret_name,
      SecretString = secret_data,
      Description = description,
      ForceOverwriteReplicaSecret = True
    )
  except SECRETS_MANAGER_CLIENT.exceptions.ResourceExistsException:
    response = SECRETS_MANAGER_CLIENT.update_secret(
      SecretId = secret_name,
      Description = description,
      SecretString = secret_data   
    )
     

def read_creds_file(gen3_secrets_path: str):
  creds_file_path = os.path.join(gen3_secrets_path, "creds.json")
  
  # Check if the file exists
  if os.path.isfile(creds_file_path):
      # Read and parse the JSON file
      with open(creds_file_path, 'r') as file:
          creds_data = json.load(file)
      return creds_data
  else:
      return None
  

def main():
  parser = argparse.ArgumentParser(description='Process manifest data')
  parser.add_argument('--print', action='store_true', 
                      help='Set print flag to true')
  parser.add_argument('--filename', type=str, default=None,
                      help='Specify a filename (defaults to manifest-hostname if not provided)')
  
  args = parser.parse_args()
  
  manifest_path = find_manifest_path()
  manifest_hostname = find_manifest_hostname(manifest_path)

  # Set variables based on args
  print_flag = args.print
  filename = args.filename if args.filename else f"{manifest_hostname}-values.yaml"
  
  full_manifest_path = f"{manifest_path}/{manifest_hostname}"

  manifest_output = translate_manifest(full_manifest_path)

  translate_secrets()

  #output(manifest_output, print_flag=print_flag, filename=filename)

main()