#!/usr/bin/env bash
# folder_dump.sh
# Prints the folder tree and contents of all files in the current directory.

set -e

echo "### Folder tree:"
# If you have 'tree' installed:
if command -v tree >/dev/null 2>&1; then
  tree
else
  find . -print
fi

echo
echo "### File contents:"
echo

# Loop over all files (not directories)
find . -type f | while read -r file; do
  echo "===== FILE: $file ====="
  cat "$file"
  echo
done

