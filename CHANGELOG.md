# Changelog

All notable changes to Desk Reminders are listed here.
Versions follow [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH.

## [Unreleased]

## [1.2.0] - 2026-11-06

### Changed
- **A new, modern look.** The main window was redesigned:
  - **Your day like a calendar's day view**: hours down the left, each reminder a quiet line with
    its title in the schedule's colour (no boxes, no bold), a red line for *now*, and busy hours grow so nothing overlaps. Group
    names (e.g. *Raid 1*) show on the right.
  - **An always-visible month calendar** on the left, and a box to type a date (e.g. `24 dec`).
  - **Schedules with on/off switches**, and a **⋯** button for Options, Export and Remove.
  - **A colourful Next up card** in the schedule's colour, and rounded buttons throughout.
  - **Little icons** for each reminder, picked from its words (a drop for water, an eye for eye
    breaks, cutlery for meals, swords for raids, a moon for bedtime...), also on the pop-up.
  - **How much of today is done**: "9 of 23 done" with a slim bar under the date.
  - **New reminder**, **Templates**, **GitHub**, **Settings** and **Undo** in one top bar (the
    old menu bar is gone).
- **New pop-ups**: a white card with rounded corners, the schedule's colour, rounded *Snooze* and
  *Done* buttons and a thin line that shows how long until it closes by itself. When several
  reminders come at once, each has its own bell to mute it.
- **A new font: Albert Sans** (free, SIL Open Font License), built in, so everyone sees the same
  look. No bold anywhere: headings are just a little larger.

- **Opening**: no more start screen. The window opens right away with a short fade-in and comes to
  the front (it used to only flash in the taskbar). Templates no longer open by themselves: an
  empty day offers *Start from a template* and *New reminder* instead.
- **Starting with Windows** puts it quietly in the tray; Settings can open the window then too.
  Starting it again while it runs opens its window.

### Added
- Double-click a time on the timeline to add a reminder at that time; right-click a reminder for
  Edit, Remove and Mute.
- **Another font**: put a `.ttf` / `.otf` file in a `fonts` folder next to the app and the whole
  app uses it instead (only for Desk Reminders; nothing is installed).
- Keys: **Ctrl+N** new reminder, **Alt+←/→** previous/next day (Delete and Ctrl+Z as before).

## [1.1.0] - 2026-11-03

### Added
- **Follow a link.** *Import → From a link*: paste a link to a shared schedule (e.g. a GitHub
  Gist) and it stays up to date by itself: checked every 20 minutes, or right away with
  *Options → Check now*. When it changes you get a short note of what changed for you.
- **Calendar links.** Follow a Google Calendar, Outlook or any `.ics` / `webcal://` calendar and
  get pop-ups for its events (next 4 months, in your local time, with the calendar's reminder as
  a heads-up). A single `.ics` file can also be imported.
- **Linked files in a synced folder.** *Import → Linked file in a synced folder* (OneDrive,
  Google Drive, Dropbox): changes come in within seconds.
- **Export, three ways:** *Save a copy as a file*, *Keep a copy updated in a folder* (every change
  you make is copied there automatically), and *Copy for a link (GitHub Gist)*.
- **A sound per schedule** under *Options* (or the one from Settings).
- **New version notice**: once a day the app asks GitHub for the latest version number and shows
  a link at the bottom when there's a new one. Can be turned off.

### Changed
- Footer: "Free, open source and offline – only connects for updates and links you follow".
- Settings has two columns, with a new *Updates* section.

## [1.0.0] - 2026-11-02

First public release.

### Your reminders
- Pop-ups with a sound at the times you choose. They never take focus from the game or app you're
  in, close by themselves after 25 seconds, and can be snoozed for 5 or 15 minutes.
- One-off and repeating reminders ("every 60 minutes from 10:00 to 17:00, on weekdays"),
  single dates and date ranges, and notices a few minutes before something starts.
- **Templates** to start fast: Hydration (interval, times and glass size), Move, Eye breaks, Meals and
  Bedtime. Pre-built but adjustable.
- Reminders at the same minute share one pop-up, each in its own schedule's colour.
- Nine soft sounds of its own (Soft chime, Warm bell, Marimba, Kalimba, Glass, Music box, Rising,
  Soft ping, Water drop), made for this app; or use your own `.wav`.

### Shared schedules (guilds, teams, communities)
- Make a schedule for your group in the app (**+ New shared schedule**), **Export** it as a file
  and post it; members **Import** it. Nothing goes online.
- The group's time zone ("server time") is converted to each member's local time.
- **Groups**, e.g. five raid teams in one guild schedule: each event is for *Everyone* or for one
  or more groups, and members tick their group(s) when they import. Everyone sees every event;
  only theirs pop up.
- **The bell and the megaphone**: click the bell in front of any event to mute it (that day or
  every time), or click a greyed-out event's bell to be notified too.
- When you import an update, the app tells you what changed for you.

### The app
- One main window: your schedules on the left (each in its own colour, with Import and Export
  at the top), your week on the right with a *Next up* bar, a calendar to jump to any date, coloured day dots and a list that
  hides what's already done.
- Quiet hours, with a choice per schedule whether it may still pop up.
- Rename your own schedule, and empty it in one go (with Undo).
- Settings: sound and volume, quiet hours, pop-up corner and screen, Start with Windows, backup and restore.
- Undo (Ctrl+Z) for the last change.
- A short animated welcome screen, then the main window opens by itself.
- Everything stays on your PC: free, open source and offline.

[Unreleased]: https://github.com/7ab9ne3021sn4b/DeskReminders/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/7ab9ne3021sn4b/DeskReminders/releases/tag/v1.2.0
[1.1.0]: https://github.com/7ab9ne3021sn4b/DeskReminders/releases/tag/v1.1.0
[1.0.0]: https://github.com/7ab9ne3021sn4b/DeskReminders/releases/tag/v1.0.0
