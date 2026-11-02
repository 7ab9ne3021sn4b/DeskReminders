# Shared schedules

A shared schedule is a schedule file for a group: a guild, a team, a Discord community.
One person writes it, everyone imports it. It runs **next to** each member's own reminders and
never changes their `schedule.csv`.

Everything stays offline: you share the file however you like (Discord, email, a USB stick),
and Desk Reminders never downloads anything itself. A schedule file only holds times and text,
so importing one can't run anything on a PC.

## For organisers: make the schedule

### In the app (recommended)

1. In the main window, click **+ New shared schedule** (bottom of the **Schedules** list on the left).
2. Enter a **name** (members see it on pop-ups and in their lists) and pick **Times are in**:
   your group's "server time", e.g. *Amsterdam, Berlin, Rome, Stockholm (CET)*. Each member's
   app converts the times to their own local time, so 20:00 Amsterdam shows as 19:00 for
   someone in London.
3. Optional: list your **groups**, one per line (e.g. *Raid Team 1* … *Raid Team 5*, or
   *Tanks*, *Healers*). Leave it empty if everyone should get every event.
4. Click **Create**. The app asks whether you want to add the first event right away.
   Later: main window → **Add reminder** → choose your schedule under **Add to**
   (or pick **+ New shared schedule** there to make another one), then fill in the event as
   usual. **Notice** gives members a heads-up before it starts. If the schedule has groups,
   tick who it's **For**: *Everyone*, or one or more groups.
5. Events from your schedule show in your own main window with *(yours)* in the **Schedule**
   column. **Edit** and **Remove** work on them like on your own reminders.
   *Remove → Only this day* cancels that one date for everyone (after you share again).
6. Click **Export** (top of the **Schedules** list) → save the file (for example
   on your Desktop). Explorer opens with the file selected, ready to drag into Discord.

To change the schedule later: edit it in the app, then **Export** again and post the new file.
The file carries the date you last changed it, so members can see which version they have.

To change the groups later: select the schedule on the left → **Options** → *Groups*.
As the organiser you get every group's pop-ups by default; untick groups under *My groups*
in the same window if you don't want that.

The schedule you made lives only on your PC (it's included in **Settings → Back up**). If you remove it, or reinstall Windows, keep a
shared copy: import that copy to see it again (you can't edit an imported copy).

### By hand (optional)

Prefer Notepad or Excel? Start from `shared-schedule.template.csv` in the Desk Reminders folder.
Set the lines at the top:

```csv
#! name = Guild Schedule
#! timezone = Europe/Amsterdam
#! groups = Raid Team 1 | Raid Team 2 | Raid Team 3
```

The `groups` line is optional. Then add rows in the same format as `schedule.csv`
([full format](schedule-format.md)). The **For** column says which group(s) an event is for,
separated by `|`; leave it empty for everyone:

```csv
Days,Time,Colour,Title,Text,Notice,For
Every day,17:00,,Dungeons,Group up in Discord.,15,
Wed,20:00,,Raid night,Be online and repaired.,30,Raid Team 1
Thu,20:00,,Raid night,Be online and repaired.,30,Raid Team 2|Raid Team 3
```

Import it yourself first to check it: any row with a mistake is listed.

### Time zone names

Use names like `Europe/Amsterdam`, `Europe/London`, `Europe/Paris`, `Europe/Berlin`,
`Europe/Warsaw`, `Europe/Helsinki`, `America/New_York`, `America/Chicago`,
`America/Los_Angeles`, `UTC`, or a Windows time zone name such as `W. Europe Standard Time`.
Summer and winter time are handled automatically.

## For members: use it

- **Import:** click **Import** (top of the **Schedules** list in the main window) → pick the file.
  The app checks every row first and tells you if anything is wrong.
- **Pick your group(s):** if the schedule has groups, tick the ones you're in. You see every
  event; events for other groups are greyed out with *(not you)* and don't pop up. Events for
  *Everyone* and for your groups do. Change it any time: select the schedule on the left → **Options**
- **See it:** guild events appear in the main window in the schedule's colour, with its
  name in the **Schedule** column, and pop-ups show the name (and group) above the title.
- **Mute or join one event:** click the bell in front of its time in the list. 🔔 pops up for
  you → click to mute (🔕), that day only or every time. A grey bell is another group's event →
  click it to be notified too (📢). Click again to switch back. Only you are affected.
- **Colour and quiet hours:** select the schedule → **Options** sets the schedule's colour and
  whether it may pop up during your quiet hours (on by default for shared schedules, so you
  don't miss a raid; set quiet hours in **Settings**).
- **Update:** import the newer file. The app shows which version you have and which one you're
  importing, replaces only that schedule, and tells you what changed for you (new events for you
  and for other groups). Your groups, mutes and notify-me-toos stay.
- **Turn it off for a while:** untick its checkbox in the **Schedules** list.
- **Skip one event:** select it in the main window → **Remove** → *Only this day* or
  *Every time*. This only hides it for you. Select the schedule → **Options** → *Show the hidden events again* brings
  them back.
- **Remove it completely:** select it in the **Schedules** list → **Remove**.

When a guild event and one of your own reminders fall on the same minute, both appear in one
pop-up with one sound.

Imported files are kept in the `shared` folder inside the Desk Reminders folder.
