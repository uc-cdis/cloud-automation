"""

lambda_function.py  is a script file destinated to be executed by AWS lambda service as a cron job.
  The idea is to check if the proxy is working and if not, the swict to the failover.

  Data comes in likes the following, or at least it is what the 'event' argument should look like:

  {
    "domain_test": "www.google.com",
    "proxy_port": 3128
  }

  If the contend of the even is null, then the variables are assumed as when in the handler is specified.

  @return: A Dictionary if there was a fail over, nothing otherwise

  @author: Fauzi Gomez
  @email:  fauzi@uchicago.edu

"""

import json
import boto3
import os
import random
import urllib.request
import urllib.parse
import socket
import http.client


outcome = {}

"""
  function to get autoscaling groups

  @var String name [Optional]: the name of the autoscaling group you want.

  @return Dictionary containing the ASG looked up, them all if the variable is omited
"""
def get_asg(name=None):
    client = boto3.client('autoscaling')
    if name != None and os.environ.get('vpc_name') != None:
        ASG = client.describe_auto_scaling_groups(AutoScalingGroupNames=[name])['AutoScalingGroups']
        del client
    else:
        ASG = client.describe_auto_scaling_groups()['AutoScalingGroups']
        del client
    return ASG
    
"""
  function to get the vpc_id of a specific instance

  @var list instance_info should contain the output of the function get_instances_info

  @return String the vpc id of the instance in question
"""
def get_instance_vpc_id(instance_info):
    for reservation in instance_info['Reservations']:
        for instance in reservation['Instances']:
            return instance['VpcId']

"""
  funtion to ge the instances id of an autoscaling group

  @var list autoscaling_group  autoscaling groups from the function get_asg

  @return list with the list of instances id found
"""
def get_instances_id(autoscaling_group):
    ids_list = []
    for instances in autoscaling_group:
        for instance in instances['Instances']:
            ids_list.append(instance['InstanceId'])
    return ids_list
  
"""
  function to get a list of instances with a "Healthy" status according to an autoscaling group

  @var list autoscaling_group  autoscaling groups from the function get_asg

  @return list containing the ids of the healthy instances
"""
def get_healthy_instances_id(autoscaling_group):
    ids_list = []
    for instances in autoscaling_group:
        for instance in instances['Instances']:
            if instance['HealthStatus'] == "Healthy":
                ids_list.append(instance['InstanceId'])
    return ids_list

"""
  function to get status of instances according to hte instance information

  @var list id_list list with the instances id you want to know the status

  @return list status of the instances in question
"""
def get_instances_status(id_list):
    client = boto3.client('ec2')
    status = client.describe_instance_status(InstanceIds=id_list)
    del client
    return status


"""
  function to get an instance information based on a ENI id
  
  @var string ENI the eni id
  
  @returm dictionary with the result of describe_instances
"""
def get_instance_by_eni(eni):
    client = boto3.client('ec2')
    reservations = client.describe_instances(Filters=[{'Name':'network-interface.network-interface-id','Values': [eni]}])
    del client
    for reservation in reservations['Reservations']:
        for instance in reservation['Instances']:
            return instance
            
    #return instance['Reservations'][0]['Instances'][0]

"""
  function to get the eni ids of an instance

  @var list instances_id list with the instances id you want to know the eni ids

  @return list with the eni ids of the instances
"""
def get_instances_eni(instances_id):
    reservations = get_instances_info(instances_id)
    ni_id = []
    for reservation in reservations['Reservations']:
        for instance in reservation['Instances']:
            for network_interfaces in instance['NetworkInterfaces']:
                ni_id.append(network_interfaces['NetworkInterfaceId'])
    return ni_id

"""
  function to ge the private ip of instances

  @var list instances_id list with the instances id you want to know the eni ids

  @return list with the private ips of the instances in the variable
"""
def get_instances_priv_ip(instances_id):
    reservations = get_instances_info(instances_id)
    priv_ip = []
    for reservation in reservations['Reservations']:
        for instance in reservation['Instances']:
            priv_ip.append(instance['PrivateIpAddress'])
    return priv_ip
    
"""
  function to get the information of instances 

  @var list id_list list with the instances id you want to get the description

  @return list instances info
"""
def get_instances_info(id_list):
    client = boto3.client('ec2')
    instances = client.describe_instances(InstanceIds=id_list)
    del client
    return instances

""" 
  function to get a vpc based on an instance id

  @var String vpc_id the id of the vpc you want to get 

  @return Dict containing the vpc data
"""
# def get_vpc(vpc_id):
#     client = boto3.resource('ec2')
#     vpc = client.Vpc(vpc_id)
#     return vpc

"""
  function to get route tables information

  @var String vpc_id id of the VPC where the route belongs to
       String name name of the route in question

  @return Dict containing the information of the table
""" 
def get_route_table(vpc_id,name):
    client = boto3.client('ec2')
    route_table = client.describe_route_tables(Filters=[{'Name':'tag:Name','Values': [name]},{'Name':'vpc-id','Values':[vpc_id]}])
    del client
    return route_table

"""
  function to get the routing table id of a routing table

  @var Dict route_table expexted the value of the function get_route_table

  @return String the routing table id
"""
def get_route_table_id(route_table):
    for table in route_table['RouteTables']:
        for association in table['Associations']:
            return association['RouteTableId']
    # There should always be one single RouteTables, otherwise we only care for the first one ?
    #return route_table['RouteTables'][0]['RouteTableId']

"""
  function to request an address from the internet. The whole lambda funtion is expected to be within a single VPC and 
  associated to the same subnets where the EKS workers are to fairly simulate traffic out to the internet from the 
  workers

  @var String ulr address to attempt a request

  @return Int with the HTTP response code
"""
def test_proxy(url):
    response = ''
    try:
        """
        #url = 'https://%s' % (url)
        #f = urllib.request.urlopen(url)
        #print(f.read())
        #response = f.getcode()
        """
        
        # The only reason we don't do https on checkups  is because in the proxy only the IP is reported instead of the domain.
        # We want to know the domain this function is calling out
        # conn = http.client.HTTPSConnection(url)
        conn = http.client.HTTPConnection(url,timeout=3)
        conn.request("GET", "/")
        response = conn.getresponse().status

    except Exception as e:
        outcome['test_proxy'] = "The url '%s' check failed with the following message: '%s'" % (url,e)
        #print(e)
        if str(e) == 'HTTP Error 403: Forbidden':
            response = 403
        elif 'Connection refused' in str(e):
            # if we get <urlopen error [Errno 111] Connection refused> then we know the squid is busted or something similar
            response = 111
        else:
            # if anything else, then let's assume the current default GW is not working
            response = 112
    return response
    
"""
  function that searches for a default gateway in a defined routing table

  @var string rtid the id of the routing table to be queried

  @return Dictionary with a boto response of the request
"""
def exist_default_gw(rtid):
    client = boto3.client('ec2')
    response = client.describe_route_tables(Filters=[{'Name': 'route.destination-cidr-block','Values':['0.0.0.0/0']}],RouteTableIds=[rtid])
    del client
    return response

"""
  function to delete a default gateway of a routing table

  @var String rtid routing table id where you want the default GW deleted

  @return Int with the response of the attemp. HTTP code
"""
def del_default_gw(rtid):
    client = boto3.client('ec2')
    response = client.delete_route(DestinationCidrBlock='0.0.0.0/0',RouteTableId=rtid)
    del client
    return response
    
"""
  function to set a default route to a routing table

  @var String eni eni id that will be handing the traffic
       String rtid routing table id you want to set the default GW

  @return Int with the response of the attemp. HTTP code
"""
def set_default_gw(eni,rtid):
    client = boto3.client('ec2')
    #print(eni)

    response = exist_default_gw(rtid)
    if len(response['RouteTables']) > 0:
        response = del_default_gw(rtid)

    if response['ResponseMetadata'] and response['ResponseMetadata']['HTTPStatusCode'] == 200:
        response = client.create_route(DestinationCidrBlock='0.0.0.0/0',NetworkInterfaceId=eni,RouteTableId=rtid)
        if response['Return'] and response['ResponseMetadata']['HTTPStatusCode'] == 200:
            outcome[rtid] = "Route %s default GW successfully changed to %s" % (rtid,eni)
            #print("Route %s changed successfully" % rtid)
        else:
            outcome[eni] = response
            #print(response)
    else:
        outcome[eni] = response
        #print(response)

    del client
    return response

"""
  function to check if a port is open for an address

  @var String addr address you want to check for the port
       Int port port to check

  @return int 0 if open, something else if otherwise
"""
def check_port(addr,port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5.0)
    result = sock.connect_ex((addr, port))
    sock.close
    return result

"""
  function to get a hosted zone in route53 based on the comments

  @var String comment what you are looking for

  @return Dict with the hosted zone information
""" 
def get_hosted_zone(comment): 
     client = boto3.client('route53') 
     zones = client.list_hosted_zones() 
     del client 
     for zone in zones['HostedZones']: 
         if 'Comment' in zone['Config'] and comment in zone['Config']['Comment']:
             return zone
    
"""
  function to get the recordsets of a hosted zone

  @var String zone_id id of the zone you want the recordsets

  @return Dict with the recordsets 
"""
def get_record_sets(zone_id): 
     client = boto3.client('route53')
     record_sets = client.list_resource_record_sets(HostedZoneId=zone_id)
     del client
     return record_sets

"""
  function to determine if a recordset exist in a hosted zone

  @var list record_sets expected the value of the function get_record_sets
       String name name of the record set you are looking for

  @return Boool if it exist or not
"""
def exist_record_set(record_sets, name):
    for record_set in record_sets['ResourceRecordSets']:
        if name in record_set['Name']:
            return True
    return False


"""
  function to get a vpc base upon its name 
  
  @var string name name of the vpc you want
  
  @return dictionary with the vpc description
"""
def get_vpc(name): 
    client = boto3.client('ec2') 
    vpcs   = client.describe_vpcs(Filters=[{'Name':'tag:Name','Values':[name]}]) 
    del client
    for vpc in vpcs['Vpcs']:
        return vpc
    

"""
  function to set a recordset in a hosted zone

  @var String zone_id the zone you want the recordset created
       String name of the record you want created
       String action ["CREATE", "UPSERT", "DELETE"]
       String type type of the record ["A", "AAAA", "CNAME", ...]
       Int ttl time to live for the record
       String value where the record will point to

  @return nothing
"""
def change_resource_record_sets(zone_id,name,action,type,ttl,value):
    try:
        client = boto3.client('route53') 
        response = client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch= {
                        'Comment': '%s %s record' % (action, value),
                        'Changes': [
                            {
                             'Action': action,
                             'ResourceRecordSet': {
                                 'Name': name,
                                 'Type': type,
                                 'TTL': ttl,
                                 'ResourceRecords': [{'Value': value}]
                            }
                        }]
        })
    except Exception as e:
        print(e)
    
"""
  function to find the instance attribute sourceDestinationCheck for a single instance
           this must be set to false if we want our instance to serve as proxy and be 
           the default gateway for a specific route table

  @var string instance_id  the id of the instance we want to know the value of the attibue 

  @return boolean True or False based on the attribute value
"""
def get_sourceDestinationCheck_attr(instance_id):
    client = boto3.client('ec2')
    response = client.describe_instance_attribute(InstanceId=instance_id, Attribute='sourceDestCheck')
    del client
    return response['SourceDestCheck']['Value']

"""
  function to set the attribute sourceDestinationCheck to false for a single instance


  @var string instance_id  the id of the instance we want to know the value set to false

  @return dictionary with the execution results 
"""
def set_sourceDestinationCheck_attr(instance_id,value=False):
    client = boto3.client('ec2')
    response = client.modify_instance_attribute(InstanceId=instance_id, SourceDestCheck={'Value': value})
    del client
    return response

    
def lambda_handler(event, context):
    
    if 'domain_test' in event:
        domain = event['domain_test']
    elif os.environ.get('domain_test') is not None:
        domain = os.environ['domain_test']
    else:
        domain = 'gen3.org'
    #print(domain)
    http_code = test_proxy(domain)
    
    #print (http_code)
    
    #data = socket.gethostbyname_ex(domain)
    #print ("\n\nThe IP Address of the Domain Name is: "+repr(data))
    
    #conn = http.client.HTTPSConnection(domain)
    #conn.request("GET", "/")
    #r1 = conn.getresponse()
    #print(r1.status, r1.reason)
    
    if 'proxy_port' in event:
        proxy_port = event['proxy_port']
    elif os.environ.get('proxy_port') is not None:
        proxy_port = os.environ['proxy_port']
    else:
        proxy_port = 3128
    
    #return
    
    #internal controls
    statusCode = 200
    
    if  http_code != 200:
        
        if os.environ.get('vpc_name') is not None:
            autoscaling_group = get_asg("squid-auto-"+os.environ['vpc_name'])
            instances_ids = get_healthy_instances_id(autoscaling_group)
            
            if len(instances_ids) > 0:
                for instance_id in instances_ids:
                    instance_priv_ip = get_instances_priv_ip([instance_id])
    
                    if get_sourceDestinationCheck_attr(instance_id):
                        set_sourceDestinationCheck_attr(instance_id)
                        outcome['sourceDestinationCheck'] = "sourceDestinationCheck set to false for %s" % instance_id
                        #print("sourceDestinationCheck set to false for %s" % instance_id)
                    
                    if check_port(instance_priv_ip[0],proxy_port) == 0:
                        healthy_instance_eni = get_instances_eni([instance_id])
                        healthy_instance_priv_ip = get_instances_priv_ip([instance_id])
                        
                        vpc_id = get_instance_vpc_id(get_instances_info([instance_id]))
                        eks_private_route_table_id = get_route_table_id(get_route_table(vpc_id,'eks_private'))
                        private_kube_route_table_id = get_route_table_id(get_route_table(vpc_id,'private_kube'))
                        
                        try:
                            set_default_gw(healthy_instance_eni[0],eks_private_route_table_id)
                            outcome['eks_private'] = 'succefully changed the default route for eks_private routing table'
                            #print('succefully changed the default route for eks_private routing table')
                        except Exception as e:
                            statusCode = statusCode + 1
                            outcome['eks_private'] = e
                            #print(e)
                            
                        try:
                            set_default_gw(healthy_instance_eni[0],private_kube_route_table_id)
                            outcome['private_kube'] = 'succefully changed the default route for private_kube routing table'
                            #print('succefully changed the default route for private_kube routing table')
                        except Exception as e:
                            statusCode = statusCode + 1
                            outcome['private_kube'] = e
                            #print(e)
                            
                        zone = get_hosted_zone(os.environ['vpc_name'])
                        zone_id = zone['Id']
                        #print(zone_id)
                        record_sets = get_record_sets(zone_id)
                        
                        if exist_record_set(record_sets,'cloud-proxy'):
                            try:
                                change_resource_record_sets(zone_id,'cloud-proxy.internal.io','UPSERT','A',300,instance_priv_ip[0])
                                outcome['cloud-proxy'] = "subdomain cloud-proxy.internal.io changed for %s with ip: %s" % (zone_id,instance_priv_ip[0])
                            except Exception as e:
                                statusCode = statusCode + 1
                                outcome['cloud-proxy'] = e
                                
                            #outcome['cloud-proxy'] = "subdomain cloud-proxy.internal.io changed for %s" % zone_id
                            #print("subdomain cloud-proxy.internal.io changed for %s" % zone_id)
                        else:
                            try:
                                change_resource_record_sets(zone_id,'cloud-proxy.internal.io','CREATE','A',300,instance_priv_ip[0])
                                outcome['cloud-proxy'] = "subdomain cloud-proxy.internal.io created for %s with ip: %s" % (zone_id,instance_priv_ip[0])
                            except Exception as e:
                                statusCode = statusCode + 1
                                outcome['cloud-proxy'] = e
                            #print("subdomain cloud-proxy.internal.io created for %s" % zone_id)
                            
                        if statusCode != 200:
                            outcome['message'] = 'Proxy switch partially successfull'
                        else:
                            outcome['message'] = 'Proxy switch successfull'
                            break
            else:
                outcome['message'] = 'No healthy instances found'
        else:
            outcome['message'] = 'ERROR: The VPC name has not been specified, cannot continue'
        
        print(json.dumps(outcome))
        return json.dumps(outcome)
        
    else:
        zone = get_hosted_zone(os.environ['vpc_name'])
        zone_id = zone['Id']
        record_sets = get_record_sets(zone_id)
        if not exist_record_set(record_sets,'cloud-proxy'):
            try:
                vpc_id = get_vpc(os.environ['vpc_name'])
                #print(vpc_id)
                route_tables = get_route_table(vpc_id['VpcId'],'eks_private')
                ip = ''
                for route_table in route_tables['RouteTables']:
                    for route in route_table['Routes']:
                        if route['DestinationCidrBlock'] == '0.0.0.0/0':
                            ip = get_instance_by_eni(route['NetworkInterfaceId'])['PrivateIpAddress']
                            break
                if ip:
                    change_resource_record_sets(zone_id,'cloud-proxy.internal.io','CREATE','A',300,ip)
                    outcome['cloud-proxy'] = "subdomain cloud-proxy.internal.io created for %s with ip: %s" % (zone_id,ip)
                else:
                    statusCode = statusCode + 1
                    outcome['cloud-proxy'] = "subdomain cloud-proxy.internal.io could not be created for %s, no ip was found" % zone_id
            except Exception as e:
                statusCode = statusCode + 1
                outcome['cloud-proxy'] = e
                
            if statusCode != 200:
                outcome['message'] = 'Proxy switch partially successfull'
            else:
                outcome['message'] = 'Proxy switch successfull'
            
            print(json.dumps(outcome))
            return json.dumps(outcome)
        

