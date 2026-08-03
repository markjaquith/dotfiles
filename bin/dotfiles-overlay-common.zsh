#!/usr/bin/env zsh

overlay_sparse_patterns() {
  emulate -L zsh

  typeset tracked_file="$1"
  typeset excluded_file="$2"
  typeset output_file="$3"

  if [[ ! -s "$excluded_file" ]]; then
    print -r -- "." > "$output_file"
    return 0
  fi

  awk '
    NR == FNR {
      excluded[$0] = 1
      count = split($0, parts, "/")
      prefix = ""
      for (i = 1; i <= count; i++) {
        prefix = prefix == "" ? parts[i] : prefix "/" parts[i]
        blocked[prefix] = 1
      }
      next
    }

    !($0 in excluded) {
      count = split($0, parts, "/")
      prefix = ""
      for (i = 1; i <= count; i++) {
        prefix = prefix == "" ? parts[i] : prefix "/" parts[i]
        if (!(prefix in blocked)) {
          print prefix
          next
        }
      }
    }
  ' "$excluded_file" "$tracked_file" | sort -u > "$output_file"
}
