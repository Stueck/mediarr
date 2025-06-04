#!/bin/bash

# ========== CONFIGURATION ==========
# DRY_RUN=true → Only simulate deletions. No actual files or directories will be removed.
DRY_RUN=true

# List of potential parent directories that may contain scene-named folders.
TARGET_PARENT_DIRS=(
  "/srv/mergerfs/Pool/server/media/movies/hd_downloadtest"
  "/srv/mergerfs/Pool/server/media/movies/hd_original"
)

# --- FALLBACK SETTINGS (via INODE) ---
# The following options apply ONLY if inode fallback is enabled (USE_INODE_FALLBACK=true)

# Enable fallback to inode-based detection if no scene-named folder is found.
# Works on most Unix-like filesystems (ext4, xfs, etc.).
# For mergerfs, ensure 'inodecalc=hybrid-hash' is set (default). 'path-hash' ist will not work.
USE_INODE_FALLBACK=true

# Path to the recycle bin where Radarr moves deleted files. (activate in radarr!)
# Needed to locate the fallback file for inode lookup.
RECYCLE_BIN_PATH="/srv/mergerfs/Pool/server/media/movies/recycle_bin"

# Enable deletion of the recycle bin folder containing the fallback file.
# Only applicable if USE_INODE_FALLBACK=true.
DELETE_RECYCLE_BIN_FOLDER=false

# ===================================

echo "✅ Event Type: $radarr_eventtype"
echo "✅ Movie File Path: $radarr_moviefile_path"
echo "$( [[ -n "$radarr_moviefile_scenename" ]] && echo -n "✅" || echo -n "⚠️" ) Scene Name: $radarr_moviefile_scenename"

# === Handle Radarr test event ===
if [ "$radarr_eventtype" == "Test" ]; then
  echo "✅ Test event detected. Exiting."
  exit 0
fi

# === Basic validation ===
if [ -z "$radarr_eventtype" ] || [ -z "$radarr_moviefile_path" ]; then
  echo "❌ Missing required environment variables!"
  exit 1
fi

# === Only process MovieFileDelete events ===
if [ "$radarr_eventtype" != "MovieFileDelete" ]; then
  echo "ℹ️ Not a MovieFileDelete event. Skipping."
  exit 0
fi

# Inform about DRY_RUN mode
if [[ "${DRY_RUN,,}" == "true" ]]; then
  echo "ℹ️ DRY_RUN is enabled. No deletions will actually occur."
fi

# === 1. SCENE-NAME BASED DELETION ===
found_scene_dir=false

# If a scene name is present, check for a matching directory in each target parent directory
if [ -n "$radarr_moviefile_scenename" ]; then
  for dir in "${TARGET_PARENT_DIRS[@]}"; do
    candidate="$dir/$radarr_moviefile_scenename"
    if [ -d "$candidate" ]; then
      echo "🧹 Found matching scene directory: $candidate"
      if [[ "${DRY_RUN,,}" == "true" ]]; then
        echo "💡 DRY RUN: Would delete: $candidate"
      else
        echo "🚮 Deleting: $candidate"
        rm -rf "$candidate"
      fi
      found_scene_dir=true
    fi
  done
fi

# Skip fallback if scene directory was already deleted
if [ "$found_scene_dir" = true ]; then
  echo "✅ Scene directory deleted successfully."
  exit 0
fi

# === 2. INODE-BASED FALLBACK DELETION ===
if [ "$USE_INODE_FALLBACK" = true ]; then
  echo "🔁 No scene directory found. Falling back to inode-based detection..."

  # Derive the relative path (from Radarr's source root to file)
  RADARR_SOURCE_ROOT=$(dirname "$(dirname "$radarr_moviefile_path")")
  REL_PATH="${radarr_moviefile_path#$RADARR_SOURCE_ROOT/}"
  FALLBACK_FILE="$RECYCLE_BIN_PATH/$REL_PATH"

  # Check that the fallback file exists in the recycle bin
  if [ ! -e "$FALLBACK_FILE" ]; then
    echo "❌ Fallback file not found: $FALLBACK_FILE"
    exit 1
  fi

  # Determine volume root (mount point) from fallback file (since it still exists)
  VOLUME_ROOT=$(findmnt -T "$FALLBACK_FILE" -n -o TARGET)
  echo "📦 Volume Root (Mountpoint): $VOLUME_ROOT"

  if [ -z "$RECYCLE_BIN_PATH" ] || [ -z "$VOLUME_ROOT" ]; then
    echo "❌ RECYCLE_BIN_PATH or VOLUME_ROOT is not set. Cannot continue."
    exit 1
  fi

  # Get the inode of the fallback file
  FILE_INODE=$(stat -c '%i' "$FALLBACK_FILE")
  echo "🔗 File Inode: $FILE_INODE"

  # Find other files on the same volume with the same inode (i.e., hard links)
  mapfile -t matches < <(find "$VOLUME_ROOT" -xdev -type f -inum "$FILE_INODE" 2>/dev/null)

  if [ ${#matches[@]} -eq 0 ]; then
    echo "❌ No other hardlinks found for inode $FILE_INODE"
    exit 0
  fi

  echo "📄 Found ${#matches[@]} hardlink(s):"
  for file in "${matches[@]}"; do
    echo "   → $file"
  done

  echo ""
  echo "🧹 Searching for matching parent directories in configured targets..."

  deleted_any_parent=false

  for file in "${matches[@]}"; do
    for dir in "${TARGET_PARENT_DIRS[@]}"; do
      if [[ "$file" == "$dir"* ]]; then
        parent_dir=$(dirname "$file")
        if [[ "${DRY_RUN,,}" == "true" ]]; then
          echo "💡 DRY RUN: Would delete: $parent_dir"
        else
          echo "🚮 Deleting: $parent_dir"
          rm -rf "$parent_dir"
        fi
        deleted_any_parent=true
      fi
    done
  done

  # If any parent directory was deleted and config requests it, delete the recycle bin folder as well
  if [ "$deleted_any_parent" = true ] && [ "$DELETE_RECYCLE_BIN_FILE" = true ]; then
    recycle_bin_dir=$(dirname "$FALLBACK_FILE")
    if [[ "${DRY_RUN,,}" == "true" ]]; then
      echo "💡 DRY RUN: Would delete recycle bin folder: $recycle_bin_dir"
    else
      echo "🗑️ Deleting recycle bin folder: $recycle_bin_dir"
      rm -rf "$recycle_bin_dir"
    fi
  fi

else
  echo "❌ No scene directory found and inode fallback is disabled. Nothing was deleted."
fi

echo "✅ Script finished."
exit 0
