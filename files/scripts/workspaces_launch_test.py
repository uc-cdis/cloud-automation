"""
You can run this script by running the following command: 
python3 workspaces_launch_test.py --commons-url https://qa-heal.planx-pla.net --images "(Generic) Jupyter Lab Notebook with R Kernel+(Tutorials) Example Analysis Jupyter Lab Notebooks" --access-token eyJhbaccess.token
Multiple image names should be separated by a plus (+) sign.
"""
import time
import argparse
import json
import logging

import requests
from urllib.parse import urlparse

workspace_internal_url = "http://workspace-token-service"
logging.basicConfig(level=logging.INFO, format='%(message)s')


def add_https_to_url(url_string):
    """
    Adds https to the url if it is not already present.
    Args:
        url_string (str): The url string to check.
    Returns:
        str: The url string with https added if it was not present.
    """
    parsed_url = urlparse(url_string)
    if parsed_url.scheme == '':
      return "https://" + parsed_url.geturl()
    return url_string

def main():
    args = parse_args()
    images = args.images.rstrip('\n')
    images = images.split("+")
    tester = WorkspaceLaunchTest(commons_url=args.commons_url, access_token=args.access_token, images=images) # Images passed from the kubernetes jobs is separated by a plus sign "+"
    tester.initialize_workspace_launch_test()

def parse_args():
    parser = argparse.ArgumentParser(
        description="Test Workspaces Launch"
    )
    parser.add_argument(
        "--commons-url",
        dest="commons_url",
        help="Specify the Commons URL to test"
    )
    parser.add_argument(
        "--access-token",
        dest="access_token",
        help="User's access token. It should have the 'credentials' scope since the /launch api requires an access token that can use to get an api key.",
    )
    parser.add_argument(
        "--images",
        dest="images", 
        help="Type of image to launch for testing."
    )

    return parser.parse_args()

class WorkspaceLaunchTest:
    def __init__(self, commons_url, access_token, images=["(Generic, Limited Gen3-licensed) Stata image"]):
        self.commons_url = add_https_to_url(commons_url)
        self.workspace_internal_url = workspace_internal_url
        self.token_expiration = 0
        self.headers = {}
        self.start_time = 0
        self.end_time = 0
        self.access_token = access_token
        self.launch_status = "Workspace did not launch. Something went wrong before launch."
        self.reason_for_failure = None
        self.status_response = None
        self.images = images
        self.update_headers()


    def update_headers(self):
        """Updates the headers with the current access token."""
        if self.access_token:
            self.headers = {"Authorization": f"Bearer {self.access_token}"}
        else:
            self.headers = {}

    def initialize_workspace_launch_test(self):
        
        available_images = {} # dict of name: id pairs of all available images
        images_to_test = {} # dict of name: id pairs of images requested that will be tested
        unavailable_images = [] # list of images requested but are not available
        
        # Get available workspace options
        options_url = self.commons_url + "/lw-workspace/options"
        try:
            options_response = requests.get(options_url, headers=self.headers)
            options_response.raise_for_status()

        except requests.exceptions.RequestException as e:
            error_msg = f"Couldn't get workspace options with error: {e}"
            logging.error(error_msg)
            self.reason_for_failure = error_msg
        
        options = options_response.json()

        for option in options:
            available_images[option["name"]] = option["id"]

        for image in self.images:
            if image in available_images:
                images_to_test[image] = available_images[image]
            else:
                unavailable_images.append(image)

        logging.info("Successfully found workspace options")
        logging.info(f"Found {len(options)} Workspace options: {options}")
        logging.info(f"Images requested to test {self.images}")
        logging.info(f"Could not find the following images: {unavailable_images}") if unavailable_images else None
        logging.info(f"Testing the following images: {images_to_test}")

        # Launch workspaces sequentially:
        final_result = []
        number_of_images = len(images_to_test)
        number_of_runs = 0

        for image_name, id in images_to_test.items():
            logging.info(f"Testing image: {image_name}")
            final_result.append(self.start_workspace_launch_test(image_name, id))
            logging.info(f"Finished testing image: {image_name}")
            
            number_of_runs += 1
            if number_of_images != number_of_runs:
                logging.info("Waiting to launch next image...")
                time.sleep(120) 

        
        logging.info("Completed all launch tests...")
        for result in final_result:
            logging.info(json.dumps({"final_result":result}))

    def start_workspace_launch_test(self, image_name, workspace_id):

        # Launch workspace
        launch_url = self.commons_url + "/lw-workspace/launch" + "?id=" + workspace_id
        try:
            launch_response = requests.post(launch_url, headers=self.headers)
            launch_response.raise_for_status()
            self.start_time = time.time()
        except requests.exceptions.RequestException as e:
            error_msg = f"Couldn't launch workspace. Error code with error: {e}"
            logging.error(error_msg)
            self.reason_for_failure = error_msg
            return

        logging.info("Successfully started launching workspace. Starting timer and monitoring workspace status...")

        self.monitor_workspace_status()

        self.end_time = time.time()
        logging.info(f"Workspace took {self.end_time-self.start_time} seconds to initialize")

        time.sleep(30)

        proxy_url = self.commons_url + "/lw-workspace/proxy/"
        try:
            logging.info("Trying to connect to workspace via proxy endpoint")
            proxy_response = requests.get(proxy_url, headers=self.headers)
            proxy_status_code = proxy_response.status_code
            proxy_response.raise_for_status()

        except requests.exceptions.RequestException as e:
            error_msg = f"Error connecting to workspace via proxy endpoint. Error: {e}"
        
        # logging.info("Connected to workspace via proxy endpoint")
        # Terminate active running workspace
        terminate_url = self.commons_url + "/lw-workspace/terminate"
        try:
            logging.info("Attempting to terminate workspace...")
            terminate_response = requests.post(terminate_url, headers= self.headers)
            terminate_response.raise_for_status()
            logging.info("Workspace terminated...")
        except requests.exceptions.RequestException as e:
            error_msg = f"Couldn't terminate workspace with error : {e}"
            logging.error(error_msg)
            self.reason_for_failure = error_msg

        json_result = {
            "image": image_name,
            "workspace_id": workspace_id,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.end_time - self.start_time,
            "result": self.launch_status,
            "reason_for_failure": self.reason_for_failure,
            "status_response": self.status_response,
            "proxy_status": proxy_status_code,
        }
        return json_result
        

    def monitor_workspace_status(self, interval=10, timeout_limit=10):
        """
        In an interval of given time (in seconds) hit the workspace status endpoint to monitor the status of the workspace

        Args:
            interval (int, optional): Interval (in seconds) to hit the options endpoint. Defaults to 10 seconds.
            timeout_limit(int, optional): Time limit, in minutes, at which a workspace launch is considered a failure.
        """
        status_url = self.commons_url + "/lw-workspace/status"

        while True:
            try:
                status_response = requests.get(status_url, headers=self.headers)
                status_response.raise_for_status()
            except requests.exceptions.RequestException as e:
                error_msg = f"Error checking workspace status: {e}"
                logging.error(error_msg)  
                self.reason_for_failure = error_msg

            logging.info("Launch Response:")
            logging.info(json.dumps(status_response.json()))

            if status_response.json()["status"] == "Running":
                self.launch_status = "Running"
                self.status_response = status_response.json()
                break
            elif status_response.json()["status"] == "Not Found":
                logging.error("Could not find workspace. Stopping status check...")
                self.launch_status = "Not Found"
                self.status_response = status_response.json()
                break
            elif time.time() - self.start_time >= timeout_limit * 60:
                logging.error(f"Workspace failed to come up in {timeout_limit * 60} minutes")
                self.launch_status = f"Workspace failed to come up in {timeout_limit * 60} minutes"
                self.status_response = status_response.json()
                break


            time.sleep(interval)
            logging.info(f"Elapsed time: {time.time()-self.start_time}")
            self.launch_status = status_response.json()["status"]

            self.status_response = status_response.json()


if __name__ == "__main__":
    main()   

