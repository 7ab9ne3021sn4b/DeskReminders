DESK REMINDERS
==============
Pop-up + sound reminders on Windows 10/11, from a schedule you set up yourself.
Version 1.2.0  -  free, open source (MIT licence) and offline
Home page, guides, updates and bug reports: https://github.com/7ab9ne3021sn4b/DeskReminders

SET UP
1. Unzip this folder somewhere permanent, e.g. Documents\DeskReminders.
2. Double-click Start-Reminders.cmd. The main window opens right away.
   A blue bell stays in the system tray (bottom right, maybe behind the
   ^ arrow); double-click it to open the window.
3. The first time, click "Start from a template" (water, moving,
   meals...) or "New reminder".
4. Optional: Settings > "Start Desk Reminders when I log in to Windows".

If Windows shows "Windows protected your PC", click More info > Run anyway.

UPDATING FROM AN OLDER VERSION
Quit from the tray, copy the new files over your old folder, start again.
Your schedule.csv, shared folder and settings.json are not in the download,
so your reminders and settings stay as they are.

THE MAIN WINDOW
Top: New reminder (Ctrl+N), Templates (ready-made reminders you can
adjust: Hydration, Move, Eye breaks, Meals, Bedtime), GitHub (how to
use, guides, troubleshooting, what's new, report a problem; opens in
your browser), Settings (the cog) and Undo (Ctrl+Z).

Left: THE MONTH AND YOUR SCHEDULES
- Month calendar: click a day to see it. The arrows or the mouse wheel
  change the month. Under it, type a date (e.g. 24-12-2026 or 24 dec)
  and press Enter.
- Schedules: My schedule and every shared schedule, each in its own
  colour. The switch turns a shared schedule on or off. The ... button
  (or a double-click) opens Options: its name (your own schedule),
  colour, sound, your groups, pop-ups during quiet hours, hidden events,
  and for followed links: Check now / Stop following. The ... menu also
  has Export and Remove (empties your own schedule - Undo brings it
  back - or takes a shared one off this PC).
- Import: add a schedule someone shared with you: From a file (a copy),
  From a link (a Gist or a calendar link like Google Calendar / Outlook
  .ics; checked every 20 minutes), or Linked file in a synced folder
  (OneDrive, Google Drive, Dropbox; updates within seconds).
- Export: share a schedule you made: Save a copy as a file, Keep a
  copy updated in a folder (synced folder; copied after every change),
  or Copy for a link (paste into a free GitHub Gist and post its link).
- New shared schedule: make one for your guild or team.

Right: YOUR DAY
- Next up: the next reminder that will pop up for you.
- < Today >: previous day, today, next day (or Alt+Left / Alt+Right).
- The day view: hours down the left, every reminder a line with its
  title in the schedule's colour; a red line shows now. What's already done is greyed out; turn on "Hide
  what's done" to hide it.
- Double-click a reminder to edit it, or double-click an empty time to
  add one there. Right-click a reminder: Edit, Remove (or Delete) and
  Mute. Removing a shared event only hides it for you.
- The bell on each reminder: bell = pops up for you; click it to mute
  that reminder (crossed-out bell), that day only or every time. A grey
  bell is another group's event: click it to be notified too
  (megaphone). Click again to switch back.
- New reminder: where to add it, title, optional text, which days, a
  time (once, or repeating every X minutes between two times), a notice,
  and for shared schedules with groups: who it's For.

FONT
The app uses Albert Sans (in the assets folder; SIL Open Font
License, see assets\AlbertSans-OFL.txt). To use another font, put a
.ttf or .otf file in a folder called "fonts" inside this folder and
restart Desk Reminders. Nothing is installed on your PC.

SETTINGS
Sound (Soft chime, Warm bell, Marimba, Kalimba, Glass, Music box, Rising,
Soft ping, Water drop, or your own .wav; volume slider; or off), quiet hours (no pop-ups at
night; each schedule can still be let through under Options), pop-up
corner and screen, Start with Windows (and whether the window opens then),
Back up / Restore (one zip with your schedule, shared schedules and
settings; keep it to yourself).

PRIVACY
Works offline. It only goes online for links you choose to follow (it
downloads them; nothing about you is sent) and, once a day, to ask GitHub
for the latest version number (Settings > Updates to turn off).

SHARED SCHEDULES (guilds, teams, communities)
- Members: Import > From a link (stays up to date), Linked file in a
  synced folder (stays up to date) or From a file. If it has groups (e.g.
  raid teams), tick yours. You see every event in the schedule's colour,
  in your local time. Events for other groups are greyed out "(not you)"
  and don't pop up; events for everyone and for your groups do. When it
  changes, the app tells you what changed for you. Mute single events or
  get another group's pop-ups too with the bell (see above). Your
  schedule.csv is never changed.
- Organisers: + New shared schedule (name, time zone, optional groups,
  one per line). Add the first event right away, or later with Add
  reminder > "Add to". Then Export: Copy for a link (GitHub Gist) or
  Keep a copy updated in a folder, so members get every change by
  themselves; or Save a copy as a file to post.
- Calendars: Import > From a link and paste a Google Calendar ("Secret
  address in iCal format"), Outlook (ICS link) or any .ics/webcal link.
  (By hand: start from shared-schedule.template.csv in this folder.)
A schedule file only contains times and text; it can't run anything.

SOUNDS
The sounds folder holds Desk Reminders' own soft sounds. Put any other
.wav file in it and it shows up in Settings > Sound too.

POP-UPS
In the corner you choose, with a sound. They never take focus away from
the game or app you are in, and close by themselves after 25 seconds.
Snooze 5 min / Snooze 15 min brings them back later.
Reminders at the same minute share one pop-up, each in its own colour.
In games, use windowed or borderless fullscreen so they can show on top.

TRAY MENU (right-click the bell)
Open Desk Reminders, Today's reminders, Import shared schedule, Settings,
Test a reminder, Pause (30 min, 1 hour, until tomorrow 06:00), Resume, Quit.

------------------------------------------------------------------------
EDITING schedule.csv BY HAND (optional)
------------------------------------------------------------------------
Open it in Notepad or Excel. One row per reminder:

  Days,Time,Colour,Title,Text,Notice,For
  Every day,08:30,,Breakfast,Time to eat something.,,
  Wed,20:00,,Raid,Be online.,30,

Save it and the app picks up the change within 10 seconds. If a row has a
mistake, the bell shows a warning saying which line; the other rows keep
working. Lines starting with # are ignored.

DAYS
  Every day
  Weekdays / Weekends
  Mon-Fri, or a list like "Mon,Wed,Fri" (quotes needed when there are commas)
  A single date: 2026-12-24
  A date range: 2026-12-01 to 2026-12-31

TIME
  08:30                         once, at that time (24-hour clock)
  every 60 min 10:00-17:00      repeats, from the first to the last time
  every 30 min 09:30-21:30      any step of 5 minutes or more
  hourly 08:00-21:00            same as every 60 min

  If a one-off time and a repeating reminder land on the same minute,
  the one-off wins.

COLOUR
  Leave empty: the colour comes from the schedule (see COLOURS above).
  skip = no reminder at that time:
    Weekdays,12:00,skip,,,,        no reminder at 12:00 on weekdays
    2026-12-24,all day,skip,,,,    clears the usual schedule on that date;
                                   rows written for 2026-12-24 still run

TEXT
  Optional. Put quotes around it if it contains a comma.

NOTICE
  Optional. Minutes before the reminder for a heads-up, e.g. 15. Empty = none.

FOR (shared schedules with groups)
  Optional. Which group(s) the event is for, separated by |, e.g.
  Raid Team 1|Raid Team 2. Empty = everyone. The groups are listed in the
  file as:  #! groups = Raid Team 1 | Raid Team 2 | Raid Team 3

CHECK A DAY FROM POWERSHELL
  powershell -ExecutionPolicy Bypass -File DeskReminders.ps1 -ListFor 2026-12-01

STOPPING FOR GOOD
Untick Start with Windows in Settings (or run Remove-From-Startup.cmd),
then Quit from the tray.

Greetings from 7ab9ne3021sn4b
