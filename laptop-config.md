# Laptop Configuration

This document tracks personal workstation/laptop configuration and setup procedures. These are configurations specific to the laptop used to manage the homelab infrastructure.

## Google Drive Sync

### Setup Overview

Google Drive sync is configured using `rclone bisync` to perform bidirectional synchronization between multiple Google Drive accounts and local directories. Syncs run on a scheduled basis via cron to keep local and remote files in sync.

### Configuration Details

- **Sync Tool**: `rclone bisync` (bidirectional sync)
- **Local Mount Points**: 
  - `~/Cloud/janvv` - Personal Google Drive account
  - `~/Cloud/delichtbron` - De Lichtbron Google Drive account
  - `~/Cloud/penningmeester` - Penningmeester Google Drive account
- **Sync Direction**: Bidirectional (two-way sync)
- **Sync Frequency**: Every 30 minutes, staggered across accounts to avoid conflicts

### Cron Schedule

Syncs are scheduled to run at different times to prevent overlap:

```cron
# Personal account (janvv) - runs at :00 and :30
0,30 * * * * rclone bisync drive-janvv:/ ~/Cloud/janvv --check-access --fast-list --drive-skip-gdocs --resilient --recover --max-lock 10m -MP >> ~/.cache/rclone/bisync-janvv.log 2>&1

# De Lichtbron account - runs at :10 and :40
10,40 * * * * rclone bisync drive-delichtbron:/ ~/Cloud/delichtbron --check-access --fast-list --drive-skip-gdocs --resilient --recover --max-lock 10m -MP >> ~/.cache/rclone/bisync-delichtbron.log 2>&1

# Penningmeester account - runs at :20 and :50
20,50 * * * * rclone bisync drive-penningmeester:/ ~/Cloud/penningmeester --check-access --fast-list --drive-skip-gdocs --resilient --recover --max-lock 10m -MP >> ~/.cache/rclone/bisync-penningmeester.log 2>&1
```

### Rclone Bisync Options

The sync commands use the following options:

- `--check-access`: Verify access to both paths before syncing
- `--fast-list`: Use server-side listing for faster operations
- `--drive-skip-gdocs`: Skip Google Docs/Sheets/Slides (only syncs exported versions)
- `--resilient`: Continue syncing even if some files fail
- `--recover`: Attempt to recover from previous sync errors
- `--max-lock 10m`: Maximum time to wait for lock file (10 minutes)
- `-MP`: Progress output (M = show progress, P = show ETA)

### Log Files

Sync logs are stored in `~/.cache/rclone/`:
- `bisync-janvv.log` - Personal account sync logs
- `bisync-delichtbron.log` - De Lichtbron account sync logs
- `bisync-penningmeester.log` - Penningmeester account sync logs

### Rclone Remote Configuration

The rclone remotes (`drive-janvv`, `drive-delichtbron`, `drive-penningmeester`) must be configured in `~/.config/rclone/rclone.conf`. These remotes authenticate to the respective Google Drive accounts using OAuth 2.0.

### Google OAuth Setup

Setting up Google Drive access via rclone requires creating OAuth 2.0 credentials in Google Cloud Console. This process is not straightforward and involves several steps.

#### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use an existing one)
3. Note the project name/ID for later reference

#### Step 2: Enable Google Drive API

1. In the Google Cloud Console, navigate to **APIs & Services** > **Library**
2. Search for "Google Drive API"
3. Click on it and press **Enable**

#### Step 3: Configure OAuth Consent Screen

1. Navigate to **APIs & Services** > **OAuth consent screen**
2. Choose **External** user type (unless you have a Google Workspace account)
3. Fill in required information:
   - App name: e.g., "Rclone Drive Sync"
   - User support email: Your email
   - Developer contact information: Your email
4. Add scopes:
   - Click **Add or Remove Scopes**
   - Search for and add: `https://www.googleapis.com/auth/drive`
5. Add test users (if app is in testing mode):
   - Add all Google accounts that will be used for sync
6. Save and continue through the remaining steps

#### Step 4: Create OAuth 2.0 Credentials

1. Navigate to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Choose application type: **Desktop app**
4. Name the client: e.g., "Rclone Desktop Client"
5. Click **Create**
6. **Important**: Copy the **Client ID** and **Client Secret** immediately (you won't be able to see the secret again)

#### Step 5: Configure rclone with OAuth Credentials

**Option A: Using rclone config (Interactive)**

1. Run `rclone config`
2. Choose **n** (new remote)
3. Name the remote: e.g., `drive-janvv`
4. Choose **drive** as the storage type
5. When prompted for client_id, paste your Client ID
6. When prompted for client_secret, paste your Client Secret
7. Choose **full access** scope (or as needed)
8. Follow the authentication flow:
   - rclone will provide a URL to visit
   - Open the URL in a browser
   - Sign in with the Google account you want to sync
   - Grant permissions
   - Copy the authorization code back to rclone
9. Complete the remaining prompts (team drive, etc.)

**Option B: Manual Configuration (Advanced)**

You can manually edit `~/.config/rclone/rclone.conf`:

```ini
[drive-janvv]
type = drive
client_id = YOUR_CLIENT_ID_HERE
client_secret = YOUR_CLIENT_SECRET_HERE
scope = drive
token = {"access_token":"...","refresh_token":"...","expiry":"..."}
team_drive =
```

However, you still need to authenticate at least once using `rclone config` or `rclone authorize "drive"` to get the token.

#### Step 6: Authenticate Multiple Accounts

For each additional Google Drive account (delichtbron, penningmeester):

1. Run `rclone config` again
2. Create a new remote with a different name
3. **Important**: You can reuse the same Client ID and Client Secret for all remotes
4. During authentication, sign in with the different Google account
5. Each remote will have its own token but can share the same OAuth credentials

#### Current Configuration

The current setup uses:

- **drive-janvv**: Has explicit `client_id` and `client_secret` configured
- **drive-delichtbron**: Uses rclone's default OAuth credentials (or shared credentials)
- **drive-penningmeester**: Uses rclone's default OAuth credentials (or shared credentials)

All remotes have:
- `scope = drive` (full Drive access)
- `team_drive =` (empty, accessing personal Drive, not a shared drive)
- OAuth tokens with `access_token`, `refresh_token`, and `expiry` fields

**Security Note**: The `rclone.conf` file contains sensitive OAuth tokens. Ensure it has proper permissions:
```bash
chmod 600 ~/.config/rclone/rclone.conf
```

**Token Refresh**: OAuth tokens expire, but rclone automatically refreshes them using the `refresh_token`. If authentication fails, you may need to re-authenticate by running `rclone config` and re-authenticating the remote.

### Installation Steps

1. **Set up Google OAuth credentials** (see [Google OAuth Setup](#google-oauth-setup) section above):
   - Create Google Cloud project
   - Enable Google Drive API
   - Configure OAuth consent screen
   - Create OAuth 2.0 credentials (Client ID and Client Secret)

2. Install rclone (if not already installed):
   ```bash
   # Arch Linux
   sudo pacman -S rclone
   
   # Or download from https://rclone.org/downloads/
   ```

3. Configure Google Drive remotes using `rclone config`:
   ```bash
   rclone config
   # Follow prompts to create remotes: drive-janvv, drive-delichtbron, drive-penningmeester
   # Use the Client ID and Client Secret from Step 1
   # Authenticate each remote with the corresponding Google account
   ```

4. Create local sync directories:
   ```bash
   mkdir -p ~/Cloud/janvv
   mkdir -p ~/Cloud/delichtbron
   mkdir -p ~/Cloud/penningmeester
   mkdir -p ~/.cache/rclone
   ```

5. Test initial sync manually:
   ```bash
   rclone bisync drive-janvv:/ ~/Cloud/janvv --check-access --fast-list --drive-skip-gdocs --resilient --recover --max-lock 10m -MP
   ```

6. Add cron jobs:
   ```bash
   crontab -e
   # Add the three cron entries listed above
   ```

### Verification

A test file `RCLONE_TEST` exists on both local and remote sides for all three sync environments to verify bidirectional sync is working correctly:

- `~/Cloud/janvv/RCLONE_TEST` ↔ `drive-janvv:/RCLONE_TEST`
- `~/Cloud/delichtbron/RCLONE_TEST` ↔ `drive-delichtbron:/RCLONE_TEST`
- `~/Cloud/penningmeester/RCLONE_TEST` ↔ `drive-penningmeester:/RCLONE_TEST`

**Verify sync is working:**
```bash
# Check if test file exists locally
ls -la ~/Cloud/janvv/RCLONE_TEST
ls -la ~/Cloud/delichtbron/RCLONE_TEST
ls -la ~/Cloud/penningmeester/RCLONE_TEST

# Check if test file exists remotely
rclone ls drive-janvv:/ | grep RCLONE_TEST
rclone ls drive-delichtbron:/ | grep RCLONE_TEST
rclone ls drive-penningmeester:/ | grep RCLONE_TEST
```

### Troubleshooting

**Check sync status:**
```bash
# View recent log entries
tail -f ~/.cache/rclone/bisync-janvv.log

# Check if sync is running
ps aux | grep rclone
```

**Manual sync:**
```bash
# Run sync manually for a specific account
rclone bisync drive-janvv:/ ~/Cloud/janvv --check-access --fast-list --drive-skip-gdocs --resilient --recover --max-lock 10m -MP
```

**Check rclone remote configuration:**
```bash
rclone listremotes
rclone config show drive-janvv
```

**Lock file issues:**
If syncs are failing due to lock files, check for stale locks:
```bash
ls -la ~/.cache/rclone/*.lock
# Remove stale lock files if needed (be careful - only if sync is not running)
```

---

**Note**: This document focuses on laptop-specific configurations. For homelab infrastructure documentation, see other files in this repository.

