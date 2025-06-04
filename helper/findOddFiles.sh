#!/bin/bash

# === Configuration: Allowed file extensions ===
ALLOWED_EXTENSIONS=("*.mkv" "*.mp4" "*.nfo" "*.jpg" "*.idx" "*.sub" "*.srt")

# === Script arguments ===
BASE_PATH="$1"
MODE="$2"  # optional: --instantDelete to auto-delete all findings

# === Helper: build find exclusion pattern ===
build_find_exclusion() {
  local EXCLUDES=()
  for EXT in "${ALLOWED_EXTENSIONS[@]}"; do
    EXCLUDES+=("-iname" "$EXT" "-o")
  done
  # Remove the last "-o"
  unset 'EXCLUDES[${#EXCLUDES[@]}-1]'
  echo "${EXCLUDES[@]}"
}

# === Check for valid input path ===
if [ -z "$BASE_PATH" ]; then
  echo "⚠️ Usage: $0 /path/to/folder [--instantDelete]"
  exit 1
fi

if [ ! -d "$BASE_PATH" ]; then
  echo "❌ Path '$BASE_PATH' does not exist."
  exit 1
fi

# === Generate exclusion pattern and search ===
echo "🔍 Scanning directory '$BASE_PATH' for files NOT matching allowed extensions: ${ALLOWED_EXTENSIONS[*]}"

EXCLUDE_PATTERN=$(build_find_exclusion)
TO_LIST=$(find "$BASE_PATH" -type f ! \( $EXCLUDE_PATTERN \))

# === If nothing to delete ===
if [ -z "$TO_LIST" ]; then
  echo "✅ No unwanted files found."
  exit 0
fi

# === Show all unwanted files first ===
echo
echo "🗂 Found files that do NOT match allowed extensions:"
echo "---------------------------------------------------------"
echo "$TO_LIST"
echo "---------------------------------------------------------"
echo

# === Determine deletion mode ===
if [ "$MODE" == "--instantDelete" ]; then
  CHOSEN_MODE="all"
else
  read -p "❓ Proceed to delete files individually, delete all at once, or cancel? [i=individual/a=all/q=quit]: " USER_CHOICE
  case "$USER_CHOICE" in
    [aA])
      CHOSEN_MODE="all"
      ;;
    [iI])
      CHOSEN_MODE="individual"
      ;;
    [qQ])
      echo "❌ Operation cancelled by user."
      exit 1
      ;;
    *)
      echo "❌ Invalid input. Aborting."
      exit 1
      ;;
  esac
fi

# === Deletion loop ===
echo
while IFS= read -r FILE; do
  echo "🗂 $FILE"
  if [ "$CHOSEN_MODE" == "all" ]; then
    rm -v "$FILE"
  else
    read -p "❓ Delete this file? [y/N/q]: " CONFIRM
    case "$CONFIRM" in
      [yY][eE][sS]|[yY])
        rm -v "$FILE"
        ;;
      [qQ])
        echo "❌ Aborted by user."
        exit 1
        ;;
      *)
        echo "Skipped."
        ;;
    esac
  fi
done <<< "$TO_LIST"

echo
echo "✅ Cleanup complete!"
