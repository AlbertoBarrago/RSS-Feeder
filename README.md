# RSSReader

A simple Menu Bar RSS reader application for iOS.

![screen](screen.png)

## Prerequisites

*   macOS with Xcode installed. You can download Xcode from the Mac App Store.

## How to Run

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd RSSReader
    ```

2.  **Open the project in Xcode:**
    Double-click on the `RSSReader.xcodeproj` file to open the project in Xcode.

3.  **Select a simulator or device:**
    In the Xcode toolbar, choose the simulator (e.g., "iPhone 15 Pro") or a connected Apple device you want to run the app on.

4.  **Run the app:**
    Click the "Run" button (the play icon) in the Xcode toolbar, or press `Cmd+R`. Or follow the instructions inside `RUN.md` for building locally

5. **Schema**
```mermaid
sequenceDiagram
  autonumber
  actor User
  participant ContentView
  participant RSSParser as Parser
  participant URLSession
  participant XMLParser
  participant RSSParserDelegate as ParserDelegate
  participant ModelContext

  User->>ContentView: Trigger refresh (pull/menu/button)
  ContentView->>Parser: refreshCurrentFilter(...)
  alt Specific feed selected
    Parser->>URLSession: dataTask(feed URL)
    URLSession-->>Parser: HTTP response + data
    Parser->>XMLParser: init(data)
    Parser->>XMLParser: set delegate = ParserDelegate(feed, context)
    XMLParser-->>ParserDelegate: parse callbacks (start/characters/end)
    ParserDelegate->>ModelContext: upsert items, update feed.lastUpdated
    ParserDelegate-->>Parser: completion via closure
  else All feeds
    loop For each feed
      Parser->>URLSession: dataTask(feed URL)
      URLSession-->>Parser: response + data
      Parser->>XMLParser: parse with ParserDelegate
      ParserDelegate->>ModelContext: persist
    end
    Parser-->>ContentView: completion (group notify)
  end
  ```


