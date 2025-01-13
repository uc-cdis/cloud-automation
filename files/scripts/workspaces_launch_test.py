import time
import argparse
import json
import jwt
import logging

import requests

COMMON_URL = "https://binamb.planx-pla.net"
TOKEN_REFRESH_THRESHOLD = 60
logging.basicConfig(level=logging.DEBUG)

def main():
    tester = WorkspaceLaunchTest(commons_url=COMMON_URL, api_file="/Users/binambajracharya/Downloads/credentials.json")
    tester.start_workspace_launch_test()

def parse_args():
    parser = argparse.ArgumentParser(
        description="Test Workspaces Launch"
    )
    parser.add_argument(
        "--commons-url",
        dest="COMMONS_URL",
        help="Specify the Commons URL to test"
    )
    parser.add_argument(
        "--api-file",
        dest="api_file",
        help="API Key file",
    )

    return parser.parse_args()


class WorkspaceLaunchTest:
    def __init__(self, commons_url, api_file):
        self.commons_url = commons_url
        self.api_file = api_file
        self.access_token = None
        self.token_expiration = 0
        self.headers = {}
        self.start_time = 0
        if self.api_file:
            self.api_file = self.get_api_key_from_file(self.api_file)
            self.access_token, self.token_expiration = self.get_access_token_with_key(self.api_file)
            self.update_headers()


    def get_api_key_from_file(self, filepath):
        try:
            with open(filepath, "r") as f:
                data = json.load(f)
            
            api_key = data.get("api_key")

            if api_key:
                return api_key
            else:
                logging.error(f"Could not get API Key from json file: {filepath}")
        except FileNotFoundError:
            logging.error(f"Could not find file: {filepath}")
            return None
        except Exception as e:
            logging.error(f"Could not get API Key from json file with error : {e}")


    def get_access_token_with_key(self, api_key):
        """
        Try to fetch an access token given the api key
        """
        # attempt to get a token from Fence
        body = {"scope": [
                    "openid",
                    "user",
                    "data",
                    "credentials",

                    "ga4gh_passport_v1",
                    "google_link",
                    "google_credentials",
                    "admin",
                    "fence",
                    "google_service_account"
                    ],
                "api_key": api_key
                }
        auth_url = "{}/user/credentials/api/access_token".format(COMMON_URL)
        try:
            resp = requests.post(auth_url, json=body)
            resp.raise_for_status()
            access_token = resp.json()["access_token"]
            decoded_token = jwt.decode(
                access_token, algorithms=["RS256"], options={"verify_signature": False}
                )
            print(access_token)
            token_expiration = decoded_token["exp"]
            logging.info("Successfully retrieved access token.")
            return access_token, token_expiration
        except requests.exceptions.RequestException as e:
            logging.error(f"Error fetching access token: {e}")
            return None, 0


    def refresh_access_token_if_needed(self):
        """
        Refresh the access token if its about to expire. 
        """
        if not self.api_file:
            return
        
        if time.time() > self.token_expiration - TOKEN_REFRESH_THRESHOLD:
            logging.info("Access token is about to expire. Refreshing token...")
            self.access_token, self.token_expiration = self.get_access_token_with_key(self.api_file)
            self.update_headers()
            if not self.access_token:
                logging.error("Failed to refresh access token")
        
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
        options_url = COMMON_URL + "/lw-workspace/options"
        try:
            self.refresh_access_token_if_needed()
            options_response = requests.get(options_url, headers=self.headers)
            options_response.raise_for_status()

        except requests.exceptions.RequestException as e:
            logging.error(f"Couldn't get workspace options with error: {e}")
        
        options = options_response.json()
        logging.info("Successfully found workspace options")
        logging.info(f"Found {len(options)} Workspace options: {options}")

        workspace_id = options[0].get("id")

        # Launch workspace
        launch_url = COMMON_URL + "/lw-workspace/launch" + "?id=" + workspace_id
        try:
            self.refresh_access_token_if_needed()
            launch_response = requests.post(launch_url, headers=self.headers)
            launch_response.raise_for_status()
            self.start_time = time.time()
        except requests.exceptions.RequestException as e:
            logging.error(f"Couldn't launch workspace. Error code with error: {e}")
            return

        logging.info("Successfully started launching workspace. Starting timer and monitoring workspace status...")

        self.monitor_workspace_status()

        end_time = time.time()
        logging.info(f"Workspace took {end_time-self.start_time} seconds to initialize")

        # Terminate active running workspace
        terminate_url = COMMON_URL + "/lw-workspace/terminate"
        try:
            self.refresh_access_token_if_needed()
            logging.info("Attempting to terminate workspace...")
            terminate_response = requests.post(terminate_url, headers= self.headers)
            terminate_response.raise_for_status()
            logging.info("Workspace terminated...")
        except requests.exceptions.RequestException as e:
            logging.error(f"Couldn't terminate workspace with error : {e}")
        
        logging.info("Workspace terminated...")
        

    def monitor_workspace_status(self, interval=10):
        status_url = COMMON_URL + "/lw-workspace/status"

        while True:
            try:
                status_response = requests.get(status_url, headers=self.headers)
                status_response.raise_for_status()
            except requests.exceptions.RequestException as e:
                logging.error(f"Error checking workspace status: {e}")

            logging.info(f"Status reposnse: {status_response.json()}")

            if status_response.json()["status"] == "Running":
                break

            time.sleep(interval)
            logging.info(f"Elapsed time: {time.time()-self.start_time}")

    


if __name__ == "__main__":
    main()   

