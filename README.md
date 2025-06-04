# README

## Overview

This repository contains several **Bash scripts** designed to **automatically create and remove release folders** ('scene names') when **SABnzbd** downloads something or **Radarr** deletes it. The setup integrates with **Radarr** and a downloader like **SABnzbd**, preserving original release names using **hardlinks**, and cleaning them up safely afterward.

The scripts are organized into subfolders:

* `sabnzbd/`: for post-processing on the downloader
* `radarr/`: for triggers and cleanup on the Radarr/media server
* `helper/`: additional tools for diagnostics and file cleanup

---

## Script Overview

### 🔗 `sabnzbd/createHardlinksForDownloads.sh` – Hardlink Creation after Download

* **Purpose:**
  This script is run by SABnzbd as a **post-processing step** after a download completes.
  It creates **hardlinks** from all files from the original download into a configured target directory, preserving the original Scene release folder name.

* **Why hardlinks?**
  Radarr moves or renames downloaded files, but hardlinks preserve the original release folder name **without duplicating disk space**.

* **Details:**

  * Skips unwanted files (e.g., `.url`, `.html`, `thumbs.db`, etc.)
  * Automatically creates the corresponding target directory
  * Preserves folder hierarchy
  * Uses `ln` to hardlink instead of copying

* **Configuration:**
  Set the base path in `TARGET_PARENT_DIR`.
  Set it in SABnzbd under Settings => Categories => Script (e.g on the movies categorie).
  Keep in mind that if you use it for more categories you need multiple versions of the script (configuration `TARGET_PARENT_DIR`).

* **Usage:**

  ```bash
  ./createHardlinksForDownloads.sh /path/to/download/Release.Name.2025.1080p-GRP
  ```

---

### 🎬 `radarr/execViaSsh.sh` – Trigger Cleanup via SSH from Radarr

* **Purpose:**
  Installed on the **Radarr server** if your hardlinks aren't reachable through radarr directly.
  It’s triggered by Radarr when a movie is deleted and uses SSH to run a cleanup script on a remote media server, forwarding Radarr environment variables.

* **Functionality:**

  * Supports insecure password-based SSH (for quick testing only, **SSH key login is strongly recommended** - guide included)
  * Includes instructions for setting up SSH key authentication for secure passwordless access
  * Passes Radarr environment variables (`radarr_eventtype`, `radarr_moviefile_path`, `radarr_moviefile_scenename`) to the remote script (e.g. `deleteUnusedReleases.sh`)

* **Configuration:**
  * Called automatically by Radarr as a custom script (see Radarr's [custom script wiki](https://wiki.servarr.com/radarr/custom-scripts))
  * Set `REMOTE_HOST`, `USER`, and `REMOTE_SCRIPT_PATH`
  * Supports temporary password-based SSH but 

---

### 🧹 `radarr/deleteUnusedReleases.sh` – Cleanup of Leftover Hardlink Folders

* **Purpose:**
  Runs on the **media server** (the remote machine where your media is stored).
  This script deletes your generated (hardlinked) release folders based on Radarr's deletion events.

* **Two Modes:**

  1. **Scene name matching (default):**
     Deletes a folder matching the original release name (by SABnzbd hardlinked earlier via `createHardlinksForDownloads.sh`).
  2. **Inode fallback (optional):**
     Uses **inode matching** to identify the correct hardlinked folder, e.g., if the scene name is not available or the folder structure was altered.
     (works also with mergerfs configured with `inodecalc=hybrid-hash`).
     **Important:**
     For Inode based deletion you have to activate radarrs recycle bin feature. 

* **Settings:**

  * `TARGET_PARENT_DIRS`: List of directories to search for release folders
  * `USE_INODE_FALLBACK=true`: Enables inode-based matching as a fallback
  * `DRY_RUN=true`: Prevents actual deletion (recommended for testing)
  * `DELETE_RECYCLE_BIN_FOLDER=true`: Optionally removes the matched folder inside the recycle bin

---

### 🧪 `radarr/radarrLogCustomScriptVariables.sh` – Debug Script for Radarr Variables

* **Purpose:**
  Logs all environment variables provided by Radarr.
  Useful for debugging and verifying what Radarr passes to your scripts.

* **Usage:**
  Register this script in Radarr as a custom script and inspect the logs.

---

## 🔧 Helper Scripts (`helper/`)

### 🔍 `helper/findOddFiles.sh` – Find Unwanted or Unexpected Files

* **Purpose:**
  Recursively scans a given directory and lists all files **not matching allowed extensions** like `.mkv`, `.nfo`, `.srt`, etc.

* **Modes:**

  * List only
  * Interactive deletion (file-by-file)
  * Instant deletion with `--instantDelete` flag

* **Usage:**

  ```bash
  ./findOddFiles.sh /path/to/folder [--instantDelete]
  ```

* **When to Use:**
  Good for cleanup after failed or messy downloads, manual edits, or general maintenance.
  e.g. you want to clean up your legacy collection before adding it to radarr

---

### 📊 `helper/hardlinkCounter.sh` – Analyze Hardlink Counts

* **Purpose:**
  Scans a directory for `.mkv` files and **counts how many hardlinks** each file has.

* **Features:**

  * Shows a summary of all hardlink counts
  * Filters files by min/max number of hardlinks
  * Useful to identify orphaned or improperly linked files

* **Usage:**

  ```bash
  ./hardlinkCounter.sh /path/to/media [min] [max]
  ```

* **Example:**
  Find all `.mkv` files with only one hardlink (possibly unlinked leftovers):

  ```bash
  ./hardlinkCounter.sh /mnt/nas/movies 1 1
  ```

---

## 🔄 How It Works Together

1. **Download Phase:**

   * SABnzbd finishes a download
   * `createHardlinksForDownloads.sh` runs and **hardlinks** the content into a target directory using the original scene release name

2. **Radarr Deletion Phase:**

   * Radarr deletes a movie file
     
   * Executing configured custom script `deleteUnusedReleases.sh`
     **For remote execution:**
     Radarr is configured to use `execViaSsh.sh`, which passes metadata (scene name, path, etc.) over SSH to the media server.

   * The (remote) **script receives the Radarr variables** and decides which directories to delete:
     * First tries to delete the scene-named folder from your configured movie directories.
     * If not found and if enabled, uses inode-based fallback to find and delete linked files/folders.
     * Honors `DRY_RUN` for testing purposes. 

3. **Cleanup Phase:**

   * The media server executes `deleteUnusedReleases.sh`
   * The (remote) **script receives the Radarr variables** and decides which directories to delete:
   * First tries to delete the scene-named folder from your configured movie directories.
   * If not found and if enabled, uses inode-based fallback to find and delete linked files/folders.
   * Honors `DRY_RUN` for testing purposes. 

4. **Debugging (Optional):**

   * Configure 

5. **Optional Diagnostics:**

   * `radarrLogCustomScriptVariables.sh` can be set in radarr as custom script to verify which environment variables are available
   * `findOddFiles.sh` can be used to scan for leftover junk
   * `hardlinkCounter.sh` can verify that files are properly linked

---

## Setup Instructions

### Step 1: Configure your scripts

* Edit `execViaSsh.sh`:

  * Set `REMOTE_HOST`, `USER`, and `REMOTE_SCRIPT_PATH` to your media server values.
* Edit `deleteUnusedReleases.sh`:

  * Set `TARGET_PARENT_DIRS` to your media storage directories which includes the hardlinked original releases.
  * Set `RECYCLE_BIN_PATH` to configured path (radarr).
  * Set `DRY_RUN=true` initially to test without deleting.
  * Set `USE_INODE_FALLBACK=true` to enable fallback for inode-based detection (if no scene name available)
  * Set `DELETE_RECYCLE_BIN_FOLDER=true` when you want to remove the matched folder inside the recycle bin

---

### Step 3: Add custom scripts to Radarr

* Go to Radarr **Settings > Connect > Custom Scripts**.
* Add `execViaSsh.sh` as a custom script to run on the event `MovieFileDelete` via os .
* **OR** Add `deleteUnusedReleases.sh` as a custom script when your files are reachable via radarr machine.
* Optionally add `radarrLogCustomScriptVariables.sh` to run for selected events during development or troubleshooting.

---

### Optional: If using the remote call set up SSH key authentication (Recommended)

* Generate SSH key on the Radarr server/client machine:

  ```bash1
  ssh-keygen -t ed25519 -C "radarr-script"
  ```
* Copy public key to media server:

  ```bash
  ssh-copy-id user@omv
  ```
* Test login:

  ```bash
  ssh user@omv
  ```
* Update `deleteUnusedReleasesLocal.sh` to remove password usage and use key-based authentication.

---

### Step 4: Testing

* Run a test in Radarr that triggers the script.
* Check logs/output to verify that the remote script receives variables and reports directories it would delete.
* If everything looks good, set `DRY_RUN=false` in the remote script to enable actual deletion.

---

## Notes

* **Hardlink creation is essential**:
  Without it, the original scene-named folders won't exist, and automatic deletion won’t be possible.

* **Security Reminder:**

  * Use SSH keys instead of passwords for remote calls (`ssh-keygen`, `ssh-copy-id`).
  * Do **not** use password-based SSH in production environments.

* **Test mode:**
  Keep `DRY_RUN=true` when testing deletion to avoid unwanted removals.

* **Filesystem Requirements:**
  For inode-based detection (fallback mode), use a compatible filesystem (e.g. `ext4`, `xfs`) and if using `mergerfs` ensure is set with `inodecalc=hybrid-hash`.

---