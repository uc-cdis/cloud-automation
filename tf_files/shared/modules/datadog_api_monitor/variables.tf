#The Datadog API key, used to interface with Datadog
variable api_key {}

#The Datadog app key, used to interface with Datadog
variable app_key {}

#The URL for the Datadog API. This can be changed if, for example, you are operating in Datadog EU
variable api_url {}

#The root URL of the commons, i.e. https://healdata.org, etc
variable commons_url {}

#The name of the commons, for use in messages and test names
variable commons_name {}

#A list of test definitions, that contain the endpoint to test, which will be concatenated to the commons_url, as well as 
#configuration data such as timeout, method, and notification information
variable test_definitions {}

#The status that we want the API to return. 
variable target_status_code {}

#The maximum allowable response time, in ms
variable target_response_time {}

#A list of locations to run the tests from. For more information,
#see: https://docs.datadoghq.com/synthetics/api_tests/#request
variable locations {}

#A list of tags, to make it easier to look up this test
variable tags {}

#The status of the monitor, i.e., whether or not it is running
variable status {}

#How many seconds should pass between runs, i.e., how often should the test run. Unit is in seconds
variable test_run_frequency_secs {}