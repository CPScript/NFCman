1. To build the app (on Linux), open Android Studio, click **New Project**, and select **No Activity**.

2. Enter the following:  
   - **Name:** NFCman  
   - **Package name:** com.nfcclone.app  
   - **Language:** Java  
   - **Minimum SDK:** API 21  
   - **Build configuration language:** Groovy DSL

3. Wait until the loading bar at the bottom right disappears, then close Android Studio.

4. Download **android_studio_setup.sh** and copy it into your project folder (e.g. `~/AndroidStudioProjects/NFCman`).

5. Open a terminal in that folder and run:
   ```bash
   chmod +x android_studio_setup.sh
   ./android_studio_setup.sh

6. Reopen Android Studio, then go to Build → Generate App Bundles or APKs → Generate APKs.

	<a href="android_studio_setup.sh" download>⬇️ Android Studio Setup Script</a>
(Can also be used to update files.)
