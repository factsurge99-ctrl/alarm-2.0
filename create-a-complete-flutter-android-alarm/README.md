# Mistress Alarm

Mistress Alarm is a dark, red-accented Android alarm app built with Flutter. Create multiple alarms with personal labels and wake-up messages, choose daily repeat, and dismiss a ringing alarm by solving a quick addition challenge. Snooze is available for five minutes.

## Requirements

- Flutter stable (3.24.5 or newer)
- Android SDK / Android Studio with Android SDK Platform 35
- Java 17

## Build locally

1. Install Flutter and Android Studio, then accept Android SDK licenses with `flutter doctor --android-licenses`.
2. Open this project folder in a terminal.
3. Run `flutter pub get`.
4. Connect an Android phone with USB debugging enabled, or start an emulator.
5. Run `flutter build apk --release`.
6. Find the APK at `build/app/outputs/flutter-apk/app-release.apk`.

To install over USB, run `flutter install --release`. To install manually, copy the APK to the phone, open it, and allow installs from that file app if Android asks.

## Get the APK from GitHub Actions

Push the project to a GitHub repository and push to the `main` branch. In the repository, open **Actions**, select **Android release APK**, open the completed run, then download the `mistress-alarm-release-apk` artifact. GitHub stores this workflow artifact for 30 days. You can also start it from **Actions → Android release APK → Run workflow**.

## Permissions and alarm behavior

On Android 13 and newer, allow notifications. On Android 12 and newer, allow **Alarms & reminders** (exact alarms) when prompted. Both permission states are shown by the shield icon on the home screen; tap it to request missing access. Android may also restrict background activity or alarms through battery optimization on some manufacturers. If alarms do not arrive on time, exempt Mistress Alarm from battery optimization in system settings.

Alarm definitions are stored on-device and rescheduled after reboot or app update. Android's exact alarm API delivers enabled alarms; repeating alarms are scheduled for the next day when they ring. A foreground service plays the device's default alarm tone in a loop and vibrates until the challenge is solved or snoozed. The ringing screen is launched through a high-priority full-screen alarm notification, subject to Android and device settings.

## Notes

- This project uses Android's default alarm sound; no bundled audio file is required.
- GitHub Actions builds an unsigned release APK suitable for direct installation. Store distribution requires your own signing configuration.
- App data is local to the device and is not synchronized.
