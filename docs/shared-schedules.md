# Shared schedules

A shared schedule is a schedule file for a group: a guild, a team, a Discord community.
One person writes it, everyone imports it. It runs **next to** each member's own reminders and
never changes their `schedule.csv`.

You can share it three ways: as a **link** that stays up to date (a free GitHub Gist), as a
**file in a synced folder** (OneDrive, Google Drive, Dropbox) that stays up to date, or as a
**plain file** you post in Discord. A schedule file only holds times and text, so importing one
can't run anything on a PC. Members can also follow a **calendar** (Google Calendar, Outlook,
any `.ics` link) directly.

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
   Later: main window → **New reminder** → choose your schedule under **Add to**
   (or pick **+ New shared schedule** there to make another one), then fill in the event as
   usual. **Notice** gives members a heads-up before it starts. If the schedule has groups,
   tick who it's **For**: *Everyone*, or one or more groups.
5. Events from your schedule show in your own main window with *(yours)* in the **Schedule**
   column. **Edit** and **Remove** work on them like on your own reminders.
   *Remove → Only this day* cancels that one date for everyone (after you share again).
6. Click **Export** (top of the **Schedules** list) and pick how to share it (see below).

### Share it so it stays up to date

**Option A: a link (GitHub Gist, free), best for a whole guild**

1. **Export → Copy for a link (GitHub Gist)**. The schedule is copied and gist.github.com opens
   (log in or make a free GitHub account).
2. File name: e.g. `Guild Schedule.csv`. Paste into the big box, click **Create secret gist**.
   *Secret* means it isn't listed publicly; only people with the link can open it.
3. Copy the page's link and post it in Discord. Members: **Import → From a link** → paste.
4. **After a change:** Export → Copy for a link again, open your gist, **Edit**, select all,
   paste, **Update**. Members get it within 20 minutes and see what changed for them.

**Option B: a synced folder (OneDrive, Google Drive, Dropbox), best for a small team**

1. **Export → Keep a copy updated in a folder** and pick a folder that's synced and shared with
   your members.
2. Members: **Import → Linked file in a synced folder** and pick the file in their copy of that
   folder.
3. From then on every change you make is copied there automatically, and members get it within
   seconds of their sync app downloading it. You don't have to do anything.

**Option C: a plain file**

**Export → Save a copy as a file** saves it (e.g. on your Desktop) and opens Explorer, ready to
drag into Discord. After a change, export and post it again; members import it again. The file
carries the date you last changed it, so members can see which version they have.

### Already have a calendar?

If your guild already keeps its events in Google Calendar, Outlook or another calendar app,
members can follow that calendar directly, with no schedule file needed:

- **Google Calendar:** Settings → pick the calendar → *Integrate calendar* → **Secret address in
  iCal format** (or *Public address in iCal format* for a public calendar).
- **Outlook.com / Microsoft 365:** Settings → Calendar → Shared calendars → *Publish a calendar*
  → **ICS** link.
- **Others** (Apple iCloud public calendars, Teamup, Discord bots that export iCal): any link
  ending in `.ics` or starting with `webcal://`.

Members: **Import → From a link** → paste it. Events for the next 4 months show up in each
member's local time, with a heads-up if the calendar event has a reminder. All-day events are
left out. Calendars don't have groups, so everyone gets every event (members can still mute
single events with the bell).

To change the groups later: click **⋯** on the schedule on the left → **Options** → *Groups*.
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

- **Import:** click **Import** (under the **Schedules** list in the main window):
  - **From a link** for a Gist or calendar link: it's checked every 20 minutes. The card shows
    *Link* or *Calendar link*; **Options → Check now** checks right away.
  - **Linked file in a synced folder** for a file in OneDrive / Google Drive / Dropbox: changes
    come in within seconds.
  - **From a file** for a file posted in Discord: a one-time copy.

  The app checks every row first and tells you if anything is wrong.
- **Pick your group(s):** if the schedule has groups, tick the ones you're in. You see every
  event; events for other groups are greyed out with *(not you)* and don't pop up. Events for
  *Everyone* and for your groups do. Change it any time: click **⋯** on the schedule on the left → **Options**
- **See it:** guild events appear in the main window in the schedule's colour, with its
  name in the **Schedule** column, and pop-ups show the name (and group) above the title.
- **Mute or join one event:** click the bell on the event in the timeline. 🔔 pops up for
  you → click to mute (🔕), that day only or every time. A grey bell is another group's event →
  click it to be notified too (📢). Click again to switch back. Only you are affected.
- **Colour and quiet hours:** click **⋯** on the schedule → **Options** sets the schedule's colour and
  whether it may pop up during your quiet hours (on by default for shared schedules, so you
  don't miss a raid; set quiet hours in **Settings**).
- **Update:** links and synced files update by themselves; a short message tells you what changed
  for you (new events for you and for other groups). For a plain file, import the newer one; the
  app shows which version you have and which one you're importing. Your groups, mutes and
  notify-me-toos always stay.
- **Stop following a link:** click **⋯** on it → **Options** → *Stop following*. You keep the last version
  as a normal copy.
- **Turn it off for a while:** turn off its switch in the **Schedules** list.
- **Skip one event:** select it in the main window → **Remove** → *Only this day* or
  *Every time*. This only hides it for you. Click **⋯** on the schedule → **Options** → *Show the hidden events again* brings
  them back.
- **Remove it completely:** select it in the **Schedules** list → **Remove**.

When a guild event and one of your own reminders fall on the same minute, both appear in one
pop-up with one sound.

Imported files are kept in the `shared` folder inside the Desk Reminders folder.
