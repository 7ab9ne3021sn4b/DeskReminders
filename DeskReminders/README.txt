DESK REMINDERS
==============
Pop-up + sound reminders on Windows 10/11, from a schedule you set up yourself.
Version 1.0.0  -  free, open source (MIT licence) and offline
Home page, guides, updates and bug reports: https://github.com/7ab9ne3021sn4b/DeskReminders

SET UP
1. Unzip this folder somewhere permanent, e.g. Documents\DeskReminders.
2. Double-click Start-Reminders.cmd. A short welcome animation plays, then
   the main window opens. A blue bell stays in the system tray (bottom
   right, maybe behind the ^ arrow); double-click it to open the window.
3. The first time, pick a few ready-made templates (water, moving, meals...)
   or start empty.
4. Optional: Settings > "Start Desk Reminders when I log in to Windows".

If Windows shows "Windows protected your PC", click More info > Run anyway.

UPDATING FROM AN OLDER VERSION
Quit from the tray, copy the new files over your old folder, start again.
Your schedule.csv, shared folder and settings.json are not in the download,
so your reminders and settings stay as they are.

THE MAIN WINDOW
Left: SCHEDULES - My schedule and every shared schedule, each in its own
colour.
- Templates (next to the title): ready-made reminders you can adjust
  (Hydration: every how many minutes, from/to, glass size; Move; Eye
  breaks; Meals; Bedtime).
- Import / Export (top): add a schedule someone shared with you /
  save a shared schedule you made as a file to post.
- Click a schedule to select it. Options: its name (your own schedule),
  colour, your groups, pop-ups during quiet hours, hidden events. The
  checkbox turns a shared schedule on or off. Remove: empties your own
  schedule (Undo brings it back) or takes a shared one off this PC.
- + New shared schedule (bottom): make one for your guild or team.
Right: YOUR WEEK
- Next up: the next reminder that will pop up for you.
- Pick a day. Coloured dots show which schedules have something that day.
  Pick a date opens a calendar to jump to any date, or type one (e.g.
  24-12-2026 or 24 dec). Today jumps back.
- Today's list hides what's already done. Untick "Hide what's done" to
  see those greyed out.
- Add reminder: where to add it, title, optional text, which days, a
  time (once, or repeating every X minutes between two times), a notice,
  and for shared schedules with groups: who it's For.
- Alert (the first column): bell = pops up for you; click it to
  mute that reminder (crossed-out bell), that day only or every time.
  A grey bell is another group's event: click it to be notified too
  (megaphone). Click again to switch back.
- Edit (or double-click), Remove (or Delete), Undo (or Ctrl+Z).
  Removing a shared event only hides it for you.
Menu bar: Settings, and GitHub (how to use, guides, troubleshooting,
what's new, report a problem; opens in your browser).

SETTINGS
Sound (Soft chime, Warm bell, Marimba, Kalimba, Glass, Music box, Rising,
Soft ping, Water drop, or your own .wav; volume slider; or off), quiet hours (no pop-ups at
night; each schedule can still be let through under Options), pop-up
corner and screen, Start with Windows, welcome screen on/off,
Back up / Restore (one zip with your schedule, shared schedules and
settings; keep it to yourself).

SHARED SCHEDULES (guilds, teams, communities)
- Members: Import > pick the file. If it has groups (e.g. raid teams),
  tick yours. You see every event in the schedule's colour, in your local
  time. Events for other groups are greyed out "(not you)" and don't pop
  up; events for everyone and for your groups do. Update: import the newer
  file; the app tells you what changed for you. Mute single events or get
  another group's pop-ups too with the bell (see above). Your schedule.csv
  is never changed.
- Organisers: + New shared schedule (name, time zone, optional groups,
  one per line). Add the first event right away, or later with Add
  reminder > "Add to". Then Export and post the file. Change it any
  time and export again.
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
