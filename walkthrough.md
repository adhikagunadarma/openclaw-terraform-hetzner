# OpenClaw Infrastructure Walkthrough

This guide documents the complete setup process for deploying the OpenClaw agent infrastructure on a Hetzner VPS using Terraform, Docker, and Tailscale. Use this guide if you need to recreate the environment on a new device or server.

<<<<<<< HEAD
## 1. Getting Started (For a Brand New Computer)

Imagine your new computer is a blank canvas. To build your AI robot (OpenClaw) and put it on a cloud server (Hetzner), you need a few tools first.

### Step 1: Install the Tools
You need these installed on your computer:
1. **Git**: The tool that downloads code. (On Windows, this installs "Git Bash", which is the terminal you should use).
2. **Terraform**: The tool that automatically rents and sets up the server for you.
3. **Make**: A tool that runs our shortcut commands (like `make deploy`).
4. **Tailscale**: A private VPN. It connects your computer securely to the server so hackers can't get in.

### Step 2: Get Your Secret Keys Ready
Think of these as passwords for your robot. Keep them safe!
- **Hetzner API Token**: Go to Hetzner Cloud, create a project, and generate an API Token. This lets Terraform rent the server.
- **Telegram Bot Token**: Message `@BotFather` on Telegram, type `/newbot`, and copy the token he gives you.
- **AI API Keys**: Keys from OpenAI, Google Gemini, or DeepSeek.
- **SSH Key**: This is a secure digital key that proves your computer is allowed to talk to the server.
  - Open Git Bash and type: `ssh-keygen -t ed25519` (press Enter for all prompts).
  - Turn on the key manager and add your key:
    ```bash
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
    ```

### Step 3: Download the Code
You need to download both of your projects into the same folder on your computer.

1. Create a folder to hold everything (e.g., `mkdir MyProject` and `cd MyProject`).
2. Clone (download) the two repositories:
   ```bash
   git clone https://github.com/your-username/openclaw-terraform-hetzner.git
   git clone https://github.com/your-username/openclaw-docker-config.git
   ```

---

## 2. Setting Up the Cloud Server (Repo 1)

Now we will use the first folder (`openclaw-terraform-hetzner`) to rent and configure the server.

1. **Enter the folder**:
   ```bash
   cd openclaw-terraform-hetzner
   ```
2. **Set up your server passwords**:
   We don't want to type passwords every time. We will create a file to hold them.
   - Copy the template: `cp config/inputs.example.sh config/inputs.sh`
   - Open `config/inputs.sh` in a text editor and paste your Hetzner API token and GitHub username inside.
3. **Load the passwords**:
   ```bash
   source config/inputs.sh
   ```
4. **Build the Server!**
   Run these commands one by one. Terraform will ask you to type `yes` to confirm.
   ```bash
=======
## 1. Preparing a New Device
If you are setting this up on a brand new device, you need to prepare the following:

### Dependencies to Install
1. **Terraform**: For provisioning the Hetzner VPS.
2. **Git & Git Bash**: For version control (use Git Bash on Windows).
3. **Make**: To run the `Makefile` deployment scripts.
4. **Tailscale**: For secure, private networking to the Web UI and SSH.

### Keys & Tokens Required
You will need to gather these tokens before starting:
- **Hetzner API Token**: For Terraform to provision the server.
- **Telegram Bot Token**: From `@BotFather` on Telegram.
- **AI API Keys**: Your Google AI Studio (Gemini) or Anthropic keys.
- **SSH Key**: Generate a new `id_ed25519` key if you don't have one, and add it to your `ssh-agent`:
  ```bash
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  ```

## 2. Infrastructure Setup (Repo 1: openclaw-terraform-hetzner)
You must set up the infrastructure first before deploying the docker configuration.

1. Create a `config/inputs.sh` file with your API tokens (Hetzner, GitHub).
2. Start your SSH agent so deployment scripts don't ask for your password repeatedly:
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```
3. Provision the server:
   ```bash
   source config/inputs.sh
>>>>>>> 39cffa1 (Update working)
   make init
   make plan
   make apply
   ```
<<<<<<< HEAD
   *Congratulations! You just created a server in the cloud.*

---

## 3. Setting Up the AI Brain (Repo 2)

The server is ready, but it's empty. We need to build the "brain" of OpenClaw using the second folder (`openclaw-docker-config`).

1. **Go to the second folder**:
   ```bash
   cd ../openclaw-docker-config
   ```
2. **Fix Windows Line Endings (Windows Only)**:
   Windows and Linux format text files differently. If you are on Windows, run this so the server can understand the scripts:
   ```bash
   dos2unix docker/*.sh scripts/*.sh
   ```
3. **Build and Upload the Brain**:
   Make sure you are logged into GitHub Container Registry (GHCR). Then run:
   ```bash
   bash scripts/build-and-push.sh
   ```
   *This packages your AI settings into a "Docker Image" and uploads it privately to GitHub.*

---

## 4. Final Deployment (Back to Repo 1)

Now we tell the server to download the brain and start running!

1. **Go back to the first folder**:
   ```bash
   cd ../openclaw-terraform-hetzner
   ```
2. **Set up the AI's secrets**:
   Copy the example secrets file to create your real one:
   ```bash
   cp secrets/openclaw.env.example secrets/openclaw.env
   ```
   Open `secrets/openclaw.env` and paste all your tokens (Telegram, AI keys, etc.).
3. **Launch the Robot!**:
   This command sends your secrets to the server safely and tells the server to start the AI.
=======
4. Verify Tailscale is connected (`make tailscale-status`), then lock down the server firewall by removing public SSH access in `inputs.sh` (`export TF_VAR_ssh_allowed_cidrs='[]'`) and running `make apply` again.

## 3. Configuration Setup (Repo 2: openclaw-docker-config)
Once the server is running, switch to the `openclaw-docker-config` repository. Your agent's settings (`openclaw.json`), personality (`SOUL.md`), skills (`skills-manifest.txt`), and Docker image definitions live here.

### Fixing Line Endings (Windows Only)
If cloning on Windows, Git converts shell scripts to `\r\n`. You must convert them back to Linux format before building the Docker image:
```bash
dos2unix docker/*.sh scripts/*.sh
```

### Building and Pushing Custom Images
1. Ensure your `GHCR_USERNAME` is correctly set in your environment.
2. Build the image and push it to your GitHub Container Registry:
   ```bash
   bash scripts/build-and-push.sh
   ```

## 4. Final Deployment (Back to Repo 1)
Once the server is provisioned and the Docker image is ready, go back to the `openclaw-terraform-hetzner` repository to deploy everything.

1. Setup your secrets in `secrets/openclaw.env`.
2. Push your config and secrets, then deploy:
>>>>>>> 39cffa1 (Update working)
   ```bash
   make push-env push-config deploy
   ```

<<<<<<< HEAD
If everything succeeds, OpenClaw is now alive and running on your server!

=======
>>>>>>> 39cffa1 (Update working)
## 5. Exposing the Gateway securely
We use **Tailscale Serve** to securely host the OpenClaw Web UI on your private Tailnet without exposing it to the public internet.
```bash
make ssh
sudo tailscale serve --bg 18789
```

**CORS & Proxies**: To ensure the Web UI works properly over Tailscale, your `openclaw.json` must include:
```json
"gateway": {
  "trustedProxies": ["172.16.0.0/12", "127.0.0.1", "::1"],
  "controlUi": {
    "allowedOrigins": ["https://your-tailnet-url.ts.net"]
  }
}
```

## 6. Telegram Bot Integration & Troubleshooting
To integrate the agent with Telegram and add it to groups, follow these steps:

1. **Create the Bot:** Talk to `@BotFather` on Telegram to create a bot and get the Token. Add it to `secrets/openclaw.env`.
2. **Turn off Privacy Mode:** In `@BotFather`, go to `Bot Settings` > `Group Privacy` > **Turn Off**. If this is on, the bot will silently ignore all group messages.
3. **Configure Allowlisting:** In `openclaw.json` (`channels.telegram`), set your User IDs in `allowFrom`. 
4. **Group Configuration:** If you add a `"groups"` block to `openclaw.json`, it enforces strict allowlisting. You must ensure:
   - Supergroup IDs always have a `-100` prefix (e.g., `-1003788752801`).
   - `"groupPolicy"` should be `"allowlist"`.
5. **Disable Heartbeat Spams:** To prevent the bot from waking up every 30 minutes, failing to compact memory, and spamming your API billing, disable the heartbeat in `openclaw.json`:
   ```json
   "agents": {
     "defaults": {
       "heartbeat": { "every": "0m" }
     }
   }
   ```
6. **Clearing Memory:** If the bot gets stuck with too much history (triggering API cap errors), type `/new` in the chat to drop the memory and start a fresh session.
<<<<<<< HEAD

## 7. Google Workspace Skill (gog) Setup

The `gog` skill gives your agent access to Gmail, Google Calendar, and Google Drive via the `gogcli` CLI. Unlike other config files, the Google OAuth credentials (`client_secret.json`) are **not** managed by `push-config` — they must be set up manually once.

### Step 1: Create a Google Cloud OAuth App

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a new project (or use an existing one).
2. Enable the APIs you need:
   - **Gmail API**
   - **Google Calendar API**
   - **Google Drive API**
3. Go to **APIs & Services → OAuth consent screen**:
   - Choose **External** user type.
   - Fill in app name, support email, etc.
   - Add scopes for Gmail, Calendar, and Drive.
   - **⚠️ IMPORTANT: Publish the app** (move from "Testing" to "Production"). If you leave it in Testing mode, Google will **expire your refresh tokens every 7 days**, forcing you to re-authenticate weekly.
4. Go to **APIs & Services → Credentials**:
   - Click **Create Credentials → OAuth client ID**.
   - Choose **Desktop app** as the application type.
   - Download the JSON file — this is your `client_secret.json`.

### Step 2: Push the Credential File to the VPS

This is a **one-time manual step**. The file lives on the VPS at `~/.openclaw/client_secret.json` and is never touched by `push-config`.

```bash
# From your local machine (replace <VPS> with your server IP or Tailscale hostname)
scp client_secret.json openclaw@<VPS>:~/.openclaw/client_secret.json

# Set secure permissions
ssh openclaw@<VPS> "chmod 600 ~/.openclaw/client_secret.json"
```

### Step 3: Register Credentials & Authenticate (Headless)

> [!WARNING]
> **Tilde (`~`) Expansion Trap:** Always `exec` into the container's `bash` shell **before** running the `gog auth` commands (as shown below). If you try to run it from outside as a one-liner (e.g. `docker exec -it ... gog auth credentials ~/.openclaw/client_secret.json`), your host server's shell will incorrectly expand `~` to `/home/openclaw` instead of `/home/node`, resulting in a "no such file or directory" error!

SSH into the VPS and exec into the running container to run `gogcli`:

```bash
# SSH into the server
make ssh

# Exec into the OpenClaw container FIRST
docker exec -it openclaw-openclaw-gateway-1 bash

# Register the client secret with gogcli (inside the container)
gog auth credentials ~/.openclaw/client_secret.json

# Authenticate your Google account (headless — no browser on server)
gog auth add your-email@gmail.com --services gmail,calendar,drive --manual
```

The `--manual` flag will print a URL. Open that URL in a browser on your local machine, sign in with your Google account, grant permissions, then copy the authorization code back into the terminal.

### Step 4: Verify It Works

```bash
# Still inside the container
gog gmail list --max 3
```

If you see your recent emails, the setup is complete. Type `exit` to leave the container.

### How Token Persistence Works

The `docker-compose.yml` sets two environment variables that make `gogcli` store tokens in an encrypted file on the persistent volume instead of the (non-existent) system keyring inside the container:

```yaml
GOG_KEYRING_BACKEND: file
GOG_KEYRING_PASSWORD: ${GOG_KEYRING_PASSWORD:-openclaw-gog-keyring}
```

This means:
- ✅ Tokens survive container restarts (`docker compose restart`)
- ✅ Tokens survive image upgrades (`make deploy`)
- ❌ Tokens are lost if you `docker compose down -v` (deletes volumes)
- ❌ Tokens are lost if you delete `~/.openclaw/` on the VPS

If tokens are lost, repeat **Step 3** to re-authenticate.

### Updating the Client Secret

If you ever need to rotate the OAuth client in Google Cloud Console:
1. Download the new `client_secret.json`
2. Push it manually: `scp client_secret.json openclaw@<VPS>:~/.openclaw/client_secret.json`
3. Re-run Step 3 to re-register and re-authenticate

## 8. OpenAI/ChatGPT (Codex) OAuth Setup

OpenClaw supports using your existing ChatGPT Plus subscription (via the Codex integration) to power your agent without needing to pay for separate OpenAI API credits. This uses OAuth instead of API keys.

### Step 1: Run the Onboarding Flow
To authenticate your OpenAI account, you need to use the `oc onboard` command inside the container.

```bash
# SSH into the server
make ssh

# Exec into the OpenClaw container
docker exec -it openclaw-openclaw-gateway-1 bash openclaw models auth login --provider openai-codex
https://docs.openclaw.ai/providers/openai#codex-subscription


This command will output an OAuth authorization URL. Open that URL in your local browser, sign in to your ChatGPT account, and grant the necessary permissions. Once complete, the token will be securely saved, and OpenClaw will route `openai` model requests through your ChatGPT account.

## 9. Gateway Device Pairing & Approval

OpenClaw treats every client (Telegram plugin, dashboard browser, CLI) as a "device" that must be paired and granted explicit scopes. On a fresh install, no admin device exists, so the first pairing must be done manually.

### Initial Bootstrap (First Time Only)

> **Note:** `tailscale.mode: "serve"` does NOT work in Docker because Tailscale runs on the host, not inside the container. Use external `tailscale serve` on the host instead.

#### Step 1: Grant the gateway-client `operator.approvals`

The internal Telegram plugin (`gateway-client`) is auto-paired with only `operator.read`. It needs `operator.approvals` to send you approve/reject prompts in Telegram. Without it, it will spam the logs every second with `pairing required` errors.

```bash
# SSH into the server
make ssh

# Add operator.approvals to the gateway-client device
jq '
  to_entries | map(
    .value.scopes += ["operator.approvals"] |
    .value.approvedScopes += ["operator.approvals"] |
    .value.tokens.operator.scopes += ["operator.approvals"]
  ) | from_entries
' ~/.openclaw/devices/paired.json > /tmp/paired_new.json \
  && mv /tmp/paired_new.json ~/.openclaw/devices/paired.json \
  && cd ~/openclaw && docker compose restart
```

> **Warning:** Do NOT remove `operator.approvals` from the gateway-client. This scope is required for the Telegram bot to function. Removing it brings back the log spam.

#### Step 2: Pair the Dashboard (Control UI)

1. Open `https://openclaw-prod.tail6eeced.ts.net` in Chrome
2. Paste the `OPENCLAW_GATEWAY_TOKEN` (from `secrets/openclaw.env`) into the Control UI settings
3. The gateway creates a pending pairing request in `~/.openclaw/devices/pending.json`
4. Approve it via SSH:

```bash
# SSH into the server
make ssh

# Move the pending request into paired.json with full admin scopes
NOW=$(date +%s)000 && \
TOKEN=$(openssl rand -base64 32 | tr '/+' '_-' | tr -d '=') && \
DEVICE_ID=$(jq -r 'to_entries[0].value.deviceId' ~/.openclaw/devices/pending.json) && \
PUBKEY=$(jq -r 'to_entries[0].value.publicKey' ~/.openclaw/devices/pending.json) && \
jq --arg tok "$TOKEN" --argjson now "$NOW" --arg did "$DEVICE_ID" --arg pk "$PUBKEY" \
'. + {($did): {deviceId:$did,publicKey:$pk,platform:"Win32",clientId:"openclaw-control-ui",clientMode:"webchat",role:"operator",roles:["operator"],scopes:["operator.admin","operator.read","operator.write","operator.approvals","operator.pairing"],approvedScopes:["operator.admin","operator.read","operator.write","operator.approvals","operator.pairing"],tokens:{operator:{token:$tok,role:"operator",scopes:["operator.admin","operator.read","operator.write","operator.approvals","operator.pairing"],createdAtMs:$now}},createdAtMs:$now,approvedAtMs:$now}}' \
~/.openclaw/devices/paired.json > /tmp/paired_new.json && \
mv /tmp/paired_new.json ~/.openclaw/devices/paired.json && \
echo '{}' > ~/.openclaw/devices/pending.json && \
cd ~/openclaw && docker compose restart
```

5. Refresh the dashboard in Chrome — it should now connect.

### Ongoing Device Pairing (After Bootstrap)

Once the dashboard is paired with admin scopes, future device pairing is done through the UI:

1. A new device connects → gateway creates a pending request
2. Open the dashboard at `https://openclaw-prod.tail6eeced.ts.net`
3. Navigate to device management
4. Approve the pending request with one click

### What Can Reset the Database

These actions wipe `paired.json` and require re-pairing:
- `docker compose down -v` (deletes Docker volumes)
- Manually deleting `~/.openclaw/devices/` directory
- `make bootstrap` does **NOT** reset it (preserves `~/.openclaw/`)

## 10. Model Selection Strategy

This section outlines the model selection strategy configured in `openclaw.json` based on available API funds and priorities. The global priority order for paid providers is: **OpenAI > Google > DeepSeek > ZAI > Qwen**. 
To balance cost and performance, we use models that are **one version behind the latest** for standard tasks, while reserving the latest premium models for complex tasks.

### 1. Primary Model (Standard Tasks)
- **Primary:** `openai-codex/gpt-5.4`
- **Fallbacks:** `openai-codex/gpt-5.4-mini` → `openai/gpt-5.4-nano` → `google/gemini-2.5-flash` → `deepseek/deepseek-v4-flash`
- **Rationale:** The standard 5.4 model handles day-to-day interactions exceptionally well without the premium cost of 5.5.

### 2. Media Tasks (Image/Video)
- **Primary:** `openai-codex/gpt-image-1-mini`
- **Fallbacks:** `openai/gpt-image-1-mini` → `google/gemini-2.5-flash-image`
- **Rationale:** Prioritizes Codex image generation, falling back to paid OpenAI credits, and then Google as a last resort.

### 3. Background Tasks (Cron, Compaction, Heartbeat)
- **Primary:** `openai-codex/gpt-5.4-mini`
- **Fallbacks:** `openai/gpt-5.4-nano` or `deepseek/deepseek-v4-flash`
- **Rationale:** Background compaction and heartbeat checks happen frequently and do not require deep reasoning. Using mini/nano models saves significant costs and prevents runaway billing.

### 4. Complex Tasks
- **Premium Models:** `openai-codex/gpt-5.5` / `openai/gpt-5.5` / `google/gemini-3.1-pro` / `deepseek/deepseek-v4-pro`
- **Usage:** OpenClaw defaults to 5.4 for standard tasks. When you need deep reasoning or complex coding, manually switch the model for that specific session or prompt (e.g., using `/model openai-codex/gpt-5.5` in Telegram).

### 5. ZAI & Qwen
- **Usage:** Kept configured for manual selection if a specific need arises, but excluded from general automated fallbacks to preserve funds for the priority providers.

### Provider Pricing References
- **Google Gemini:** [https://ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing)
- **OpenAI:** [https://developers.openai.com/api/docs/pricing](https://developers.openai.com/api/docs/pricing)
- **Qwen:** [https://www.qwencloud.com/models](https://www.qwencloud.com/models)
- **ZAI:** [https://docs.z.ai/guides/overview/pricing](https://docs.z.ai/guides/overview/pricing)
- **DeepSeek:** [https://api-docs.deepseek.com/quick_start/pricing/](https://api-docs.deepseek.com/quick_start/pricing/)

## 10. GitHub CLI (gh) Setup

To allow OpenClaw to interact with GitHub (e.g., read private repositories or manage PRs), the `gh` CLI must be authenticated inside the container. We ensure this authentication persists across deployments by setting `GH_CONFIG_DIR: /home/node/.openclaw/gh` inside `docker-compose.yml`.

### Step 1: Get a Token
Generate a GitHub Personal Access Token (Classic) with full `repo` permissions.

### Step 2: Authenticate (Interactive)
SSH into your server, jump inside the container, and start the interactive login flow:

```bash
# 1. Enter the container
docker exec -it openclaw-openclaw-gateway-1 bash

# 2. Clear the env var & start login
unset GH_TOKEN
GH_CONFIG_DIR=/home/node/.openclaw/gh gh auth login
```

> [!NOTE]
> **Why `unset GH_TOKEN`?** OpenClaw hides the `GH_TOKEN` environment variable from the AI's isolated terminal for security reasons. However, the main container shell *does* have `GH_TOKEN` exported (via `.env`). If you run `gh auth login` without unsetting it first, the CLI will detect the token and refuse to create the persistent `hosts.yml` file on the disk, completely blinding the AI.

**Answer the prompts exactly like this:**
- Where do you use GitHub? **GitHub.com**
- What is your preferred protocol for Git operations? **HTTPS**
- Authenticate Git with your GitHub credentials? **Y**
- How would you like to authenticate? **Paste an authentication token**

Paste your token and hit enter. Once it succeeds, type `exit` to leave the container.

### Step 3: Informing the Agent
Because the AI's subprocess environment is isolated, you must explicitly tell the AI where to find the auth file. The very first time you ask the agent to do a GitHub task, provide this exact instruction:

*"When running any `gh` commands, you must explicitly prefix it with the config directory because the token is intentionally hidden from your environment. Always run it like this: `GH_CONFIG_DIR=/home/node/.openclaw/gh gh <command>`"*
=======
>>>>>>> 39cffa1 (Update working)
