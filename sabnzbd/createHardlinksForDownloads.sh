#!/bin/bash

# ========== CONFIGURATION ==========
# Set the base target directory
#TARGET_PARENT_DIR="/path/to/target/folder"
TARGET_PARENT_DIR="/mnt/nas/media/movies/hd_downloadtest/"

# No hardlinks for extensions or files
EXCLUDED_EXTENSIONS=("*.url" "*.html" "thumbs.db", "support.txt", "unterstuetzung.txt")
# ===================================

# Download directory is passed as $1
# Check if the first parameter ($1) is set
if [ -z "$1" ]; then
  echo "❌ The parameter \$1 (Download directory) is not set!"
  exit 1
fi

# Set the path to the download directory
DOWNLOAD_DIR="$1"
echo "✅ Provided parameter (Download directory): $DOWNLOAD_DIR"

# Check if the directory exists
if [ ! -d "$DOWNLOAD_DIR" ]; then
  echo "❌ The directory $DOWNLOAD_DIR does not exist!"
  exit 1
fi

# Set the target folder
DIR_NAME=$(basename "$DOWNLOAD_DIR")
TARGET_DIR="$TARGET_PARENT_DIR/$DIR_NAME"

echo "🔍 Target folder (with path): $TARGET_DIR"

# Check if the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "✅ Target folder does not exist. Creating target folder..."
  mkdir -p "$TARGET_DIR"
  echo "✅ Target folder created: $TARGET_DIR"
else
  echo "✅ Target folder already exists: $TARGET_DIR"
fi

# Traverse through all files
echo "🔍 Starting to process the download directory: $DOWNLOAD_DIR"
find "$DOWNLOAD_DIR" -type f | while read -r DOWNLOAD_FILE; do
  echo "🔍 Processing file: $DOWNLOAD_FILE"

  if [ -f "$DOWNLOAD_FILE" ]; then
    # Check if file matches any excluded pattern
    for pattern in "${EXCLUDED_EXTENSIONS[@]}"; do
      if [[ "$(basename "$DOWNLOAD_FILE")" == $pattern ]]; then
        echo "⏭️ Skipping excluded file: $DOWNLOAD_FILE"
        continue 2  # skip to next file in while-loop
      fi
    done

    # Create relative path
    RELATIVE_PATH=$(realpath --relative-to="$DOWNLOAD_DIR" "$DOWNLOAD_FILE")
    TARGET_FILE="$TARGET_DIR/$RELATIVE_PATH"
    TARGET_FILE_DIR=$(dirname "$TARGET_FILE")

    # Ensure target subdirectory exists
    if [ ! -d "$TARGET_FILE_DIR" ]; then
      echo "✅ Target subfolder does not exist. Creating: $TARGET_FILE_DIR"
      mkdir -p "$TARGET_FILE_DIR"
    fi

    # Create hardlink
    echo "✅ Creating hardlink for: $DOWNLOAD_FILE"
    ln "$DOWNLOAD_FILE" "$TARGET_FILE"
    echo "✅ Hardlink created: $TARGET_FILE"
  else
    echo "🔍 No file found or it is a directory: $DOWNLOAD_FILE"
  fi
done

echo "✅ Script completed. All files processed."
exit 0
