# Building and Running from the Command Line

These instructions explain how to build and run the RSSReader macOS application from your terminal.

### 1. Build the Application

Use `xcodebuild` to compile the app.

```bash
xcodebuild build -scheme RSSReader -project RSSReader.xcodeproj
```

This command builds the project and places the resulting `RSSReader.app` file in a build products directory (typically within `~/Library/Developer/Xcode/DerivedData`).

### 2. Run the Application

After the build succeeds, you can launch the app using the `open` command.

1.  **Find the App Bundle:**
    You can find the path to your compiled `.app` bundle with this command:
    ```bash
    find ~/Library/Developer/Xcode/DerivedData -name "RSSReader.app" | head -n 1
    ```

2.  **Launch the App:**
    Use the `open` command with the path you just found:
    ```bash
    open <path_to_your_app_bundle>
    ```
    > **Note:** Replace `<path_to_your_app_bundle>` with the actual path returned by the `find` command.
