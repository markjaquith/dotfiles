#!/usr/bin/env zsh
# Fonts installation

decrypt_and_install_fonts() {
	local FONT_DIR="$HOME/Library/Fonts"
	local FONT_SOURCE_DIR="$HOME/dotfiles/.fonts"

	# Ensure the source directory exists
	if [[ ! -d "$FONT_SOURCE_DIR" ]]; then
		echo "Error: Font directory '$FONT_SOURCE_DIR' does not exist."
		return 1
	fi

	# Move into the font source directory
	cd "$FONT_SOURCE_DIR" || return 1

	local ENCRYPTED_FONTS=()
	local BARE_FONTS=()

	# Find all encrypted font files (.otf.gpg and .ttf.gpg) and compute expected font names
	for file in *.otf.gpg(.N); do
		ENCRYPTED_FONTS+=("${file%.gpg}")
	done

	for file in *.ttf.gpg(.N); do
		ENCRYPTED_FONTS+=("${file%.gpg}")
	done

	# Find all plain font files (.otf and .ttf)
	for file in *.otf(.N); do
		BARE_FONTS+=("${file}")
	done

	for file in *.ttf(.N); do
		BARE_FONTS+=("${file}")
	done

	# Combine arrays
	local ALL_FONTS=("${ENCRYPTED_FONTS[@]}" "${BARE_FONTS[@]}")

	# Exit if no font files are found
	if [[ ${#ALL_FONTS[@]} -eq 0 ]]; then
		echo "No font files found in $FONT_SOURCE_DIR."
		return 1
	fi

	# Check if all expected fonts already exist
	local all_fonts_exist=true
	for font in "${ALL_FONTS[@]}"; do
		if [[ ! -f "$FONT_DIR/$font" ]]; then
			all_fonts_exist=false
			break
		fi
	done

	# Exit silently if all fonts exist
	if [[ $all_fonts_exist == true ]]; then
		return 0
	fi

	# Prompt for passphrase if encrypted fonts exist
	local passphrase=""
	if [[ ${#ENCRYPTED_FONTS[@]} -gt 0 ]]; then
		echo "Enter passphrase for decryption:"
		read -s passphrase
	fi

	# Decrypt and move encrypted fonts
	for file in *.otf.gpg(.N) *.ttf.gpg(.N); do
		local output_file="${file%.gpg}"
		gpg --batch --yes --passphrase "$passphrase" --output "$output_file" --decrypt "$file"
		mv "$output_file" "$FONT_DIR/"
	done

	# Copy non-encrypted fonts
	for file in *.otf(.N) *.ttf(.N); do
		cp "$file" "$FONT_DIR/"
	done
}

decrypt_and_install_fonts
