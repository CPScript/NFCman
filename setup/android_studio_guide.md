1. To build the app, open Android Studio, click **New Project**, and select **No Activity**.

2. Enter the following:  
   - **Name:** NFCman  
   - **Package name:** com.nfcclone.app  
   - **Language:** Java  
   - **Minimum SDK:** API 21  
   - **Build configuration language:** Groovy DSL

3. Wait until the loading bar at the bottom right disappears, then close Android Studio.

4. Download (**android_studio_setup.sh** or **windows_setup_script.bat**) and copy it into your project folder (e.g. `~/AndroidStudioProjects/NFCman`).

5. Download an App-Icon that you like in `.svg` format and place it in the same folder.

6. Open a terminal in that folder and run:
   ```bash
   Linux:
   chmod +x android_studio_setup.sh
   ./android_studio_setup.sh
   Windows:
   windows_setup_script.bat

7. Reopen Android Studio, then go to Build → Generate App Bundles or APKs → Generate APKs.

	<a href="android_studio_setup.sh" download>⬇️ Direct Android Studio Setup Script | **LINUX**</a>
 
	<a href="windows_setup_script.bat" download>⬇️ Direct Android Studio Setup Script | **WINDOWS**</a>
 
   (Can also be used to update files.)
