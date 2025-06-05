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
         {"key": "sk-..."},
         {"key": "sk-..."}
       ]
     }
     ```
   - If not present, the installer will prompt you to enter your Groq API keys and a custom local API key interactively.

3. Run the interactive install script:
   ```sh
   sudo bash install.sh
   ```
   - The script uses colored output for clear feedback and suppresses unnecessary terminal spam.
   - It will set up a virtual environment, install all dependencies, create apikeys.json, and do a debug test run.
   - You can choose to install the server as a systemd service for auto-start on boot.

4. To start the server manually:
   ```sh
   sudo bash run.sh
   ```
   The server will be available at http://localhost:8000

5. To install as a service later (if you skipped during install):
   ```sh
   sudo bash install-service.sh
   ```
   This will make the server start automatically on boot.

6. To test the proxy manually:
   ```sh
   source venv/bin/activate
   python test_proxy.py
   ```
   Or use the interactive test script:
   ```sh
   bash test.sh
   ```
   This will prompt you for a model and prompt, send a test request, and show the response. The Authorization header for test requests is set from the custom_local_api_key in apikeys.json.

7. To update all files except your API keys:
   ```sh
   bash update.sh
   ```
   This will update all files except apikeys.json and version.txt from the remote repository (git required), add new files, and delete local files not present in the repo.

8. To uninstall and clean up everything:
   ```sh
   sudo bash uninstall.sh
   ```
   - This will remove the venv, apikeys.json, debug log, __pycache__, the systemd service, and the entire groq-api project folder (if run from within it).
   - The script uses colored output for clear, informative feedback.

The API server will now be running and ready to accept requests!
