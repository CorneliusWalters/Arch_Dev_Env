#!/bin/bash

# Define the output file name
OUTPUT_FILE="repo_contents.txt"

# Clear the output file if it already exists
> "$OUTPUT_FILE"

echo "Exporting Git repository structure and content to $OUTPUT_FILE"
echo "--------------------------------------------------------" >> "$OUTPUT_FILE"

# Use 'git ls-files' to get a list of all tracked files
# -z ensures filenames with spaces are handled correctly
git ls-files -z | while IFS= read -r -d $'\0' file; do
  # Check if the file is likely a text file
  # Note: 'file --mime-type' might not be available or behave the same on all systems (e.g., Windows Git Bash might be different)
  if [[ $(file --mime-type -b "$file") == text/* ]]; then
    echo "" >> "$OUTPUT_FILE"
    echo "--- FILE: $file ---" >> "$OUTPUT_FILE"
    echo "```" >> "$OUTPUT_FILE" # Markdown-style code block start
    cat "$file" >> "$OUTPUT_FILE"
    echo "```" >> "$OUTPUT_FILE" # Markdown-style code block end
    echo "" >> "$OUTPUT_FILE"
  else
    echo "--- BINARY FILE (SKIPPED): $file ---" >> "$OUTPUT_FILE"
  fi
done

echo "--------------------------------------------------------"
echo "Export complete. Check '$OUTPUT_FILE'."