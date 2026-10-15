# swift-app-usage

A Mac's Screen Time history, read from the stores macOS already keeps: which app was in front and when, how long the display was lit, which notifications arrived. Read-only and on-device: nothing is written, nothing leaves the Mac.

```swift
import AppUsage

let store = UsageStore()
let today = DateInterval(start: Calendar.current.startOfDay(for: .now), end: .now)
let fragments = try store.fragments(in: today)          // Biome's ScreenTime.AppUsage stream
for app in UsageSummaries.totals(fragments) {
    let name = AppNames.info(for: app.bundleID).name ?? app.bundleID
    print(name, Int(app.seconds / 60), "min,", app.visits, "visits")
}
```

The `screentime` CLI is built on it.

## Where the history is

| Source | Path | Holds | Used for |
| --- | --- | --- | --- |
| `biome.screentime` | `~/Library/Biome/streams/restricted/ScreenTime.AppUsage` | app in front, start and end | app usage (default) |
| `biome.focus` | `…/restricted/App.InFocus` | app in front, start and end | described only: its spells carry on while the display sleeps |
| `biome.focus.remote.<id>` | `…/App.InFocus/remote/<device>` | the same, synced from other devices on the Apple Account | described only, one entry per device |
| `biome.web` | `…/restricted/App.WebUsage` | web use by domain | described only (no live records on the Mac measured) |
| `knowledge.app-usage` | `~/Library/Application Support/Knowledge/knowledgeC.db`, `/app/usage` | app in front | app usage with `source: .knowledge` |
| `knowledge.display` | knowledgeC.db, `/display/isBacklit` | display lit or dark | screen-on time and wakes |
| `knowledge.notifications` | knowledgeC.db, `/notification/usage` | notification events | notification counts |

`UsageStore.sources()` reports each one's records and first and last day.

Both places need **Full Disk Access**. A refusal is `AppUsageError.needsFullDiskAccess` — checked with `open(2)` directly, because Foundation reports a refusal on a parent folder as "file not found".

## Reading safely

- **knowledgeC.db is never opened.** It is live (macOS writes it through a write-ahead log), so the database and its `-wal`/`-shm` are copied into a private temporary folder, read there, and the folder is deleted.
- **Biome files are read as bytes.** They are preallocated and appended to while read; every offset is bounds-checked, each payload's CRC-32 is verified, and only entries in the *written* state count — Biome prunes history by marking entries deleted in place, and reading those would bring back history macOS has let go of.
- Rows another device synced into knowledgeC.db (`ZSOURCE.ZDEVICEID` set) are left out: this library reports this Mac.

## Formats (measured on macOS 27)

**SEGB v2** (Biome): `"SEGB"`, a UInt32 entry count, the creation time (Double, seconds since 2001), 16 bytes of bookkeeping, then entries from 0x20, each on a 4-byte boundary as CRC-32 + 4 unused bytes + payload. The trailer runs backwards from the end of the file, 16 bytes per entry: end offset (relative to 0x20), state (1 written, 3 deleted, 4 bookkeeping), and the entry's time. File names are the creation time in microseconds since 2001, which lets a read skip files outside its interval.

**ScreenTime.AppUsage payload** (protobuf): field 1 started (1) or ended (0), field 2 the time in seconds since **1970**, field 3 the bundle identifier, field 5 the "usage is trusted" flag (the same flag as knowledgeC's `ISUSAGETRUSTED`; carried, never filtered on).

`SEGBWriter` writes these files, for fixtures.

## Fragments, visits, totals

Stores keep **fragments**: Biome cuts a spell at about 25 minutes, and a Mac user flicks between windows constantly, so most fragments last seconds. So:

- **Totals** are the sum of fragment time. They do not depend on merging.
- **Visits** join an app's fragments when the time away between them is at most `mergeGap` (default 60 s), whatever was in front meanwhile — a glance at a chat is not leaving the editor. Joining only fragments that touch changes almost nothing (switching apps is the norm), which is why the gap is measured in time away rather than in neighbours.
- **The timeline** joins only neighbours: fragments of the same app with nothing between them, so it stays one strip with no overlaps.
- A spell with no end ends at the next app's start or now, and is never believed past 30 minutes. An end with no start is dropped.
- Spells crossing midnight are split, so each day holds only its own time.

## Measured

On one Mac, a month of history:

- **Biome and knowledgeC agree.** On every complete day both held, daily totals were within 0.1–3.1 % of each other. knowledgeC's `/app/usage` held a shorter history with whole days missing, so Biome is the default.
- **App time against screen-on time:** time in front was 1–10 % below the display's lit time on ordinary days, as it should be (the lock screen and idle moments are lit but not in an app).
- **Speed:** a month of Biome history reads in 87 ms, one day in 4 ms; knowledgeC, including the copy, in 78 ms.
- **Not yet measured:** agreement with the System Settings › Screen Time pane. Screen Time's own aggregate store is closed even to Full Disk Access, so the check needs a person reading the pane.

## Requirements

macOS 14 or later. Swift 6.2.

## Licence

MIT.
