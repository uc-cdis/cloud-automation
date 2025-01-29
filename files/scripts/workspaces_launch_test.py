import time
import argparse
import json
import logging

import requests

workspace_internal_url = "http://workspace-token-service"
logging.basicConfig(level=logging.INFO, format='%(message)s')

def main():
    args = parse_args()
    tester = WorkspaceLaunchTest(commons_url=args.commons_url, access_token=args.access_token)
    tester.start_workspace_launch_test()

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
        "--notebook",
        dest="notebook",
        help="Type of notebook to launch for testing."
    )

    return parser.parse_args()


class WorkspaceLaunchTest:
    def __init__(self, commons_url, access_token, notebook="(Generic, Limited Gen3-licensed) Stata Notebook"):
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
        self.notebook = notebook 
        self.update_headers()


    def update_headers(self):
        """Updates the headers with the current access token."""
        if self.access_token:
            self.headers = {"Authorization": f"Bearer {self.access_token}"}
        else:
            self.headers = {}


    def start_workspace_launch_test(self):
        self.headers = {
            "Authorization": f"Bearer {self.access_token}"
        }
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

        workspace_id = options[0].get("id")
        for option in options:
            if option.get("name") == self.notebook:
                workspace_id = option.get("id")

        # Launch workspace
        launch_url = self.commons_url + "/lw-workspace/launch" + "?id=" + workspace_id
        try:
            launch_response = requests.post(launch_url, headers=self.headers)
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
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.end_time - self.start_time,
            "result": self.launch_status,
            "reason_for_failure": self.reason_for_failure,
            "status_response": self.status_response
        }
        json_result = json.dumps(json_result)
        logging.info("Result:")
        logging.info(json_result)
        

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

