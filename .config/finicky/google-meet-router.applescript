use framework "AppKit"
use scripting additions

on open location meetURL
  tell application "Google Chrome"
    repeat with chromeWindow in windows
      set chromeTab to tab (active tab index of chromeWindow) of chromeWindow

      if URL of chromeTab starts with "https://meet.google.com/" then
        set URL of chromeTab to meetURL
        my bringMeetToFront()
        return
      end if
    end repeat
  end tell

  do shell script "/usr/bin/open -b com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan " & quoted form of meetURL
  bringMeetToFront()
end open location

on bringMeetToFront()
  set meetApps to current application's NSRunningApplication's runningApplicationsWithBundleIdentifier:"com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"
  set meetApp to meetApps's firstObject()

  if meetApp is not missing value then
    meetApp's activateWithOptions:3
  end if
end bringMeetToFront
