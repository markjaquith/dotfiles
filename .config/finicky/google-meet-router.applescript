use framework "AppKit"
use scripting additions

on open location meetURL
  if my routeMeetTab(meetURL) then
    my bringMeetToFront()
    return
  end if

  do shell script "/usr/bin/open -b com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"

  repeat 50 times
    delay 0.1

    if my routeMeetTab(meetURL) then
      my bringMeetToFront()
      return
    end if
  end repeat

  do shell script "/usr/bin/open -a 'Google Chrome' " & quoted form of meetURL
end open location

on routeMeetTab(meetURL)
  tell application "Google Chrome"
    repeat with chromeWindow in windows
      set chromeTab to tab (active tab index of chromeWindow) of chromeWindow

      if URL of chromeTab starts with "https://meet.google.com/" then
        set URL of chromeTab to meetURL
        return true
      end if
    end repeat
  end tell

  return false
end routeMeetTab

on bringMeetToFront()
  set meetApps to current application's NSRunningApplication's runningApplicationsWithBundleIdentifier:"com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"
  set meetApp to meetApps's firstObject()

  if meetApp is not missing value then
    meetApp's activateWithOptions:3
  end if
end bringMeetToFront
