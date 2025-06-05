#!/bin/bash

# ============ CONFIGURATION ==============
# Path to the remote script on the target server
REMOTE_SCRIPT_PATH="/home/$USER/deleteUnusedReleasesSSH.sh"
# SSH connection configuration
REMOTE_HOST="omv" # hostname or ip
USER="user"
PASSWORD="password"

# Radarr environment variables 
# https://wiki.servarr.com/radarr/custom-scripts
# For testing, use the script radarrLogCustomScriptVariables.sh - it logs all active variables to the Radarr debug log
RADARR_EVENTTYPE="$radarr_eventtype"
RADARR_MOVIEFILE_PATH="$radarr_moviefile_path"
RADARR_MOVIEFILE_SCENENAME="$radarr_moviefile_scenename"
# ========== END CONFIGURATION ============

# ========== CALL REMOTE SCRIPT ===========

# SSH call with passing of three environment variables to the remote script (INSECURE! Only suitable for testing. Use SSH key authentication instead of password)
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$REMOTE_HOST" \
"export radarr_eventtype='${radarr_eventtype}'; \
 export radarr_moviefile_path='${radarr_moviefile_path}'; \
 export radarr_moviefile_scenename='${radarr_moviefile_scenename}'; \
 bash '$REMOTE_SCRIPT_PATH'"

# ======== END CALL REMOTE SCRIPT =========



# ========== SSH SECURITY GUIDE ===========

### For secure ssh connection follow this steps
# generate ssh key
ssh-keygen -t ed25519 -C "radarr-script"
# copy to remote host
ssh-copy-id user@omv
# now login without password is possible
# => ssh user@omv
# full command (replaces above one)
ssh -o StrictHostKeyChecking=no "$USER@$REMOTE_HOST" \
"export radarr_eventtype='${RADARR_EVENTTYPE}'; \
 export radarr_moviefile_path='${RADARR_MOVIEFILE_PATH}'; \
 export radarr_moviefile_scenename='${RADARR_MOVIEFILE_SCENENAME}'; \
 bash '$REMOTE_SCRIPT_PATH'"

# ======== END SSH SECURITY GUIDE =========
