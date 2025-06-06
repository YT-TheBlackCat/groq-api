# groq-api: Fast, Modern, Multi-Key Groq Proxy

## Features
- **No requirements.txt needed**: All dependencies are installed automatically by `server.sh`.
- **Modern CLI**: Use `options.sh` for a powerful menu or direct commands (see below).
- **Automatic systemd service**: Runs as a service for reliability and auto-start.
- **Rate limit & usage tracking**: Per-model, per-key, with automatic DB setup.
- **Easy key management**: Add, update, or remove keys interactively or via CLI.
- **Customizable system prompt**: Edit `systemprompt.txt` to change the AI's default behavior and security policy.

## Quickstart

1. **Clone the repository:**
   ```sh
   git clone https://github.com/YT-TheBlackCat/groq-api
   cd groq-api
   ```

2. **Prepare your API keys:**
   - (Optional) Place a global `apikeys.json` in your home directory (`/home/$USER/apikeys.json`) to use the same keys for all installs. Example:
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

3. **Run the installer:**
   ```sh
   sudo bash server.sh
   ```
   - All Python requirements are installed automatically (no requirements.txt needed).
   - The script restores from backup if available, sets up a venv, installs dependencies, and configures the systemd service.

4. **Server access:**
   - The server runs at http://localhost:8000
   - To start manually:
     ```sh
     source venv/bin/activate
     uvicorn main:app --host 0.0.0.0 --port 8000 --reload
     ```

5. **Manage API keys, test, or uninstall:**
   ```sh
   bash options.sh
   # or use direct commands:
   bash options.sh update-keys
   bash options.sh usage
   bash options.sh backup
   bash options.sh add-model
   bash options.sh uninstall
   bash options.sh status
   bash options.sh --help
   ```
   - The CLI is colorized, robust, and supports both menu and direct commands.

6. **Customizing the system prompt:**
   - Edit `systemprompt.txt` to change the default AI behavior and security policy.
   - This file is loaded automatically if the user requests `systemprompt.txt` as the system prompt.

7. **Uninstall and clean up:**
   ```sh
   bash options.sh uninstall
   ```
   - Removes venv, apikeys.json, debug log, __pycache__, the systemd service, and the project folder (if run from within it).

## Notes
- The API key is never hardcoded. All scripts load from `apikeys.json`.
- All dependencies are managed by `server.sh`—no need for requirements.txt.
- For advanced usage, see the comments in `systemprompt.txt` and the CLI help (`bash options.sh --help`).

---

Enjoy your fast, modern, and secure Groq API proxy!
