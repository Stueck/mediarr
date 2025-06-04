#!/bin/bash

# ========== INPUT HANDLING ==========

if [ -z "$1" ]; then
  echo "❌ Please provide a directory to search."
  echo "👉 Usage: $0 /path/to/dir [min] [max]"
  exit 1
fi
SEARCH_PATH="$1"

if [ -z "$2" ]; then
  read -p "🔢 Enter the minimum number of hardlinks: " MIN_HARDLINKS
else
  MIN_HARDLINKS="$2"
fi

if [ -z "$3" ]; then
  read -p "🔢 Enter the maximum number of hardlinks (0 = no limit): " MAX_HARDLINKS
else
  MAX_HARDLINKS="$3"
fi

if [ ! -d "$SEARCH_PATH" ]; then
  echo "❌ Directory not found: $SEARCH_PATH"
  exit 1
fi

if ! [[ "$MIN_HARDLINKS" =~ ^[0-9]+$ ]] || ! [[ "$MAX_HARDLINKS" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid input for min or max hardlinks!"
  exit 1
fi

# ========== START ==========
echo "🔍 Searching for .mkv files in: $SEARCH_PATH"
echo "🔗 Minimum hardlinks: $MIN_HARDLINKS"
if [ "$MAX_HARDLINKS" -gt 0 ]; then
  echo "🔗 Maximum hardlinks: $MAX_HARDLINKS"
else
  echo "🔓 No upper limit"
fi
echo

declare -A HARDLINK_STATS
MATCH_COUNT=0

while IFS= read -r FILE; do
  LINK_COUNT=$(stat -c %h "$FILE")
  FILENAME=$(basename "$FILE")

  ((HARDLINK_STATS["$LINK_COUNT"]++))

  if [ "$LINK_COUNT" -lt "$MIN_HARDLINKS" ]; then
    continue
  fi
  if [ "$MAX_HARDLINKS" -gt 0 ] && [ "$LINK_COUNT" -gt "$MAX_HARDLINKS" ]; then
    continue
  fi

  echo "$FILENAME | Hardlinks: $LINK_COUNT"
  ((MATCH_COUNT++))

done < <(find "$SEARCH_PATH" -type f -name "*.mkv")

echo
echo "✅ Done."
echo "📁 Files matching filter: $MATCH_COUNT"
echo "📊 Hardlink summary (all .mkv files):"
for LINK_COUNT in $(printf "%s\n" "${!HARDLINK_STATS[@]}" | sort -n); do
  COUNT=${HARDLINK_STATS[$LINK_COUNT]}
  printf "  %d hardlinks → %d files\n" "$LINK_COUNT" "$COUNT"
done

exit 0
