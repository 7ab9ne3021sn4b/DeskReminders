# Troubleshooting

### "Windows protected your PC" when I start it
Windows shows this for new programs that aren't code-signed. Click **More info → Run anyway**.
Everything Desk Reminders does is in `DeskReminders.ps1`, which you can open in Notepad and read.

If the files were downloaded and Windows still blocks them, right-click the zip **before
extracting** → **Properties** → tick **Unblock** → **OK**, then extract again.

### My antivirus flagged it
Some antivirus programs are wary of `.cmd` files that start PowerShell, which is how Desk
Reminders starts. Only download it from the official
[Releases page](https://github.com/7ab9ne3021sn4b/DeskReminders/releases), and compare the
zip's SHA-256 checksum with the one in the release notes:

```powershell
Get-FileHash .\DeskReminders-v1.0.0.zip -Algorithm SHA256
```

### I don't see the bell in the tray
Click the `^` arrow next to the clock. To keep it visible: **Settings → Personalization →
Taskbar → Other system tray icons** and switch on **Windows PowerShell**.

### Pop-ups don't show in my game
Set the game to **windowed** or **borderless fullscreen**. In exclusive fullscreen Windows
doesn't let other windows appear on top. The chime still plays.

### The sound is too loud or too quiet
**Settings → Sound → Volume**. You hear the new volume when you let go of the slider.
(The slider works for Desk Reminders' own sounds and for normal 16-bit `.wav` files.)

### No sound
Open the main window → **Settings** and check that *Play a sound* is ticked and the volume isn't
at 0% (click **Play** to hear it), that the `sounds` folder is next to `DeskReminders.ps1`, and that Windows system sounds aren't muted
in the volume mixer.

### A reminder didn't pop up
- Open **Today's reminders** from the tray menu. Is it listed? If not, check the row in
  `schedule.csv` (a problem is shown at the bottom of that list).
- Was it paused? The tray tooltip says "Paused until …".
- Is it during your **quiet hours** (Settings)? Only schedules allowed through during quiet
  hours pop up then. Your own reminders are not allowed through unless you tick that box.
- Is it a shared event for another group? Those are greyed out with *(not you)* and don't pop
  up. Pick your groups: click **⋯** on the schedule on the left → **Options**
- Is it muted? A crossed-out bell 🔕 in front of the time means no pop-up; click it to turn it
  back on.
- Is the schedule turned off? Its switch in the **Schedules** list must be on (blue).
- Reminders only fire while the PC is on and awake. Missed ones aren't shown later.
- Check that the Windows clock and time zone are right.

### "Desk Reminders is already running"
It only runs once at a time. Look for the bell in the tray (see above).

### I changed schedule.csv in Excel and now everything is on one line / in one column
Save it as **CSV (Comma delimited)** or **CSV UTF-8**. Semicolon-separated files work too,
but don't mix both in one file.

### It doesn't start when I log in
**Settings** → untick and tick *Start Desk Reminders when I log in* again, then **Save** (or
run `Add-To-Startup.cmd` again). If you moved the Desk Reminders folder, the startup entry
still points to the old place, so this fixes that.

### A PowerShell window stays open
Start Desk Reminders with **Start-Reminders.cmd** (not by right-clicking the `.ps1`). It uses
the classic Windows console, which can be hidden; Windows Terminal can't hide its windows.
A black window may flash for a moment while it starts; that's normal.

### A followed link says "link problem"
Click **⋯** on the schedule → **Options** to see what went wrong, then **Check now**.
- *Doesn't contain a schedule or a calendar / looks like a web page*: you pasted the page, not the
  file. For a GitHub Gist the app fixes this itself; for other sites use the "Raw" or "Download"
  link. For Google Calendar use the **Secret address in iCal format**, not the normal share link.
- *Couldn't connect / no answer*: you're offline or the site is down. The last version you have
  keeps working, and the app tries again every 20 minutes.
- *403 / 404*: the link is private, was removed, or changed. Ask the organiser for the new link.

### A linked file in a synced folder doesn't update
Check that the sync app (OneDrive, Google Drive, Dropbox) is running and the file is downloaded
on this PC. The card shows *link problem* if the file is missing.

### Pop-ups appear on the wrong screen or corner
**Settings → Pop-ups**: pick the corner and screen, click **Test**, then **Save**.

### I removed something by mistake
Click **Undo** in the main window (or press Ctrl+Z). It takes back the last
change. Hidden shared events can also be brought back: click **⋯** on the schedule → **Options** → *Show the hidden events again*.

### A shared event shows at the wrong time
Check the `#! timezone = …` line in the shared file (see
[shared schedules](shared-schedules.md)). If the time zone isn't recognised, the app says so under
**Schedules** list and uses the times as your local time. Also check your Windows time zone:
**Settings → Time & language → Date & time**.

### Still stuck?
[Open an issue](https://github.com/7ab9ne3021sn4b/DeskReminders/issues/new/choose) with your
Windows version and what you see.
