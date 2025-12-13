import requests

def upload_json(json_path, BASE_URL, auth_token=None, print_response=None):
    """Uploads a JSON file to the API endpoint. Returns True if successful, False otherwise."""
    print(f"Uploading transcript JSON: {json_path}")
    try:
        with open(json_path, 'rb') as f:
            files = {'file': (json_path, f, 'application/json')}
            headers = {}
            if auth_token:
                headers['Authorization'] = auth_token if auth_token.startswith('Token') else f'Token {auth_token}'
            response = requests.post(
                f"{BASE_URL}/users/upload_json/",
                headers=headers,
                files=files
            )
            if print_response:
                print_response(response, "Upload JSON File")
            if response.status_code == 201:
                print("✅ Upload JSON successful!")
                return True
            else:
                print("❌ Upload JSON failed!")
                return False
    except FileNotFoundError:
        print(f"❌ Transcript JSON file not found at {json_path}")
        return False
    except Exception as e:
        print(f"❌ Exception during upload: {e}")
        return False


