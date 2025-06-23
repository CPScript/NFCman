To build the app (on Linux), open Android Studio, click "New Project", and select "No Activity".

Enter the following:
Name: **NFCman**
Package name: **com.nfcclone.app**
Language: **Java**
Minimum SDK: **API 21**
Build configuration language: **Groovy DSL**

Now wait until the loading bar at the bottom right disappears.
Close Android Studio.
Download **android_studio_setup.sh** and copy it into your project folder (e.g. ~/AndroidStudioProjects/NFCman).
Open a terminal in this location.
Run `chmod +x android_studio_setup.sh` and then `./android_studio_setup.sh`. (can also be used to update files)
After that, reopen Android Studio and click on the menu at the top left, go to Build → Gernerate Appbundles or APKs → Generate APKs.

<a href="android_studio_setup.sh" download>⬇️ Android Studio Setup Script</a>