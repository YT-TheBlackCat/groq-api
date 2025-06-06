# Install & Run Tutorial for groq-api

1. Clone the repository:
   ```sh
   git clone https://github.com/YT-TheBlackCat/groq-api
   cd groq-api
   ```

2. Prepare your API keys:
   - (Optional) Place a global apikeys.json in your home directory (`/home/$USER/apikeys.json`) to use the same keys for all installs. The structure should be:
     ```json
     {
       "custom_local_api_key": "your-local-api-key",
       "groq_keys": [
         {"key": "grk_..."},
         {"key": "grk_..."}
       ]
     }
     ```
   - If not present, the installer will prompt you to enter your Groq API keys and a custom local API key interactively.

3. The installer (server.sh) will automatically look for backups in ~/groq-api-backup. If apikeys.json or apikeys.db is missing, it will restore them from the backup folder if available.

4. Run the interactive install/update script:
   ```sh
   sudo bash server.sh
   ```
   - The script uses colored output for clear feedback and suppresses unnecessary terminal spam.
   - It will set up a virtual environment, install all dependencies, create apikeys.json, update from the remote repo, and do a debug test run.
   - The server is always installed as a systemd service for auto-start on boot.

5. To start the server manually (if not running as a service):
   ```sh
   source venv/bin/activate
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
   The server will be available at http://localhost:8000

6. To update API keys, test the proxy, or uninstall:
   ```sh
   bash options.sh
   ```
   This script provides a menu to update apikeys.json, test the proxy interactively, or uninstall and clean up everything.

7. To test the proxy manually (Python):
   ```sh
   source venv/bin/activate
   python test_proxy.py
   ```
   This will prompt you for a model and prompt, send a test request, and show the response. The Authorization header for test requests is always set from the custom_local_api_key in apikeys.json. If apikeys.json is missing, the script will exit with an error.

8. The API key is never hardcoded in any script. All scripts (main.py, test_proxy.py) always load the API key from apikeys.json. If apikeys.json is missing, the scripts will exit with an error and prompt you to run server.sh.

9. To update all files except your API keys:
   ```sh
   sudo bash server.sh
   ```
   This will update all files except apikeys.json and version.txt from the remote repository (git required), add new files, and delete local files not present in the repo.

10. To uninstall and clean up everything:
    ```sh
    bash options.sh
    ```
    - Choose the uninstall option from the menu.
    - This will remove the venv, apikeys.json, debug log, __pycache__, the systemd service, and the entire groq-api project folder (if run from within it).
    - The script uses colored output for clear, informative feedback.

The API server will now be running and ready to accept requests!
