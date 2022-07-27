#The Datadog API key, used to interface with Datadog
api_key = ""

#The Datadog app key, used to interface with Datadog
app_key = ""

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
api_url = "https://api.datadoghq.com/"

#The root URL of the commons, i.e. https://healdata.org, etc
commons_url = ""

#A list of test definitions, that contain the endpoint to test, which will be concatenated to the commons_url, as well as 
#configuration data such as timeout, method, and notification information
test_definitions = [
    {
        endpoint = "/api/v0/submission/_dictionary/_all"
        target_status_code = "200"
        target_response_time = "4000"
    
    },
    
    {
        endpoint = "/mds/aggregate/metadata?data=True&limit=1000&offset=0"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/mds/metadata?data=True&_guid_type=unregistered_discovery_metadata&limit=1000&offset=0"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/index/index"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/user/login"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/portal/discovery"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/user/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/peregrine/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/requestor/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/wts/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/audit/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    },

    {
        endpoint = "/api/_status"
        target_status_code = "200"
        target_response_time = "4000"
    
    }
]

#The status that we want the API to return. 
target_status_code = "200"

#The maximum allowable response time, in ms
target_response_time = 4000

#A list of locations to run the tests from. For more information,
#see: https://docs.datadoghq.com/synthetics/api_tests/#request
locations = ["aws:us-east-1"]

#The name to give to the synthetic test
name = "API Test"

#The message to attach to the synthetic test
message = "An API test message"

#A list of tags, to make it easier to look up this test
tags = []

#The status of the monitor, i.e., whether or not it is running
status = "live"

#How many seconds should pass between runs, i.e., how often should the test run. Unit is in seconds
test_run_frequency_secs = 300