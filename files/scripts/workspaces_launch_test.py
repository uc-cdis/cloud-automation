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

workspace_internal_url = "http://workspace-token-service"
logging.basicConfig(level=logging.INFO, format='%(message)s')

def main():
    args = parse_args()
    tester = WorkspaceLaunchTest(commons_url=args.commons_url, access_token=args.access_token, images=args.images.split("+")) # Images passed from the kubernetes jobs is separated by a plus sign "+"
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
        nargs="*",
        help="Type of image to launch for testing."
    )

    return parser.parse_args()

class WorkspaceLaunchTest:
    def __init__(self, commons_url, access_token, images=["(Generic, Limited Gen3-licensed) Stata image"]):
        self.commons_url = commons_url
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

    def get_info_for_image(self, image_name, options=None):
        for option in options:
            if option["name"] == image_name:
                return option
        return None
            

    def initialize_workspace_launch_test(self):
        
        test_image_ids_map = {} # list of tuples containing image name and image ids
        
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
        logging.info("Successfully found workspace options")
        logging.info(f"Found {len(options)} Workspace options: {options}")

        available_images = [option['name'] for option in options]

        for image in self.images:
            if image in available_images:
                test_image_ids_map[image] = self.get_info_for_image(image, options)["id"]

        logging.info(f"Images requested to test {self.images}")
        logging.info(f"Images available to test {test_image_ids_map}")

        unavailable_images = set(self.images) - set(available_images)
        if len(unavailable_images) != 0:
            logging.warning(f"The following requested images are not available: {unavailable_images}")

        # Launch workspaces sequentially:
        final_result = [] 
        number_of_images = len(test_image_ids_map)
        number_of_runs = 0

        for image_name, id in test_image_ids_map.items():
            logging.info(f"Testing image: {image_name}")
            final_result.append(self.start_workspace_launch_test(image_name, id))
            logging.info(f"Finished testing image: {image_name}")
            
            number_of_runs += 1
            if number_of_images != number_of_runs:
                logging.info("Waiting to launch next image...")
                time.sleep(120) 

        
        logging.info("Completed all launch tests...")
        logging.info("Results:")
        logging.info(json.dumps(final_result))

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

        # proxy_url = self.commons_url + "/lw-workspace/proxy"
        # try:
        #     logging.info("Trying to connect to workspace via proxy endpoint")
        #     proxy_response = requests.get(proxy_url, headers=self.headers)
        #     proxy_response.raise_for_status()
        #     print(proxy_response)
        # except requests.exceptions.RequestException as e:
        #     error_msg = f"Error connecting to workspace via proxy endpoint. Error: {e}"
        
        # logging.info("Connected to workspace via proxy endpoint")
        # print(proxy_response.json())


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
            "iamge": image_name,
            "workspace_id": workspace_id,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.end_time - self.start_time,
            "result": self.launch_status,
            "reason_for_failure": self.reason_for_failure,
            "status_response": self.status_response
        }
        return json_result
        

    def monitor_workspace_status(self, interval=10):
        """
        In an interval of given time (in seconds) hit the workspace status endpoint to monitor the status of the workspace

        Args:
            interval (int, optional): Interval (in seconds) to hit the options endpoint. Defaults to 10 seconds.
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

            time.sleep(interval)
            logging.info(f"Elapsed time: {time.time()-self.start_time}")
            self.launch_status = status_response.json()["status"]

            self.status_response = status_response.json()


if __name__ == "__main__":
    main()   

