# Flutter Code Map

A developer tool and VS Code extension for analyzing and understanding Dart and Flutter codebases without requiring AI.

## Architecture

```text
Flutter/Dart Project
        ↓
Dart Analyzer / AST
        ↓
Symbol & Reference Resolution
        ↓
Project Knowledge Graph
        ↓
Question / Query Engine
        ↓
VS Code Webview UI
```

---

## How to Install and Use from GitHub

You can use this extension directly from GitHub in **3 simple ways**:

### Option 1: Install `.vsix` from GitHub Releases (Recommended)

1. Go to your repository's **Releases** page on GitHub.
2. Download the latest `flutter-code-map.vsix` file.
3. In VS Code:
   - Open the **Extensions** view (`Cmd+Shift+X` on Mac / `Ctrl+Shift+X` on Windows/Linux).
   - Click the **`...`** (Views and More Actions) menu in the top-right of the Extensions panel.
   - Select **"Install from VSIX..."** and choose the downloaded file.
   - *Or run via terminal:*
     ```bash
     code --install-extension flutter-code-map.vsix
     ```

---

### Option 2: Build `.vsix` Locally from Git

If you cloned the repository to your machine:

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/flutter-code-map.git
cd flutter-code-map

# 2. Compile and package the extension
cd vscode-extension
npm install
npx @vscode/vsce package -o ../flutter-code-map.vsix

# 3. Install in VS Code
code --install-extension ../flutter-code-map.vsix
```

---

### Option 3: Direct Git Extension Directory Linking (Developer Mode)

VS Code automatically loads any extension placed in its extensions directory:

- **macOS / Linux**: `~/.vscode/extensions/`
- **Windows**: `%USERPROFILE%\.vscode\extensions\`

You can symlink or clone directly:

```bash
# Clone directly into VS Code extensions folder
git clone https://github.com/YOUR_USERNAME/flutter-code-map.git ~/.vscode/extensions/flutter-code-map

# Install dependencies and build
cd ~/.vscode/extensions/flutter-code-map/vscode-extension
npm install
npm run compile
```

Restart or reload VS Code (`Developer: Reload Window`), and the extension will be active immediately.

---

## Usage

1. Open any Dart or Flutter project in VS Code.
2. Press `Cmd+Shift+P` (or `Ctrl+Shift+P`) and type:
   ```text
   Flutter Code Map: Open
   ```
   *(or click the `Code Map` item in the bottom status bar)*.
3. A dedicated Code Map tab will open. Ask questions like:
   - `Where is LoginPage?`
   - `Who uses AuthBloc?`
   - `What does LoginPage depend on?`
   - `Show login flow`
   - `List widgets`
   - `List routes`
