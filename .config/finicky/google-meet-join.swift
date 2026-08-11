import AppKit
import ApplicationServices

let meetBundleID = "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"
let joinLabels = Set(["Join now", "Ask to join", "Join anyway"])

let trustOptions = [
	kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
] as CFDictionary
let trustDeadline = Date().addingTimeInterval(30)
if !AXIsProcessTrusted() {
	_ = AXIsProcessTrustedWithOptions(trustOptions)
}

while !AXIsProcessTrusted(), Date() < trustDeadline {
	Thread.sleep(forTimeInterval: 0.2)
}

guard AXIsProcessTrusted() else {
	exit(EXIT_FAILURE)
}

let joinDeadline = Date().addingTimeInterval(30)
let fastPollDeadline = Date().addingTimeInterval(5)
var pollInterval = 0.05

func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
	var value: CFTypeRef?
	guard
		AXUIElementCopyAttributeValue(element, name as CFString, &value)
			== .success
	else {
		return nil
	}

	return value as? T
}

func click(_ element: AXUIElement) -> Bool {
	let isEnabled: Bool = attribute(kAXEnabledAttribute, of: element) ?? false
	guard
		isEnabled,
		let positionValue: AXValue = attribute(kAXPositionAttribute, of: element),
		let sizeValue: AXValue = attribute(kAXSizeAttribute, of: element)
	else {
		return false
	}

	var position = CGPoint.zero
	var size = CGSize.zero
	guard
		AXValueGetValue(positionValue, .cgPoint, &position),
		AXValueGetValue(sizeValue, .cgSize, &size)
	else {
		return false
	}

	let clickPoint = CGPoint(
		x: position.x + size.width / 2,
		y: position.y + size.height / 2
	)
	let previousPosition = CGEvent(source: nil)?.location

	guard
		let mouseDown = CGEvent(
			mouseEventSource: nil,
			mouseType: .leftMouseDown,
			mouseCursorPosition: clickPoint,
			mouseButton: .left
		),
		let mouseUp = CGEvent(
			mouseEventSource: nil,
			mouseType: .leftMouseUp,
			mouseCursorPosition: clickPoint,
			mouseButton: .left
		)
	else {
		return false
	}

	mouseDown.post(tap: .cghidEventTap)
	mouseUp.post(tap: .cghidEventTap)
	if let previousPosition {
		CGWarpMouseCursorPosition(previousPosition)
	}

	return true
}

func clickJoinButton(in element: AXUIElement, depth: Int = 0) -> Bool {
	guard depth < 25 else { return false }

	let role: String? = attribute(kAXRoleAttribute, of: element)
	if role == kAXButtonRole as String {
		let title: String = attribute(kAXTitleAttribute, of: element) ?? ""
		let description: String =
			attribute(kAXDescriptionAttribute, of: element) ?? ""

		if joinLabels.contains(title) || joinLabels.contains(description) {
			return click(element)
		}
	}

	let children: [AXUIElement] =
		attribute(kAXChildrenAttribute, of: element) ?? []
	return children.contains { child in
		clickJoinButton(in: child, depth: depth + 1)
	}
}

while Date() < joinDeadline {
	if let meetApp = NSRunningApplication.runningApplications(
		withBundleIdentifier: meetBundleID
	).first {
		let meetElement = AXUIElementCreateApplication(meetApp.processIdentifier)
		AXUIElementSetAttributeValue(
			meetElement,
			kAXFrontmostAttribute as CFString,
			kCFBooleanTrue
		)
		let windows: [AXUIElement] =
			attribute(kAXWindowsAttribute, of: meetElement) ?? []
		windows.forEach { window in
			AXUIElementPerformAction(window, kAXRaiseAction as CFString)
		}

		if clickJoinButton(in: meetElement) {
			exit(EXIT_SUCCESS)
		}
	}

	Thread.sleep(forTimeInterval: pollInterval)
	if Date() >= fastPollDeadline {
		pollInterval = min(pollInterval * 2, 0.5)
	}
}

exit(EXIT_FAILURE)
