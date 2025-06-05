# Install & Run Tutorial for groq-api

1. Clone the repository:
   ```sh
   git clone https://github.com/YT-TheBlackCat/groq-api
   cd groq-api
   ```

2. Run the interactive install script:
   ```sh
   bash install.sh
   ```
   - This will ask for your GROQ_API_KEY and if you want to install the server as a systemd service.
   - It will set up a virtual environment, install all dependencies, and do a debug test run.

3. To start the server manually:
   ```sh
   bash run.sh
   ```
   The server will be available at http://localhost:8000

4. To install as a service later (if you skipped during install):
   ```sh
   bash install-service.sh
   ```
   This will make the server start automatically on boot.

5. To test the proxy manually:
   ```sh
   source venv/bin/activate
   python test_proxy.py
   ```

The API server will now be running and ready to accept requests!
