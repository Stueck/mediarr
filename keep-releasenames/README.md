# 📁 Overview

This repository contains several **Bash scripts** designed to work alongside **SABnzbd** and **Radarr** to **preserve Scene release folders** via **hardlinks**, and automatically delete them when they're no longer needed.

The scripts are organized into subfolders based on their purpose:

* `sabnzbd/`: Post-processing scripts for SABnzbd downloads
* `radarr/`: Scripts triggered by Radarr events (e.g. deletion)
* `helper/`: Utilities for analysis and cleanup

---

## 🧩 Script Overview

### 🔗 `sabnzbd/createHardlinksForDownloads.sh`

Executed by SABnzbd after a download completes.
It creates a **hardlink** copy of the files in a separate target directory while **preserving the original Scene name**.  
💡 This allows Radarr to move and rename files as needed without affecting the original data.

---

### 🎬 `radarr/execViaSsh.sh`

**Use case:** If your data resides **on the same system** where Radarr is running, this script is **not required**. You can directly configure `deleteUnusedReleases.sh` as a custom script within Radarr (**Settings > Connect > Custom Scripts**).

**Problem:**
In many setups, storage is accessed over a network using mounts like **SMB** or **NFS**. Unfortunately, these protocols often fail to provide **reliable inode information**, which makes detecting hardlinks difficult or impossible.
For instance:

* **Samba** only supports the required "Unix extensions" in version 1, which has many limitations.
* **NFS** supports inodes but causes permission issues when passed to virtual machines.
* If you're also using **MergerFS**, which abstracts inodes (`inodecalc=hybrid-hash` by default), things get even trickier.

**Solution:**
This simple script is triggered by Radarr as a custom script. It creates an **SSH connection** to a remote system (e.g., a NAS like OMV or TrueNAS) where the actual media data resides.
It then executes the real deletion logic using `deleteUnusedReleases.sh` on that host.

📌 **SSH key-based authentication is strongly recommended.** See the comments in the script for setup details.

---

### 🧹 `radarr/deleteUnusedReleases.sh`

Removes previously created **Scene release folders**.  
Configure in Radarr (**Settings > Connect > Custom Scripts**) when not using `execViaSsh.sh` instead.

* **Standard mode:** Deletes the folder based on its name
* **Fallback mode:** Uses **inode comparison** to match files
  (Works with **MergerFS** if configured with `inodecalc=hybrid-hash` — the default setting)
* Optionally deletes files from Radarr’s **Recycle Bin**
* Supports **`DRY_RUN=true`** for safe testing

📌 To enable fallback deletion, **make sure the Recycle Bin feature is enabled in Radarr** (`Settings → Media Management → Enable Recycle Bin`).  
📌 See script comments for setup and configuration.

---

### 🧪 `radarr/radarrLogCustomScriptVariables.sh`

Prints all environment variables passed by Radarr during execution.  
Useful for debugging and understanding what data Radarr provides.

---

## 🔧 Helper Scripts (`helper/`)

### 🔍 `helper/findOddFiles.sh`

Scans a directory for **unexpected or unwanted files**, i.e., those that do not match common media extensions like `.mkv`, `.nfo`, `.srt`, etc.  
Files can either be deleted interactively or immediately.

* **Usage:**

  ```bash
  ./findOddFiles.sh /path/to/folder [--instantDelete]
  ```

---

### 📊 `helper/hardlinkCounter.sh`

Counts how many **hardlinks** exist for each `.mkv` file.  
Helpful to identify orphaned or duplicate media files.

* **Usage:**

  ```bash
  ./hardlinkCounter.sh /path/to/media [min] [max]
  ```

---

## 🔄 How It Works

1. **SABnzbd** finishes a download
   → `createHardlinksForDownloads.sh` creates a **hardlinked copy** using the Scene folder naming convention

2. **Radarr** deletes the movie
   → `execViaSsh.sh` (or `deleteUnusedReleases.sh` if local) is triggered

3. The **remote server** removes the corresponding Scene folder
   → either by name or via the inode fallback mechanism

4. **Optional tools:**

   * `radarrLogCustomScriptVariables.sh` for debugging
   * `findOddFiles.sh` for directory cleanup
   * `hardlinkCounter.sh` for link structure analysis

---

## ✅ Recommendations

* Use **SSH keys** for secure remote execution
* Always **test with `DRY_RUN=true`** first
* Make sure your filesystem **provides stable inode support**, e.g., `ext4`, `xfs`
