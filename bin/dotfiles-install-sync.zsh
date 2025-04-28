#!/usr/bin/env zsh
# Merge files from the local dotfiles directory

for default_file in "$DOTFILES_DIR"/**/*.default.*(ND.); do
    relative_path=${default_file#$DOTFILES_DIR/}
    dir_part=${relative_path:h}
    filename=${relative_path:t}

    if [[ $filename =~ '^(.*)\.default\.(.*)$' ]]; then
        local base_name=$match[1]
        local extension=$match[2]
        local target_filename="${base_name}.${extension}"
        local target_dir
        local target_file
        local local_check_dir

        if [[ "$dir_part" == "." ]]; then
            target_dir="$HOME"
            local_check_dir="$LOCAL_DOTFILES_DIR"
        else
            target_dir="$HOME/$dir_part"
            local_check_dir="$LOCAL_DOTFILES_DIR/$dir_part"
        fi
        target_file="$target_dir/$target_filename"

        local local_file=""
        local local_type=""

        if [[ -d "$local_check_dir" ]]; then
            local potential_local_prepend="$local_check_dir/$base_name.prepend.$extension"
            local potential_local_append="$local_check_dir/$base_name.append.$extension"

            if [[ -f "$potential_local_prepend" ]]; then
                local_file="$potential_local_prepend"
                local_type="prepend"
            elif [[ -f "$potential_local_append" ]]; then
                local_file="$potential_local_append"
                local_type="append"
            else
                # No corresponding local file
                :
            fi
        else
            # print "  Local check directory does not exist or not checked: $local_check_dir"
            # print "  No corresponding local file found."
        fi

        mkdir -p "$target_dir"
        if [[ $? -ne 0 ]]; then
            print -u2 "Error: Failed to create target directory: $target_dir for $default_file"
            continue
        fi

        if [[ -z "$local_file" ]]; then
            cat "$default_file" > "$target_file"
        elif [[ "$local_type" == "prepend" ]]; then
            cat "$local_file" "$default_file" > "$target_file"
        elif [[ "$local_type" == "append" ]]; then
            cat "$default_file" "$local_file" > "$target_file"
        fi

        if [[ $? -ne 0 ]]; then
            print -u2 "Error: Failed to write target file: $target_file"
        fi
    else
        print -u2 "Warning: Could not parse filename format (expected *.default.*): $filename in $default_file"
    fi
done
