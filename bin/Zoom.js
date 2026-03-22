#!/usr/bin/osascript -l JavaScript

const APP_NAME = "zoom.us"
const MENU_NAME = "Meeting"
const AUDIO_ON = "audio-on"
const AUDIO_OFF = "audio-off"
const VIDEO_ON = "video-on"
const VIDEO_OFF = "video-off"

const ZOOM_STATUS = {
	CLOSED: "closed",
	OPEN: "open",
	CALL: "call",
}

const AUDIO_STATUS = {
	DISABLED: "disabled",
	ON: "on",
	OFF: "off",
}

const VIDEO_STATUS = AUDIO_STATUS

const MENU_ITEM = {
	AUDIO: {
		ON: "Unmute audio",
		OFF: "Mute audio",
	},
	VIDEO: {
		ON: "Start video",
		OFF: "Stop video",
	},
}

const SOUND = {
	FUNK: "Funk",
	BOTTLE: "Bottle",
	PURR: "Purr",
	POP: "Pop",
}

function makeSound(sound) {
	const app = Application.currentApplication()
	app.includeStandardAdditions = true
	app.doShellScript(`afplay /System/Library/Sounds/${sound}.aiff`)
}

function throwUsageError() {
	throw new Error(
		`Usage: Zoom.js ${AUDIO_ON} | ${AUDIO_OFF} | ${VIDEO_ON} | ${VIDEO_OFF}`,
	)
}

function run(argv) {
	// Ensure one argument is provided.
	if (argv.length < 1) throwUsageError()

	// Split the argument (e.g., "audio-off" into ["audio", "off"]).
	const command = argv[0]

	// Not currently used, but might be useful in the future.
	let zoomStatus = ZOOM_STATUS.CLOSED
	let audioStatus = AUDIO_STATUS.DISABLED
	let videoStatus = AUDIO_STATUS.DISABLED

	let muteAudioItem, unmuteAudioItem, startVideoItem, stopVideoItem

	// Locate the zoom.us process
	const zoomProcs = Application("System Events").processes.whose({
		name: APP_NAME,
	})

	// Noop if Zoom is not running or does not have a window.
	if (zoomProcs.length === 0 || zoomProcs[0].windows.length === 0) return

	const zoomProc = zoomProcs[0]

	zoomStatus = ZOOM_STATUS.OPEN

	// Look for the "Meeting" menu bar item
	const meetingItems = zoomProc.menuBars[0].menuBarItems.whose({
		name: MENU_NAME,
	})
	if (meetingItems.length > 0) {
		const meetingMenu = meetingItems[0]
		zoomStatus = ZOOM_STATUS.CALL
		const meetingMenuContent = meetingMenu.menus[0]

		// Capture menu items and infer status from which are available.
		const muteItems = meetingMenuContent.menuItems.whose({
			name: MENU_ITEM.AUDIO.OFF,
		})
		if (muteItems.length > 0) {
			muteAudioItem = muteItems[0]
			audioStatus = AUDIO_STATUS.ON
		}
		const unmuteItems = meetingMenuContent.menuItems.whose({
			name: MENU_ITEM.AUDIO.ON,
		})
		if (unmuteItems.length > 0) {
			unmuteAudioItem = unmuteItems[0]
			audioStatus = AUDIO_STATUS.OFF
		}
		const startVideoItems = meetingMenuContent.menuItems.whose({
			name: MENU_ITEM.VIDEO.ON,
		})
		if (startVideoItems.length > 0) {
			startVideoItem = startVideoItems[0]
			videoStatus = VIDEO_STATUS.OFF
		}
		const stopVideoItems = meetingMenuContent.menuItems.whose({
			name: MENU_ITEM.VIDEO.OFF,
		})
		if (stopVideoItems.length > 0) {
			stopVideoItem = stopVideoItems[0]
			videoStatus = VIDEO_STATUS.ON
		}
	}

	// Determine which menu item to click based on the command.
	const menuItem = {
		[AUDIO_ON]: unmuteAudioItem,
		[AUDIO_OFF]: muteAudioItem,
		[VIDEO_ON]: startVideoItem,
		[VIDEO_OFF]: stopVideoItem,
	}[command]

	const sound = {
		[AUDIO_ON]: SOUND.FUNK,
		[AUDIO_OFF]: SOUND.BOTTLE,
		[VIDEO_ON]: SOUND.PURR,
		[VIDEO_OFF]: SOUND.POP,
	}[command]

	// Click the menu item if it exists and is enabled.
	if (menuItem && menuItem.enabled()) {
		menuItem.click()
		makeSound(sound)
	}
}
