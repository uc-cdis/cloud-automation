#The Datadog API key, used to interface with Datadog
api_key = ""

#The Datadog app key, used to interface with Datadog
app_key = ""

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
api_url = "https://api.datadoghq.com/"

#The root URL of the commons, i.e. https://healdata.org, etc
commons_url = ""

#The name of the commons, for use in messages and test names
commons_name = ""

#Second channel to send notifications to. By default, this module sends notifications to a platform engineering 
#channel, and can also be set to send one to a project-specific alerts channel
project_slack_channel = ""

#A list of test definitions, that contain the endpoint to test, which will be concatenated to the commons_url, as well as 
#configuration data such as timeout, method, and notification information
test_definitions = [
    {
        endpoint = "/api/v0/submission/_dictionary/_all"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Submission health check for: "
        message = "@slack-gpe-alarms The submission health check failed for: "
    },
    
    {
        endpoint = "/mds/aggregate/metadata?data=True&limit=1000&offset=0"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Metadata health check for: "
        message = "@slack-gpe-alarms The metadata health check failed for: "
    },

    {
        endpoint = "/mds/metadata?data=True&_guid_type=unregistered_discovery_metadata&limit=1000&offset=0"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Metadata health check 2 for: "
        message = "@slack-gpe-alarms The metadata health check failed for: "
    },

    {
        endpoint = "/index/index"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Indexd health check for: "
        message = "@slack-gpe-alarms The indexd health check failed for: "    
    },

    {
        endpoint = "/user/login"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Login page health check for: "
        message = "@slack-gpe-alarms The login page health check failed for: "    
    },

    {
        endpoint = "/portal/discovery"
        target_status_code = "200"
        target_response_time = "2000"
        name = ""
        message = ""    
    },

    {
        endpoint = "/user/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = ""
        message = ""    
    },

    {
        endpoint = "/peregrine/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Peregrine health check for: "
        message = "@slack-gpe-alarms The peregrine health check failed for: "    
    },

    {
        endpoint = "/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Commons health check for: "
        message = "@slack-gpe-alarms The commons health check failed for: "    
    },

    {
        endpoint = "/requestor/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Requestor health check for: "
        message = "@slack-gpe-alarms The requestor health check failed for: "    
    },

    {
        endpoint = "/wts/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "WTS health check for: "
        message = "@slack-gpe-alarms The WTS health check failed for: "    
    },

    {
        endpoint = "/audit/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "Audit health check for: "
        message = "@slack-gpe-alarms The audit health check failed for: "    
    },

    {
        endpoint = "/api/_status"
        target_status_code = "200"
        target_response_time = "2000"
        name = "API health check for: "
        message = "@slack-gpe-alarms The API health check failed for: "    
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

#A list of strings representing tags, to make it easier to look up this test
tags = []

#The status of the monitor, i.e., whether or not it is running
status = "live"

#How many seconds should pass between runs, i.e., how often should the test run. Unit is in seconds
test_run_frequency_secs = 300