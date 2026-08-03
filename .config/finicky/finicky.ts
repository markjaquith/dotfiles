export default {
	defaultBrowser: "Google Chrome",
	handlers: [
		{
			match: /^https?:\/\/meet\.google\.com(?:\/|$)/,
			browser: {
				name: "local.finicky.google-meet-router",
				appType: "bundleId",
			},
		},
	],
}
