# Only these preferences are shared. Never include routing credentials, device
# selection, output folders, calendar connections, recents, or migration state.
def portable_fields:
	[
		["release_microphone_while_idle", "boolean"],
		["sound_effects", "boolean"],
		["sound_effect_volume", "number"],
		["sound_theme", "string"],
		["avoid_bluetooth_microphone", "boolean"],
		["recording_audio_behavior", "string"],
		["recording_duck_volume", "number"],
		["pause_browser_media", "boolean"],
		["double_tap_lock", "boolean"],
		["double_tap_only", "boolean"],
		["shortcut_mode", "string"],
		["dictation_hotkey", "object"],
		["paste_last_hotkey", "object"],
		["cancel_hotkey", "object"],
		["raw_dictation_hotkey", "object"],
		["typed_text_hotkey", "object"],
		["second_dictation_hotkey", "object"],
		["extra_dictation_hotkeys", "array"],
		["terminal_paste_hotkey", "object"],
		["show_dock_icon", "boolean"],
		["transcription.model", "string"],
		["transcription.language", "string"],
		["keyboard_model_switching", "object"],
		["dictation_processing", "object"],
		["history_retention", "string"],
		["meetings.enabled", "boolean"],
		["meetings.summaries", "string"],
		["meetings.show_recording_indicator", "boolean"],
		["meetings.recording_indicator_corner", "string"],
		["meetings.calendar.remind", "boolean"],
		["meetings.calendar.lead_minutes", "number"],
		["capture.enabled", "boolean"],
		["capture.hotkey", "object"],
		["capture.replay_hotkey", "object"],
		["capture.transcriber", "string"],
		["capture.media_days", "number"],
		["capture.bundle_days", "number"],
		["capture.show_overlays_in_recordings", "boolean"],
		["capture.capsule_flow", "string"],
		["experimental.hex_microphone", "boolean"],
		["experimental.hex_microphone_mode", "string"],
		["experimental.hex_microphone_comfort_noise", "boolean"],
		["experimental.hex_microphone_strength", "number"],
		["screenshots.hotkey", "object"],
		["screenshots.record_hotkey", "object"],
		["enable_on_launch", "boolean"],
		["paste_with_shift", "boolean"],
		["gnome_keyboard_shortcuts", "boolean"],
		["share_dictation_shortcut", "boolean"],
		["ui_language", "string"],
		["indicator_position", "string"],
		["updates.channel", "string"],
		["vocabulary", "array"],
		["vocabulary_boost", "string"]
	] + (
		[
			"live_text", "failure_notices", "live_typing", "live_chapters",
			"playground", "vocabulary_biasing", "mouse_shortcuts", "unload_idle",
			"restore_shortcut_default", "keep_on_clipboard", "copy_only",
			"return_to_app", "spoken_formatting", "filler_words", "subtitle_export",
			"second_dictation_shortcut", "more_dictation_shortcuts",
			"terminal_paste_shortcut", "smart_spacing", "spoken_symbols",
			"picker_sort_filter", "sided_modifier_chords", "tap_or_hold",
			"double_tap_modifiers", "benchmark_details", "parakeet_ultra",
			"standalone_special_keys", "history_stats", "recent_dictations",
			"skip_pauses", "stop_when_call_ends", "output_fixes",
			"picker_active_first", "model_in_place", "picker_downloaded",
			"section_key_alone", "keep_recordings", "settings_search",
			"release_notes_link", "hide_menu_bar_icon", "quit_closes_window",
			"caps_lock_dictation", "appearance", "movable_meeting_capsules",
			"gnome_clipboard_restore", "typed_text", "meeting_notes_vocabulary",
			"notch_indicator", "meeting_finished_event", "gnome_meeting_capsules",
			"gnome_annotate", "screenshots", "follow_live_transcript",
			"meeting_import", "meeting_descriptive_filenames", "meeting_notes_file",
			"expire_meeting_audio", "annotate_replay", "more_call_apps",
			"opencode_in_wsl", "transcribe_files", "api_processing",
			"api_timestamps", "speakers_only", "app_model_switching", "pause_menu"
		] | map(["labs." + ., "boolean"])
	) + [
		["labs.unload_idle_minutes", "number"],
		["labs.caps_lock_light", "string"],
		["labs.appearance_theme", "string"]
	];

def path_exists($path):
	if ($path | length) == 0 then true
	elif type != "object" then false
	elif has($path[0]) then .[$path[0]] | path_exists($path[1:])
	else false end;

def portable:
	. as $source |
	reduce portable_fields[] as $field ({};
		($field[0] | split(".")) as $path |
		if ($source | path_exists($path)) then
			setpath($path; $source | getpath($path))
		else . end
	);

def valid:
	. as $source |
	type == "object" and . == portable and
	all(portable_fields[];
		. as $field |
		($field[0] | split(".")) as $path |
		($source | getpath($field[0] | split("."))) as $value |
		($source | path_exists($path) | not) or
		($value | type) == $field[1] or
		($value == null and ($field[0] |
			test("hotkey$|^ui_language$|^updates.channel$"))));
