#!/usr/bin/env zsh
# Apply local overlay file overrides into main dotfiles checkout.

emulate -L zsh
setopt typeset_silent

if ! command -v fd >/dev/null 2>&1; then
  print -u2 "Warning: fd is required for dotfiles overlays; skipping"
  return 0
fi

typeset -a overlay_dirs
typeset -a overlay_roots

if [[ -n "${DOTFILES_OVERLAY_DIRS:-}" ]]; then
  overlay_dirs=("${(@s/:/)DOTFILES_OVERLAY_DIRS}")
elif [[ -n "${LOCAL_DOTFILES_DIR:-}" ]]; then
  overlay_dirs=("$LOCAL_DOTFILES_DIR")
else
  return 0
fi

typeset tmp_dir
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-overlay.XXXXXX") || return 1
trap 'rm -rf "$tmp_dir"' EXIT

typeset desired_raw="$tmp_dir/desired.raw.tsv"
typeset desired_map="$tmp_dir/desired.map.tsv"
typeset desired_rel="$tmp_dir/desired.rel"
typeset desired_untracked_rel="$tmp_dir/desired.untracked.rel"
typeset actual_map="$tmp_dir/actual.map.tsv"
typeset actual_rel="$tmp_dir/actual.rel"
typeset stale_rel="$tmp_dir/stale.rel"
typeset missing_rel="$tmp_dir/missing.rel"
typeset common_rel="$tmp_dir/common.rel"

: > "$desired_raw"
: > "$actual_map"

typeset overlay_dir
for overlay_dir in "${overlay_dirs[@]}"; do
  [[ ! -d "$overlay_dir" ]] && continue

  typeset overlay_root="${overlay_dir:A}"
  overlay_roots+=("$overlay_root")

  typeset overlay_abs
  while IFS= read -r overlay_abs; do
    [[ -z "$overlay_abs" ]] && continue
    [[ "$overlay_abs" != "$overlay_dir"/* ]] && continue

    rel="${overlay_abs#$overlay_dir/}"
    [[ "$rel" == .git/* ]] && continue
    [[ "$rel" == .ignore ]] && continue
    [[ "$rel" == .gitignore ]] && continue
    [[ "$rel" == local-init.zsh ]] && continue

    print -r -- "$rel	$overlay_root/$rel" >> "$desired_raw"
  done < <(fd -HI -t f -t l -E .git . "$overlay_dir")
done

awk -F '\t' '{ map[$1] = $2 } END { for (k in map) print k "\t" map[k] }' "$desired_raw" > "$desired_map"
awk -F '\t' 'NF > 0 { print $1 }' "$desired_map" | sort > "$desired_rel"

: > "$desired_untracked_rel"
rel=""
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  if ! git -C "$DOTFILES_DIR" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    print -r -- "$rel" >> "$desired_untracked_rel"
  fi
done < "$desired_rel"

typeset exclude_file="$DOTFILES_DIR/.git/info/exclude"
typeset exclude_tmp="$tmp_dir/exclude.tmp"
typeset overlay_exclude_start="# BEGIN DOTFILES OVERLAY"
typeset overlay_exclude_end="# END DOTFILES OVERLAY"

if [[ -f "$exclude_file" ]]; then
  awk -v start="$overlay_exclude_start" -v end="$overlay_exclude_end" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$exclude_file" > "$exclude_tmp"
else
  : > "$exclude_tmp"
fi

if [[ -s "$desired_untracked_rel" ]]; then
  {
    print -r -- "$overlay_exclude_start"
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      print -r -- "/$rel"
    done < "$desired_untracked_rel"
    print -r -- "$overlay_exclude_end"
  } >> "$exclude_tmp"
fi

mv "$exclude_tmp" "$exclude_file"

main_link=""
while IFS= read -r main_link; do
  [[ -z "$main_link" ]] && continue
  [[ "$main_link" != "$DOTFILES_DIR"/* ]] && continue

  rel="${main_link#$DOTFILES_DIR/}"
  [[ "$rel" == .git/* ]] && continue

  resolved_target=""
  link_target=$(readlink "$main_link" 2>/dev/null)
  [[ -z "$link_target" ]] && continue

  if [[ "$link_target" == /* ]]; then
    resolved_target="$link_target"
  else
    resolved_target="${main_link:h}/$link_target"
    resolved_target="${resolved_target:A}"
  fi
  root=""
  for root in "${overlay_roots[@]}"; do
    if [[ "$resolved_target" == "$root"/* ]]; then
      print -r -- "$rel	$resolved_target" >> "$actual_map"
      break
    fi
  done
done < <(fd -HI -t l -E .git . "$DOTFILES_DIR")

awk -F '\t' '{ map[$1] = $2 } END { for (k in map) print k "\t" map[k] }' "$actual_map" > "$actual_map.tmp"
mv "$actual_map.tmp" "$actual_map"
awk -F '\t' 'NF > 0 { print $1 }' "$actual_map" | sort > "$actual_rel"

comm -23 "$actual_rel" "$desired_rel" > "$stale_rel"
comm -13 "$actual_rel" "$desired_rel" > "$missing_rel"
comm -12 "$actual_rel" "$desired_rel" > "$common_rel"

rel=""
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue

  typeset main_path="$DOTFILES_DIR/$rel"
  [[ -L "$main_path" ]] && rm -f "$main_path"

  git -C "$DOTFILES_DIR" update-index --no-skip-worktree -- "$rel" >/dev/null 2>&1 || true
  if git -C "$DOTFILES_DIR" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    git -C "$DOTFILES_DIR" restore --worktree -- "$rel" >/dev/null 2>&1 || true
  fi
done < "$stale_rel"

apply_override() {
  typeset rel="$1"
  typeset target="$2"
  typeset main_path="$DOTFILES_DIR/$rel"

  [[ -z "$rel" || -z "$target" ]] && return 0
  [[ ! -e "$target" && ! -L "$target" ]] && return 0

  if [[ -d "$main_path" && ! -L "$main_path" ]]; then
    print -u2 "Warning: Cannot override directory path: $main_path"
    return 0
  fi

  mkdir -p "${main_path:h}"
  rm -f "$main_path"
  ln -s "$target" "$main_path"
  if git -C "$DOTFILES_DIR" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    git -C "$DOTFILES_DIR" update-index --skip-worktree -- "$rel" >/dev/null 2>&1 || true
  fi
}

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  target=""
  target=$(awk -F '\t' -v key="$rel" '$1 == key { print $2; exit }' "$desired_map")
  apply_override "$rel" "$target"
done < "$missing_rel"

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  desired_target=""
  actual_target=""
  desired_target=$(awk -F '\t' -v key="$rel" '$1 == key { print $2; exit }' "$desired_map")
  actual_target=$(awk -F '\t' -v key="$rel" '$1 == key { print $2; exit }' "$actual_map")

  if [[ "$desired_target" != "$actual_target" ]]; then
    apply_override "$rel" "$desired_target"
  fi
done < "$common_rel"
