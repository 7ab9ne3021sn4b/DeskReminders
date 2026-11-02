# Desk Reminders
# https://github.com/7ab9ne3021sn4b/DeskReminders  -  MIT licence
#
# Pop-up + sound reminders from your own schedule (schedule.csv) and from shared
# schedules you import (the shared folder). Runs from the system tray.
# Double-click the tray icon to open the schedule.
#
# Check what a day looks like without starting the app:
#   powershell -ExecutionPolicy Bypass -File DeskReminders.ps1 -ListFor 2026-12-01

param([string]$ListFor, [switch]$InstallStartup, [switch]$RemoveStartup)

$AppVersion   = '1.0.0'
$ScheduleFile = Join-Path $PSScriptRoot 'schedule.csv'
$TemplateFile = Join-Path $PSScriptRoot 'schedule.template.csv'
$SharedDir    = Join-Path $PSScriptRoot 'shared'
$SettingsFile = Join-Path $PSScriptRoot 'settings.json'
$IconFile     = Join-Path $PSScriptRoot 'DeskReminders.ico'
$PopupSeconds = 25
$RepoUrl      = 'https://github.com/7ab9ne3021sn4b/DeskReminders'
$Greeting     = 'Greetings from 7ab9ne3021sn4b'
$MineColor    = '#1F4E8C'
$script:DefaultColor = $MineColor   # copy that dialogs can't shadow
# Colours handed out to shared schedules, in this order (changeable per schedule)
$SchedulePalette = [ordered]@{
    Green = '#2E6B3A'; Purple = '#5B3F9E'; Orange = '#B5541B'; Teal = '#0F6E6E'
    Pink = '#A23B6B'; Gold = '#8A6A0E'; Slate = '#4A5560'; Red = '#A11A1A'; Blue = '#1F4E8C'
}

# First run: start from the empty template. Your own schedule.csv is never overwritten.
if (-not (Test-Path $ScheduleFile) -and (Test-Path $TemplateFile)) { Copy-Item -LiteralPath $TemplateFile -Destination $ScheduleFile }
$En = [Globalization.CultureInfo]::GetCultureInfo('en-US')

$Colors = [ordered]@{
    blue   = '#1F4E8C'
    green  = '#2E6B3A'
    orange = '#B33A0B'
    purple = '#3B2E6B'
    black  = '#161616'
    red    = '#A11A1A'
    teal   = '#0F5E5E'
}

$DayNames = @{
    mon = 1; monday = 1; tue = 2; tuesday = 2; wed = 3; wednesday = 3
    thu = 4; thursday = 4; fri = 5; friday = 5; sat = 6; saturday = 6
    sun = 7; sunday = 7
}

# Common time zone names -> Windows time zone IDs (Windows IDs work directly too)
$TzAliases = @{
    'utc' = 'UTC'; 'gmt' = 'UTC'
    'europe/amsterdam' = 'W. Europe Standard Time'; 'europe/berlin' = 'W. Europe Standard Time'
    'europe/rome' = 'W. Europe Standard Time'; 'europe/stockholm' = 'W. Europe Standard Time'
    'europe/vienna' = 'W. Europe Standard Time'; 'europe/zurich' = 'W. Europe Standard Time'
    'europe/paris' = 'Romance Standard Time'; 'europe/brussels' = 'Romance Standard Time'
    'europe/madrid' = 'Romance Standard Time'; 'europe/copenhagen' = 'Romance Standard Time'
    'europe/london' = 'GMT Standard Time'; 'europe/dublin' = 'GMT Standard Time'; 'europe/lisbon' = 'GMT Standard Time'
    'europe/warsaw' = 'Central European Standard Time'; 'europe/prague' = 'Central Europe Standard Time'
    'europe/budapest' = 'Central Europe Standard Time'
    'europe/bucharest' = 'GTB Standard Time'; 'europe/athens' = 'GTB Standard Time'
    'europe/helsinki' = 'FLE Standard Time'; 'europe/kyiv' = 'FLE Standard Time'; 'europe/istanbul' = 'Turkey Standard Time'
    'europe/moscow' = 'Russian Standard Time'
    'america/new_york' = 'Eastern Standard Time'; 'america/chicago' = 'Central Standard Time'
    'america/denver' = 'Mountain Standard Time'; 'america/los_angeles' = 'Pacific Standard Time'
    'america/sao_paulo' = 'E. South America Standard Time'
    'asia/tokyo' = 'Tokyo Standard Time'; 'asia/seoul' = 'Korea Standard Time'; 'asia/shanghai' = 'China Standard Time'
    'australia/sydney' = 'AUS Eastern Standard Time'
}

# Choices for "Times are in" when creating a shared schedule
$FriendlyZones = @(
    @('Amsterdam, Berlin, Rome, Stockholm (CET)', 'Europe/Amsterdam'),
    @('Paris, Brussels, Madrid (CET)', 'Europe/Paris'),
    @('Warsaw (CET)', 'Europe/Warsaw'),
    @('Prague, Budapest (CET)', 'Europe/Prague'),
    @('London, Dublin, Lisbon (GMT/BST)', 'Europe/London'),
    @('Athens, Bucharest (EET)', 'Europe/Athens'),
    @('Helsinki, Kyiv (EET)', 'Europe/Helsinki'),
    @('Istanbul', 'Europe/Istanbul'),
    @('Moscow', 'Europe/Moscow'),
    @('New York, Toronto (Eastern)', 'America/New_York'),
    @('Chicago (Central)', 'America/Chicago'),
    @('Denver (Mountain)', 'America/Denver'),
    @('Los Angeles (Pacific)', 'America/Los_Angeles'),
    @('Sao Paulo', 'America/Sao_Paulo'),
    @('Tokyo', 'Asia/Tokyo'),
    @('Seoul', 'Asia/Seoul'),
    @('Shanghai, Beijing', 'Asia/Shanghai'),
    @('Sydney', 'Australia/Sydney'),
    @('UTC', 'UTC')
)

# ---------------------------------------------------------------------------
# PARSING
# ---------------------------------------------------------------------------
function Parse-Date([string]$s) {
    $d = [datetime]::MinValue
    if ([datetime]::TryParseExact($s, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$d)) { return $d }
    return $null
}

function Parse-Days([string]$spec) {
    $s = ($spec -replace '\s+', ' ').Trim().ToLower()
    if ($s -in @('every day', 'everyday', 'daily', '*')) { return @{ Kind = 'all' } }
    if ($s -eq 'weekdays') { return @{ Kind = 'week'; Days = @(1, 2, 3, 4, 5) } }
    if ($s -eq 'weekends') { return @{ Kind = 'week'; Days = @(6, 7) } }
    if ($s -match '^\d{4}-\d{2}-\d{2}$') {
        $d = Parse-Date $s
        if ($d) { return @{ Kind = 'date'; Date = $d } } else { return $null }
    }
    if ($s -match '^(\d{4}-\d{2}-\d{2})\s*(\.\.|to)\s*(\d{4}-\d{2}-\d{2})$') {
        $a = Parse-Date $Matches[1]; $b = Parse-Date $Matches[3]
        if ($a -and $b -and $a -le $b) { return @{ Kind = 'range'; From = $a; To = $b } } else { return $null }
    }
    $days = @()
    foreach ($tok in ($s -split ',')) {
        $t = $tok.Trim()
        if ($t -match '^([a-z]+)\s*-\s*([a-z]+)$') {
            if (-not ($DayNames.ContainsKey($Matches[1]) -and $DayNames.ContainsKey($Matches[2]))) { return $null }
            $i = $DayNames[$Matches[1]]; $j = $DayNames[$Matches[2]]
            while ($true) { $days += $i; if ($i -eq $j) { break }; $i = ($i % 7) + 1 }
        }
        elseif ($DayNames.ContainsKey($t)) { $days += $DayNames[$t] }
        else { return $null }
    }
    if ($days.Count -eq 0) { return $null }
    return @{ Kind = 'week'; Days = $days }
}

function Parse-Clock([string]$s) {
    if ($s -match '^(\d{1,2}):(\d{2})$') {
        $h = [int]$Matches[1]; $m = [int]$Matches[2]
        if ($h -le 23 -and $m -le 59) { return $h * 60 + $m }
    }
    return $null
}

# Returns @{ Repeat; AllDay; Minutes } or $null if invalid.
function Parse-Time([string]$spec) {
    $s = ($spec -replace '\s+', ' ').Trim().ToLower()
    if ($s -eq 'all day') { return @{ Repeat = $false; AllDay = $true; Minutes = @() } }
    $one = Parse-Clock $s
    if ($null -ne $one) { return @{ Repeat = $false; AllDay = $false; Minutes = @($one) } }

    $step = $null; $from = $null; $to = $null
    if ($s -match '^every (\d+) ?min(utes)? (\d{1,2}:\d{2}) ?- ?(\d{1,2}:\d{2})$') {
        $step = [int]$Matches[1]; $from = Parse-Clock $Matches[3]; $to = Parse-Clock $Matches[4]
    }
    elseif ($s -match '^hourly (\d{1,2}:\d{2}) ?- ?(\d{1,2}:\d{2})$') {
        $step = 60; $from = Parse-Clock $Matches[1]; $to = Parse-Clock $Matches[2]
    }
    if ($step -and $step -ge 5 -and $null -ne $from -and $null -ne $to -and $from -le $to) {
        $list = @(); for ($m = $from; $m -le $to; $m += $step) { $list += $m }
        return @{ Repeat = $true; AllDay = $false; Minutes = $list }
    }
    return $null
}

function Resolve-TimeZone([string]$name) {
    $n = $name.Trim()
    $candidates = @()
    if ($TzAliases.ContainsKey($n.ToLower())) { $candidates += $TzAliases[$n.ToLower()] }
    $candidates += $n
    foreach ($id in $candidates) {
        try { return [TimeZoneInfo]::FindSystemTimeZoneById($id) } catch {}
    }
    return $null
}

# Reads one schedule file (your schedule.csv or a shared one).
# Lines starting with "#!" are settings: "#! name = Guild Schedule", "#! timezone = Europe/Amsterdam".
function Read-ScheduleFile([string]$path) {
    $result = @{ Rows = @(); Errors = @(); Delim = ','; Name = ''; Tz = $null; TzText = ''; Updated = ''; Groups = @(); HasHeader = $false }
    if (-not (Test-Path -LiteralPath $path)) { $result.Errors = @('file not found'); return $result }
    $lines = @(Get-Content -LiteralPath $path -Encoding UTF8)
    $header = $null
    $rows = @(); $errors = @()
    for ($n = 0; $n -lt $lines.Count; $n++) {
        $line = [string]$lines[$n]
        $trim = $line.Trim().Trim('"').Trim()
        if ($trim.StartsWith('#!')) {
            $directive = ($trim.Substring(2) -replace '[,;"]+$', '').Trim()
            if ($directive -match '^([A-Za-z ]+?)\s*[=:]\s*(.+)$') {
                $key = $Matches[1].Trim().ToLower() -replace ' ', ''
                $val = ($Matches[2] -replace '[,;"]+$', '').Trim()
                if ($key -eq 'name') { $result.Name = $val }
                elseif ($key -in @('timezone', 'tz')) { $result.TzText = $val }
                elseif ($key -eq 'updated') { $result.Updated = $val }
                elseif ($key -eq 'groups') { $result.Groups = @($val -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
            }
            continue
        }
        if ($trim -eq '' -or $trim.StartsWith('#')) { continue }
        if ((($line -replace '[,;"\s]', '')) -eq '') { continue }   # empty row saved by Excel
        if (-not $header) {
            $header = $line
            if ($line.Contains(';') -and -not $line.Contains(',')) { $result.Delim = ';' }  # Dutch/European Excel
            continue
        }
        $r = @(@($header, $line) | ConvertFrom-Csv -Delimiter $result.Delim)[0]
        $lineNo = $n + 1
        if (-not $r) { $errors += "line ${lineNo}: could not read this row"; continue }

        $daysText = ([string]$r.Days).Trim()
        $timeText = ([string]$r.Time).Trim()
        $days  = Parse-Days $daysText
        $time  = Parse-Time $timeText
        $colRaw = if ($r.PSObject.Properties['Colour']) { $r.Colour } else { $r.Color }
        $color = ([string]$colRaw).Trim().ToLower()
        $title = ([string]$r.Title).Trim()
        $noticeText = if ($r.PSObject.Properties['Notice']) { ([string]$r.Notice).Trim() } else { '' }
        $notice = 0

        if (-not $days) { $errors += "line ${lineNo}: Days '$daysText' not understood. Use Every day, Weekdays, Weekends, Mon-Fri, a date like 2026-12-24, or 2026-12-01 to 2026-12-31"; continue }
        if (-not $time) { $errors += "line ${lineNo}: Time '$timeText' not understood. Use 24-hour time like 09:30, or every 60 min 10:00-17:00"; continue }
        # The colour now comes from the schedule; only 'skip' still has a meaning here
        if ($color -ne 'skip') { $color = '' }
        $forText = if ($r.PSObject.Properties['For']) { ([string]$r.For).Trim() } else { '' }
        $for = @($forText -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne 'everyone' })
        if ($time.AllDay -and $color -ne 'skip') { $errors += "line ${lineNo}: 'all day' only works with Colour skip"; continue }
        if ($color -ne 'skip' -and $title -eq '') { $errors += "line ${lineNo}: Title is empty"; continue }
        if ($noticeText -ne '') {
            if ($noticeText -match '^\d{1,4}$' -and [int]$noticeText -le 1440) { $notice = [int]$noticeText }
            else { $errors += "line ${lineNo}: Notice '$noticeText' must be a number of minutes (0-1440)"; continue }
        }

        $rows += [pscustomobject]@{
            Line = $lineNo; Days = $days; Time = $time; Colour = $color
            Title = $title; Text = ([string]$r.Text).Trim(); Notice = $notice
            DaysText = $daysText; TimeText = $timeText; For = $for
        }
        foreach ($g in $for) { if ($result.Groups -notcontains $g) { $result.Groups += $g } }
    }
    if ($header) { $result.HasHeader = $true } else { $errors += 'no header row (Days,Time,Colour,Title,Text,Notice)' }
    if ($result.TzText -ne '') {
        $result.Tz = Resolve-TimeZone $result.TzText
        if (-not $result.Tz) { $errors += "time zone '$($result.TzText)' not recognised, so times are used as your local time" }
    }
    $result.Rows = $rows
    $result.Errors = $errors
    return $result
}

function Test-DayMatch($days, [datetime]$date) {
    $dow = [int]$date.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
    switch ($days.Kind) {
        'all'   { return $true }
        'week'  { return $days.Days -contains $dow }
        'date'  { return $days.Date -eq $date.Date }
        'range' { return ($date.Date -ge $days.From -and $date.Date -le $days.To) }
    }
    return $false
}

# One day of one schedule file, in that file's own time.
# - A one-off time beats a repeating reminder at the same minute.
# - Colour 'skip' removes whatever falls at that time.
# - 'skip' with Time 'all day' clears the regular schedule for that day;
#   rows written for that exact date still run.
function Get-DayEntries($rows, [datetime]$date) {
    $todays = @($rows | Where-Object { Test-DayMatch $_.Days $date })
    $clearDay = @($todays | Where-Object { $_.Colour -eq 'skip' -and $_.Time.AllDay }).Count -gt 0
    if ($clearDay) { $todays = @($todays | Where-Object { $_.Days.Kind -eq 'date' -and -not $_.Time.AllDay }) }

    $byTime = @{}; $skips = @()
    foreach ($r in $todays) {
        foreach ($m in $r.Time.Minutes) {
            $hhmm = '{0:D2}:{1:D2}' -f [int][math]::Floor($m / 60), [int]($m % 60)
            if ($r.Colour -eq 'skip') { $skips += $hhmm; continue }
            if (-not $byTime.ContainsKey($hhmm)) { $byTime[$hhmm] = @{ One = @(); Rep = @() } }
            $entry = [pscustomobject]@{
                Minute = $m; Time = $hhmm; Title = $r.Title; Text = $r.Text
                Notice = $r.Notice; Line = $r.Line; DaysText = $r.DaysText; TimeText = $r.TimeText
                OneOff = ($r.Days.Kind -eq 'date' -and -not $r.Time.Repeat); For = @($r.For)
            }
            if ($r.Time.Repeat) { $byTime[$hhmm].Rep += $entry } else { $byTime[$hhmm].One += $entry }
        }
    }
    $out = @()
    foreach ($k in $byTime.Keys) {
        if ($skips -contains $k) { continue }
        # A one-off reminder replaces repeating ones at the same minute; otherwise they all show
        if ($byTime[$k].One.Count -gt 0) { $out += $byTime[$k].One } else { $out += $byTime[$k].Rep }
    }
    $out | Sort-Object Minute
}

function Test-Hidden($hidden, [string]$key, [string]$date) {
    foreach ($h in $hidden) {
        if ($h.Key -eq $key -and ($h.Date -eq '' -or $h.Date -eq $date)) { return $true }
    }
    return $false
}

# Every reminder and notice that falls on your local dates $from..$to,
# from all enabled schedules, converted to your local time.
function Get-Occurrences($sources, [datetime]$from, [datetime]$to, $hidden) {
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($src in $sources) {
        if (-not $src.Enabled) { continue }
        for ($d = $from.Date.AddDays(-2); $d -le $to.Date.AddDays(1); $d = $d.AddDays(1)) {
            foreach ($e in (Get-DayEntries $src.Rows $d)) {
                # A plain clock time in the schedule's zone (not marked as local, or Windows refuses to convert it)
                $zoneAt = [datetime]::SpecifyKind($d.AddMinutes($e.Minute), [DateTimeKind]::Unspecified)
                $at = $zoneAt
                if ($src.Tz) {
                    $ok = $true
                    try { $at = [TimeZoneInfo]::ConvertTime($zoneAt, $src.Tz, [TimeZoneInfo]::Local) } catch { $ok = $false }
                    if (-not $ok) { continue }   # a time that doesn't exist there (clocks going forward)
                    $at = [datetime]::SpecifyKind($at, [DateTimeKind]::Unspecified)
                }
                $key = ''
                if (-not $src.IsMine) {
                    $key = "$($src.Name)|$($e.DaysText)|$($e.TimeText)|$($e.Title)"
                    if (Test-Hidden $hidden $key $at.ToString('yyyy-MM-dd')) { continue }
                }
                $forMe = $true
                if (-not $src.IsMine -and @($e.For).Count -gt 0) {
                    $forMe = @($e.For | Where-Object { @($src.MyGroups) -contains $_ }).Count -gt 0
                }
                $kinds = @('event')
                if ($e.Notice -gt 0) { $kinds += 'notice' }
                foreach ($kind in $kinds) {
                    $when = if ($kind -eq 'notice') { $at.AddMinutes(-$e.Notice) } else { $at }
                    if ($when.Date -lt $from.Date -or $when.Date -gt $to.Date) { continue }
                    $out.Add([pscustomobject]@{
                        At = $when; Time = $when.ToString('HH:mm'); Kind = $kind
                        EventAt = $at; EventTime = $at.ToString('HH:mm')
                        Colour = $src.Color; Title = $e.Title; Text = $e.Text; Notice = $e.Notice
                        For = @($e.For); ForMe = $forMe; QuietAllow = [bool]$src.QuietAllow
                        Source = $src.Name; IsMine = $src.IsMine; TzText = $src.TzText
                        Line = $e.Line; DaysText = $e.DaysText; TimeText = $e.TimeText
                        OneOff = $e.OneOff; Key = $key; ZoneTime = $e.Time; ZoneDate = $d.ToString('yyyy-MM-dd')
                        File = $src.File; Owned = [bool]$src.Owned; Editable = ($src.IsMine -or [bool]$src.Owned)
                    })
                }
            }
        }
    }
    $out | Sort-Object At, @{ Expression = { if ($_.IsMine) { 0 } else { 1 } } }, Source
}

# ---------------------------------------------------------------------------
# SETTINGS AND SOURCES
# ---------------------------------------------------------------------------
function ConvertTo-Hash($o) {
    $h = @{}
    if ($o -is [System.Collections.IDictionary]) { foreach ($k in $o.Keys) { $h[$k] = $o[$k] }; return $h }
    if ($o) { foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = $p.Value } }
    return $h
}

function Load-Settings {
    $s = @{
        Sound = 'Soft chime.wav'; SoundOn = $true; Volume = 40; MineName = ''; Disabled = @(); Hidden = @(); Alerts = @(); Owned = @()
        Colors = @{}; MyGroups = @{}; QuietAllow = @{}; Quiet = @{ On = $false; From = '23:00'; To = '08:00' }
        Corner = 'BottomRight'; Monitor = 0; Welcomed = $false; ShowWelcome = $true; HidePast = $true; ViewOff = @()
    }
    if (Test-Path -LiteralPath $SettingsFile) {
        try {
            $j = Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.Sound) { $s.Sound = [string]$j.Sound }
            if ($null -ne $j.SoundOn) { $s.SoundOn = [bool]$j.SoundOn }
            if ($j.MineName) { $s.MineName = ([string]$j.MineName).Trim() }
            if ($null -ne $j.Volume) { $s.Volume = [math]::Max(0, [math]::Min(100, [int]$j.Volume)) }
            if ($j.Disabled) { $s.Disabled = @($j.Disabled | ForEach-Object { [string]$_ }) }
            if ($j.Owned) { $s.Owned = @($j.Owned | ForEach-Object { [string]$_ }) }
            if ($j.ViewOff) { $s.ViewOff = @($j.ViewOff | ForEach-Object { [string]$_ }) }
            if ($j.Hidden) { $s.Hidden = @($j.Hidden | ForEach-Object { @{ Key = [string]$_.Key; Date = [string]$_.Date } }) }
            if ($j.Alerts) { $s.Alerts = @($j.Alerts | Where-Object { $_.Mode -in @('mute', 'shout') } | ForEach-Object { @{ Key = [string]$_.Key; Date = [string]$_.Date; Mode = [string]$_.Mode } }) }
            if ($j.Colors) { $s.Colors = ConvertTo-Hash $j.Colors }
            if ($j.QuietAllow) { $qa = ConvertTo-Hash $j.QuietAllow; foreach ($k in @($qa.Keys)) { $s.QuietAllow[$k] = [bool]$qa[$k] } }
            if ($j.MyGroups) { $mg = ConvertTo-Hash $j.MyGroups; foreach ($k in @($mg.Keys)) { $s.MyGroups[$k] = @($mg[$k] | ForEach-Object { [string]$_ }) } }
            if ($j.Quiet) { $q = ConvertTo-Hash $j.Quiet; $s.Quiet = @{ On = [bool]$q.On; From = [string]$q.From; To = [string]$q.To } }
            if ($j.Corner) { $s.Corner = [string]$j.Corner }
            if ($null -ne $j.Monitor) { $s.Monitor = [int]$j.Monitor }
            if ($null -ne $j.Welcomed) { $s.Welcomed = [bool]$j.Welcomed }
            if ($null -ne $j.ShowWelcome) { $s.ShowWelcome = [bool]$j.ShowWelcome }
            if ($null -ne $j.HidePast) { $s.HidePast = [bool]$j.HidePast }
        } catch {}
    }
    return $s
}

function Save-Settings {
    $st = $script:settings
    $mg = [ordered]@{}; foreach ($k in $st.MyGroups.Keys) { $mg[$k] = @($st.MyGroups[$k]) }
    $o = [ordered]@{
        Sound      = $st.Sound
        SoundOn    = [bool]$st.SoundOn
        Volume     = [int]$st.Volume
        MineName   = [string]$st.MineName
        Disabled   = @($st.Disabled)
        Owned      = @($st.Owned)
        ViewOff    = @($st.ViewOff)
        Hidden     = @($st.Hidden | ForEach-Object { [ordered]@{ Key = $_.Key; Date = $_.Date } })
        Alerts     = @($st.Alerts | ForEach-Object { [ordered]@{ Key = $_.Key; Date = $_.Date; Mode = $_.Mode } })
        Colors     = $st.Colors
        QuietAllow = $st.QuietAllow
        MyGroups   = $mg
        Quiet      = $st.Quiet
        Corner     = $st.Corner
        Monitor    = [int]$st.Monitor
        Welcomed   = [bool]$st.Welcomed
        ShowWelcome = [bool]$st.ShowWelcome
        HidePast   = [bool]$st.HidePast
    }
    try { ($o | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch {}
}

function Get-FileStamp([string]$path) {
    if (Test-Path -LiteralPath $path) { return (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks }
    return [long]0
}

function Load-AllSources($settings) {
    $mine = Read-ScheduleFile $ScheduleFile
    $all = @([pscustomobject]@{
        Name = 'Mine'; IsMine = $true; Owned = $false; File = $ScheduleFile; FileName = 'schedule.csv'
        Rows = $mine.Rows; Tz = $null; TzText = ''; Errors = $mine.Errors; Enabled = $true
        Delim = $mine.Delim; Updated = ''; Stamp = (Get-FileStamp $ScheduleFile)
        Color = $(if ($settings.Colors.ContainsKey('schedule.csv')) { $settings.Colors['schedule.csv'] } else { $MineColor }); Groups = @(); MyGroups = @()
        QuietAllow = $(if ($settings.QuietAllow.ContainsKey('schedule.csv')) { [bool]$settings.QuietAllow['schedule.csv'] } else { $false })
    })
    $errors = @($mine.Errors | ForEach-Object { "schedule.csv, $_" })
    if (Test-Path -LiteralPath $SharedDir) {
        foreach ($f in (Get-ChildItem -LiteralPath $SharedDir -Filter '*.csv' -File | Sort-Object Name)) {
            $r = Read-ScheduleFile $f.FullName
            $name = if ($r.Name) { $r.Name } else { $f.BaseName }
            $enabled = -not (@($settings.Disabled) -contains $f.Name)
            if (-not $settings.Colors.ContainsKey($f.Name)) {
                $used = @($settings.Colors.Values) + $MineColor
                $free = @($SchedulePalette.Values | Where-Object { $used -notcontains $_ })
                $settings.Colors[$f.Name] = if ($free.Count -gt 0) { $free[0] } else { @($SchedulePalette.Values)[$settings.Colors.Count % $SchedulePalette.Count] }
            }
            $all += [pscustomobject]@{
                Name = $name; IsMine = $false; Owned = (@($settings.Owned) -contains $f.Name); File = $f.FullName; FileName = $f.Name
                Rows = $r.Rows; Tz = $r.Tz; TzText = $r.TzText; Errors = $r.Errors; Enabled = $enabled
                Delim = $r.Delim; Updated = $r.Updated; Stamp = (Get-FileStamp $f.FullName)
                Color = $settings.Colors[$f.Name]; Groups = @($r.Groups)
                MyGroups = $(if ($settings.MyGroups.ContainsKey($f.Name)) { @($settings.MyGroups[$f.Name]) } else { @() })
                QuietAllow = $(if ($settings.QuietAllow.ContainsKey($f.Name)) { [bool]$settings.QuietAllow[$f.Name] } else { $true })
            }
            if ($enabled) { $errors += @($r.Errors | ForEach-Object { "$name, $_" }) }
        }
    }
    return @{ All = $all; Mine = $mine; Errors = $errors }
}

# ---------------------------------------------------------------------------
# Start with Windows (shortcut in your Startup folder)
# ---------------------------------------------------------------------------
function Get-StartupLinkPath { Join-Path ([Environment]::GetFolderPath('Startup')) 'Desk Reminders.lnk' }
function Test-StartupLink { Test-Path -LiteralPath (Get-StartupLinkPath) }
function Install-StartupLink {
    $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-StartupLinkPath))
    # conhost = the classic console, which can be hidden (Windows Terminal can't)
    $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $conhost = Join-Path $env:WINDIR 'System32\conhost.exe'
    $psArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    if (Test-Path -LiteralPath $conhost) { $sc.TargetPath = $conhost; $sc.Arguments = "`"$ps`" $psArgs" }
    else { $sc.TargetPath = $ps; $sc.Arguments = $psArgs }
    $sc.WorkingDirectory = $PSScriptRoot
    $sc.IconLocation = "$IconFile,0"
    $sc.WindowStyle = 7
    $sc.Description = 'Desk Reminders'
    $sc.Save()
    $old = Join-Path ([Environment]::GetFolderPath('Startup')) 'DeskReminders.cmd'
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
}
function Remove-StartupLink {
    $old = Join-Path ([Environment]::GetFolderPath('Startup')) 'DeskReminders.cmd'
    foreach ($f in @((Get-StartupLinkPath), $old)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
}
if ($InstallStartup) {
    Install-StartupLink
    Write-Host 'Desk Reminders will now start when you log in to Windows.'
    Write-Host 'Keep this folder where it is. If you move it, run Add-To-Startup.cmd again.'
    return
}
if ($RemoveStartup) {
    Remove-StartupLink
    Write-Host 'Desk Reminders will no longer start when you log in.'
    return
}

# ---------------------------------------------------------------------------
# -ListFor: print a day and stop
# ---------------------------------------------------------------------------
if ($ListFor) {
    $settings = Load-Settings
    $loaded = Load-AllSources $settings
    foreach ($e in $loaded.Errors) { Write-Host "PROBLEM  $e" -ForegroundColor Red }
    $day = Parse-Date $ListFor
    if (-not $day) { Write-Host "Use a date like 2026-12-01" -ForegroundColor Red; return }
    $list = @(Get-Occurrences $loaded.All $day $day $settings.Hidden)
    if ($list.Count -eq 0) { Write-Host "No reminders on $ListFor." }
    else {
        $list | Select-Object Time,
            @{ Name = 'What'; Expression = { if ($_.Kind -eq 'notice') { "Notice: $($_.Title) at $($_.EventTime)" } else { $_.Title } } },
            @{ Name = 'From'; Expression = { $_.Source } },
            @{ Name = 'For'; Expression = { if (@($_.For).Count -gt 0) { (@($_.For) -join ', ') + $(if ($_.ForMe) { '' } else { ' (not you)' }) } else { 'Everyone' } } }, Text |
            Format-Table -AutoSize -Wrap
    }
    return
}

# ---------------------------------------------------------------------------
# APP
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# A window that shows on top without taking focus from the game or app you're in
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System.Windows.Forms;
public class QuietForm : Form {
    [System.Runtime.InteropServices.DllImport("shell32.dll")]
    public static extern int SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string appId);
    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    static extern System.IntPtr GetConsoleWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
    public static void HideConsole() {
        System.IntPtr h = GetConsoleWindow();
        if (h != System.IntPtr.Zero) { ShowWindow(h, 0); }
    }
    // Returns a copy of a 16-bit PCM .wav with every sample multiplied by 'volume' (0..1).
    // Other formats come back unchanged (they play at full volume).
    public static byte[] ScaleWav(byte[] b, double volume) {
        if (b == null || b.Length < 44 || b[0] != 'R' || b[1] != 'I' || b[2] != 'F' || b[3] != 'F') { return b; }
        byte[] o = (byte[])b.Clone();
        int pos = 12, format = 0, bits = 0;
        while (pos + 8 <= o.Length) {
            string id = System.Text.Encoding.ASCII.GetString(o, pos, 4);
            int size = System.BitConverter.ToInt32(o, pos + 4);
            if (size < 0) { return b; }
            if (id == "fmt " && pos + 24 <= o.Length) {
                format = System.BitConverter.ToUInt16(o, pos + 8);
                bits = System.BitConverter.ToUInt16(o, pos + 22);
            } else if (id == "data") {
                if ((format != 1 && format != 0xFFFE) || bits != 16) { return b; }
                int end = System.Math.Min(o.Length, pos + 8 + size);
                for (int i = pos + 8; i + 1 < end; i += 2) {
                    int v = (short)(o[i] | (o[i + 1] << 8));
                    v = (int)System.Math.Round(v * volume);
                    if (v > 32767) { v = 32767; } else if (v < -32768) { v = -32768; }
                    o[i] = (byte)(v & 0xFF); o[i + 1] = (byte)((v >> 8) & 0xFF);
                }
                return o;
            }
            pos += 8 + size + (size & 1);
        }
        return b;
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            cp.ExStyle |= 0x00000008; // WS_EX_TOPMOST
            cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW
            return cp;
        }
    }
}
"@

# Hide the PowerShell window this runs in (the app lives in the tray)
try { [QuietForm]::HideConsole() } catch {}

$created = $false
$script:mutex = New-Object System.Threading.Mutex($true, 'Local\DeskReminders', [ref]$created)
if (-not $created) {
    [System.Windows.Forms.MessageBox]::Show('Desk Reminders is already running (check the tray).', 'Desk Reminders') | Out-Null
    return
}

[System.Windows.Forms.Application]::EnableVisualStyles()
# Older "Start with Windows" shortcuts left a PowerShell window open on Windows 11: update them
try {
    if (Test-StartupLink) {
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-StartupLinkPath))
        if ($lnk.TargetPath -notlike '*conhost.exe' -or -not ([string]$lnk.Arguments).Contains($PSCommandPath)) { Install-StartupLink }
    }
} catch {}
# Own taskbar identity, so windows show the bell instead of the PowerShell icon
try { [void][QuietForm]::SetCurrentProcessExplicitAppUserModelID('DeskReminders.App') } catch {}

$script:settings   = Load-Settings
$script:current    = $null
$script:pauseUntil = [datetime]::MinValue
$script:fired      = @{}
$script:snoozed    = New-Object System.Collections.ArrayList
$script:loaded     = @{ All = @(); Mine = @{ Rows = @(); Errors = @(); Delim = ',' }; Errors = @() }
$script:errors     = @()
$script:stamp      = ''
$script:undo       = $null
$script:sw         = $null      # schedule window
$script:swc        = @{}        # its controls
$script:selSource  = 'schedule.csv'   # selected in the Schedules panel
$script:choice     = $null
$script:dlgBusy    = $false

$script:appIcon = $null
if (Test-Path $IconFile) { try { $script:appIcon = New-Object System.Drawing.Icon $IconFile } catch {} }

$UiFont     = New-Object System.Drawing.Font('Segoe UI', 10)
$BoldFont   = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$SmallFont  = New-Object System.Drawing.Font('Segoe UI', 9)
$SmallBold  = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
$ItalicFont = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
$Accent     = [System.Drawing.ColorTranslator]::FromHtml($MineColor)
$Dot        = [string][char]0x25CF

function To-Color([string]$c) {
    if ($c -notmatch '^#[0-9A-Fa-f]{6}$') { $c = $script:DefaultColor }
    try { return [System.Drawing.ColorTranslator]::FromHtml($c) } catch { return [System.Drawing.Color]::FromArgb(31, 78, 140) }
}

# Mixes a colour with white: 0 = the colour, 1 = white
# Your own schedule's name (you can rename it under Options)
function Get-MineName {
    if ($script:settings.MineName) { return [string]$script:settings.MineName }
    return 'My schedule'
}

function Get-Tint($color, [double]$k) {
    [System.Drawing.Color]::FromArgb([int]($color.R + (255 - $color.R) * $k), [int]($color.G + (255 - $color.G) * $k), [int]($color.B + (255 - $color.B) * $k))
}

function Open-Url([string]$url) { try { Start-Process $url } catch {} }

# --- Sound ------------------------------------------------------------------
# Desk Reminders' own soft sounds live in the "sounds" folder, in this order
$SoundDir = Join-Path $PSScriptRoot 'sounds'
$SoundOrder = @('Soft chime', 'Warm bell', 'Marimba', 'Kalimba', 'Glass', 'Music box', 'Rising', 'Soft ping', 'Water drop')
$SoundChoices = @($SoundOrder | ForEach-Object { "$_.wav" } | Where-Object { Test-Path -LiteralPath (Join-Path $SoundDir $_) })
if (Test-Path -LiteralPath $SoundDir) {
    # Any other .wav you drop into the sounds folder shows up in the list too
    $SoundChoices += @(Get-ChildItem -LiteralPath $SoundDir -Filter '*.wav' -File | Sort-Object Name |
        ForEach-Object { $_.Name } | Where-Object { $SoundChoices -notcontains $_ })
}

function Get-SoundLabel([string]$s) {
    if ([System.IO.Path]::IsPathRooted($s)) { return 'Your own: ' + [System.IO.Path]::GetFileNameWithoutExtension($s) }
    return [System.IO.Path]::GetFileNameWithoutExtension($s)
}

function Get-SoundPath([string]$s) {
    if (-not $s) { return $null }
    if ([System.IO.Path]::IsPathRooted($s)) { return $s }
    $own = Join-Path $SoundDir $s
    if (Test-Path -LiteralPath $own) { return $own }
    return Join-Path $env:WINDIR "Media\$s"     # older settings may name a Windows sound
}

$script:soundCache = @{}

# Plays the chosen sound at the chosen volume (0-100; the curve follows how loud it sounds)
function Play-Chime([switch]$Preview, [string]$Sound, [int]$Volume = -1) {
    if (-not $Preview -and -not $script:settings.SoundOn) { return }
    $s = if ($Sound) { $Sound } else { $script:settings.Sound }
    $vol = if ($Volume -ge 0) { $Volume } else { [int]$script:settings.Volume }
    if ($vol -le 0) { return }
    $wav = Get-SoundPath $s
    if (-not $wav -or -not (Test-Path -LiteralPath $wav)) { $wav = Get-SoundPath 'Soft chime.wav' }
    if ($wav -and (Test-Path -LiteralPath $wav)) {
        try {
            $key = "$wav|$vol"
            if (-not $script:soundCache.ContainsKey($key)) {
                $gain = [math]::Pow([math]::Min($vol, 100) / 100.0, 2)
                $script:soundCache[$key] = [QuietForm]::ScaleWav([System.IO.File]::ReadAllBytes($wav), $gain)
            }
            if ($script:player) { try { $script:player.Stop() } catch {} }
            $script:player = New-Object System.Media.SoundPlayer (New-Object System.IO.MemoryStream (, $script:soundCache[$key]))
            $script:player.Play()
            return
        } catch {}
    }
    [System.Media.SystemSounds]::Asterisk.Play()
}

# --- Quiet hours ------------------------------------------------------------
function Test-QuietNow([datetime]$t) {
    $q = $script:settings.Quiet
    if (-not $q.On) { return $false }
    $from = Parse-Clock $q.From; $to = Parse-Clock $q.To
    if ($null -eq $from -or $null -eq $to -or $from -eq $to) { return $false }
    $m = $t.Hour * 60 + $t.Minute
    if ($from -lt $to) { return ($m -ge $from -and $m -lt $to) }
    return ($m -ge $from -or $m -lt $to)
}

# Which of these reminders may pop up right now
function Select-Poppable($items, [datetime]$now) {
    $quiet = Test-QuietNow $now
    @($items | Where-Object { $_.Notify -and (-not $quiet -or $_.QuietAllow) })
}

# --- Per-event alerts: the bell (mute) and the megaphone (notify me too) -------
# A reminder pops up when it's for you (your schedule, Everyone, or one of your groups),
# unless you muted it; another group's event pops up when you asked to be notified too.
function Get-AlertKey($e) {
    if ($e.IsMine) { return "Mine|$($e.DaysText)|$($e.TimeText)|$($e.Title)" }
    return $e.Key
}

function Add-Alerts($list) {
    foreach ($e in @($list)) {
        $k = Get-AlertKey $e
        $d = $e.EventAt.ToString('yyyy-MM-dd')
        $mode = $null; $dayMode = $null
        foreach ($a in @($script:settings.Alerts)) {
            if ($a.Key -ne $k) { continue }
            if ($a.Date -eq $d) { $dayMode = $a.Mode } elseif ($a.Date -eq '') { $mode = $a.Mode }
        }
        if ($dayMode) { $mode = $dayMode }     # one day beats every time
        $notify = if ($mode -eq 'mute') { $false } elseif ($mode -eq 'shout') { $true } else { [bool]$e.ForMe }
        $state = if ($mode -eq 'mute') { 'muted' } elseif ($mode -eq 'shout') { 'shout' } elseif ($e.ForMe) { 'on' } else { 'off' }
        $e | Add-Member -NotePropertyName Notify -NotePropertyValue $notify -Force
        $e | Add-Member -NotePropertyName AlertState -NotePropertyValue $state -Force
        $e | Add-Member -NotePropertyName AlertKey -NotePropertyValue $k -Force
        $e
    }
}

# Small drawn icons for the list (16x16)
function New-AlertIcon([string]$kind) {
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $ink = switch ($kind) {
        'on'    { [System.Drawing.Color]::FromArgb(40, 44, 52) }
        'muted' { [System.Drawing.Color]::FromArgb(120, 120, 120) }
        'off'   { [System.Drawing.Color]::FromArgb(195, 195, 195) }
        'shout' { [System.Drawing.ColorTranslator]::FromHtml('#B5541B') }
    }
    $brush = New-Object System.Drawing.SolidBrush($ink)
    if ($kind -eq 'shout') {
        # Megaphone: mouth on the right, handle on the left, two sound waves
        $pts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF(2, 6)), (New-Object System.Drawing.PointF(5, 6)),
            (New-Object System.Drawing.PointF(10, 2)), (New-Object System.Drawing.PointF(10, 13)),
            (New-Object System.Drawing.PointF(5, 9)), (New-Object System.Drawing.PointF(2, 9)))
        $g.FillPolygon($brush, $pts)
        $g.FillRectangle($brush, 4, 9, 2, 4)
        $pen = New-Object System.Drawing.Pen($ink, 1.4)
        $g.DrawArc($pen, 9, 4, 4, 7, -60, 120)
        $g.DrawArc($pen, 10, 2, 6, 11, -60, 120)
        $pen.Dispose()
    } else {
        # Bell: dome, flared rim, clapper
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc(4, 2, 8, 9, 180, 180)
        $path.AddLine(12, 6.5, 13.5, 11.5)
        $path.AddLine(13.5, 11.5, 2.5, 11.5)
        $path.AddLine(2.5, 11.5, 4, 6.5)
        $path.CloseFigure()
        $g.FillPath($brush, $path)
        $g.FillEllipse($brush, 6.5, 12, 3, 3)
        $g.FillRectangle($brush, 7.5, 1, 1, 2)
        $path.Dispose()
        if ($kind -ne 'on') {
            # The slash: a white gap with a line on top, so it reads on any row
            $gap = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)
            $g.DrawLine($gap, 2, 14, 14, 2)
            $line = New-Object System.Drawing.Pen($ink, 1.6)
            $g.DrawLine($line, 2, 14, 14, 2)
            $gap.Dispose(); $line.Dispose()
        }
    }
    $brush.Dispose(); $g.Dispose()
    return $bmp
}

function Get-AlertTip($e) {
    switch ($e.AlertState) {
        'on'    { 'Pops up for you. Click the bell to mute it.' }
        'muted' { 'Muted: no pop-up. Click the bell to turn it back on.' }
        'off'   { "For $(@($e.For) -join ', '), not for you. Click the bell to be notified too." }
        'shout' { "For $(@($e.For) -join ', '); you asked to be notified too. Click to undo." }
    }
}

# Click on the icon: bell -> muted, muted -> bell, grey bell -> megaphone, megaphone -> grey bell
function Switch-Alert($e) {
    $k = $e.AlertKey
    $d = $e.EventAt.ToString('yyyy-MM-dd')
    $before = @($script:settings.Alerts)
    $others = @($script:settings.Alerts | Where-Object { -not ($_.Key -eq $k -and ($_.Date -eq '' -or $_.Date -eq $d)) })
    if ($e.AlertState -in @('muted', 'shout')) {
        $script:settings.Alerts = $others
        $what = if ($e.AlertState -eq 'muted') { 'unmute' } else { 'notify me too' }
    } else {
        $mode = if ($e.AlertState -eq 'on') { 'mute' } else { 'shout' }
        $date = $d
        if (-not $e.OneOff) {
            $dayText = $e.EventAt.ToString('dddd d MMMM', $En)
            $q = if ($mode -eq 'mute') { "Mute '$($e.Title)' only on $dayText, or every time?" } else { "Get pop-ups for '$($e.Title)' too, only on $dayText, or every time?" }
            $ans = Ask-Choice $(if ($mode -eq 'mute') { 'Mute' } else { 'Notify me too' }) $q @('Only this day', 'Every time', 'Cancel') $script:sw
            if ($ans -eq 'Cancel') { return }
            if ($ans -eq 'Every time') { $date = '' }
        }
        $script:settings.Alerts = $others + @{ Key = $k; Date = $date; Mode = $mode }
        $what = if ($mode -eq 'mute') { 'mute' } else { 'notify me too' }
    }
    $script:undo = @{ Kind = 'alerts'; Alerts = $before; What = $what }
    Save-Settings
    Refresh-ScheduleWindow
    Update-TrayText
}

# --- Pop-up: one or more reminders at the same minute, one sound --------------
function Get-PopupArea {
    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    $i = [int]$script:settings.Monitor
    if ($i -ge 1 -and $i -le $screens.Count) { return $screens[$i - 1].WorkingArea }
    return [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
}

function Show-Reminder($items) {
    $items = @($items)
    if ($items.Count -eq 0) { return }
    if ($script:current -and -not $script:current.IsDisposed) { $script:current.Close() }

    $form = New-Object QuietForm
    $form.FormBorderStyle = 'None'
    $form.StartPosition   = 'Manual'
    $form.ShowInTaskbar   = $false
    $form.TopMost         = $true
    $form.Width = 460

    # Every reminder gets a block in its own schedule's colour
    $shown = [math]::Min($items.Count, 4)
    $colours = @($items[0..($shown - 1)] | ForEach-Object { (To-Color $_.Colour).ToArgb() } | Select-Object -Unique)
    $mixed = $colours.Count -gt 1
    $barColor = if ($mixed) { [System.Drawing.Color]::FromArgb(43, 47, 54) } else { To-Color $items[0].Colour }
    $form.BackColor = $barColor

    $controls = @()
    $closers = @()
    $y = 0
    for ($i = 0; $i -lt $shown; $i++) {
        $it = $items[$i]
        $back = To-Color $it.Colour
        $panel = New-Object System.Windows.Forms.Panel
        $panel.BackColor = $back
        $closers += $panel
        $py = 12
        $inner = @()
        if ($i -gt 0 -and -not $mixed) {
            $line = New-Object System.Windows.Forms.Panel
            $line.BackColor = [System.Windows.Forms.ControlPaint]::Light($back)
            $line.SetBounds(20, 0, 420, 1)
            $inner += $line
        }
        $label = if ($it.IsMine) { '' } else { $it.Source.ToUpper() }
        if (@($it.For).Count -gt 0) { $label += '  -  ' + ((@($it.For) -join ', ').ToUpper()) }
        if ($it.Snoozed) { $label = ('SNOOZED   ' + $label).Trim() }
        if ($label) {
            $src = New-Object System.Windows.Forms.Label
            $src.Text = $label
            $src.ForeColor = [System.Windows.Forms.ControlPaint]::LightLight($back)
            $src.Font = $SmallBold
            $src.AutoSize = $false
            $src.AutoEllipsis = $true
            $src.SetBounds(20, $py, 420, 18)
            $inner += $src
            $py += 18
        }
        $title = New-Object System.Windows.Forms.Label
        $title.Text = "$($it.EventTime)  $($it.Title)"
        $title.ForeColor = 'White'
        $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
        $title.AutoSize = $false
        $title.AutoEllipsis = $true
        $title.SetBounds(20, $py, 420, 36)
        $inner += $title
        $py += 36
        $bodyText = $it.Text
        if ($it.Kind -eq 'notice') {
            $bodyText = "Starts in $($it.Notice) minutes." + $(if ($it.Text) { ' ' + $it.Text } else { '' })
        }
        if ($bodyText) {
            $body = New-Object System.Windows.Forms.Label
            $body.Text = $bodyText
            $body.ForeColor = 'White'
            $body.Font = New-Object System.Drawing.Font('Segoe UI', 11)
            $body.AutoSize = $false
            $body.SetBounds(20, $py, 420, 44)
            $inner += $body
            $py += 46
        }
        $py += 6
        $panel.SetBounds(0, $y, 460, $py)
        $panel.Controls.AddRange([System.Windows.Forms.Control[]]$inner)
        $closers += @($inner | Where-Object { $_ -is [System.Windows.Forms.Label] })
        $controls += $panel
        $y += $py
    }
    $y += 12   # same space above the buttons as below them
    if ($items.Count -gt $shown) {
        $more = New-Object System.Windows.Forms.Label
        $more.Text = "+ $($items.Count - $shown) more (see the Schedule window)"
        $more.ForeColor = 'White'
        $more.Font = $UiFont
        $more.SetBounds(20, $y, 420, 22)
        $controls += $more
        $closers += $more
        $y += 26
    }

    $btnX = 20
    $snoozeList = $script:snoozed   # closures below can't see $script: variables
    foreach ($spec in @(@('Snooze 5 min', 5), @('Snooze 15 min', 15))) {
        $sb = New-Object System.Windows.Forms.Button
        $sb.Text = $spec[0]
        $sb.Tag = $spec[1]
        $sb.FlatStyle = 'Flat'
        $sb.ForeColor = 'White'
        $sb.FlatAppearance.BorderColor = [System.Windows.Forms.ControlPaint]::Light($barColor)
        $sb.Font = $SmallFont
        $sb.SetBounds($btnX, $y, 110, 32)
        $sb.Add_Click({
            $later = (Get-Date).AddMinutes([int]$this.Tag)
            $copies = @($items | ForEach-Object { $c = $_.PSObject.Copy(); $c | Add-Member -NotePropertyName Snoozed -NotePropertyValue $true -Force; $c })
            [void]$snoozeList.Add(@{ At = $later; Items = $copies })
            $form.Close()
        }.GetNewClosure())
        $controls += $sb
        $btnX += 116
    }
    $done = New-Object System.Windows.Forms.Button
    $done.Text = 'Done'
    $done.FlatStyle = 'Flat'
    $done.ForeColor = 'White'
    $done.FlatAppearance.BorderColor = [System.Drawing.Color]::White
    $done.Font = $BoldFont
    $done.SetBounds(350, $y, 90, 32)
    $done.Add_Click({ $form.Close() }.GetNewClosure())
    $controls += $done
    $form.Height = $y + 32 + 12

    foreach ($ctl in $closers) { $ctl.Add_Click({ $form.Close() }.GetNewClosure()) }
    $form.Controls.AddRange([System.Windows.Forms.Control[]]$controls)

    $area = Get-PopupArea
    $x = if ($script:settings.Corner -like '*Left') { $area.Left + 24 } else { $area.Right - $form.Width - 24 }
    $yPos = if ($script:settings.Corner -like 'Top*') { $area.Top + 24 } else { $area.Bottom - $form.Height - 24 }
    $form.Location = New-Object System.Drawing.Point($x, $yPos)

    $life = New-Object System.Windows.Forms.Timer
    $life.Interval = $PopupSeconds * 1000 + [math]::Max(0, $shown - 1) * 5000
    $life.Add_Tick({ $life.Stop(); if (-not $form.IsDisposed) { $form.Close() } }.GetNewClosure())
    $form.Add_FormClosed({ $life.Stop(); $life.Dispose() }.GetNewClosure())
    $life.Start()

    $script:current = $form
    $form.Show()
    Play-Chime
}

# Uses the colours you picked: yours, and your first shared schedule's (or green)
function Show-TestReminder([string]$MyColor = '') {
    $now = Get-Date
    $mine = if ($MyColor) { $MyColor } else { $script:loaded.All[0].Color }
    $shared = @($script:loaded.All | Where-Object { -not $_.IsMine -and $_.Enabled })
    $guildName = 'Guild Schedule'; $guildColor = $SchedulePalette.Green; $guildFor = @('Raid Team 1')
    if ($shared.Count -gt 0) {
        $guildName = $shared[0].Name; $guildColor = $shared[0].Color
        $guildFor = if (@($shared[0].MyGroups).Count -gt 0) { @(@($shared[0].MyGroups)[0]) } else { @() }
    }
    Show-Reminder @(
        [pscustomobject]@{ EventTime = $now.ToString('HH:mm'); Colour = $mine; Title = 'Test reminder'; Text = "From your own schedule. Closes by itself after $PopupSeconds seconds."; Kind = 'event'; Notice = 0; IsMine = $true; Source = 'Mine'; For = @() },
        [pscustomobject]@{ EventTime = $now.AddMinutes(15).ToString('HH:mm'); Colour = $guildColor; Title = 'Example guild event'; Text = 'From a shared schedule, in its own colour.'; Kind = 'notice'; Notice = 15; IsMine = $false; Source = $guildName; For = $guildFor }
    )
}

# --- Tray -------------------------------------------------------------------
$tray = New-Object System.Windows.Forms.NotifyIcon
if ($script:appIcon) {
    $tray.Icon = New-Object System.Drawing.Icon($IconFile, [System.Windows.Forms.SystemInformation]::SmallIconSize)
} else {
    $tray.Icon = [System.Drawing.SystemIcons]::Information
}
$tray.Visible = $true

function Get-SourcesStamp {
    $parts = @()
    if (Test-Path -LiteralPath $ScheduleFile) { $parts += 'mine|' + (Get-Item -LiteralPath $ScheduleFile).LastWriteTimeUtc.Ticks }
    if (Test-Path -LiteralPath $SharedDir) {
        foreach ($f in (Get-ChildItem -LiteralPath $SharedDir -Filter '*.csv' -File)) { $parts += "$($f.Name)|$($f.LastWriteTimeUtc.Ticks)" }
    }
    return ($parts -join ';')
}

# Reload all schedules whenever one of the files has changed
function Sync-Schedule([switch]$Force) {
    $stamp = Get-SourcesStamp
    if (-not $Force -and $stamp -eq $script:stamp) { return }
    $script:stamp = $stamp
    $colorCount = $script:settings.Colors.Count
    $script:loaded = Load-AllSources $script:settings
    if ($script:settings.Colors.Count -ne $colorCount) { Save-Settings }
    $newErrors = @($script:loaded.Errors)
    if ($newErrors.Count -gt 0 -and (($newErrors -join '|') -ne ($script:errors -join '|'))) {
        $msg = ($newErrors | Select-Object -First 2) -join "`n"
        if ($newErrors.Count -gt 2) { $msg += "`n(+$($newErrors.Count - 2) more)" }
        $tray.ShowBalloonTip(10000, 'A schedule has a problem', $msg, 'Warning')
    }
    elseif (-not $Force -and $newErrors.Count -eq 0) {
        $tray.ShowBalloonTip(3000, 'Schedule updated', 'Your changes are loaded.', 'Info')
    }
    $script:errors = $newErrors
    Refresh-ScheduleWindow
}

function Get-Today([datetime]$day) {
    @(Add-Alerts @(Get-Occurrences $script:loaded.All $day $day $script:settings.Hidden))
}

# Next reminder that will pop up for you (events only, or also notices)
function Get-Next([switch]$EventsOnly) {
    $now = Get-Date
    foreach ($o in @(Add-Alerts @(Get-Occurrences $script:loaded.All $now.Date $now.Date.AddDays(1) $script:settings.Hidden))) {
        if ($o.At -le $now -or -not $o.Notify) { continue }
        if ($EventsOnly -and $o.Kind -ne 'event') { continue }
        return $o
    }
}

function Format-Until([datetime]$at) {
    $span = $at - (Get-Date)
    $mins = [int][math]::Ceiling($span.TotalMinutes)
    if ($mins -lt 60) { return "in $mins min" }
    $h = [int][math]::Floor($mins / 60); $m = $mins % 60
    if ($m -eq 0) { return "in ${h}h" }
    return "in ${h}h ${m}m"
}

function Update-TrayText {
    $txt = 'Desk Reminders'
    if ((Get-Date) -lt $script:pauseUntil) {
        $txt = 'Paused until ' + $script:pauseUntil.ToString('HH:mm')
    } else {
        $n = Get-Next
        if ($n) {
            $txt = 'Next: ' + $n.Time + ' ' + $(if ($n.Kind -eq 'notice') { 'Notice: ' } else { '' }) + $n.Title
        } else { $txt = 'No reminders in the next 24h' }
    }
    if ($txt.Length -gt 63) { $txt = $txt.Substring(0, 63) }
    $tray.Text = $txt
}

# --- Writing schedule files --------------------------------------------------
function Format-CsvField([string]$v) {
    if ($v -match '[",;\r\n]') { return '"' + ($v -replace '"', '""') + '"' }
    return $v
}

function Get-Source([string]$file) {
    foreach ($s in $script:loaded.All) { if ($s.File -eq $file) { return $s } }
    return $null
}

function Get-HeaderIndex($list) {
    for ($i = 0; $i -lt $list.Count; $i++) {
        $t = $list[$i].Trim().Trim('"').Trim()
        if ($t -ne '' -and -not $t.StartsWith('#') -and (($list[$i] -replace '[,;"\s]', '') -ne '')) { return $i }
    }
    return -1
}

function Read-FileLines([string]$path) {
    $list = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $path) {
        foreach ($l in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) { $list.Add($l) }
    }
    if ((Get-HeaderIndex $list) -lt 0) { $list.Insert(0, 'Days,Time,Colour,Title,Text,Notice,For') }
    return ,$list
}

# Older files miss the Notice / For columns: add them to the header row
function Add-Columns($list, [string]$delim) {
    $i = Get-HeaderIndex $list
    if ($i -lt 0) { return }
    if ($list[$i] -notmatch '(?i)notice') { $list[$i] = $list[$i].TrimEnd() + $delim + 'Notice' }
    if ($list[$i] -notmatch '(?i)(^|[,;"])\s*for\s*("|$|[,;])') { $list[$i] = $list[$i].TrimEnd() + $delim + 'For' }
}

# Sets a "#! key = value" line, or adds it right below the header row
function Set-Directive($list, [string]$key, [string]$value) {
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i].Trim().Trim('"').Trim() -match "^#!\s*$key\s*[=:]") { $list[$i] = "#! $key = $value"; return }
    }
    $list.Insert((Get-HeaderIndex $list) + 1, "#! $key = $value")
}

function New-CsvLine([string[]]$fields, [string]$delim) {
    ($fields | ForEach-Object { Format-CsvField $_ }) -join $delim
}

# Line numbers are only valid if nobody changed the file since it was loaded
function Confirm-SourceUnchanged($src) {
    if ((Get-FileStamp $src.File) -ne $src.Stamp) {
        Sync-Schedule -Force
        Show-Msg $script:sw "$($src.FileName) was changed outside this window, so the list has been refreshed. Please try again." 'Desk Reminders' | Out-Null
        return $false
    }
    return $true
}

# Applies a change to a schedule file you can edit (your own, or a shared one you made).
# The file as it was before is kept, so the change can be undone.
function Update-ScheduleFile($src, [scriptblock]$change, [string]$what = 'change') {
    if (-not (Confirm-SourceUnchanged $src)) { return $false }
    $before = if (Test-Path -LiteralPath $src.File) { [System.IO.File]::ReadAllLines($src.File, [System.Text.Encoding]::UTF8) } else { @() }
    $fileLines = Read-FileLines $src.File
    Add-Columns $fileLines $src.Delim
    & $change $fileLines
    if ($src.Owned) { Set-Directive $fileLines 'updated' (Get-Date).ToString('yyyy-MM-dd HH:mm') }
    [System.IO.File]::WriteAllLines($src.File, $fileLines.ToArray(), (New-Object System.Text.UTF8Encoding($true)))
    $script:undo = @{ Kind = 'file'; File = $src.File; Lines = $before; What = $what }
    Sync-Schedule -Force
    return $true
}

function Invoke-Undo {
    $u = $script:undo
    if (-not $u) { Show-Msg $script:sw 'There is nothing to undo.' 'Undo' | Out-Null; return }
    if ($u.Kind -eq 'file') {
        [System.IO.File]::WriteAllLines($u.File, [string[]]$u.Lines, (New-Object System.Text.UTF8Encoding($true)))
    } elseif ($u.Kind -eq 'hidden') {
        $script:settings.Hidden = @($u.Hidden)
        Save-Settings
    } elseif ($u.Kind -eq 'alerts') {
        $script:settings.Alerts = @($u.Alerts)
        Save-Settings
    }
    $script:undo = $null
    Sync-Schedule -Force
    Refresh-ScheduleWindow
}

# Message box with or without an owner window (picks the right overload)
function Show-Msg($owner, [string]$text, [string]$title, $buttons = 'OK', $icon = 'None') {
    $b = [System.Windows.Forms.MessageBoxButtons]$buttons
    $i = [System.Windows.Forms.MessageBoxIcon]$icon
    if ($owner) { return [System.Windows.Forms.MessageBox]::Show($owner, $text, $title, $b, $i) }
    return [System.Windows.Forms.MessageBox]::Show($text, $title, $b, $i)
}

function Get-SafeName([string]$name) {
    $safe = ($name -replace '[^\w\- ]', '').Trim()
    if ($safe -eq '' -or $safe -ieq 'schedule') { $safe = 'Shared schedule' }
    return $safe
}

function Format-Updated([string]$u) {
    if (-not $u) { return '-' }
    $d = [datetime]::MinValue
    if ([datetime]::TryParseExact($u, 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$d)) { return $d.ToString('d MMM yyyy, HH:mm', $En) }
    return $u
}

function New-Dialog([string]$title, [int]$w, [int]$h) {
    $d = New-Object System.Windows.Forms.Form
    $d.Text = $title
    $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false; $d.MinimizeBox = $false
    $d.StartPosition = 'CenterParent'
    $d.Font = $UiFont
    $d.ClientSize = New-Object System.Drawing.Size($w, $h)
    if ($script:appIcon) { $d.Icon = $script:appIcon }
    return $d
}

function Show-Dialog($d, $owner) {
    if ($owner -and -not $owner.IsDisposed) { return $d.ShowDialog($owner) }
    $d.StartPosition = 'CenterScreen'
    return $d.ShowDialog()
}

# --- Small "pick one" dialog -----------------------------------------------
function Ask-Choice([string]$heading, [string]$text, [string[]]$buttons, $owner) {
    $f = New-Dialog $heading 500 210
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.SetBounds(16, 16, 468, 136)
    $f.Controls.Add($l)
    $x = 500 - 16
    for ($i = $buttons.Count - 1; $i -ge 0; $i--) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $buttons[$i]
        $x -= 146
        $b.SetBounds($x, 162, 140, 34)
        $b.Add_Click({ $script:choice = $this.Text; $this.FindForm().Close() })
        $f.Controls.Add($b)
    }
    $script:choice = 'Cancel'
    [void](Show-Dialog $f $owner)
    $f.Dispose()
    return $script:choice
}

function New-TimePicker([int]$x, [int]$y, [datetime]$value) {
    $p = New-Object System.Windows.Forms.DateTimePicker
    $p.Format = 'Custom'
    $p.CustomFormat = 'HH:mm'
    $p.ShowUpDown = $true
    $p.Value = $value
    $p.SetBounds($x, $y, 80, 28)
    return $p
}

function New-Label([string]$text, [int]$x, [int]$y, [int]$w = 100) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.SetBounds($x, $y + 4, $w, 24)
    return $l
}

function New-Note([string]$text, [int]$x, [int]$y, [int]$w, [int]$h) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.ForeColor = [System.Drawing.Color]::DimGray
    $l.SetBounds($x, $y, $w, $h)
    return $l
}

# --- "Which group are you in?" ------------------------------------------------
function Show-GroupPicker([string]$scheduleName, [string[]]$groups, [string[]]$current, $owner) {
    $d = New-Dialog "Your groups in $scheduleName" 440 330
    $intro = New-Note "'$scheduleName' has groups. Tick the ones you're in. You'll see every event, but only get pop-ups for your groups and for events meant for everyone." 16 12 408 64
    $intro.ForeColor = [System.Drawing.SystemColors]::ControlText
    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.CheckOnClick = $true
    $list.SetBounds(16, 80, 408, 180)
    foreach ($g in $groups) { [void]$list.Items.Add($g, (@($current) -contains $g)) }
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Save'; $ok.SetBounds(226, 280, 96, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = 'Not now'; $cancel.SetBounds(328, 280, 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel
    $d.Controls.AddRange(@($intro, $list, $ok, $cancel))
    $res = Show-Dialog $d $owner
    $picked = @($list.CheckedItems | ForEach-Object { [string]$_ })
    $d.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return ,$picked
}

# --- Add / edit reminder dialog ---------------------------------------------
$NewScheduleItem = '+ New shared schedule'

function Get-TargetLabel($src) {
    if ($src.IsMine) { return (Get-MineName) }
    return "$($src.Name) (shared, made by you)"
}

function Update-DialogTarget {
    $c = $script:dlgCtl
    $t = $script:dlgTargets[$c.AddTo.SelectedIndex]
    if (-not $t) { return }
    $c.AddTo.ForeColor = To-Color $t.Color
    if ($t.Tz) {
        $c.TzNote.Text = "Times in '$($t.Name)' are in $($t.TzText) time. Members see them in their own local time."
    } elseif (-not $t.IsMine) {
        $c.TzNote.Text = "Times in '$($t.Name)' are used as each member's local time."
    } else {
        $c.TzNote.Text = ''
    }
    $groups = @($t.Groups)
    $c.For.Items.Clear()
    $c.ForLabel.Visible = ($groups.Count -gt 0)
    $c.For.Visible = ($groups.Count -gt 0)
    if ($groups.Count -gt 0) {
        $preset = @($script:dlgPresetFor)
        [void]$c.For.Items.Add('Everyone', ($preset.Count -eq 0))
        foreach ($g in $groups) { [void]$c.For.Items.Add($g, ($preset -contains $g)) }
    }
}

function Set-DialogTargets([string]$selectFile) {
    $c = $script:dlgCtl
    $script:dlgBusy = $true
    $script:dlgTargets = @($script:loaded.All | Where-Object { $_.IsMine -or $_.Owned })
    $c.AddTo.Items.Clear()
    $sel = 0
    for ($i = 0; $i -lt $script:dlgTargets.Count; $i++) {
        [void]$c.AddTo.Items.Add((Get-TargetLabel $script:dlgTargets[$i]))
        if ($selectFile -and $script:dlgTargets[$i].File -eq $selectFile) { $sel = $i }
    }
    [void]$c.AddTo.Items.Add($NewScheduleItem)
    $c.AddTo.SelectedIndex = $sel
    $script:dlgLastIndex = $sel
    $script:dlgBusy = $false
    Update-DialogTarget
}

# Mode 'Add' or 'Edit'. In Edit mode $Entry is the selected reminder.
function Show-ReminderDialog([string]$Mode = 'Add', $Entry = $null, [string]$TargetFile = '') {
    $row = $null; $editSrc = $null
    if ($Mode -eq 'Edit') {
        $editSrc = Get-Source $Entry.File
        if (-not $editSrc) { return }
        $row = @($editSrc.Rows | Where-Object { $_.Line -eq $Entry.Line })[0]
        if (-not $row) { return }
    }
    if (-not $script:weekStart) { Set-WeekValues (Get-Date) (Get-Date) }

    # The day the "Only on" / "Every" choices refer to
    $day = $script:selDay
    if ($row -and $row.Days.Kind -eq 'date') { $day = $row.Days.Date }
    if ($row -and $row.Days.Kind -eq 'week' -and @($row.Days.Days).Count -eq 1) { $day = $script:weekStart.AddDays(@($row.Days.Days)[0] - 1) }

    $d = New-Dialog $(if ($Mode -eq 'Edit') { 'Edit reminder' } else { 'Add reminder' }) 520 500
    $c = @{}
    $script:dlgCtl = $c
    $script:dlgPresetFor = if ($row) { @($row.For) } else { @() }

    $c.AddTo = New-Object System.Windows.Forms.ComboBox
    $c.AddTo.DropDownStyle = 'DropDownList'
    $c.AddTo.SetBounds(130, 16, 370, 28)
    $c.AddTo.Font = $BoldFont

    $c.Title = New-Object System.Windows.Forms.TextBox; $c.Title.SetBounds(130, 56, 370, 28)
    $c.Text  = New-Object System.Windows.Forms.TextBox; $c.Text.SetBounds(130, 92, 370, 28)

    $c.Days = New-Object System.Windows.Forms.ComboBox
    $c.Days.DropDownStyle = 'DropDownList'
    $c.Days.SetBounds(130, 128, 370, 28)
    [void]$c.Days.Items.AddRange(@(
        ('Only on ' + $day.ToString('dddd d MMMM', $En)),
        ('Every ' + $day.ToString('dddd', $En)),
        'Every day', 'Weekdays (Mon-Fri)', 'Weekends (Sat-Sun)'))
    $c.Days.SelectedIndex = 0

    $start = if ($day -eq (Get-Date).Date) {
        $n = (Get-Date).AddMinutes(5); $n.Date.AddHours($n.Hour).AddMinutes([math]::Ceiling($n.Minute / 5) * 5)
    } else { $day.Date.AddHours(9) }

    $c.Once = New-Object System.Windows.Forms.RadioButton
    $c.Once.Text = 'Once at'; $c.Once.Checked = $true
    $c.Once.SetBounds(130, 168, 90, 28)
    $c.At = New-TimePicker 230 168 $start
    $c.Rep = New-Object System.Windows.Forms.RadioButton
    $c.Rep.Text = 'Repeat every'
    $c.Rep.SetBounds(130, 206, 120, 28)
    $c.Step = New-Object System.Windows.Forms.NumericUpDown
    $c.Step.Minimum = 5; $c.Step.Maximum = 720; $c.Step.Value = 60; $c.Step.Increment = 5
    $c.Step.SetBounds(255, 206, 64, 28)
    $minLbl = New-Label 'min' 325 206 40
    $fromLbl = New-Label 'from' 150 242 40
    $c.From = New-TimePicker 195 242 $day.Date.AddHours(9)
    $toLbl = New-Label 'to' 285 242 24
    $c.To = New-TimePicker 312 242 $day.Date.AddHours(17)

    $c.Notice = New-Object System.Windows.Forms.NumericUpDown
    $c.Notice.Minimum = 0; $c.Notice.Maximum = 1440; $c.Notice.Value = 0; $c.Notice.Increment = 5
    $c.Notice.SetBounds(130, 284, 64, 28)
    $noticeLbl = New-Label 'minutes before (0 = no notice)' 200 284 280

    $c.ForLabel = New-Label 'For' 16 324
    $c.For = New-Object System.Windows.Forms.CheckedListBox
    $c.For.CheckOnClick = $true
    $c.For.SetBounds(130, 324, 370, 84)

    $c.TzNote = New-Note '' 16 414 488 36

    # Fill in the reminder being edited
    if ($row) {
        $c.Title.Text = $row.Title
        $c.Text.Text = $row.Text
        $dk = $row.Days
        $wd = @($dk.Days)
        if ($dk.Kind -eq 'date') { $c.Days.SelectedIndex = 0 }
        elseif ($dk.Kind -eq 'all') { $c.Days.SelectedIndex = 2 }
        elseif ($dk.Kind -eq 'week' -and $wd.Count -eq 1) { $c.Days.SelectedIndex = 1 }
        elseif ($dk.Kind -eq 'week' -and (($wd | Sort-Object) -join ',') -eq '1,2,3,4,5') { $c.Days.SelectedIndex = 3 }
        elseif ($dk.Kind -eq 'week' -and (($wd | Sort-Object) -join ',') -eq '6,7') { $c.Days.SelectedIndex = 4 }
        else { [void]$c.Days.Items.Add("Keep: $($row.DaysText)"); $c.Days.SelectedIndex = 5 }
        $mins = @($row.Time.Minutes)
        if ($row.Time.Repeat) {
            $c.Rep.Checked = $true
            $step = if ($mins.Count -gt 1) { $mins[1] - $mins[0] } else { 60 }
            $c.Step.Value = [math]::Min([math]::Max($step, 5), 720)
            $c.From.Value = $day.Date.AddMinutes($mins[0])
            $c.To.Value = $day.Date.AddMinutes($mins[-1])
        } else {
            $c.Once.Checked = $true
            $c.At.Value = $day.Date.AddMinutes($mins[0])
        }
        $c.Notice.Value = [math]::Min([int]$row.Notice, 1440)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = if ($Mode -eq 'Edit') { 'Save' } else { 'Add' }
    $ok.SetBounds(302, 452, 96, 34)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'; $cancel.SetBounds(404, 452, 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel

    $script:dlgForm = $d
    if ($Mode -eq 'Edit') {
        $script:dlgTargets = @($editSrc)
        [void]$c.AddTo.Items.Add((Get-TargetLabel $editSrc))
        $c.AddTo.SelectedIndex = 0
        $c.AddTo.Enabled = $false
        Update-DialogTarget
    } else {
        $pre = if ($TargetFile) { $TargetFile } else { $ScheduleFile }
        Set-DialogTargets $pre
    }
    $c.AddTo.Add_SelectedIndexChanged({
        if ($script:dlgBusy) { return }
        $c = $script:dlgCtl
        if ([string]$c.AddTo.SelectedItem -eq $NewScheduleItem) {
            $newFile = @(New-SharedSchedule $script:dlgForm -FromDialog)[-1]
            if ($newFile) { Set-DialogTargets $newFile }
            else { $script:dlgBusy = $true; $c.AddTo.SelectedIndex = $script:dlgLastIndex; $script:dlgBusy = $false }
            return
        }
        $script:dlgLastIndex = $c.AddTo.SelectedIndex
        Update-DialogTarget
    })
    $c.For.Add_ItemCheck({
        # "Everyone" and specific groups exclude each other
        $c = $script:dlgCtl
        if ($_.NewValue -ne 'Checked') { return }
        if ($_.Index -eq 0) { for ($i = 1; $i -lt $c.For.Items.Count; $i++) { $c.For.SetItemChecked($i, $false) } }
        else { $c.For.SetItemChecked(0, $false) }
    })
    $ok.Add_Click({
        $c = $script:dlgCtl
        if ($c.Title.Text.Trim() -eq '') {
            Show-Msg $this.FindForm() 'Give the reminder a title.' 'Reminder' | Out-Null; return
        }
        if ($c.Rep.Checked -and $c.From.Value.TimeOfDay -gt $c.To.Value.TimeOfDay) {
            Show-Msg $this.FindForm() 'The "from" time must be before the "to" time.' 'Reminder' | Out-Null; return
        }
        $this.FindForm().DialogResult = [System.Windows.Forms.DialogResult]::OK
    })

    $d.Controls.AddRange(@(
        (New-Label 'Add to' 16 16), $c.AddTo,
        (New-Label 'Title' 16 56), $c.Title,
        (New-Label 'Text (optional)' 16 92 112), $c.Text,
        (New-Label 'Days' 16 128), $c.Days,
        (New-Label 'Time' 16 168), $c.Once, $c.At, $c.Rep, $c.Step, $minLbl, $fromLbl, $c.From, $toLbl, $c.To,
        (New-Label 'Notice' 16 284), $c.Notice, $noticeLbl,
        $c.ForLabel, $c.For, $c.TzNote, $ok, $cancel))

    $result = Show-Dialog $d $script:sw
    $target = $script:dlgTargets[$c.AddTo.SelectedIndex]
    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $target) {
        $daysText = switch ($c.Days.SelectedIndex) {
            0 { $day.ToString('yyyy-MM-dd') }
            1 { $day.ToString('ddd', $En) }
            2 { 'Every day' }
            3 { 'Weekdays' }
            4 { 'Weekends' }
            5 { $row.DaysText }
        }
        if ($c.Once.Checked) { $timeText = $c.At.Value.ToString('HH:mm') }
        else { $timeText = 'every ' + [int]$c.Step.Value + ' min ' + $c.From.Value.ToString('HH:mm') + '-' + $c.To.Value.ToString('HH:mm') }
        $notice = if ([int]$c.Notice.Value -gt 0) { [string][int]$c.Notice.Value } else { '' }
        $forText = ''
        # (Not .Visible: the window is already closed here, so every control reports invisible)
        if ($c.For.Items.Count -gt 0) {
            $picked = @($c.For.CheckedItems | ForEach-Object { [string]$_ } | Where-Object { $_ -ne 'Everyone' })
            $forText = $picked -join '|'
        }
        $newLine = New-CsvLine @($daysText, $timeText, '', $c.Title.Text.Trim(), $c.Text.Text.Trim(), $notice, $forText) $target.Delim
        if ($Mode -eq 'Edit') {
            $lineIndex = $Entry.Line - 1
            [void](Update-ScheduleFile $target { param($l) $l[$lineIndex] = $newLine } 'edit')
        } else {
            [void](Update-ScheduleFile $target { param($l) $l.Add($newLine) } 'add')
        }
    }
    $d.Dispose()
}

function Get-SelectedEntry {
    $c = $script:swc
    if (-not $c.List -or $c.List.SelectedItems.Count -eq 0 -or -not $c.List.SelectedItems[0].Tag) { return $null }
    return $c.List.SelectedItems[0].Tag
}

function Edit-Selected {
    $e = Get-SelectedEntry
    if (-not $e) { Show-Msg $script:sw 'Select a reminder in the list first.' 'Edit' | Out-Null; return }
    if (-not $e.Editable) {
        Show-Msg $script:sw "'$($e.Title)' comes from '$($e.Source)', a shared schedule you imported. Only the person who made it can change it. You can hide it for yourself with Remove." 'Edit' | Out-Null
        return
    }
    Show-ReminderDialog 'Edit' $e
}

# --- Remove / hide ----------------------------------------------------------
function Remove-Selected {
    $e = Get-SelectedEntry
    if (-not $e) { Show-Msg $script:sw 'Select a reminder in the list first.' 'Remove' | Out-Null; return }
    $dayText = $script:selDay.ToString('dddd d MMMM', $En)

    if (-not $e.Editable) {
        $msg = "'$($e.Title)' at $($e.EventTime) comes from the shared schedule '$($e.Source)'.`n`nHide it only on $dayText, or every time? This only changes what you see; the shared file stays as it is. You can show them again: select the schedule on the left > Options."
        $ans = Ask-Choice 'Hide shared reminder' $msg @('Only this day', 'Every time', 'Cancel') $script:sw
        $before = @($script:settings.Hidden)
        if ($ans -eq 'Only this day') { $script:settings.Hidden += @{ Key = $e.Key; Date = $e.EventAt.ToString('yyyy-MM-dd') } }
        elseif ($ans -eq 'Every time') { $script:settings.Hidden += @{ Key = $e.Key; Date = '' } }
        else { return }
        $script:undo = @{ Kind = 'hidden'; Hidden = $before; What = 'hide' }
        Save-Settings
        Refresh-ScheduleWindow
        return
    }

    $src = Get-Source $e.File
    if (-not $src) { return }
    $forAll = if ($src.Owned) { "`n`nThis changes your shared schedule '$($src.Name)'. Members get the change when you share the file again." } else { '' }
    $lineIndex = $e.Line - 1

    if ($e.OneOff) {
        $ans = Show-Msg $script:sw "Remove '$($e.Title)' at $($e.EventTime) on ${dayText}?$forAll" 'Remove reminder' 'YesNo' 'Question'
        if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        [void](Update-ScheduleFile $src { param($l) $l.RemoveAt($lineIndex) } 'remove')
        return
    }

    $msg = "'$($e.Title)' at $($e.EventTime) is part of a repeating reminder:`n$($e.DaysText), $($e.TimeText)`n`nRemove it only on $dayText, or remove the whole reminder?$forAll"
    $ans = Ask-Choice 'Remove reminder' $msg @('Only this day', 'Whole reminder', 'Cancel') $script:sw
    if ($ans -eq 'Only this day') {
        $skipLine = New-CsvLine @($e.ZoneDate, $e.ZoneTime, 'skip', '', '', '', '') $src.Delim
        [void](Update-ScheduleFile $src { param($l) $l.Add($skipLine) } 'remove')
    }
    elseif ($ans -eq 'Whole reminder') {
        [void](Update-ScheduleFile $src { param($l) $l.RemoveAt($lineIndex) } 'remove')
    }
}

# --- Shared schedules ----------------------------------------------------------
function Clear-ScheduleSettings([string]$fileName) {
    $st = $script:settings
    $st.Disabled = @($st.Disabled | Where-Object { $_ -ne $fileName })
    $st.Owned    = @($st.Owned | Where-Object { $_ -ne $fileName })
    $st.ViewOff  = @($st.ViewOff | Where-Object { $_ -ne $fileName })
    foreach ($h in @($st.Colors, $st.MyGroups, $st.QuietAllow)) { if ($h.ContainsKey($fileName)) { $h.Remove($fileName) } }
}

function Get-CleanGroups([string]$text) {
    $out = @()
    foreach ($g in ($text -split "[\r\n]+")) {
        $g = ($g -replace '[|,;"=:#]', ' ').Trim()
        if ($g -ne '' -and $g -ine 'everyone' -and $out -notcontains $g) { $out += $g }
    }
    return ,$out
}

function Import-SharedSchedule($owner) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Import a shared schedule'
    $dlg.Filter = 'Schedule files (*.csv)|*.csv|All files (*.*)|*.*'
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = $dlg.FileName

    $r = Read-ScheduleFile $path
    $good = @($r.Rows | Where-Object { $_.Colour -ne 'skip' }).Count
    if (-not $r.HasHeader -or $good -eq 0) {
        Show-Msg $owner ("This file has no reminders Desk Reminders can read.`n`n" + (($r.Errors | Select-Object -First 5) -join "`n")) 'Import shared schedule' | Out-Null
        return
    }
    $name = if ($r.Name) { $r.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($path) }
    $safe = Get-SafeName $name
    $fileName = "$safe.csv"
    $dest = Join-Path $SharedDir $fileName

    if ($r.Errors.Count -gt 0) {
        $ans = Show-Msg $owner ("$($r.Errors.Count) row(s) in this file have a problem and will be skipped:`n`n" + (($r.Errors | Select-Object -First 5) -join "`n") + "`n`nImport the rest anyway?") 'Import shared schedule' 'YesNo' 'Warning'
        if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    $isUpdate = Test-Path -LiteralPath $dest
    if ($isUpdate) {
        $old = Read-ScheduleFile $dest
        $msg = "You already have '$name' (updated: $(Format-Updated $old.Updated)).`nThis file was updated: $(Format-Updated $r.Updated).`n`nReplace your version with this one?"
        if ($old.Updated -and $r.Updated -and ($r.Updated -lt $old.Updated)) { $msg += "`n`nNote: the file you picked is OLDER than the one you have." }
        if (@($script:settings.Owned) -contains $fileName) { $msg += "`n`nYou made this schedule on this PC. Your own changes to it will be replaced." }
        $msg += "`n`nYour own reminders are not affected."
        $ans = Show-Msg $owner $msg 'Update shared schedule' 'YesNo' 'Question'
        if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    if (-not (Test-Path -LiteralPath $SharedDir)) { New-Item -ItemType Directory -Path $SharedDir | Out-Null }
    if ([System.IO.Path]::GetFullPath($path) -ne [System.IO.Path]::GetFullPath($dest)) {
        Copy-Item -LiteralPath $path -Destination $dest -Force
    }
    $script:settings.Disabled = @($script:settings.Disabled | Where-Object { $_ -ne $fileName })

    # Groups: ask once, or again when the schedule has groups you haven't seen yet
    $groupNote = ''
    $groups = @($r.Groups)
    if ($groups.Count -gt 0) {
        $mine = if ($script:settings.MyGroups.ContainsKey($fileName)) { @($script:settings.MyGroups[$fileName]) } else { @() }
        $mine = @($mine | Where-Object { $groups -contains $_ })
        if (-not $isUpdate -or $mine.Count -eq 0) {
            $picked = Show-GroupPicker $name $groups $mine $owner
            if ($null -ne $picked) { $mine = @($picked) }
        }
        $script:settings.MyGroups[$fileName] = @($mine)
        $groupNote = if ($mine.Count -gt 0) { "`nYour groups: $($mine -join ', '). Events for other groups show greyed out and don't pop up." }
                     else { "`nYou didn't pick a group, so only events for everyone pop up. Change it any time: select it on the left > Options." }
    }
    Save-Settings
    Sync-Schedule -Force

    $tzNote = if ($r.Tz) { "Its times are in $($r.TzText) time and are shown in your own local time." } else { 'Its times are used as your local time.' }
    $verb = if ($isUpdate) { 'Updated' } else { 'Imported' }

    # What changed for you since the version you had
    $changes = ''
    if ($isUpdate) {
        $keyOf = { param($row) "$($row.DaysText)|$($row.TimeText)|$($row.Title)|$(@($row.For) -join '+')" }
        $oldKeys = @($old.Rows | Where-Object { $_.Colour -ne 'skip' } | ForEach-Object { & $keyOf $_ })
        $newRows = @($r.Rows | Where-Object { $_.Colour -ne 'skip' })
        $newKeys = @($newRows | ForEach-Object { & $keyOf $_ })
        $added = @($newRows | Where-Object { $oldKeys -notcontains (& $keyOf $_) })
        $removedCount = @($oldKeys | Where-Object { $newKeys -notcontains $_ }).Count
        $myGroups = @($script:settings.MyGroups[$fileName])
        $forMe = @($added | Where-Object { @($_.For).Count -eq 0 -or @($_.For | Where-Object { $myGroups -contains $_ }).Count -gt 0 }).Count
        if ($added.Count -eq 0 -and $removedCount -eq 0) { $changes = "`n`nNo changes to the events since your version." }
        else {
            $changes = "`n`nWhat changed:"
            if ($added.Count -gt 0) {
                $changes += "`n- $($added.Count) new or changed event(s): $forMe for you"
                if ($added.Count - $forMe -gt 0) { $changes += ", $($added.Count - $forMe) for other groups" }
            }
            if ($removedCount -gt 0) { $changes += "`n- $removedCount event(s) removed or changed" }
        }
    }
    Show-Msg $owner "$verb '$name' with $good reminder(s).$changes`n`n$tzNote$groupNote`nYour own schedule is unchanged." 'Import shared schedule' | Out-Null
}

# Create a new shared schedule that you can edit and share. Returns its file path.
function New-SharedSchedule($owner, [switch]$FromDialog) {
    $f = New-Dialog 'New shared schedule' 520 460
    $intro = New-Note 'A schedule for your guild, team or community. You add the events; members import the file you share.' 16 12 488 40
    $intro.ForeColor = [System.Drawing.SystemColors]::ControlText

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.SetBounds(140, 62, 364, 28)
    $nameBox.Text = 'Guild Schedule'

    $zoneBox = New-Object System.Windows.Forms.ComboBox
    $zoneBox.DropDownStyle = 'DropDownList'
    $zoneBox.SetBounds(140, 102, 364, 28)
    $local = [TimeZoneInfo]::Local
    $script:zoneValues = @()
    $pick = -1
    foreach ($z in $FriendlyZones) {
        $tz = Resolve-TimeZone $z[1]
        if (-not $tz) { continue }
        [void]$zoneBox.Items.Add($z[0])
        $script:zoneValues += $z[1]
        if ($pick -lt 0 -and $tz.Id -eq $local.Id) { $pick = $zoneBox.Items.Count - 1 }
    }
    if ($pick -lt 0) {
        $zoneBox.Items.Insert(0, "My time zone ($($local.DisplayName))")
        $script:zoneValues = @($local.Id) + $script:zoneValues
        $pick = 0
    }
    $zoneBox.SelectedIndex = $pick
    $zoneNote = New-Note 'Your "server time". Every member sees the events in their own local time.' 140 134 364 36

    $groupBox = New-Object System.Windows.Forms.TextBox
    $groupBox.Multiline = $true
    $groupBox.ScrollBars = 'Vertical'
    $groupBox.AcceptsReturn = $true
    $groupBox.SetBounds(140, 176, 364, 120)
    $groupNote = New-Note "Optional. One per line, e.g. Raid Team 1, Raid Team 2. Members pick their group when they import; events can be for everyone or for some groups. Leave empty if you don't need groups." 140 300 364 92

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Create'; $ok.SetBounds(306, 410, 96, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'; $cancel.SetBounds(408, 410, 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.AcceptButton = $null; $f.CancelButton = $cancel   # Enter makes a new line in Groups

    $f.Controls.AddRange(@($intro, (New-Label 'Name' 16 62), $nameBox, (New-Label 'Times are in' 16 102 120), $zoneBox, $zoneNote,
        (New-Label 'Groups' 16 176), $groupBox, $groupNote, $ok, $cancel))
    $res = Show-Dialog $f $owner
    $name = ($nameBox.Text -replace '[\r\n=:]', ' ').Trim()
    $zone = $script:zoneValues[$zoneBox.SelectedIndex]
    $groups = Get-CleanGroups $groupBox.Text
    $f.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    if ($name -eq '') { Show-Msg $owner 'Give the schedule a name.' 'New shared schedule' | Out-Null; return $null }

    $safe = Get-SafeName $name
    $fileName = "$safe.csv"
    $dest = Join-Path $SharedDir $fileName
    if (Test-Path -LiteralPath $dest) {
        Show-Msg $owner "You already have a schedule called '$name'. Pick another name, or remove the old one first." 'New shared schedule' | Out-Null
        return $null
    }
    if (-not (Test-Path -LiteralPath $SharedDir)) { New-Item -ItemType Directory -Path $SharedDir | Out-Null }
    $lines = @('Days,Time,Colour,Title,Text,Notice,For', "#! name = $name", "#! timezone = $zone")
    if ($groups.Count -gt 0) { $lines += '#! groups = ' + ($groups -join ' | ') }
    $lines += @(
        ('#! updated = ' + (Get-Date).ToString('yyyy-MM-dd HH:mm')),
        '# Made with Desk Reminders. To use it: click Import in Desk Reminders and pick this file.'
    )
    [System.IO.File]::WriteAllLines($dest, [string[]]$lines, (New-Object System.Text.UTF8Encoding($true)))
    Clear-ScheduleSettings $fileName
    $script:settings.Owned = @($script:settings.Owned) + $fileName
    # As the organiser you get every group's pop-ups; change it under Options
    if ($groups.Count -gt 0) { $script:settings.MyGroups[$fileName] = @($groups) }
    Save-Settings
    Sync-Schedule -Force

    if (-not $FromDialog) {
        $ans = Show-Msg $owner "Created '$name'.`n`nAdd the first event now?`n`nWhen you're ready, click Export to save a file you can post for your members." 'New shared schedule' 'YesNo' 'Question'
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { Show-ReminderDialog 'Add' -TargetFile $dest }
    }
    return $dest
}

# Save a copy of a schedule file to post in Discord, email, ...
function Share-Schedule($src, $owner) {
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title = "Share '$($src.Name)'"
    $dlg.Filter = 'Schedule files (*.csv)|*.csv'
    $dlg.FileName = (Get-SafeName $src.Name) + '.csv'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }
    if ([System.IO.Path]::GetFullPath($dlg.FileName) -ne [System.IO.Path]::GetFullPath($src.File)) {
        Copy-Item -LiteralPath $src.File -Destination $dlg.FileName -Force
    }
    Start-Process explorer.exe -ArgumentList "/select,`"$($dlg.FileName)`""
}

# --- Colour picker (palette + custom) -------------------------------------------
function New-ColorPicker([int]$x, [int]$y, [string]$current) {
    $box = New-Object System.Windows.Forms.ComboBox
    $box.DropDownStyle = 'DropDownList'
    $box.DrawMode = 'OwnerDrawFixed'
    $box.ItemHeight = 22
    $box.SetBounds($x, $y, 200, 28)
    $names = @($SchedulePalette.Keys)
    foreach ($n in $names) { [void]$box.Items.Add($n) }
    $match = @($names | Where-Object { $SchedulePalette[$_] -ieq $current })
    if ($match.Count -gt 0) { $box.SelectedItem = $match[0] }
    else { [void]$box.Items.Add("Custom $current"); $box.SelectedIndex = $box.Items.Count - 1 }
    [void]$box.Items.Add('Other colour')
    $box.Tag = @{ Value = $current; Last = $box.SelectedIndex }
    $box.Add_DrawItem({
        param($s, $e)
        if ($e.Index -lt 0) { return }
        $e.DrawBackground()
        $label = [string]$s.Items[$e.Index]
        $hex = if ($SchedulePalette.Contains($label)) { $SchedulePalette[$label] } elseif ($label -like 'Custom #*') { $label.Substring(7) } else { $null }
        $tx = $e.Bounds.X + 4
        if ($hex) {
            $brush = New-Object System.Drawing.SolidBrush((To-Color $hex))
            $e.Graphics.FillRectangle($brush, $e.Bounds.X + 4, $e.Bounds.Y + 4, 28, $e.Bounds.Height - 8)
            $brush.Dispose()
            $tx += 36
        }
        $fore = New-Object System.Drawing.SolidBrush($e.ForeColor)
        $e.Graphics.DrawString($label, $s.Font, $fore, [single]$tx, [single]($e.Bounds.Y + 2))
        $fore.Dispose()
    })
    $box.Add_SelectedIndexChanged({
        $t = $this.Tag
        $label = [string]$this.SelectedItem
        if ($label -eq 'Other colour') {
            $cd = New-Object System.Windows.Forms.ColorDialog
            $cd.FullOpen = $true
            $cd.Color = To-Color $t.Value
            if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $hex = '#{0:X2}{1:X2}{2:X2}' -f $cd.Color.R, $cd.Color.G, $cd.Color.B
                $t.Value = $hex
                $this.Items.Insert($this.Items.Count - 1, "Custom $hex")
                $this.SelectedIndex = $this.Items.Count - 2
            } else { $this.SelectedIndex = $t.Last }
            return
        }
        $t.Last = $this.SelectedIndex
        if ($SchedulePalette.Contains($label)) { $t.Value = $SchedulePalette[$label] }
        elseif ($label -like 'Custom #*') { $t.Value = $label.Substring(7) }
    })
    return $box
}

# --- Options for one shared schedule --------------------------------------------
function Show-ScheduleOptions($src, $owner) {
    $fileName = $src.FileName
    $groups = @($src.Groups)
    $h = 230
    if ($groups.Count -gt 0) { $h += 150 }
    if ($src.Owned) { $h += 150 }
    $hiddenCount = if ($src.IsMine) { 0 } else { @($script:settings.Hidden | Where-Object { $_.Key.StartsWith("$($src.Name)|") }).Count }
    if ($hiddenCount -gt 0) { $h += 50 }
    if ($src.IsMine) { $h += 50 }
    $title = if ($src.IsMine) { Get-MineName } else { $src.Name }
    $d = New-Dialog "Options - $title" 520 $h
    $ctl = @()
    $y = 16
    $nameBox = $null
    if ($src.IsMine) {
        $ctl += New-Label 'Name' 16 $y
        $nameBox = New-Object System.Windows.Forms.TextBox
        $nameBox.Text = Get-MineName
        $nameBox.MaxLength = 40
        $nameBox.SetBounds(140, $y, 364, 28)
        $ctl += $nameBox
        $y += 50
    }
    $ctl += New-Label 'Colour' 16 $y
    $color = New-ColorPicker 140 $y $src.Color
    $ctl += $color
    $ctl += New-Note 'Pop-ups and the schedule list use this colour.' 140 ($y + 32) 364 20
    $y += 64

    $quiet = New-Object System.Windows.Forms.CheckBox
    $quiet.Text = 'Allow pop-ups during quiet hours'
    $quiet.Checked = [bool]$src.QuietAllow
    $quiet.SetBounds(140, $y, 364, 26)
    $ctl += $quiet
    $qText = if ($script:settings.Quiet.On) { "Quiet hours are $($script:settings.Quiet.From)-$($script:settings.Quiet.To) (change them in Settings)." } else { 'Quiet hours are off right now (turn them on in Settings).' }
    $ctl += New-Note $qText 140 ($y + 28) 364 20
    $y += 64

    $groupList = $null
    if ($groups.Count -gt 0) {
        $ctl += New-Label 'My groups' 16 $y
        $groupList = New-Object System.Windows.Forms.CheckedListBox
        $groupList.CheckOnClick = $true
        $groupList.SetBounds(140, $y, 364, 110)
        foreach ($g in $groups) { [void]$groupList.Items.Add($g, (@($src.MyGroups) -contains $g)) }
        $ctl += $groupList
        $ctl += New-Note 'You see every event; only yours and those for everyone pop up.' 140 ($y + 114) 364 20
        $y += 150
    }

    $groupEdit = $null
    if ($src.Owned) {
        $ctl += New-Label 'Groups' 16 $y
        $groupEdit = New-Object System.Windows.Forms.TextBox
        $groupEdit.Multiline = $true
        $groupEdit.ScrollBars = 'Vertical'
        $groupEdit.AcceptsReturn = $true
        $groupEdit.SetBounds(140, $y, 364, 96)
        $groupEdit.Text = ($groups -join "`r`n")
        $ctl += $groupEdit
        $ctl += New-Note 'You made this schedule: one group per line. Export the file again after changing them.' 140 ($y + 100) 364 40
        $y += 150
    }

    if ($hiddenCount -gt 0) {
        $ctl += New-Label 'Hidden' 16 $y
        $unhide = New-Object System.Windows.Forms.Button
        $unhide.Text = "Show the $hiddenCount hidden event(s) again"
        $unhide.SetBounds(140, $y, 300, 32)
        $unhide.Tag = $src.Name
        $unhide.Add_Click({
            $script:undo = @{ Kind = 'hidden'; Hidden = @($script:settings.Hidden); What = 'show hidden' }
            $n = [string]$this.Tag
            $script:settings.Hidden = @($script:settings.Hidden | Where-Object { -not $_.Key.StartsWith("$n|") })
            Save-Settings
            $this.Enabled = $false
            $this.Text = 'Done: they show again'
            Refresh-ScheduleWindow
        })
        $ctl += $unhide
        $y += 50
    }

    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Save'; $ok.SetBounds(306, ($h - 50), 96, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = 'Cancel'; $cancel.SetBounds(408, ($h - 50), 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.CancelButton = $cancel
    $d.Controls.AddRange(@($ctl) + @($ok, $cancel))

    $res = Show-Dialog $d $owner
    $newColor = $color.Tag.Value
    $newQuiet = $quiet.Checked
    $newName = if ($nameBox) { ($nameBox.Text -replace '[\r\n]', ' ').Trim() } else { $null }
    $newMine = $null; $newGroups = $null
    if ($groupList) { $newMine = @($groupList.CheckedItems | ForEach-Object { [string]$_ }) }
    if ($groupEdit) { $newGroups = Get-CleanGroups $groupEdit.Text }
    $d.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $script:settings.Colors[$fileName] = $newColor
    $script:settings.QuietAllow[$fileName] = [bool]$newQuiet
    if ($null -ne $newName) { $script:settings.MineName = $(if ($newName -eq '' -or $newName -eq 'My schedule') { '' } else { $newName }) }
    if ($null -ne $newMine) { $script:settings.MyGroups[$fileName] = @($newMine) }
    Save-Settings
    if ($null -ne $newGroups -and (($newGroups -join '|') -ne ($groups -join '|'))) {
        $text = $newGroups -join ' | '
        [void](Update-ScheduleFile $src { param($l) Set-Directive $l 'groups' $text } 'groups')
        $added = @($newGroups | Where-Object { $groups -notcontains $_ })
        if ($added.Count -gt 0) {
            $script:settings.MyGroups[$fileName] = @(@($script:settings.MyGroups[$fileName]) + $added | Select-Object -Unique)
            Save-Settings
        }
        $inUse = @($src.Rows | ForEach-Object { @($_.For) } | Where-Object { $newGroups -notcontains $_ } | Select-Object -Unique)
        if ($inUse.Count -gt 0) {
            Show-Msg $owner ("These groups are still used by events, so they stay in the list until you change those events: " + ($inUse -join ', ')) 'Groups' | Out-Null
        }
    }
    Sync-Schedule -Force
}

# --- Schedules panel helpers (left side of the main window) ---------------------
function Get-SideSource {
    foreach ($s in $script:loaded.All) { if ($s.FileName -eq $script:selSource) { return $s } }
    return $script:loaded.All[0]
}

function Remove-SharedSchedule($s) {
    if (-not $s -or $s.IsMine) { return }
    $extra = if ($s.Owned) { "`n`nYou made this schedule. Removing it deletes your editable copy; members who imported it keep theirs. Tip: Export it first to keep a copy." } else { "`n`nYou can import it again later." }
    $ans = Show-Msg $script:sw "Remove the shared schedule '$($s.Name)' from this PC?$extra`n`nYour own reminders are not affected." 'Remove shared schedule' 'YesNo' 'Question'
    if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $before = [System.IO.File]::ReadAllLines($s.File, [System.Text.Encoding]::UTF8)
    Remove-Item -LiteralPath $s.File -Force
    Clear-ScheduleSettings $s.FileName
    $script:settings.Hidden = @($script:settings.Hidden | Where-Object { -not $_.Key.StartsWith("$($s.Name)|") })
    $script:settings.Alerts = @($script:settings.Alerts | Where-Object { -not $_.Key.StartsWith("$($s.Name)|") })
    Save-Settings
    $script:undo = @{ Kind = 'file'; File = $s.File; Lines = $before; What = 'remove schedule' }
    $script:selSource = 'schedule.csv'
    Sync-Schedule -Force
}

# Removes every reminder in your own schedule (the file stays, so you can start again; Undo brings them back)
function Clear-MySchedule {
    $mine = $script:loaded.All[0]
    $count = @($mine.Rows).Count
    if ($count -eq 0) { Show-Msg $script:sw "$(Get-MineName) is already empty." 'Remove' | Out-Null; return }
    $ans = Show-Msg $script:sw "Remove all $count reminder(s) in '$(Get-MineName)'?`n`nShared schedules are not affected. You can undo this with Undo." 'Remove all reminders' 'YesNo' 'Warning'
    if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    [void](Update-ScheduleFile $mine {
        param($l)
        $h = Get-HeaderIndex $l
        for ($i = $l.Count - 1; $i -gt $h; $i--) {
            if (-not $l[$i].Trim().Trim('"').StartsWith('#')) { $l.RemoveAt($i) }   # keep your notes, drop the reminders
        }
    } 'remove all')
}

# Export = save a copy of a shared schedule to post for your members
function Export-SharedSchedule($anchor) {
    $shared = @($script:loaded.All | Where-Object { -not $_.IsMine })
    if ($shared.Count -eq 0) {
        Show-Msg $script:sw "There is no shared schedule to export yet.`n`nClick '+ New shared schedule' to make one for your guild or team, add events, then Export it to post in Discord." 'Export' | Out-Null
        return
    }
    $sel = Get-SideSource
    if (-not $sel.IsMine) { Share-Schedule $sel $script:sw; return }
    if ($shared.Count -eq 1) { Share-Schedule $shared[0] $script:sw; return }
    # More than one: pick from a small menu under the button
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.Font = $UiFont
    foreach ($s in $shared) {
        $mi = New-Object System.Windows.Forms.ToolStripMenuItem("$Dot  $($s.Name)")
        $mi.ForeColor = To-Color $s.Color
        $mi.Tag = $s.FileName
        $mi.Add_Click({ foreach ($s in $script:loaded.All) { if ($s.FileName -eq $this.Tag) { Share-Schedule $s $script:sw } } })
        [void]$m.Items.Add($mi)
    }
    $m.Show($anchor, (New-Object System.Drawing.Point(0, $anchor.Height)))
}

# Runs a scriptblock right after the current click has finished
# (for actions that rebuild the control that was clicked)
function Invoke-Later([scriptblock]$action) {
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 1
    $t.Tag = $action
    $t.Add_Tick({ $this.Stop(); $a = $this.Tag; $this.Dispose(); & $a })
    $t.Start()
}

function New-ScheduleCard($s, [bool]$selected) {
    $col = To-Color $s.Color
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(204, 58)
    $card.Margin = New-Object System.Windows.Forms.Padding(6, 3, 4, 3)
    $card.BackColor = if ($selected) { Get-Tint $col 0.86 } else { [System.Drawing.Color]::White }
    $card.Cursor = [System.Windows.Forms.Cursors]::Hand
    $card.Tag = $s.FileName
    $bar = New-Object System.Windows.Forms.Panel
    $bar.SetBounds(0, 0, 6, 58)
    $bar.BackColor = if ($s.Enabled) { $col } else { [System.Drawing.Color]::Silver }
    $x = 14
    $parts = @()
    if (-not $s.IsMine) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.SetBounds(14, 20, 18, 18)
        $cb.Checked = [bool]$s.Enabled
        $cb.Tag = $s.FileName
        $cb.BackColor = $card.BackColor
        $script:sideTip.SetToolTip($cb, 'On or off: pop-ups and the list')
        $cb.Add_CheckedChanged({
            if ($script:sideLoading) { return }
            $others = @($script:settings.Disabled | Where-Object { $_ -ne $this.Tag })
            $script:settings.Disabled = if ($this.Checked) { $others } else { $others + $this.Tag }
            Save-Settings
            Invoke-Later { Sync-Schedule -Force }
        })
        $card.Controls.Add($cb)
        $x = 36
    }
    $name = New-Object System.Windows.Forms.Label
    $name.Text = if ($s.IsMine) { Get-MineName } else { $s.Name }
    $name.Font = $BoldFont
    $name.ForeColor = if ($s.Enabled) { $col } else { [System.Drawing.Color]::Gray }
    $name.AutoEllipsis = $true
    $name.SetBounds($x, 8, (198 - $x), 22)
    $count = @($s.Rows | Where-Object { $_.Colour -ne 'skip' }).Count
    if ($s.IsMine) { $parts = @('Your reminders', "$count row(s)") }
    else {
        if (-not $s.Enabled) { $parts += 'Off' }
        $parts += $(if ($s.Owned) { 'Made by you' } else { 'Shared' })
        $parts += "$count event(s)"
        if (@($s.Groups).Count -gt 0) { $parts += $(if (@($s.MyGroups).Count -gt 0) { @($s.MyGroups) -join ', ' } else { 'no group picked' }) }
    }
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $parts -join '  -  '
    $sub.Font = $SmallFont
    $sub.ForeColor = [System.Drawing.Color]::DimGray
    $sub.AutoEllipsis = $true
    $sub.SetBounds($x, 31, (198 - $x), 20)
    $script:sideTip.SetToolTip($sub, $sub.Text)
    $card.Controls.AddRange(@($bar, $name, $sub))
    foreach ($ctl in @($card, $bar, $name, $sub)) {
        $ctl.Tag = $s.FileName
        $ctl.Add_Click({ $script:selSource = [string]$this.Tag; Refresh-Sidebar })
        $ctl.Add_DoubleClick({ $script:selSource = [string]$this.Tag; Invoke-Later { Show-ScheduleOptions (Get-SideSource) $script:sw } })
    }
    return $card
}

function Refresh-Sidebar {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    if (-not (@($script:loaded.All | ForEach-Object { $_.FileName }) -contains $script:selSource)) { $script:selSource = 'schedule.csv' }
    $sig = "name=$(Get-MineName);" + ($script:loaded.All | ForEach-Object { "$($_.FileName)=$($_.Name)=$($_.Color)=$($_.Enabled)=$(@($_.Rows).Count)=$(@($_.MyGroups) -join ',')=$($_.Owned)" }) -join ';'
    if ($c.SideSig -ne $sig) {
        $c.SideSig = $sig
        $script:sideLoading = $true
        $c.Cards.SuspendLayout()
        foreach ($old in @($c.Cards.Controls)) { $old.Dispose() }
        $c.Cards.Controls.Clear()
        foreach ($s in $script:loaded.All) { $c.Cards.Controls.Add((New-ScheduleCard $s $false)) }
        if (@($script:loaded.All).Count -le 1) {
            $hint = New-Object System.Windows.Forms.Label
            $hint.Text = "No shared schedules yet.`n`nImport one your guild or team shared with you, or make your own with '+ New shared schedule'."
            $hint.ForeColor = [System.Drawing.Color]::Gray
            $hint.Font = $SmallFont
            $hint.Size = New-Object System.Drawing.Size(200, 96)
            $hint.Margin = New-Object System.Windows.Forms.Padding(12, 10, 4, 0)
            $c.Cards.Controls.Add($hint)
        }
        $c.Cards.ResumeLayout()
        $script:sideLoading = $false
    }
    # Highlight the selected schedule (recolour only: the cards stay, so clicks are safe)
    foreach ($card in @($c.Cards.Controls)) {
        if (-not ($card -is [System.Windows.Forms.Panel])) { continue }
        $src = $null
        foreach ($s in $script:loaded.All) { if ($s.FileName -eq $card.Tag) { $src = $s } }
        if (-not $src) { continue }
        $back = if ($card.Tag -eq $script:selSource) { Get-Tint (To-Color $src.Color) 0.86 } else { [System.Drawing.Color]::White }
        $card.BackColor = $back
        foreach ($ch in $card.Controls) { if ($ch -is [System.Windows.Forms.CheckBox]) { $ch.BackColor = $back } }
    }
    $sel = Get-SideSource
    $script:sideTip.SetToolTip($c.SideOptions, $(if ($sel.IsMine) { "Name, colour and quiet hours for $(Get-MineName)" } else { "Colour, your groups and quiet hours for $($sel.Name)" }))
    $script:sideTip.SetToolTip($c.SideRemove, $(if ($sel.IsMine) { "Remove all reminders in $(Get-MineName) (you can undo it)" } else { "Remove $($sel.Name) from this PC" }))
}

# --- Templates: ready-made sets of reminders you can adjust ---------------------------
function Show-PacksDialog($owner, [switch]$Welcome) {
    $d = New-Dialog $(if ($Welcome) { 'Welcome to Desk Reminders' } else { 'Templates' }) 700 560
    $intro = New-Note '' 16 12 668 44
    $intro.ForeColor = [System.Drawing.SystemColors]::ControlText
    $intro.Text = if ($Welcome) { "Pick a few ready-made reminders to start with and adjust them to how you like it. You can change or remove each one later in the list. More any time under Templates (top left)." }
                  else { "Ready-made reminders. Tick what you want, adjust the times, and they're added to your own schedule." }
    $base = (Get-Date).Date
    $ctl = @($intro)

    $ctl += New-Label 'Days' 16 62 60
    $days = New-Object System.Windows.Forms.ComboBox
    $days.DropDownStyle = 'DropDownList'
    $days.SetBounds(80, 62, 200, 28)
    [void]$days.Items.AddRange(@('Every day', 'Weekdays (Mon-Fri)', 'Weekends (Sat-Sun)'))
    $days.SelectedIndex = 0
    $ctl += $days

    function New-Pack([string]$name, [int]$y, [bool]$on) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $name
        $cb.Font = $BoldFont
        $cb.Checked = $on
        $cb.SetBounds(16, $y, 130, 28)
        return $cb
    }
    function New-Num([int]$x, [int]$y, [int]$min, [int]$max, [int]$val, [int]$step) {
        $n = New-Object System.Windows.Forms.NumericUpDown
        $n.Minimum = $min; $n.Maximum = $max; $n.Value = $val; $n.Increment = $step
        $n.SetBounds($x, $y, 64, 28)
        return $n
    }

    # Hydration
    $y = 110
    $p = @{}
    $p.Water = New-Pack 'Hydration' $y $true
    $p.WaterStep = New-Num 210 $y 15 240 60 15
    $p.WaterFrom = New-TimePicker 340 $y $base.AddHours(9)
    $p.WaterTo   = New-TimePicker 450 $y $base.AddHours(21)
    $p.WaterMl   = New-Num 590 $y 50 1000 250 50
    $ctl += @($p.Water, (New-Label 'every' 160 $y 48), $p.WaterStep, (New-Label 'min' 278 $y 34), (New-Label 'from' 304 $y 36),
        $p.WaterFrom, (New-Label 'to' 424 $y 24), $p.WaterTo, (New-Label 'glass' 540 $y 48), $p.WaterMl, (New-Label 'ml' 656 $y 30),
        (New-Note 'A pop-up to drink a glass of water.' 160 ($y + 30) 520 20))

    # Move
    $y += 64
    $p.Move = New-Pack 'Move' $y $true
    $p.MoveStep = New-Num 210 $y 15 240 60 15
    $p.MoveFrom = New-TimePicker 340 $y $base.AddHours(10).AddMinutes(30)
    $p.MoveTo   = New-TimePicker 450 $y $base.AddHours(20).AddMinutes(30)
    $p.MoveText = New-Object System.Windows.Forms.TextBox
    $p.MoveText.Text = 'Stand up, stretch, a few squats.'
    $p.MoveText.SetBounds(210, ($y + 32), 474, 28)
    $ctl += @($p.Move, (New-Label 'every' 160 $y 48), $p.MoveStep, (New-Label 'min' 278 $y 34), (New-Label 'from' 304 $y 36),
        $p.MoveFrom, (New-Label 'to' 424 $y 24), $p.MoveTo, (New-Label 'text' 160 ($y + 32) 48), $p.MoveText)

    # Eye breaks
    $y += 78
    $p.Eyes = New-Pack 'Eye breaks' $y $false
    $p.EyesStep = New-Num 210 $y 10 120 20 5
    $p.EyesFrom = New-TimePicker 340 $y $base.AddHours(9).AddMinutes(20)
    $p.EyesTo   = New-TimePicker 450 $y $base.AddHours(18)
    $ctl += @($p.Eyes, (New-Label 'every' 160 $y 48), $p.EyesStep, (New-Label 'min' 278 $y 34), (New-Label 'from' 304 $y 36),
        $p.EyesFrom, (New-Label 'to' 424 $y 24), $p.EyesTo,
        (New-Note 'Look at something far away for 20 seconds (the 20-20-20 rule).' 160 ($y + 30) 520 20))

    # Meals
    $y += 64
    $p.Meals = New-Pack 'Meals' $y $false
    $p.Breakfast = New-Object System.Windows.Forms.CheckBox; $p.Breakfast.Text = 'Breakfast'; $p.Breakfast.Checked = $true; $p.Breakfast.SetBounds(160, $y, 92, 28)
    $p.BreakfastAt = New-TimePicker 252 $y $base.AddHours(8)
    $p.Lunch = New-Object System.Windows.Forms.CheckBox; $p.Lunch.Text = 'Lunch'; $p.Lunch.Checked = $true; $p.Lunch.SetBounds(346, $y, 70, 28)
    $p.LunchAt = New-TimePicker 416 $y $base.AddHours(12).AddMinutes(30)
    $p.Dinner = New-Object System.Windows.Forms.CheckBox; $p.Dinner.Text = 'Dinner'; $p.Dinner.Checked = $true; $p.Dinner.SetBounds(510, $y, 74, 28)
    $p.DinnerAt = New-TimePicker 584 $y $base.AddHours(18)
    $p.MealNotice = New-Num 210 ($y + 32) 0 120 15 5
    $ctl += @($p.Meals, $p.Breakfast, $p.BreakfastAt, $p.Lunch, $p.LunchAt, $p.Dinner, $p.DinnerAt,
        (New-Label 'notice' 160 ($y + 32) 50), $p.MealNotice, (New-Label 'minutes before (0 = none), to start cooking or wrap up' 280 ($y + 32) 404))

    # Bedtime
    $y += 78
    $p.Bed = New-Pack 'Bedtime' $y $false
    $p.BedAt = New-TimePicker 210 $y $base.AddHours(23)
    $p.BedNotice = New-Num 360 $y 0 120 30 5
    $ctl += @($p.Bed, (New-Label 'at' 160 $y 48), $p.BedAt, (New-Label 'notice' 300 $y 56), $p.BedNotice, (New-Label 'minutes before' 430 $y 120),
        (New-Note 'Time to wind down: screens off, get ready for bed.' 160 ($y + 30) 520 20))

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Add to my schedule'; $ok.SetBounds(392, 510, 180, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = $(if ($Welcome) { 'Start empty' } else { 'Cancel' }); $cancel.SetBounds(578, 510, 106, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel
    $d.Controls.AddRange(@($ctl) + @($ok, $cancel))

    $res = Show-Dialog $d $owner
    $daysText = @('Every day', 'Weekdays', 'Weekends')[$days.SelectedIndex]
    $rows = @()
    function Get-Range($step, $from, $to) {
        'every ' + [int]$step.Value + ' min ' + $from.Value.ToString('HH:mm') + '-' + $to.Value.ToString('HH:mm')
    }
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($p.Water.Checked -and $p.WaterFrom.Value.TimeOfDay -le $p.WaterTo.Value.TimeOfDay) {
            $rows += ,@($daysText, (Get-Range $p.WaterStep $p.WaterFrom $p.WaterTo), '', 'Drink water', "Have a glass of water ($([int]$p.WaterMl.Value) ml).", '', '')
        }
        if ($p.Move.Checked -and $p.MoveFrom.Value.TimeOfDay -le $p.MoveTo.Value.TimeOfDay) {
            $rows += ,@($daysText, (Get-Range $p.MoveStep $p.MoveFrom $p.MoveTo), '', 'Move', $p.MoveText.Text.Trim(), '', '')
        }
        if ($p.Eyes.Checked -and $p.EyesFrom.Value.TimeOfDay -le $p.EyesTo.Value.TimeOfDay) {
            $rows += ,@($daysText, (Get-Range $p.EyesStep $p.EyesFrom $p.EyesTo), '', 'Eye break', 'Look at something far away for 20 seconds.', '', '')
        }
        if ($p.Meals.Checked) {
            $mn = if ([int]$p.MealNotice.Value -gt 0) { [string][int]$p.MealNotice.Value } else { '' }
            if ($p.Breakfast.Checked) { $rows += ,@($daysText, $p.BreakfastAt.Value.ToString('HH:mm'), '', 'Breakfast', 'Time to eat something.', $mn, '') }
            if ($p.Lunch.Checked)     { $rows += ,@($daysText, $p.LunchAt.Value.ToString('HH:mm'), '', 'Lunch', 'Lunch break.', $mn, '') }
            if ($p.Dinner.Checked)    { $rows += ,@($daysText, $p.DinnerAt.Value.ToString('HH:mm'), '', 'Dinner', 'Dinner time.', $mn, '') }
        }
        if ($p.Bed.Checked) {
            $bn = if ([int]$p.BedNotice.Value -gt 0) { [string][int]$p.BedNotice.Value } else { '' }
            $rows += ,@($daysText, $p.BedAt.Value.ToString('HH:mm'), '', 'Bedtime', 'Screens off, time to wind down.', $bn, '')
        }
    }
    $d.Dispose()
    if ($Welcome) { $script:settings.Welcomed = $true; Save-Settings }
    if ($rows.Count -eq 0) { return }
    $mine = $script:loaded.All[0]
    $newLines = @($rows | ForEach-Object { New-CsvLine $_ $mine.Delim })
    if (Update-ScheduleFile $mine { param($l) foreach ($n in $newLines) { $l.Add($n) } } 'template') {
        $tray.ShowBalloonTip(5000, 'Reminders added', "$($rows.Count) reminder(s) added to your schedule. Change or remove them in the Schedule window.", 'Info')
    }
}

# --- Backup and restore ---------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Backup-Reminders($owner) {
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title = 'Back up your reminders'
    $dlg.Filter = 'Zip files (*.zip)|*.zip'
    $dlg.FileName = 'DeskReminders-backup-' + (Get-Date).ToString('yyyy-MM-dd') + '.zip'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('DeskRemindersBackup-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $tmp | Out-Null
        foreach ($f in @($ScheduleFile, $SettingsFile)) { if (Test-Path -LiteralPath $f) { Copy-Item -LiteralPath $f -Destination $tmp } }
        if (Test-Path -LiteralPath $SharedDir) {
            New-Item -ItemType Directory -Path (Join-Path $tmp 'shared') | Out-Null
            Get-ChildItem -LiteralPath $SharedDir -Filter '*.csv' -File | Copy-Item -Destination (Join-Path $tmp 'shared')
        }
        if (Test-Path -LiteralPath $dlg.FileName) { Remove-Item -LiteralPath $dlg.FileName -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $dlg.FileName)
        Show-Msg $owner "Saved your schedule, shared schedules and settings to:`n$($dlg.FileName)`n`nThis file contains your own reminders, so keep it to yourself." 'Backup' | Out-Null
    } catch {
        Show-Msg $owner "The backup failed: $($_.Exception.Message)" 'Backup' 'OK' 'Warning' | Out-Null
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}

function Restore-Reminders($owner) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Restore a backup'
    $dlg.Filter = 'Zip files (*.zip)|*.zip'
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return $false }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('DeskRemindersRestore-' + [guid]::NewGuid().ToString('N'))
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($dlg.FileName, $tmp)
        $sched = Join-Path $tmp 'schedule.csv'
        $sett = Join-Path $tmp 'settings.json'
        $shared = @()
        if (Test-Path -LiteralPath (Join-Path $tmp 'shared')) { $shared = @(Get-ChildItem -LiteralPath (Join-Path $tmp 'shared') -Filter '*.csv' -File) }
        if (-not (Test-Path -LiteralPath $sched) -and -not (Test-Path -LiteralPath $sett) -and $shared.Count -eq 0) {
            Show-Msg $owner 'This zip is not a Desk Reminders backup.' 'Restore' | Out-Null; return $false
        }
        $ans = Show-Msg $owner "Replace your current schedule, shared schedules and settings with this backup?`n`n(Tip: make a backup of the current state first.)" 'Restore' 'YesNo' 'Question'
        if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
        if (Test-Path -LiteralPath $sched) { Copy-Item -LiteralPath $sched -Destination $ScheduleFile -Force }
        if (Test-Path -LiteralPath $sett) { Copy-Item -LiteralPath $sett -Destination $SettingsFile -Force }
        if ($shared.Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $tmp 'shared'))) {
            if (Test-Path -LiteralPath $SharedDir) { Get-ChildItem -LiteralPath $SharedDir -Filter '*.csv' -File | Remove-Item -Force }
            else { New-Item -ItemType Directory -Path $SharedDir | Out-Null }
            $shared | Copy-Item -Destination $SharedDir
        }
        $script:settings = Load-Settings
        $script:undo = $null
        Sync-Schedule -Force
        Show-Msg $owner 'Backup restored.' 'Restore' | Out-Null
        return $true
    } catch {
        Show-Msg $owner "The restore failed: $($_.Exception.Message)" 'Restore' 'OK' 'Warning' | Out-Null
        return $false
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}

# --- Settings window -------------------------------------------------------------
function Show-SettingsDialog($owner) {
    $st = $script:settings
    $d = New-Dialog 'Settings - Desk Reminders' 560 598
    $ctl = @()

    # Sound
    $gSound = New-Object System.Windows.Forms.GroupBox; $gSound.Text = 'Sound'; $gSound.SetBounds(12, 8, 536, 132)
    $soundOn = New-Object System.Windows.Forms.CheckBox; $soundOn.Text = 'Play a sound with each pop-up'; $soundOn.Checked = [bool]$st.SoundOn; $soundOn.SetBounds(14, 24, 300, 26)
    $soundBox = New-Object System.Windows.Forms.ComboBox; $soundBox.DropDownStyle = 'DropDownList'; $soundBox.SetBounds(14, 56, 300, 28)
    $script:soundValues = @($SoundChoices)
    foreach ($s in $SoundChoices) { [void]$soundBox.Items.Add((Get-SoundLabel $s)) }
    if ([System.IO.Path]::IsPathRooted($st.Sound)) { [void]$soundBox.Items.Add((Get-SoundLabel $st.Sound)); $script:soundValues += $st.Sound }
    [void]$soundBox.Items.Add('Your own .wav file')
    $idx = [array]::IndexOf([string[]]$script:soundValues, [string]$st.Sound)
    $soundBox.SelectedIndex = [math]::Max(0, $idx)
    $script:soundLast = $soundBox.SelectedIndex
    $soundBox.Add_SelectedIndexChanged({
        if ($this.SelectedIndex -lt $script:soundValues.Count) {
            $script:soundLast = $this.SelectedIndex
            Play-Chime -Preview -Sound $script:soundValues[$this.SelectedIndex] -Volume $script:setCtl.Volume.Value   # hear it right away
            return
        }
        $fd = New-Object System.Windows.Forms.OpenFileDialog
        $fd.Title = 'Choose a sound'; $fd.Filter = 'WAV sounds (*.wav)|*.wav'
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:soundValues += $fd.FileName
            $this.Items.Insert($this.Items.Count - 1, (Get-SoundLabel $fd.FileName))
            $this.SelectedIndex = $this.Items.Count - 2
        } else { $this.SelectedIndex = $script:soundLast }
    })
    $play = New-Object System.Windows.Forms.Button; $play.Text = 'Play'; $play.SetBounds(322, 55, 80, 30)
    $play.Add_Click({ Play-Chime -Preview -Sound $script:soundValues[$script:setCtl.Sound.SelectedIndex] -Volume $script:setCtl.Volume.Value })
    $volLbl = New-Label 'Volume' 14 92 60
    $vol = New-Object System.Windows.Forms.TrackBar
    $vol.Minimum = 0; $vol.Maximum = 100; $vol.TickFrequency = 10; $vol.SmallChange = 5; $vol.LargeChange = 10
    $vol.Value = [math]::Max(0, [math]::Min(100, [int]$st.Volume))
    $vol.AutoSize = $false
    $vol.SetBounds(76, 90, 300, 34)
    $volPct = New-Label "$($vol.Value)%" 382 92 60
    $vol.Tag = $volPct
    $vol.Add_ValueChanged({ $this.Tag.Text = "$($this.Value)%" })
    # Hear the new volume when you let go of the slider
    $vol.Add_MouseUp({ Play-Chime -Preview -Sound $script:soundValues[$script:setCtl.Sound.SelectedIndex] -Volume $this.Value })
    $vol.Add_KeyUp({ Play-Chime -Preview -Sound $script:soundValues[$script:setCtl.Sound.SelectedIndex] -Volume $this.Value })
    $gSound.Controls.AddRange(@($soundOn, $soundBox, $play, $volLbl, $vol, $volPct))

    # Quiet hours
    $gQuiet = New-Object System.Windows.Forms.GroupBox; $gQuiet.Text = 'Quiet hours'; $gQuiet.SetBounds(12, 148, 536, 104)
    $quietOn = New-Object System.Windows.Forms.CheckBox; $quietOn.Text = 'No pop-ups from'; $quietOn.Checked = [bool]$st.Quiet.On; $quietOn.SetBounds(14, 26, 140, 26)
    $base = (Get-Date).Date
    $qf = Parse-Clock $st.Quiet.From; if ($null -eq $qf) { $qf = 23 * 60 }
    $qt = Parse-Clock $st.Quiet.To; if ($null -eq $qt) { $qt = 8 * 60 }
    $quietFrom = New-TimePicker 156 25 $base.AddMinutes($qf)
    $toLbl = New-Label 'to' 242 25 24
    $quietTo = New-TimePicker 270 25 $base.AddMinutes($qt)
    $qNote = New-Note 'Each schedule can still be let through: select it in the Schedules list > Options. Missed pop-ups are not shown later.' 14 60 510 36
    $gQuiet.Controls.AddRange(@($quietOn, $quietFrom, $toLbl, $quietTo, $qNote))

    # Pop-ups
    $gPop = New-Object System.Windows.Forms.GroupBox; $gPop.Text = 'Pop-ups'; $gPop.SetBounds(12, 260, 536, 98)
    $corner = New-Object System.Windows.Forms.ComboBox; $corner.DropDownStyle = 'DropDownList'; $corner.SetBounds(140, 24, 180, 28)
    $cornerValues = @('BottomRight', 'BottomLeft', 'TopRight', 'TopLeft')
    [void]$corner.Items.AddRange(@('Bottom right', 'Bottom left', 'Top right', 'Top left'))
    $corner.SelectedIndex = [math]::Max(0, [array]::IndexOf($cornerValues, [string]$st.Corner))
    $screen = New-Object System.Windows.Forms.ComboBox; $screen.DropDownStyle = 'DropDownList'; $screen.SetBounds(140, 58, 180, 28)
    [void]$screen.Items.Add('Main screen')
    $all = @([System.Windows.Forms.Screen]::AllScreens)
    for ($i = 0; $i -lt $all.Count; $i++) { [void]$screen.Items.Add("Screen $($i + 1) ($($all[$i].Bounds.Width)x$($all[$i].Bounds.Height))") }
    $screen.SelectedIndex = if ([int]$st.Monitor -lt $screen.Items.Count) { [int]$st.Monitor } else { 0 }
    $test = New-Object System.Windows.Forms.Button; $test.Text = 'Test'; $test.SetBounds(440, 23, 80, 30)
    $test.Add_Click({
        $c = $script:setCtl
        $keep = @{ Corner = $script:settings.Corner; Monitor = $script:settings.Monitor }
        $script:settings.Corner = @('BottomRight', 'BottomLeft', 'TopRight', 'TopLeft')[$c.Corner.SelectedIndex]
        $script:settings.Monitor = $c.Screen.SelectedIndex
        $keepVol = $script:settings.Volume; $script:settings.Volume = $c.Volume.Value
        Show-TestReminder
        $script:settings.Corner = $keep.Corner; $script:settings.Monitor = $keep.Monitor; $script:settings.Volume = $keepVol
    })
    $gPop.Controls.AddRange(@((New-Label 'Corner' 14 24 120), $corner, (New-Label 'Screen' 14 58 120), $screen, $test))

    # Windows
    $gWin = New-Object System.Windows.Forms.GroupBox; $gWin.Text = 'Windows'; $gWin.SetBounds(12, 366, 536, 170)
    $startup = New-Object System.Windows.Forms.CheckBox; $startup.Text = 'Start Desk Reminders when I log in to Windows'
    $startup.Checked = [bool](Test-StartupLink); $startup.SetBounds(14, 24, 500, 26)
    $splashOn = New-Object System.Windows.Forms.CheckBox; $splashOn.Text = 'Show the welcome screen and open the schedule when it starts'
    $splashOn.Checked = [bool]$st.ShowWelcome; $splashOn.SetBounds(14, 52, 510, 26)
    $bk = New-Object System.Windows.Forms.Button; $bk.Text = 'Back up'; $bk.SetBounds(14, 90, 110, 32)
    $bk.Add_Click({ Backup-Reminders $this.FindForm() })
    $rs = New-Object System.Windows.Forms.Button; $rs.Text = 'Restore'; $rs.SetBounds(130, 90, 110, 32)
    $rs.Add_Click({
        $form = $this.FindForm()
        if (Restore-Reminders $form) { $form.DialogResult = [System.Windows.Forms.DialogResult]::Abort }
    })
    $of = New-Object System.Windows.Forms.Button; $of.Text = 'Open folder'; $of.SetBounds(246, 90, 110, 32)
    $of.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$PSScriptRoot`"" })
    $bkNote = New-Note 'A backup holds your schedule, shared schedules and settings in one zip, e.g. for a new PC.' 14 128 510 36
    $gWin.Controls.AddRange(@($startup, $splashOn, $bk, $rs, $of, $bkNote))

    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Save'; $ok.SetBounds(350, 550, 96, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = 'Cancel'; $cancel.SetBounds(452, 550, 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel
    $d.Controls.AddRange(@($gSound, $gQuiet, $gPop, $gWin, $ok, $cancel))
    $script:setCtl = @{ Sound = $soundBox; Corner = $corner; Screen = $screen; Volume = $vol }

    $res = Show-Dialog $d $owner
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        $st = $script:settings   # a restore may have replaced it
        $st.SoundOn = $soundOn.Checked
        $st.Volume = $vol.Value
        $st.Sound = $script:soundValues[$soundBox.SelectedIndex]
        $st.Quiet = @{ On = $quietOn.Checked; From = $quietFrom.Value.ToString('HH:mm'); To = $quietTo.Value.ToString('HH:mm') }
        $st.Corner = $cornerValues[$corner.SelectedIndex]
        $st.Monitor = $screen.SelectedIndex
        $st.ShowWelcome = [bool]$splashOn.Checked
        Save-Settings
        try {
            if ($startup.Checked -and -not (Test-StartupLink)) { Install-StartupLink }
            elseif (-not $startup.Checked -and (Test-StartupLink)) { Remove-StartupLink }
        } catch {
            Show-Msg $owner "Could not change the Windows startup setting: $($_.Exception.Message)" 'Settings' 'OK' 'Warning' | Out-Null
        }
        Sync-Schedule -Force
    }
    $d.Dispose()
}

# --- Main window ------------------------------------------------------------
function Set-WeekValues([datetime]$anyDay, [datetime]$select) {
    $dow = [int]$anyDay.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
    $script:weekStart = $anyDay.Date.AddDays(1 - $dow)
    $script:selDay = $select.Date
}

function Set-Week([datetime]$anyDay, [datetime]$select) {
    Set-WeekValues $anyDay $select
    Refresh-ScheduleWindow
}

function Update-Banner {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    if ((Get-Date) -lt $script:pauseUntil) {
        $c.Banner.BackColor = Get-Tint ([System.Drawing.Color]::DimGray) 0.85
        $c.BannerBar.BackColor = [System.Drawing.Color]::DimGray
        $c.BannerText.Text = 'Paused until ' + $script:pauseUntil.ToString('HH:mm') + '. Right-click the bell > Resume to continue.'
        return
    }
    $n = Get-Next
    if ($n) {
        $col = To-Color $n.Colour
        $c.Banner.BackColor = Get-Tint $col 0.86
        $c.BannerBar.BackColor = $col
        $what = if ($n.Kind -eq 'notice') { "Notice: $($n.Title) at $($n.EventTime)" } else { $n.Title }
        $from = if ($n.IsMine) { Get-MineName } else { $n.Source }
        $day = if ($n.At.Date -ne (Get-Date).Date) { 'tomorrow ' } else { '' }
        $c.BannerText.Text = "Next up:  $day$($n.Time)   $what    ($(Format-Until $n.At), $from)"
    } else {
        $c.Banner.BackColor = Get-Tint $Accent 0.9
        $c.BannerBar.BackColor = $Accent
        $c.BannerText.Text = 'Nothing coming up in the next 24 hours.'
    }
}

function Refresh-ScheduleWindow([switch]$Tick) {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    $today = (Get-Date).Date
    $end = $script:weekStart.AddDays(6)
    $c.Week.Text = $script:weekStart.ToString('d MMM', $En) + ' - ' + $end.ToString('d MMM yyyy', $En)

    Refresh-Sidebar
    $script:refreshError = $null
    try {
        $all = @(Add-Alerts @(Get-Occurrences $script:loaded.All $script:weekStart $end $script:settings.Hidden))
        $week = @($all | Where-Object { $_.Kind -eq 'event' })
    } catch {
        $week = @()
        $script:refreshError = $_.Exception.Message
    }
    for ($i = 0; $i -lt 7; $i++) {
        $d = $script:weekStart.AddDays($i)
        $b = $c.Days[$i]
        $b.Text = $d.ToString('ddd', $En) + "`n" + $d.ToString('d MMM', $En)
        # Dots for the other days only: the selected day's reminders are in the list below
        $b.Tag = @{ Index = $i; Dots = $(if ($d -eq $script:selDay) { @() } else { @($week | Where-Object { $_.At.Date -eq $d } | ForEach-Object { $_.Colour } | Select-Object -Unique) }) }
        # (A flat button draws its border in the text colour unless told otherwise:
        #  the selected day gets a blue border, so no thin white line around it)
        if ($d -eq $script:selDay) {
            $b.BackColor = $Accent; $b.ForeColor = [System.Drawing.Color]::White
            $b.FlatAppearance.BorderColor = $Accent
        } else {
            $b.BackColor = [System.Drawing.SystemColors]::Control; $b.ForeColor = [System.Drawing.SystemColors]::ControlText
            $b.FlatAppearance.BorderColor = [System.Drawing.SystemColors]::ControlText
        }
        $b.Font = if ($d -eq $today) { $BoldFont } else { $UiFont }
        $b.Invalidate()
    }

    # Today: what's already over is hidden (or greyed out when "Hide what's done" is off)
    $now = Get-Date
    $isToday = ($script:selDay -eq $today)
    $entries = @($week | Where-Object { $_.At.Date -eq $script:selDay })
    $doneCount = 0
    if ($isToday) {
        $doneCount = @($entries | Where-Object { $_.At.AddMinutes(1) -le $now }).Count
        if ($script:settings.HidePast) { $entries = @($entries | Where-Object { $_.At.AddMinutes(1) -gt $now }) }
    }
    $c.HidePast.Visible = $isToday
    $script:hidePastLoading = $true
    $c.HidePast.Checked = [bool]$script:settings.HidePast
    $script:hidePastLoading = $false
    $c.Heading.Text = $script:selDay.ToString('dddd d MMMM yyyy', $En) + $(if ($isToday) { '  (today)' } else { '' }) +
        $(if ($isToday -and $script:settings.HidePast -and $doneCount -gt 0) { "  -  $doneCount done and hidden" } else { '' })
    $script:listMinute = $now.ToString('yyyy-MM-dd HH:mm')

    # Keep what you selected (and where you scrolled) when the list refreshes by itself
    $keepSel = $null; $keepTop = $null
    if ($c.List.SelectedItems.Count -gt 0 -and $c.List.SelectedItems[0].Tag) {
        $t0 = $c.List.SelectedItems[0].Tag; $keepSel = "$($t0.File)|$($t0.Line)|$($t0.At)"
    }
    if ($Tick -and $c.List.TopItem -and $c.List.TopItem.Tag) {
        $t1 = $c.List.TopItem.Tag; $keepTop = "$($t1.File)|$($t1.Line)|$($t1.At)"
    }
    $c.List.BeginUpdate()
    $c.List.Items.Clear()
    $grey = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $firstUpcoming = $null
    foreach ($e in $entries) {
        $isDone = $isToday -and ($e.At.AddMinutes(1) -le $now)
        $col = if ($isDone) { $grey } else { To-Color $e.Colour }
        $active = $e.AlertState -ne 'off'      # 'off' = another group's event you didn't ask for
        $it = New-Object System.Windows.Forms.ListViewItem('')
        $it.ImageKey = $e.AlertState
        $it.ToolTipText = Get-AlertTip $e
        $it.UseItemStyleForSubItems = $false
        $tm = $it.SubItems.Add($e.Time)
        $tm.ForeColor = if ($active) { $col } else { $grey }
        $t = $it.SubItems.Add($e.Title)
        $t.ForeColor = if ($active) { $col } else { $grey }
        $t.Font = if ($e.AlertState -eq 'off') { $ItalicFont } elseif ($e.AlertState -eq 'muted') { $UiFont } else { $BoldFont }
        $tx = $it.SubItems.Add($e.Text)
        if (-not $active) { $tx.ForeColor = $grey }
        $forText = if (@($e.For).Count -eq 0) { $(if ($e.IsMine) { '' } else { 'Everyone' }) }
                   else { (@($e.For) -join ', ') + $(if ($e.ForMe) { '' } elseif ($e.AlertState -eq 'shout') { ' (you too)' } else { ' (not you)' }) }
        $fs = $it.SubItems.Add($forText)
        $fs.ForeColor = if ($active) { [System.Drawing.SystemColors]::ControlText } else { $grey }
        $ns = $it.SubItems.Add($(if ($e.Notice -gt 0) { "$($e.Notice) min before" } else { '' }))
        if (-not $active) { $ns.ForeColor = $grey }
        $ss = $it.SubItems.Add($(if ($e.IsMine) { Get-MineName } elseif ($e.Owned) { "$($e.Source) (yours)" } else { $e.Source }))
        $ss.ForeColor = if ($active) { $col } else { $grey }
        $rep = if ($e.OneOff) { 'This day only' } else { "$($e.DaysText), $($e.TimeText)" }
        if (-not $e.IsMine -and $e.TzText) { $rep += " ($($e.TzText))" }
        $s = $it.SubItems.Add($rep)
        $s.ForeColor = if ($isDone) { $grey } else { [System.Drawing.Color]::DimGray }
        if ($isDone) {
            foreach ($sub in $it.SubItems) { $sub.ForeColor = $grey }
            $t.Font = $UiFont
        }
        $it.Tag = $e
        [void]$c.List.Items.Add($it)
        if (-not $isDone -and -not $firstUpcoming) { $firstUpcoming = $it }
    }
    if ($entries.Count -eq 0) {
        $it = New-Object System.Windows.Forms.ListViewItem('')
        [void]$it.SubItems.Add('')
        $msg = if (@($script:loaded.Mine.Rows).Count -eq 0 -and @($script:loaded.All).Count -le 1) { 'No reminders yet. Click Add reminder, or Templates (top left) to get started.' }
               elseif ($isToday -and $doneCount -gt 0) { "Nothing left for today. Untick ""Hide what's done"" to see the $doneCount earlier one(s)." }
               else { 'No reminders on this day' }
        [void]$it.SubItems.Add($msg)
        $it.ForeColor = [System.Drawing.Color]::Gray
        [void]$c.List.Items.Add($it)
    }
    $c.List.EndUpdate()
    $topItem = $null
    foreach ($it in $c.List.Items) {
        if (-not $it.Tag) { continue }
        $k = "$($it.Tag.File)|$($it.Tag.Line)|$($it.Tag.At)"
        if ($keepSel -and $k -eq $keepSel) { $it.Selected = $true }
        if ($keepTop -and $k -eq $keepTop) { $topItem = $it }
    }
    try {
        if ($topItem) { $c.List.TopItem = $topItem }
        elseif (-not $Tick -and $firstUpcoming) { $firstUpcoming.EnsureVisible() }
    } catch {}

    if ($script:refreshError) {
        $c.Status.ForeColor = [System.Drawing.Color]::Firebrick
        $c.Status.Text = 'Could not show this week: ' + $script:refreshError
    } elseif ($script:errors.Count -gt 0) {
        $c.Status.ForeColor = [System.Drawing.Color]::Firebrick
        $c.Status.Text = "$($script:errors.Count) row(s) have a problem and are ignored. First: " + $script:errors[0]
    } else {
        $c.Status.ForeColor = [System.Drawing.Color]::DimGray
        $c.Status.Text = if ($script:settings.Quiet.On) { "Quiet hours $($script:settings.Quiet.From)-$($script:settings.Quiet.To)" } else { '' }
    }
    $canUndo = [bool]$script:undo
    $c.Undo.Enabled = $canUndo
    # The button stays short ("Undo"); the tooltip says what it undoes
    $what = if ($canUndo) { "Undo $($script:undo.What)" } else { 'Undo' }
    $c.UndoTip.SetToolTip($c.Undo, $(if ($canUndo) { "$what (Ctrl+Z)" } else { 'Nothing to undo' }))
    Update-Banner
}

function New-MenuItem($parent, [string]$text, [scriptblock]$action) {
    $mi = New-Object System.Windows.Forms.ToolStripMenuItem $text
    if ($action) { $mi.Add_Click($action) }
    if ($parent -is [System.Windows.Forms.ToolStripMenuItem]) { [void]$parent.DropDownItems.Add($mi) } else { [void]$parent.Items.Add($mi) }
    return $mi
}

function New-Btn([string]$text, [int]$x, [int]$y, [int]$w, [int]$h = 34) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.SetBounds($x, $y, $w, $h)
    return $b
}

# --- Date picker: a big, simple month calendar (no animation) -----------------
function Update-DatePicker {
    $p = $script:dp
    $first = $p.Month
    $p.Title.Text = $first.ToString('MMMM yyyy', $En)
    $dow = [int]$first.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
    $start = $first.AddDays(1 - $dow)          # weeks start on Monday
    $today = (Get-Date).Date
    for ($i = 0; $i -lt 42; $i++) {
        $d = $start.AddDays($i)
        $b = $p.Days[$i]
        $b.Text = [string]$d.Day
        $b.Tag = $d
        $inMonth = ($d.Month -eq $first.Month)
        if ($d -eq $script:selDay) {
            $b.BackColor = $Accent; $b.ForeColor = [System.Drawing.Color]::White
            $b.FlatAppearance.BorderColor = $Accent; $b.FlatAppearance.BorderSize = 1
            $b.Font = $BoldFont
        } else {
            $b.BackColor = [System.Drawing.Color]::White
            $b.ForeColor = if ($d -eq $today) { $Accent } elseif ($inMonth) { [System.Drawing.Color]::FromArgb(30, 30, 30) } else { [System.Drawing.Color]::FromArgb(185, 185, 185) }
            $b.FlatAppearance.BorderColor = $Accent
            $b.FlatAppearance.BorderSize = $(if ($d -eq $today) { 2 } else { 0 })
            $b.Font = if ($d -eq $today) { $BoldFont } else { $UiFont }
        }
    }
}

# Understands a date typed by hand: 24-12-2026, 24/12/2026, 24.12.2026, 2026-12-24,
# 24 dec 2026, 24 December, December 24, 24-12 ... (day first; no year = the next time it comes)
function ConvertFrom-TypedDate([string]$text) {
    $t = ($text -replace '\s+', ' ' -replace ',', '').Trim()
    if ($t -eq '') { return $null }
    $cultures = @($En, [Globalization.CultureInfo]::InvariantCulture)
    $withYear = @('d-M-yyyy', 'd/M/yyyy', 'd.M.yyyy', 'yyyy-M-d', 'yyyy/M/d', 'd MMM yyyy', 'd MMMM yyyy', 'MMM d yyyy', 'MMMM d yyyy',
                  'd-M-yy', 'd/M/yy', 'd.M.yy', 'M/d/yyyy')
    $noYear = @('d-M', 'd/M', 'd.M', 'd MMM', 'd MMMM', 'MMM d', 'MMMM d')
    $out = [datetime]::MinValue
    foreach ($c in $cultures) {
        if ([datetime]::TryParseExact($t, [string[]]$withYear, $c, 'AllowWhiteSpaces', [ref]$out)) { return $out.Date }
    }
    foreach ($c in $cultures) {
        if ([datetime]::TryParseExact($t, [string[]]$noYear, $c, 'AllowWhiteSpaces', [ref]$out)) {
            $d = $out.Date
            $d = New-Object DateTime((Get-Date).Year, $d.Month, $d.Day)
            if ($d -lt (Get-Date).Date) { $d = $d.AddYears(1) }
            return $d
        }
    }
    return $null
}

function Invoke-TypedDate {
    $p = $script:dp
    $d = ConvertFrom-TypedDate $p.Typed.Text
    if (-not $d) {
        $p.TypedHint.Text = "Can't read that date. Try 24-12-2026 or 24 dec 2026."
        $p.TypedHint.ForeColor = [System.Drawing.Color]::Firebrick
        return
    }
    $p.Drop.Close()
    Set-Week $d $d
}

function Move-DatePicker([int]$months) {
    $script:dp.Month = $script:dp.Month.AddMonths($months)
    Update-DatePicker
}

function Show-DatePicker($anchor) {
    if (-not $script:dp) {
        $cell = 46; $pad = 12
        $W = $pad * 2 + 7 * $cell
        $panel = New-Object System.Windows.Forms.Panel
        $panel.BackColor = [System.Drawing.Color]::White
        $panel.Size = New-Object System.Drawing.Size($W, 400)
        $p = @{ Panel = $panel; Days = @() }

        $back = New-Btn ([string][char]0x2039) $pad 10 40 36
        $fwd = New-Btn ([string][char]0x203A) ($W - $pad - 40) 10 40 36
        foreach ($nav in @($back, $fwd)) {
            $nav.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            $nav.FlatStyle = 'Flat'; $nav.FlatAppearance.BorderSize = 0
            $nav.ForeColor = $Accent
            $nav.Cursor = [System.Windows.Forms.Cursors]::Hand
        }
        $back.Add_Click({ Move-DatePicker -1 })
        $fwd.Add_Click({ Move-DatePicker 1 })
        $p.Title = New-Object System.Windows.Forms.Label
        $p.Title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
        $p.Title.TextAlign = 'MiddleCenter'
        $p.Title.SetBounds(($pad + 44), 10, ($W - 2 * $pad - 88), 36)
        $panel.Controls.AddRange(@($back, $fwd, $p.Title))

        $names = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
        for ($i = 0; $i -lt 7; $i++) {
            $l = New-Object System.Windows.Forms.Label
            $l.Text = $names[$i]
            $l.Font = $SmallBold
            $l.ForeColor = [System.Drawing.Color]::Gray
            $l.TextAlign = 'MiddleCenter'
            $l.SetBounds(($pad + $i * $cell), 54, $cell, 22)
            $panel.Controls.Add($l)
        }
        for ($i = 0; $i -lt 42; $i++) {
            $b = New-Object System.Windows.Forms.Button
            $b.FlatStyle = 'Flat'
            $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(228, 236, 247)
            $b.SetBounds(($pad + ($i % 7) * $cell + 2), (80 + [math]::Floor($i / 7) * 42), ($cell - 4), 38)
            $b.Cursor = [System.Windows.Forms.Cursors]::Hand
            $b.Add_Click({
                $d = [datetime]$this.Tag
                $script:dp.Drop.Close()
                Set-Week $d $d
            })
            $panel.Controls.Add($b)
            $p.Days += $b
        }
        # Or type a date by hand
        $p.TypedHint = New-Object System.Windows.Forms.Label
        $p.TypedHint.Font = $SmallFont
        $p.TypedHint.SetBounds($pad, 334, ($W - 2 * $pad), 18)
        $p.Typed = New-Object System.Windows.Forms.TextBox
        $p.Typed.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $p.Typed.SetBounds($pad, 355, ($W - 2 * $pad - 80), 30)
        $p.Typed.Add_KeyDown({
            if ($_.KeyCode -eq 'Enter') { $_.SuppressKeyPress = $true; Invoke-TypedDate }
        })
        $go = New-Btn 'Go' ($W - $pad - 74) 353 74 32
        $go.Font = $BoldFont
        $go.Add_Click({ Invoke-TypedDate })
        $panel.Controls.AddRange(@($p.TypedHint, $p.Typed, $go))
        $panel.Height = 398
        # The mouse wheel flips months too (whichever part of the calendar has focus)
        foreach ($ctl in @($panel) + @($panel.Controls)) {
            $ctl.Add_MouseWheel({ if ($_.Delta -gt 0) { Move-DatePicker -1 } else { Move-DatePicker 1 } })
        }

        $hostCtl = New-Object System.Windows.Forms.ToolStripControlHost($panel)
        $hostCtl.Margin = New-Object System.Windows.Forms.Padding(0)
        $hostCtl.Padding = New-Object System.Windows.Forms.Padding(0)
        $drop = New-Object System.Windows.Forms.ToolStripDropDown
        $drop.Padding = New-Object System.Windows.Forms.Padding(1)
        $drop.DropShadowEnabled = $true
        [void]$drop.Items.Add($hostCtl)
        $drop.Add_Opened({ [void]$script:dp.Days[10].Focus() })
        $p.Drop = $drop
        $script:dp = $p
    }
    $script:dp.Month = New-Object DateTime($script:selDay.Year, $script:selDay.Month, 1)
    $script:dp.Typed.Text = ''
    $script:dp.TypedHint.Text = 'Or type a date, e.g. 24-12-2026 or 24 dec'
    $script:dp.TypedHint.ForeColor = [System.Drawing.Color]::Gray
    Update-DatePicker
    $script:dp.Drop.Show($anchor, 0, $anchor.Height)
}

function Open-ScheduleWindow {
    if ($script:sw -and -not $script:sw.IsDisposed) {
        if ($script:sw.WindowState -eq 'Minimized') { $script:sw.WindowState = 'Normal' }
        $script:sw.Activate(); return
    }
    $W = 1130; $H = 700
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Desk Reminders $AppVersion"
    $f.Font = $UiFont
    $f.StartPosition = 'CenterScreen'
    $f.ClientSize = New-Object System.Drawing.Size($W, $H)
    $f.MinimumSize = New-Object System.Drawing.Size(1000, 560)
    if ($script:appIcon) { $f.Icon = $script:appIcon }
    $c = @{}
    $script:sideTip = New-Object System.Windows.Forms.ToolTip

    # Menu bar: Settings and GitHub (everything online lives under GitHub)
    $ms = New-Object System.Windows.Forms.MenuStrip
    $ms.Font = $UiFont
    [void](New-MenuItem $ms 'Settings' { Show-SettingsDialog $script:sw })
    $mGh = New-MenuItem $ms 'GitHub' $null
    [void](New-MenuItem $mGh 'Code and downloads' { Open-Url $RepoUrl })
    [void](New-MenuItem $mGh 'How to use' { Open-Url "$RepoUrl#readme" })
    [void](New-MenuItem $mGh 'Shared schedules and groups' { Open-Url "$RepoUrl/blob/main/docs/shared-schedules.md" })
    [void](New-MenuItem $mGh 'Schedule file format' { Open-Url "$RepoUrl/blob/main/docs/schedule-format.md" })
    [void](New-MenuItem $mGh 'Troubleshooting' { Open-Url "$RepoUrl/blob/main/docs/troubleshooting.md" })
    [void]$mGh.DropDownItems.Add('-')
    [void](New-MenuItem $mGh "What's new (releases)" { Open-Url "$RepoUrl/releases" })
    [void](New-MenuItem $mGh 'Report a problem or idea' { Open-Url "$RepoUrl/issues/new/choose" })
    foreach ($mi in $mGh.DropDownItems) { if ($mi -is [System.Windows.Forms.ToolStripMenuItem]) { $mi.ToolTipText = 'Opens in your browser' } }

    $top = 34
    # Next-up banner, full width
    $c.Banner = New-Object System.Windows.Forms.Panel
    $c.Banner.SetBounds(12, $top, ($W - 24), 40)
    $c.Banner.Anchor = 'Top, Left, Right'
    $c.BannerBar = New-Object System.Windows.Forms.Panel
    $c.BannerBar.SetBounds(0, 0, 6, 40)
    $c.BannerText = New-Object System.Windows.Forms.Label
    $c.BannerText.Font = $BoldFont
    $c.BannerText.SetBounds(16, 0, ($W - 50), 40)
    $c.BannerText.TextAlign = 'MiddleLeft'
    $c.BannerText.AutoEllipsis = $true
    $c.BannerText.Anchor = 'Top, Left, Right'
    $c.Banner.Controls.AddRange(@($c.BannerBar, $c.BannerText))

    # --- Left: Schedules panel (your own + shared) ---
    $y0 = $top + 52
    $footH = 34
    $sideH = $H - $y0 - $footH - 12
    $side = New-Object System.Windows.Forms.Panel
    $side.SetBounds(12, $y0, 236, $sideH)
    $side.Anchor = 'Top, Bottom, Left'
    $side.BackColor = [System.Drawing.Color]::White
    $side.BorderStyle = 'FixedSingle'
    $sideTitle = New-Object System.Windows.Forms.Label
    $sideTitle.Text = 'Schedules'
    $sideTitle.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $sideTitle.SetBounds(10, 8, 108, 26)
    $tpl = New-Btn 'Templates' 120 7 104 28
    $tpl.Add_Click({ Show-PacksDialog $script:sw })
    $script:sideTip.SetToolTip($tpl, 'Ready-made reminders you can adjust: water, moving, eye breaks, meals, bedtime')
    $imp = New-Btn 'Import' 10 40 104 36
    $imp.Font = $BoldFont
    $imp.Add_Click({ Import-SharedSchedule $script:sw })
    $script:sideTip.SetToolTip($imp, 'Add a schedule file someone shared with you (e.g. from Discord)')
    $exp = New-Btn 'Export' 120 40 104 36
    $exp.Font = $BoldFont
    $exp.Add_Click({ Export-SharedSchedule $this })
    $script:sideTip.SetToolTip($exp, 'Save a shared schedule you made as a file to post for your members')
    $c.Cards = New-Object System.Windows.Forms.FlowLayoutPanel
    $c.Cards.SetBounds(0, 84, 234, ($sideH - 84 - 96))
    $c.Cards.Anchor = 'Top, Bottom, Left'
    $c.Cards.FlowDirection = 'TopDown'
    $c.Cards.WrapContents = $false
    $c.Cards.AutoScroll = $true
    $sep = New-Object System.Windows.Forms.Panel
    $sep.SetBounds(10, ($sideH - 92), 214, 1)
    $sep.BackColor = [System.Drawing.Color]::Gainsboro
    $sep.Anchor = 'Bottom, Left'
    $c.SideOptions = New-Btn 'Options' 10 ($sideH - 84) 104 32
    $c.SideOptions.Anchor = 'Bottom, Left'
    $c.SideOptions.Add_Click({ Show-ScheduleOptions (Get-SideSource) $script:sw })
    $c.SideRemove = New-Btn 'Remove' 120 ($sideH - 84) 104 32
    $c.SideRemove.Anchor = 'Bottom, Left'
    $c.SideRemove.Add_Click({
        $s = Get-SideSource
        if ($s.IsMine) { Clear-MySchedule } else { Remove-SharedSchedule $s }
    })
    $newSh = New-Btn '+ New shared schedule' 10 ($sideH - 46) 214 32
    $newSh.Anchor = 'Bottom, Left'
    $newSh.Add_Click({ $n = @(New-SharedSchedule $script:sw)[-1]; if ($n) { $script:selSource = [System.IO.Path]::GetFileName($n); Refresh-ScheduleWindow } })
    $script:sideTip.SetToolTip($newSh, 'Make a schedule for your guild, team or community')
    $side.Controls.AddRange(@($sideTitle, $tpl, $imp, $exp, $c.Cards, $sep, $c.SideOptions, $c.SideRemove, $newSh))

    # --- Right: week and reminders ---
    $x0 = 262
    $cw = $W - $x0 - 12
    $y = $y0
    # Pick a date: our own big month calendar drops down; choosing a day jumps to its week
    $prev = New-Btn ('Pick a date  ' + [char]0x25BE) $x0 $y 140 32
    $prev.Font = $BoldFont
    $prev.Add_Click({ Show-DatePicker $this })
    $script:sideTip.SetToolTip($prev, 'Jump to any date, e.g. to plan something weeks ahead')
    $c.Week = New-Object System.Windows.Forms.Label
    $c.Week.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $c.Week.TextAlign = 'MiddleCenter'
    $c.Week.SetBounds(($x0 + 146), $y, ($cw - 262), 32)
    $c.Week.Anchor = 'Top, Left, Right'
    $todayBtn = New-Btn 'Today' ($x0 + $cw - 110) $y 110 32
    $todayBtn.Anchor = 'Top, Right'
    $todayBtn.Add_Click({ Set-Week (Get-Date) (Get-Date) })

    $y += 42
    $c.Days = @()
    $dw = [int][math]::Floor(($cw - 36) / 7)
    for ($i = 0; $i -lt 7; $i++) {
        $b = New-Object System.Windows.Forms.Button
        $b.SetBounds(($x0 + $i * ($dw + 6)), $y, $dw, 62)
        $b.FlatStyle = 'Flat'
        $b.TextAlign = 'TopCenter'
        $b.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
        $b.Tag = @{ Index = $i; Dots = @() }
        $b.Add_Click({ $script:selDay = $script:weekStart.AddDays([int]$this.Tag.Index); Refresh-ScheduleWindow })
        # Coloured dots: which schedules have something on that day
        $b.Add_Paint({
            param($s, $e)
            $dots = @($s.Tag.Dots)
            if ($dots.Count -eq 0) { return }
            $e.Graphics.SmoothingMode = 'AntiAlias'
            $n = [math]::Min($dots.Count, 6)
            $x = [int](($s.Width - ($n * 12 - 4)) / 2)
            for ($k = 0; $k -lt $n; $k++) {
                $brush = New-Object System.Drawing.SolidBrush((To-Color $dots[$k]))
                $e.Graphics.FillEllipse($brush, $x + $k * 12, $s.Height - 15, 8, 8)
                $brush.Dispose()
            }
        })
        $c.Days += $b
    }

    $y += 74
    $c.Heading = New-Object System.Windows.Forms.Label
    $c.Heading.Font = $BoldFont
    $c.Heading.SetBounds($x0, $y, 600, 24)
    $c.HidePast = New-Object System.Windows.Forms.CheckBox
    $c.HidePast.Text = "Hide what's done"
    $c.HidePast.ForeColor = [System.Drawing.Color]::DimGray
    $c.HidePast.SetBounds(($x0 + $cw - 160), ($y - 2), 160, 26)
    $c.HidePast.Anchor = 'Top, Right'
    $c.HidePast.Add_CheckedChanged({
        if ($script:hidePastLoading) { return }
        $script:settings.HidePast = $this.Checked
        Save-Settings
        Refresh-ScheduleWindow
    })

    $y += 28
    $btnY = $H - $footH - 12 - 34
    $c.List = New-Object System.Windows.Forms.ListView
    $c.List.View = 'Details'
    $c.List.FullRowSelect = $true
    $c.List.MultiSelect = $false
    $c.List.HideSelection = $false
    $c.List.SetBounds($x0, $y, $cw, ($btnY - 30 - $y))
    $c.List.Anchor = 'Top, Bottom, Left, Right'
    [void]$c.List.Columns.Add('Alert', 48)
    [void]$c.List.Columns.Add('Time', 58)
    [void]$c.List.Columns.Add('Reminder', 145)
    [void]$c.List.Columns.Add('Text', 165)
    [void]$c.List.Columns.Add('For', 100)
    [void]$c.List.Columns.Add('Notice', 90)
    [void]$c.List.Columns.Add('Schedule', 125)
    [void]$c.List.Columns.Add('Repeats', 125)
    $icons = New-Object System.Windows.Forms.ImageList
    $icons.ImageSize = New-Object System.Drawing.Size(16, 16)
    $icons.ColorDepth = 'Depth32Bit'
    foreach ($k in @('on', 'muted', 'off', 'shout')) { $icons.Images.Add($k, (New-AlertIcon $k)) }
    $c.List.SmallImageList = $icons
    $c.List.ShowItemToolTips = $true
    $c.List.Add_KeyDown({
        if ($_.KeyCode -eq 'Delete') { Remove-Selected }
        elseif ($_.Control -and $_.KeyCode -eq 'Z') { Invoke-Undo }
    })
    # A click on the bell or megaphone switches it
    $c.List.Add_MouseClick({
        $hit = $this.HitTest($_.Location)
        if ($hit.Item -and $hit.Item.Tag -and $_.X -lt $this.Columns[0].Width) {
            $script:pendingAlert = $hit.Item.Tag
            Invoke-Later { Switch-Alert $script:pendingAlert }
        }
    })
    $c.List.Add_DoubleClick({
        if ($this.PointToClient([System.Windows.Forms.Cursor]::Position).X -lt $this.Columns[0].Width) { return }
        Edit-Selected
    })

    $c.Status = New-Object System.Windows.Forms.Label
    $c.Status.SetBounds($x0, ($btnY - 26), ($cw - 430), 22)
    $c.Status.Anchor = 'Bottom, Left, Right'
    $c.Status.AutoEllipsis = $true

    # Legend for the icons in front of each time
    $legend = New-Object System.Windows.Forms.Panel
    $legend.SetBounds(($x0 + $cw - 426), ($btnY - 27), 426, 22)
    $legend.Anchor = 'Bottom, Right'
    $lx = 0
    foreach ($spec in @(@('on', 'pops up'), @('muted', 'muted'), @('shout', 'you too'))) {
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = $icons.Images[$spec[0]]
        $pic.SetBounds($lx, 3, 16, 16)
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $spec[1]
        $lbl.Font = $SmallFont
        $lbl.ForeColor = [System.Drawing.Color]::DimGray
        $lbl.SetBounds(($lx + 18), 2, 62, 18)
        $legend.Controls.AddRange(@($pic, $lbl))
        $lx += 84
    }
    $hintL = New-Object System.Windows.Forms.Label
    $hintL.Text = '(click the icon to change)'
    $hintL.Font = $SmallFont
    $hintL.ForeColor = [System.Drawing.Color]::Gray
    $hintL.SetBounds($lx, 2, (426 - $lx), 18)
    $legend.Controls.Add($hintL)

    $bx = $x0
    $btns = @()
    foreach ($spec in @(@('Add reminder', 136), @('Edit', 80), @('Remove', 84), @('Undo', 84))) {
        $b = New-Btn $spec[0] $bx $btnY $spec[1]
        $b.Anchor = 'Bottom, Left'
        $bx += $spec[1] + 6
        $btns += $b
    }
    $btns[0].Font = $BoldFont
    $btns[0].Add_Click({
        $t = Get-SideSource
        if ($t.IsMine -or $t.Owned) { Show-ReminderDialog 'Add' -TargetFile $t.File } else { Show-ReminderDialog 'Add' }
    })
    $btns[1].Add_Click({ Edit-Selected })
    $btns[2].Add_Click({ Remove-Selected })
    $btns[3].Add_Click({ Invoke-Undo })
    $c.Undo = $btns[3]
    $c.UndoTip = New-Object System.Windows.Forms.ToolTip

    # Footer
    $foot = New-Object System.Windows.Forms.Panel
    $foot.SetBounds(0, ($H - $footH), $W, $footH)
    $foot.Dock = 'Bottom'
    $foot.BackColor = [System.Drawing.Color]::FromArgb(243, 245, 248)
    $hello = New-Object System.Windows.Forms.Label
    $hello.Text = $Greeting
    $hello.Font = $ItalicFont
    $hello.ForeColor = [System.Drawing.Color]::DimGray
    $hello.SetBounds(14, 0, 400, $footH)
    $hello.TextAlign = 'MiddleLeft'
    $free = New-Object System.Windows.Forms.Label
    $free.Text = 'Free, open source and offline'
    $free.Font = $SmallFont
    $free.ForeColor = [System.Drawing.Color]::Gray
    $free.SetBounds(($W - 314), 0, 300, $footH)
    $free.TextAlign = 'MiddleRight'
    $free.Anchor = 'Top, Right'
    $foot.Controls.AddRange(@($hello, $free))

    $f.Controls.AddRange(@($c.Banner, $side, $prev, $c.Week, $todayBtn) + $c.Days + @($c.Heading, $c.HidePast, $c.List, $c.Status, $legend) + $btns + @($foot))
    $f.Controls.Add($ms)
    $f.MainMenuStrip = $ms
    $f.Add_FormClosed({ $script:sw = $null; $script:swc = @{}; if ($script:dp) { $script:dp.Drop.Dispose(); $script:dp = $null } })

    $script:sw = $f
    $script:swc = $c
    if (-not $script:selSource) { $script:selSource = 'schedule.csv' }
    Set-Week (Get-Date) (Get-Date)
    $f.Show()
    $f.Activate()
}

# --- Splash: a short animated welcome, then the main window --------------------
function Start-AfterSplash {
    Open-ScheduleWindow
    $firstRun = (-not $script:settings.Welcomed) -and @($script:loaded.Mine.Rows).Count -eq 0 -and @($script:loaded.All).Count -le 1
    if ($firstRun) { Show-PacksDialog $script:sw -Welcome }
    elseif (-not $script:settings.Welcomed) { $script:settings.Welcomed = $true; Save-Settings }
}

function Show-Splash {
    $W = 460; $H = 300
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'
    $f.StartPosition = 'CenterScreen'
    $f.ShowInTaskbar = $false
    $f.TopMost = $true
    $f.BackColor = [System.Drawing.Color]::White
    $f.ClientSize = New-Object System.Drawing.Size($W, $H)
    $f.Opacity = 0
    if ($script:appIcon) { $f.Icon = $script:appIcon }

    # Coloured top edge
    $edge = New-Object System.Windows.Forms.Panel
    $edge.SetBounds(0, 0, $W, 5)
    $edge.BackColor = $Accent

    # The bell rings: drawn rotated a little on every frame
    $bell = New-Object System.Windows.Forms.PictureBox
    $bell.SetBounds((($W - 96) / 2), 30, 96, 96)
    try { $script:splashImg = (New-Object System.Drawing.Icon($IconFile, 64, 64)).ToBitmap() } catch { $script:splashImg = $null }
    $bell.Add_Paint({
        param($s, $e)
        if (-not $script:splashImg) { return }
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.TranslateTransform(48, 20)                # swing from the top of the bell
        $g.RotateTransform([single]$script:splash.Angle)
        $g.DrawImage($script:splashImg, -32, -12, 64, 64)
    })

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Welcome to Desk Reminders $AppVersion"
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $Accent
    $title.TextAlign = 'MiddleCenter'
    $title.SetBounds(0, 134, $W, 40)

    $hello = New-Object System.Windows.Forms.Label
    $hello.Text = $Greeting
    $hello.Font = $ItalicFont
    $hello.ForeColor = [System.Drawing.Color]::DimGray
    $hello.TextAlign = 'MiddleCenter'
    $hello.SetBounds(0, 176, $W, 24)

    # Progress line that fills up over 3 seconds
    $track = New-Object System.Windows.Forms.Panel
    $track.SetBounds(90, 222, ($W - 180), 4)
    $track.BackColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.SetBounds(0, 0, 0, 4)
    $fill.BackColor = $Accent
    $track.Controls.Add($fill)

    $foot = New-Object System.Windows.Forms.Label
    $foot.Text = 'Free, open source and offline'
    $foot.Font = $SmallFont
    $foot.ForeColor = [System.Drawing.Color]::Gray
    $foot.BackColor = [System.Drawing.Color]::FromArgb(243, 245, 248)
    $foot.TextAlign = 'MiddleCenter'
    $foot.SetBounds(0, ($H - 40), $W, 40)

    $f.Controls.AddRange(@($edge, $bell, $title, $hello, $track, $foot))
    # A click skips the wait
    foreach ($ctl in @($f, $bell, $title, $hello, $foot)) { $ctl.Add_Click({ if ($script:splash.Phase -lt 2) { $script:splash.Phase = 2; $script:splash.Out = Get-Date } }) }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $script:splash = @{ Form = $f; Bell = $bell; Fill = $fill; Track = $track; Timer = $timer; Start = (Get-Date); Phase = 0; Out = $null; Angle = 0.0 }
    $timer.Add_Tick({
        $sp = $script:splash
        $t = ((Get-Date) - $sp.Start).TotalSeconds
        # Bell swings, settling down
        $sp.Angle = 16 * [math]::Sin($t * 2 * [math]::PI * 2.2) * [math]::Exp(-1.6 * $t)
        $sp.Bell.Invalidate()
        # Progress (eased)
        $p = [math]::Min(1, $t / 3.0)
        $ease = 1 - [math]::Pow(1 - $p, 3)
        $sp.Fill.Width = [int]($sp.Track.Width * $ease)
        if ($sp.Phase -eq 0) {
            $sp.Form.Opacity = [math]::Min(1, $t / 0.35)
            if ($t -ge 3.0) { $sp.Phase = 2; $sp.Out = Get-Date }
        }
        if ($sp.Phase -eq 2) {
            $o = 1 - ((Get-Date) - $sp.Out).TotalSeconds / 0.35
            if ($o -le 0) {
                $sp.Phase = 3
                $sp.Timer.Stop()
                $sp.Form.Close()
                Start-AfterSplash
                return
            }
            $sp.Form.Opacity = [math]::Min($sp.Form.Opacity, $o)
        }
    })
    $f.Add_FormClosed({ $script:splash.Timer.Stop(); $script:splash.Timer.Dispose() })
    $f.Show()
    $timer.Start()
}

# --- Tray menu --------------------------------------------------------------
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miSchedule = New-MenuItem $menu 'Open Desk Reminders' { Open-ScheduleWindow }
$miSchedule.Font = $BoldFont
if ($script:appIcon) { try { $miSchedule.Image = (New-Object System.Drawing.Icon($IconFile, 16, 16)).ToBitmap() } catch {} }
$tray.Add_DoubleClick({ Open-ScheduleWindow })

[void](New-MenuItem $menu "Today's reminders" {
    $lines = @(Get-Today (Get-Date).Date | ForEach-Object {
        $what = if ($_.Kind -eq 'notice') { "Notice: $($_.Title) at $($_.EventTime)" } else { $_.Title }
        $from = if ($_.IsMine) { '' } else { "   [$($_.Source)]" }
        $not = if ($_.Notify) { '' } elseif ($_.AlertState -eq 'muted') { '   (muted)' } else { '   (other group)' }
        "$($_.Time)   $what$from$not"
    })
    if ($lines.Count -eq 0) { $lines = @('No reminders today. Open Desk Reminders and click Add reminder.') }
    if ($script:errors.Count -gt 0) { $lines += @('', 'PROBLEMS (these rows are ignored):') + $script:errors }
    [System.Windows.Forms.MessageBox]::Show(($lines -join "`r`n"), "Today's reminders") | Out-Null
})
[void](New-MenuItem $menu 'Import shared schedule' { Import-SharedSchedule $null })
[void](New-MenuItem $menu 'Settings' { Show-SettingsDialog $script:sw })
[void]$menu.Items.Add('-')
[void](New-MenuItem $menu 'Test a reminder' { Show-TestReminder })
[void]$menu.Items.Add('-')
[void](New-MenuItem $menu 'Pause 30 minutes' { $script:pauseUntil = (Get-Date).AddMinutes(30); Update-TrayText; Update-Banner })
[void](New-MenuItem $menu 'Pause 1 hour' { $script:pauseUntil = (Get-Date).AddHours(1); Update-TrayText; Update-Banner })
[void](New-MenuItem $menu 'Pause until tomorrow 06:00' { $script:pauseUntil = (Get-Date).Date.AddDays(1).AddHours(6); Update-TrayText; Update-Banner })
[void](New-MenuItem $menu 'Resume' { $script:pauseUntil = [datetime]::MinValue; Update-TrayText; Update-Banner })
[void]$menu.Items.Add('-')
[void](New-MenuItem $menu 'Quit' {
    $clock.Stop()
    if ($script:sw -and -not $script:sw.IsDisposed) { $script:sw.Close() }
    $tray.Visible = $false
    $tray.Dispose()
    if ($script:current -and -not $script:current.IsDisposed) { $script:current.Close() }
    [System.Windows.Forms.Application]::Exit()
})
$tray.ContextMenuStrip = $menu

# --- Clock ------------------------------------------------------------------
$clock = New-Object System.Windows.Forms.Timer
$clock.Interval = 10000
$clock.Add_Tick({
    Sync-Schedule
    $now = Get-Date
    Update-TrayText
    Update-Banner
    # Today's list moves on as reminders pass
    if ($script:sw -and -not $script:sw.IsDisposed -and $script:listMinute -ne $now.ToString('yyyy-MM-dd HH:mm') -and $script:selDay -eq $now.Date) {
        Refresh-ScheduleWindow -Tick
    }
    if ($now -lt $script:pauseUntil) { return }

    # Snoozed pop-ups that are due again
    $due = @()
    foreach ($s in @($script:snoozed)) {
        if ($s.At -le $now) { $due += @($s.Items); $script:snoozed.Remove($s) }
    }

    $key = $now.ToString('yyyy-MM-dd HH:mm')
    $hits = @()
    if (-not $script:fired.ContainsKey($key)) {
        $script:fired[$key] = $true
        $hits = Select-Poppable @(Get-Today $now.Date | Where-Object { $_.At.ToString('yyyy-MM-dd HH:mm') -eq $key }) $now
    }
    $all = @($hits) + @($due)
    if ($all.Count -gt 0) { Show-Reminder $all }

    # Forget old minutes once a day
    if ($script:fired.Count -gt 2000) {
        $keep = $now.ToString('yyyy-MM-dd')
        foreach ($k in @($script:fired.Keys)) { if (-not $k.StartsWith($keep)) { $script:fired.Remove($k) } }
    }
})

Sync-Schedule -Force
$clock.Start()
Update-TrayText

$firstRun = (-not $script:settings.Welcomed) -and @($script:loaded.Mine.Rows).Count -eq 0 -and @($script:loaded.All).Count -le 1
if ($script:settings.ShowWelcome -or $firstRun) {
    Show-Splash
} else {
    $tray.ShowBalloonTip(5000, 'Desk Reminders is running', $tray.Text, 'Info')
}

[System.Windows.Forms.Application]::Run()
$script:mutex.ReleaseMutex()
