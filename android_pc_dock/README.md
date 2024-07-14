# android_pc_dock
Tool to use an Android smartphone as if it was "docked" to a computer.

Prerequisites:
- Install the `Rotation | Orientation Manager` application from the Google play store: [com.pranavpandey.rotation](https://play.google.com/store/apps/details?id=com.pranavpandey.rotation)
Make sure you enable the accessibility service and grant all permissions to the application.
The script uses reverse engineered intents within this application to enable and disable the landscape rotation.
- Install the `Null Keyboard` application (no longer on the play store, but available here: [com.wparam.nullkeyboard](https://apkcombo.com/null-keyboard/com.wparam.nullkeyboard/download/apk)).
The script will automatically enable/disable this Input Method for the duration of the session to make sure the Google Keyboard doesn't pop up when clicking on text fields.
- Download scrcpy, from Github's latest releases: https://github.com/Genymobile/scrcpy/releases
Extract it to a directory of your choice, then copy this script next to the scrcpy executable.
- Make sure you have PHP 7.4 or newer installed on your computer to run this script
