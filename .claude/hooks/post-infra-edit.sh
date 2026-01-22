#!/usr/bin/env bash

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only validate .tf files in infra directory
if [[ "$file_path" =~ infra/.*\.tf$ ]]; then
  cd "$CLAUDE_PROJECT_DIR" || exit 0

  # Run validate first
  output=$(tofu -chdir=./infra validate 2>&1)
  exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    # Don't block on "Module not installed" - user needs to run infra init
    if echo "$output" | grep -q "Module not installed"; then
      echo "Note: Module not installed. Run 'infra init' to download modules." >&2
      exit 0
    fi

    echo "OpenTofu validation failed for $file_path:" >&2
    echo "$output" >&2
    echo "" >&2
    echo "Fix the terraform syntax errors above before continuing." >&2
    exit 2  # Exit 2 blocks and shows stderr to Claude
  fi

  # Run fmt
  output=$(tofu -chdir=./infra fmt 2>&1)
  if [[ $? -ne 0 ]]; then
    echo "OpenTofu fmt failed for $file_path:" >&2
    echo "$output" >&2
    exit 2
  fi
fi

exit 0
