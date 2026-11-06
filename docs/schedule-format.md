# schedule.csv format

The easiest way to manage reminders is the **main window** (double-click the tray bell).
This page is for people who prefer editing the file directly, in Notepad or Excel.

`schedule.csv` lives in the Desk Reminders folder. Save it and the app reloads it within
10 seconds. No restart needed.

## Columns

```csv
Days,Time,Colour,Title,Text,Notice,For
Every day,08:30,,Breakfast,Time to eat something.,,
```

| Column | Required | What goes in it |
|---|---|---|
| **Days** | yes | Which days the reminder runs. See [Days](#days). |
| **Time** | yes | When it pops up. See [Time](#time). |
| **Colour** | no | Leave empty, or `skip`. See [Colour](#colour). |
| **Title** | yes | Big text on the pop-up. |
| **Text** | no | Smaller text under the title. |
| **Notice** | no | Minutes before, for an extra heads-up pop-up ("Starts in 15 minutes"). Empty or 0 = none. |
| **For** | no | Shared schedules with groups only: which group(s), separated by `\|`. Empty = everyone. See [Groups](#groups). |

- Lines starting with `#` are ignored, so you can use them for notes.
- Put a value in double quotes when it contains a comma: `"Mon,Wed,Fri"`, `"Call Sam, then eat"`.
- The header may say `Color` instead of `Colour`.
- Excel with Dutch or other European settings saves with semicolons (`;`). That works too.
- Notice and For may be left out of the header. They're added automatically when you add a
  reminder from the main window.

## Days

| Write | Means |
|---|---|
| `Every day` (or `Daily`) | every day |
| `Weekdays` | Monday to Friday |
| `Weekends` | Saturday and Sunday |
| `Mon` / `Monday` | every Monday (any day name, short or full) |
| `Mon-Fri`, `Fri-Mon` | a range of days (can wrap around the weekend) |
| `"Mon,Wed,Fri"` | a list (in quotes, because of the commas) |
| `2026-12-24` | one date (year-month-day) |
| `2026-12-01 to 2026-12-31` | every day in a date range |

## Time

| Write | Means |
|---|---|
| `08:30` | once, at 08:30 (24-hour clock) |
| `every 30 min 09:00-17:00` | 09:00, 09:30, 10:00 … 17:00 |
| `every 90 min 08:00-20:00` | any step from 5 minutes up |
| `hourly 08:00-21:00` | same as `every 60 min 08:00-21:00` |
| `all day` | only together with Colour `skip` (see below) |

Within one file, if a one-off time and a repeating reminder fall on the same minute, the one-off wins,
so you get one pop-up, not two. (In the full example at the bottom, *Lunch* replaces the
12:00 *Stand up*.)

## Colour

The colour belongs to the **schedule**, not to each row: your own reminders
are blue, the first shared schedule is green, the next purple, and so on. Change them in the app:
click **⋯** on the schedule in the **Schedules** list on the left → **Options**

Colour names (`green`, `red`, …) in this column are ignored. The only value that means
something here is `skip`.

### skip

`skip` removes whatever would pop up at that time. Title and Text can stay empty.

```csv
Weekdays,12:00,skip,,,,
```
No reminder at 12:00 on weekdays, even if a repeating reminder would normally fire then.

```csv
2026-12-25,all day,skip,,,,
2026-12-25,10:00,,Presents,Open them!,,
```
`all day` + `skip` clears your **usual** schedule on that date. Rows written for that exact
date (like `Presents` above) still run. Good for holidays and special days.

The main window writes `skip` rows for you when you remove one occurrence of a
repeating reminder ("only this day").

## Settings lines (`#!`)

Lines starting with `#!` are settings for the whole file. They're mainly for
[shared schedules](shared-schedules.md):

```csv
#! name = Guild Schedule
#! timezone = Europe/Amsterdam
```

- `name`: the name shown on pop-ups and in lists.
- `timezone`: the time zone the file's times are written in; they're converted to your local time.
- `groups`: the groups members can pick, separated by `|`: `#! groups = Raid Team 1 | Raid Team 2`.
- `updated`: when the schedule was last changed (`2026-11-02 14:55`). The app sets this itself for
  schedules you made, and shows it to members when they import.

## Groups

A shared schedule can have groups, for example five raid teams in one guild. List them in a
`#! groups` line and say per row who it's for in the **For** column:

```csv
#! groups = Raid Team 1 | Raid Team 2 | Raid Team 3
Days,Time,Colour,Title,Text,Notice,For
Wed,20:00,,Raid night,Be online.,30,Raid Team 1
Thu,20:00,,Raid night,Be online.,30,Raid Team 2|Raid Team 3
Sun,19:00,,Guild meeting,Everyone welcome.,15,
```

Members tick their group(s) when they import. They see every event, but events for other groups
are greyed out and don't pop up. Rows with an empty **For** (or `Everyone`) pop up for everybody.
A group used in **For** but missing from the `#! groups` line is added to the list automatically.

## Several reminders at the same time

Reminders from different files (your own and shared ones), or a notice and a reminder, can land
on the same minute. They're shown together in one pop-up, with one sound. Within one file,
two repeating reminders at the same minute (say *Drink water* and *Move* every hour) both show.

## Mistakes

If a row can't be read, the tray bell shows a warning with the line number, and the
main window and **Today's reminders** list the problem. The other rows keep working.

## Check a day without waiting

Open PowerShell in the Desk Reminders folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File DeskReminders.ps1 -ListFor 2026-12-01
```

## A full example

```csv
Days,Time,Colour,Title,Text,Notice,For
# Mornings
Every day,07:30,,Breakfast,Time to eat something.,,
Weekdays,08:45,,Start work,Open your task list.,,

# Move and drink during the day
Weekdays,every 60 min 10:00-17:00,,Stand up,Stretch and drink some water.,,
Weekdays,12:00,,Lunch,Away from the screen.,,

# Evenings
Every day,22:00,,Wind down,Screens off in 30 minutes.,,

# Holidays
2026-12-25,all day,skip,,,,
2026-12-25,10:00,,Presents,Open them!,,
```
