 <img width="1672" height="941" alt="banner" src="https://github.com/user-attachments/assets/ad8c11b3-d13f-4e6b-bc54-454008923c25" />

# Ashkan Localhost

A small, portable Windows launcher for previewing static web apps through a local HTTP server. It uses built-in Windows PowerShell and .NET `HttpListener`; no installer, Python, Node.js, or production hosting account is required.

**Technical name:** PowerShell Local Web Preview. It runs a local static HTTP server bound to `127.0.0.1` and opens the app in your browser. The app is served over HTTP instead of being opened as a `file://` URL.

## Features

- Add projects with a display name and a folder path.
- Choose a saved project from the main dropdown.
- Set a default project; it starts automatically the next time the launcher opens.
- Uses a stable port per project so browser storage (such as `localStorage` and IndexedDB) stays on the same origin between launches.
- Serves common web assets and supports clean SPA routes that fall back to `index.html`.
- Includes a visible PowerShell server window, with Stop server in the launcher or Ctrl+C in PowerShell.

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 (included with Windows).
- A static web app folder containing `index.html`.

This serves static front-end files only. It does not run PHP, Node backends, databases, API servers, or a production build pipeline. Test those separately if your project needs them.

## Run

1. Extract the ZIP to a folder you can write to.
2. Double-click `Start-Ashkan-Localhost.bat`.
3. To add an app, enter **App name**, choose **App folder**, and click **Save app**.
4. Select it in the dropdown and click **Launch app**.
5. To launch it automatically on future starts, select it and click **Set selected as default**.

For a project archive with `dist/index.html`, select the `dist` folder, not its parent. For example, for Delbar choose `Delbar-v1-source/dist`.

## Browser storage

Each app is assigned a fixed port from 8000 to 8999 and always opens at `http://127.0.0.1:<port>/`. This keeps the browser origin stable so local browser data persists across launches. If the saved port is occupied by another process, stop that process or choose a different app port by editing `apps.json` while the launcher is closed. Keep the same host (`127.0.0.1`) and port to retain the same origin.

The first time you use the app, browser data is stored in that browser's profile. Private/incognito windows usually discard it after closing.

## Files

- `Start-Ashkan-Localhost.bat` — opens the launcher.
- `AshkanLocalhost.ps1` — launcher interface and project configuration.
- `StaticServer.ps1` — local static HTTP server.
- `apps.json` — created automatically beside the launcher; stores names, folders, ports, and the default project.
- `banner.png` — project banner artwork.

## GitHub

Create a new GitHub repository, extract this ZIP, then upload all files and folders or run:

```powershell
git init
git add .
git commit -m "Initial Ashkan Localhost release"
git branch -M main
git remote add origin https://github.com/ashkan261/ashkan-localhost.git
git push -u origin main
```

## Troubleshooting

- **404 / Not found:** choose the folder that directly contains `index.html`; for built projects this is often `dist`.
- **Server did not start:** check the PowerShell window. The app's saved port may already be in use.
- **Changes not visible:** refresh the browser. The server sends `Cache-Control: no-cache`.
- **Browser data looks new:** confirm the same browser, `127.0.0.1`, and saved port are being used; private browsing has separate, temporary storage.

## License

MIT. See [LICENSE](LICENSE).
