# Desk Reminders
# https://github.com/7ab9ne3021sn4b/DeskReminders  -  MIT licence
#
# Pop-up + sound reminders from your own schedule (schedule.csv) and from shared
# schedules you import (the shared folder). Runs from the system tray.
# Double-click the tray icon to open the schedule.
#
# Check what a day looks like without starting the app:
#   powershell -ExecutionPolicy Bypass -File DeskReminders.ps1 -ListFor 2026-12-01

param([string]$ListFor, [switch]$InstallStartup, [switch]$RemoveStartup, [switch]$Startup)   # -Startup: started by Windows at login

$AppVersion   = '1.2.0'
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
        Corner = 'BottomRight'; Monitor = 0; Welcomed = $false; OpenAtLogin = $false; HidePast = $true; ViewOff = @()
        Links = @{}; Publish = @{}; Sounds = @{}; Theme = 'System'; CheckUpdates = $true; UpdateChecked = ''; LatestSeen = ''
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
            if ($null -ne $j.OpenAtLogin) { $s.OpenAtLogin = [bool]$j.OpenAtLogin }
            if ($null -ne $j.HidePast) { $s.HidePast = [bool]$j.HidePast }
            if ($j.Links) { $lk = ConvertTo-Hash $j.Links; foreach ($k in @($lk.Keys)) { $s.Links[$k] = ConvertTo-Hash $lk[$k] } }
            if ($j.Publish) { $s.Publish = ConvertTo-Hash $j.Publish }
            if ($j.Sounds) { $s.Sounds = ConvertTo-Hash $j.Sounds }
            if ($j.Theme -in @('Light', 'Dark', 'System')) { $s.Theme = [string]$j.Theme }
            if ($null -ne $j.CheckUpdates) { $s.CheckUpdates = [bool]$j.CheckUpdates }
            if ($j.UpdateChecked) { $s.UpdateChecked = [string]$j.UpdateChecked }
            if ($j.LatestSeen) { $s.LatestSeen = [string]$j.LatestSeen }
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
        OpenAtLogin = [bool]$st.OpenAtLogin
        HidePast   = [bool]$st.HidePast
        Links      = $st.Links
        Publish    = $st.Publish
        Sounds     = $st.Sounds
        Theme      = [string]$st.Theme
        CheckUpdates = [bool]$st.CheckUpdates
        UpdateChecked = [string]$st.UpdateChecked
        LatestSeen = [string]$st.LatestSeen
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
    $psArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Startup"
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
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System.Windows.Forms;
using System.Drawing;
using System.Collections.Generic;
// --- Modern look: drawn controls for the main window and the pop-ups ---
public static class DrUi {
    [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    static extern System.IntPtr SendMessage(System.IntPtr h, int msg, System.IntPtr w, string l);
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
    [System.Runtime.InteropServices.DllImport("gdi32.dll")]
    static extern System.IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int w, int h);

    public static System.Drawing.Drawing2D.GraphicsPath Round(System.Drawing.RectangleF r, float rad) {
        System.Drawing.Drawing2D.GraphicsPath p = new System.Drawing.Drawing2D.GraphicsPath();
        float d = System.Math.Min(rad * 2, System.Math.Min(r.Width, r.Height));
        if (d < 1) { p.AddRectangle(r); return p; }
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
    // k = how much of b (0..1)
    public static Color Mix(Color a, Color b, double k) {
        return Color.FromArgb((int)(a.R + (b.R - a.R) * k), (int)(a.G + (b.G - a.G) * k), (int)(a.B + (b.B - a.B) * k));
    }
    public static Color Hex(string s) { return ColorTranslator.FromHtml(s); }
    // A font a bit bigger or smaller. Never bold: headings are just a little larger (cleaner look)
    public static Font F(Font f, float delta, bool bigger) {
        return new Font(f.FontFamily, f.Size + delta + (bigger ? 0.5f : 0f), FontStyle.Regular);
    }
    [System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    static extern int AddFontResourceEx(string name, uint flags, System.IntPtr reserved);
    // Lets Windows' own text drawing use a font file for this app only (nothing is installed)
    public static void LoadFontForGdi(string path) { try { AddFontResourceEx(path, 0x10, System.IntPtr.Zero); } catch { } }
    public static Color Back(Control p) {
        if (p == null) { return Color.White; }
        DrCard c = p as DrCard;
        if (c != null) { return c.Fill; }
        return p.BackColor;
    }
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetForegroundWindow();
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(System.IntPtr h, System.IntPtr pid);
    [System.Runtime.InteropServices.DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool SetForegroundWindow(System.IntPtr h);
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool BringWindowToTop(System.IntPtr h);
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int pid);
    // Brings a window you asked for to the front (Windows otherwise may only flash it in the taskbar).
    // Only used when you open the window yourself, never for pop-ups.
    public static void ToFront(Form f) {
        try {
            System.IntPtr h = f.Handle;
            uint fg = GetWindowThreadProcessId(GetForegroundWindow(), System.IntPtr.Zero);
            uint me = GetCurrentThreadId();
            bool attached = fg != me && AttachThreadInput(fg, me, true);
            BringWindowToTop(h);
            SetForegroundWindow(h);
            if (attached) { AttachThreadInput(fg, me, false); }
            f.TopMost = true; f.TopMost = false;
            f.Activate();
        } catch { }
    }
    public static void AllowAnyForeground() { try { AllowSetForegroundWindow(-1); } catch { } }
    // Grey hint text inside an empty text box
    public static void Cue(TextBox t, string text) { try { SendMessage(t.Handle, 0x1501, (System.IntPtr)1, text); } catch { } }
    // Rounded window corners: Windows 11 does it (with its own shadow); otherwise a rounded region
    public static bool RoundWindow(Form f, int radius) {
        int v = 2;
        try { if (DwmSetWindowAttribute(f.Handle, 33, ref v, 4) == 0 && System.Environment.OSVersion.Version.Major >= 6) {
            Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            int build = 0;
            if (k != null) { int.TryParse(System.Convert.ToString(k.GetValue("CurrentBuildNumber")), out build); k.Close(); }
            if (build >= 22000) { return true; }
        } } catch { }
        try { f.Region = Region.FromHrgn(CreateRoundRectRgn(0, 0, f.Width + 1, f.Height + 1, radius * 2, radius * 2)); } catch { }
        return false;
    }

    // --- Icons (drawn, so they stay sharp at any size) ---
    public static void Icon(Graphics g, string kind, RectangleF r, Color ink) {
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        float s = System.Math.Min(r.Width, r.Height) / 24f;
        float ox = r.X + (r.Width - 24 * s) / 2, oy = r.Y + (r.Height - 24 * s) / 2;
        using (Pen pen = new Pen(ink, System.Math.Max(1.4f, 2f * s))) {
            pen.StartCap = System.Drawing.Drawing2D.LineCap.Round; pen.EndCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.LineJoin = System.Drawing.Drawing2D.LineJoin.Round;
            System.Func<float, float> X = delegate(float v) { return ox + v * s; };
            System.Func<float, float> Y = delegate(float v) { return oy + v * s; };
            switch (kind) {
                case "left":  g.DrawLines(pen, new PointF[] { new PointF(X(15), Y(6)), new PointF(X(9), Y(12)), new PointF(X(15), Y(18)) }); break;
                case "right": g.DrawLines(pen, new PointF[] { new PointF(X(9), Y(6)), new PointF(X(15), Y(12)), new PointF(X(9), Y(18)) }); break;
                case "down":  g.DrawLines(pen, new PointF[] { new PointF(X(7), Y(10)), new PointF(X(12), Y(15)), new PointF(X(17), Y(10)) }); break;
                case "plus":  g.DrawLine(pen, X(12), Y(5), X(12), Y(19)); g.DrawLine(pen, X(5), Y(12), X(19), Y(12)); break;
                case "close": g.DrawLine(pen, X(7), Y(7), X(17), Y(17)); g.DrawLine(pen, X(17), Y(7), X(7), Y(17)); break;
                case "undo":
                    g.DrawLines(pen, new PointF[] { new PointF(X(9), Y(5)), new PointF(X(4), Y(10)), new PointF(X(9), Y(15)) });
                    g.DrawArc(pen, X(4), Y(10) - 0, 16 * s, 10 * s, 270, 180);
                    g.DrawLine(pen, X(4), Y(10), X(12), Y(10));
                    break;
                case "gear":
                    // A cog: 8 teeth around a ring, with a hole in the middle
                    PointF[] cog = new PointF[32];
                    for (int i = 0; i < 32; i++) {
                        double a = (i / 32.0) * 2 * System.Math.PI - System.Math.PI / 32;
                        float rr = (i % 4 == 0 || i % 4 == 1) ? 9.2f : 7.0f;
                        cog[i] = new PointF(X(12 + (float)(rr * System.Math.Cos(a))), Y(12 + (float)(rr * System.Math.Sin(a))));
                    }
                    g.DrawPolygon(pen, cog);
                    g.DrawEllipse(pen, X(9), Y(9), 6 * s, 6 * s);
                    break;
                case "more":
                    using (SolidBrush b = new SolidBrush(ink)) { for (int i = 0; i < 3; i++) { g.FillEllipse(b, X(5.5f + i * 6), Y(10.5f), 3 * s, 3 * s); } }
                    break;
                case "calendar":
                    g.DrawPath(pen, Round(new RectangleF(X(4), Y(5), 16 * s, 15 * s), 2.5f * s));
                    g.DrawLine(pen, X(4), Y(10), X(20), Y(10)); g.DrawLine(pen, X(8), Y(3), X(8), Y(7)); g.DrawLine(pen, X(16), Y(3), X(16), Y(7));
                    break;
                case "templates":
                    g.DrawPath(pen, Round(new RectangleF(X(4), Y(4), 7 * s, 7 * s), 1.5f * s)); g.DrawPath(pen, Round(new RectangleF(X(13), Y(4), 7 * s, 7 * s), 1.5f * s));
                    g.DrawPath(pen, Round(new RectangleF(X(4), Y(13), 7 * s, 7 * s), 1.5f * s)); g.DrawPath(pen, Round(new RectangleF(X(13), Y(13), 7 * s, 7 * s), 1.5f * s));
                    break;
                case "import":
                    g.DrawLine(pen, X(12), Y(4), X(12), Y(15));
                    g.DrawLines(pen, new PointF[] { new PointF(X(7), Y(10)), new PointF(X(12), Y(15)), new PointF(X(17), Y(10)) });
                    g.DrawLines(pen, new PointF[] { new PointF(X(4), Y(16)), new PointF(X(4), Y(20)), new PointF(X(20), Y(20)), new PointF(X(20), Y(16)) });
                    break;
                case "export":
                    g.DrawLine(pen, X(12), Y(15), X(12), Y(4));
                    g.DrawLines(pen, new PointF[] { new PointF(X(7), Y(9)), new PointF(X(12), Y(4)), new PointF(X(17), Y(9)) });
                    g.DrawLines(pen, new PointF[] { new PointF(X(4), Y(16)), new PointF(X(4), Y(20)), new PointF(X(20), Y(20)), new PointF(X(20), Y(16)) });
                    break;
                case "code":
                    g.DrawLines(pen, new PointF[] { new PointF(X(8), Y(7)), new PointF(X(3), Y(12)), new PointF(X(8), Y(17)) });
                    g.DrawLines(pen, new PointF[] { new PointF(X(16), Y(7)), new PointF(X(21), Y(12)), new PointF(X(16), Y(17)) });
                    g.DrawLine(pen, X(14), Y(5), X(10), Y(19));
                    break;
                case "drop":
                    System.Drawing.Drawing2D.GraphicsPath dp = new System.Drawing.Drawing2D.GraphicsPath();
                    dp.AddBezier(X(12), Y(2.8f), X(12), Y(2.8f), X(18), Y(9.2f), X(18), Y(14));
                    dp.AddArc(X(6), Y(8), 12 * s, 12 * s, 0, 180);
                    dp.AddBezier(X(6), Y(14), X(6), Y(9.2f), X(12), Y(2.8f), X(12), Y(2.8f));
                    g.DrawPath(pen, dp); dp.Dispose();
                    break;
                case "eye":
                    g.DrawBezier(pen, X(2), Y(12), X(5.5f), Y(5.5f), X(18.5f), Y(5.5f), X(22), Y(12));
                    g.DrawBezier(pen, X(2), Y(12), X(5.5f), Y(18.5f), X(18.5f), Y(18.5f), X(22), Y(12));
                    g.DrawEllipse(pen, X(9), Y(9), 6 * s, 6 * s);
                    break;
                case "food":
                    g.DrawLine(pen, X(6), Y(3), X(6), Y(9)); g.DrawLine(pen, X(10), Y(3), X(10), Y(9));
                    g.DrawArc(pen, X(6), Y(6), 4 * s, 6 * s, 0, 180);
                    g.DrawLine(pen, X(8), Y(12), X(8), Y(21));
                    g.DrawBezier(pen, X(18), Y(3), X(15.5f), Y(4), X(14.5f), Y(8), X(14.5f), Y(12));
                    g.DrawLine(pen, X(14.5f), Y(12), X(18), Y(12));
                    g.DrawLine(pen, X(18), Y(3), X(18), Y(21));
                    break;
                case "swords":
                    g.DrawLine(pen, X(4), Y(4), X(15), Y(15)); g.DrawLine(pen, X(20), Y(4), X(9), Y(15));
                    g.DrawLine(pen, X(12), Y(18.5f), X(18.5f), Y(12)); g.DrawLine(pen, X(5.5f), Y(12), X(12), Y(18.5f));
                    g.DrawLine(pen, X(16.5f), Y(16.5f), X(20), Y(20)); g.DrawLine(pen, X(7.5f), Y(16.5f), X(4), Y(20));
                    break;
                case "moon":
                    g.DrawArc(pen, X(4), Y(4), 16 * s, 16 * s, 320, 280);
                    g.DrawBezier(pen, X(18.1f), Y(6.9f), X(14.5f), Y(11.5f), X(9.5f), Y(10), X(8), Y(5.1f));
                    break;
                case "move":
                    g.DrawLines(pen, new PointF[] { new PointF(X(3), Y(12)), new PointF(X(7), Y(12)), new PointF(X(10), Y(5)), new PointF(X(14), Y(19)), new PointF(X(17), Y(12)), new PointF(X(21), Y(12)) });
                    break;
                case "pill":
                    g.DrawPath(pen, Round(new RectangleF(X(3), Y(8.5f), 18 * s, 7 * s), 3.5f * s));
                    g.DrawLine(pen, X(12), Y(8.5f), X(12), Y(15.5f));
                    break;
                case "cup":
                    g.DrawPath(pen, Round(new RectangleF(X(4), Y(9), 12 * s, 11 * s), 3 * s));
                    g.DrawArc(pen, X(14), Y(11), 5 * s, 5 * s, -90, 180);
                    g.DrawLine(pen, X(8), Y(3), X(8), Y(6)); g.DrawLine(pen, X(12), Y(3), X(12), Y(6));
                    break;
                case "megaphone":
                    g.DrawPolygon(pen, new PointF[] { new PointF(X(3), Y(10)), new PointF(X(8), Y(10)), new PointF(X(15), Y(5)), new PointF(X(15), Y(19)), new PointF(X(8), Y(14)), new PointF(X(3), Y(14)) });
                    g.DrawLine(pen, X(6), Y(14), X(7), Y(19));
                    g.DrawArc(pen, X(15), Y(8.5f), 5 * s, 7 * s, -60, 120);
                    break;
                case "bell": case "bell-off":
                    System.Drawing.Drawing2D.GraphicsPath bp = new System.Drawing.Drawing2D.GraphicsPath();
                    bp.AddArc(X(6), Y(3), 12 * s, 12 * s, 180, 180);
                    bp.AddLine(X(18), Y(9), X(18), Y(14));
                    bp.AddLine(X(18), Y(14), X(20.5f), Y(17));
                    bp.AddLine(X(20.5f), Y(17), X(3.5f), Y(17));
                    bp.AddLine(X(3.5f), Y(17), X(6), Y(14));
                    bp.CloseFigure();
                    g.DrawPath(pen, bp); bp.Dispose();
                    g.DrawArc(pen, X(9.5f), Y(18), 5 * s, 3.5f * s, 0, 180);
                    if (kind == "bell-off") { g.DrawLine(pen, X(3), Y(3), X(21), Y(21)); }
                    break;
            }
        }
    }
}

// A rounded card: children should use the same BackColor as Fill
public class DrCard : Panel {
    public int Radius = 12;
    public Color Fill = Color.White;
    public Color Border = Color.Empty;
    public Color Bar = Color.Empty;
    public DrCard() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }
    protected override void OnPaintBackground(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(DrUi.Back(Parent));
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(r, Radius)) {
            using (SolidBrush b = new SolidBrush(Fill)) { g.FillPath(b, p); }
            if (Bar != Color.Empty) {
                Region old = g.Clip;
                g.SetClip(p);
                using (SolidBrush b = new SolidBrush(Bar)) { g.FillRectangle(b, 0, 0, 5, Height); }
                g.Clip = old;
            }
            if (Border != Color.Empty) { using (Pen pen = new Pen(Border)) { g.DrawPath(pen, p); } }
        }
    }
}

// Rounded button: Kind = primary, outline, ghost or soft; Icon = one of DrUi.Icon's names
public class DrButton : Button {
    public string Kind = "outline";
    public string IconName = "";
    public int Radius = 8;
    public Color Accent = Color.FromArgb(47, 111, 219);
    public Color Ink = Color.Empty;
    bool hover, down;
    public DrButton() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Cursor = Cursors.Hand;
        UseVisualStyleBackColor = false;
    }
    protected override void OnMouseEnter(System.EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(System.EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnEnabledChanged(System.EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        Color back = DrUi.Back(Parent);
        g.Clear(back);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Color fill = Color.Empty, border = Color.Empty, ink = DrUi.Hex("#1B1F24");
        switch (Kind) {
            case "primary":
                fill = !Enabled ? DrUi.Mix(Accent, Color.White, 0.55) : down ? DrUi.Mix(Accent, Color.Black, 0.2) : hover ? DrUi.Mix(Accent, Color.Black, 0.1) : Accent;
                ink = Color.White; break;
            case "ghost":
                if (hover && Enabled) { fill = down ? DrUi.Mix(back, Color.Black, 0.1) : DrUi.Mix(back, Color.Black, 0.055); }
                ink = DrUi.Hex("#3D4652"); break;
            case "soft":
                fill = down ? DrUi.Mix(Accent, Color.White, 0.72) : hover ? DrUi.Mix(Accent, Color.White, 0.8) : DrUi.Mix(Accent, Color.White, 0.88);
                ink = DrUi.Mix(Accent, Color.Black, 0.3); break;
            default:
                fill = down ? DrUi.Hex("#E9ECF0") : hover ? DrUi.Hex("#F3F5F8") : Color.White;
                border = hover ? DrUi.Hex("#C9CFD7") : DrUi.Hex("#DADFE5"); break;
        }
        if (Ink != Color.Empty && Kind != "primary") { ink = Ink; }
        if (!Enabled && Kind != "primary") { ink = DrUi.Hex("#A5ACB6"); }
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(r, Radius)) {
            if (fill != Color.Empty) { using (SolidBrush b = new SolidBrush(fill)) { g.FillPath(b, p); } }
            if (border != Color.Empty) { using (Pen pen = new Pen(border)) { g.DrawPath(pen, p); } }
            if (Focused && ShowFocusCues) { using (Pen pen = new Pen(DrUi.Mix(Accent, Color.White, 0.3), 1.6f)) { g.DrawPath(pen, p); } }
        }
        TextFormatFlags tf = TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding;
        bool hasIcon = IconName != "";
        bool hasText = Text != "";
        int iconSize = 18;
        if (hasIcon && !hasText) {
            DrUi.Icon(g, IconName, new RectangleF((Width - iconSize) / 2f, (Height - iconSize) / 2f, iconSize, iconSize), ink);
            return;
        }
        Size ts = TextRenderer.MeasureText(g, Text, Font, new Size(9999, Height), tf);
        int total = ts.Width + (hasIcon ? iconSize + 6 : 0);
        int x = System.Math.Max(8, (Width - total) / 2);
        if (hasIcon) {
            DrUi.Icon(g, IconName, new RectangleF(x, (Height - iconSize) / 2f, iconSize, iconSize), ink);
            x += iconSize + 6;
        }
        TextRenderer.DrawText(g, Text, Font, new Rectangle(x, 0, Width - x - 6, Height), ink, fill == Color.Empty ? back : fill, tf);
    }
}

// On/off switch (a CheckBox underneath, so Checked and CheckedChanged work as usual)
public class DrToggle : CheckBox {
    public Color Accent = Color.FromArgb(47, 111, 219);
    public DrToggle() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        AutoSize = false;
        Cursor = Cursors.Hand;
    }
    protected override void OnCheckedChanged(System.EventArgs e) { Invalidate(); base.OnCheckedChanged(e); }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        Color back = DrUi.Back(Parent);
        g.Clear(back);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        RectangleF track = new RectangleF(1, (Height - 20) / 2f, 36, 20);
        Color tc = Checked ? (Enabled ? Accent : DrUi.Mix(Accent, Color.White, 0.5)) : DrUi.Hex("#C3C9D2");
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(track, 10)) { using (SolidBrush b = new SolidBrush(tc)) { g.FillPath(b, p); } }
        float kx = Checked ? track.Right - 18 : track.X + 2;
        using (SolidBrush sh = new SolidBrush(Color.FromArgb(40, 0, 0, 0))) { g.FillEllipse(sh, kx, track.Y + 3, 16, 16); }
        g.FillEllipse(Brushes.White, kx, track.Y + 2, 16, 16);
        if (Text != "") {
            TextRenderer.DrawText(g, Text, Font, new Rectangle(46, 0, Width - 46, Height), ForeColor, back,
                TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        }
    }
}

// A small rounded square with an icon in a schedule's colour
public class DrIconTile : Control {
    public Color Color1 = Color.FromArgb(47, 111, 219);
    public string IconName = "bell";
    public bool Tile = true;
    public DrIconTile() { SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true); }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(DrUi.Back(Parent));
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        if (IconName == "dot") { using (SolidBrush b = new SolidBrush(Color1)) { g.FillEllipse(b, 0, 0, Width - 1, Height - 1); } return; }
        if (Tile) {
            using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(new RectangleF(0, 0, Width - 1, Height - 1), Width / 3.6f)) {
                using (SolidBrush b = new SolidBrush(DrUi.Mix(Color1, Color.White, 0.86))) { g.FillPath(b, p); }
            }
        }
        float s = Tile ? Width * 0.5f : Width * 0.85f;
        DrUi.Icon(g, IconName, new RectangleF((Width - s) / 2, (Height - s) / 2, s, s), Color1);
    }
}

// The Next up card: the schedule's colour as a soft gradient, white text and a little icon
public class DrBanner : Control {
    public Color Color1 = Color.FromArgb(47, 111, 219);
    public string Label = "", Title = "", RightText = "", IconName = "bell";
    public DrBanner() { SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true); }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(DrUi.Back(Parent));
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
        Color a = DrUi.Mix(Color1, Color.Black, 0.12), b2 = DrUi.Mix(Color1, Color.White, 0.18);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(r, 16))
        using (System.Drawing.Drawing2D.LinearGradientBrush br = new System.Drawing.Drawing2D.LinearGradientBrush(new PointF(0, 0), new PointF(Width, Height * 0.6f), a, b2)) {
            g.FillPath(br, p);
        }
        RectangleF tile = new RectangleF(16, (Height - 46) / 2f, 46, 46);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(tile, 14)) { using (SolidBrush b = new SolidBrush(Color.FromArgb(48, 255, 255, 255))) { g.FillPath(b, p); } }
        DrUi.Icon(g, IconName, new RectangleF(tile.X + 12, tile.Y + 12, 22, 22), Color.White);
        Color soft = Color.FromArgb(225, 235, 245);
        TextFormatFlags one = TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding;
        int tx = 78;
        int rw = 0;
        using (Font small = new Font(Font.FontFamily, Font.Size - 1f))
        using (Font big = new Font(Font.FontFamily, Font.Size + 3f)) {
            if (RightText != "") {
                rw = System.Math.Min(TextRenderer.MeasureText(g, RightText, small, new Size(9999, 30), one).Width + 4, Width / 3);
                TextRenderer.DrawText(g, RightText, small, new Rectangle(Width - 20 - rw, 0, rw, Height), soft, Color.Transparent, one | TextFormatFlags.Right);
            }
            int tw = Width - tx - rw - 36;
            TextRenderer.DrawText(g, Label, small, new Rectangle(tx, Height / 2 - 24, tw, 20), soft, Color.Transparent, one);
            TextRenderer.DrawText(g, Title, big, new Rectangle(tx, Height / 2 - 4, tw, 28), Color.White, Color.Transparent, one);
        }
    }
}

// A slim progress bar (how much of today is done)
public class DrProgress : Control {
    public double Value;
    public Color From = Color.FromArgb(47, 111, 219), To = Color.FromArgb(46, 139, 87);
    public DrProgress() { SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true); }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(DrUi.Back(Parent));
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        RectangleF track = new RectangleF(0, (Height - 6) / 2f, Width - 1, 6);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(track, 3)) { using (SolidBrush b = new SolidBrush(DrUi.Hex("#EAEDF1"))) { g.FillPath(b, p); } }
        float w = (float)(System.Math.Max(0, System.Math.Min(1, Value)) * (Width - 1));
        if (w >= 6) {
            RectangleF fr = new RectangleF(0, track.Y, w, 6);
            using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(fr, 3))
            using (System.Drawing.Drawing2D.LinearGradientBrush br = new System.Drawing.Drawing2D.LinearGradientBrush(new PointF(0, 0), new PointF(Width, 0), From, To)) { g.FillPath(br, p); }
        }
    }
}

// Month calendar that is always visible: click a day, arrows or the mouse wheel change the month
public class DrMonth : Control {
    public System.DateTime Month = new System.DateTime(System.DateTime.Today.Year, System.DateTime.Today.Month, 1);
    public System.DateTime Selected = System.DateTime.Today;
    public System.DateTime Today = System.DateTime.Today;
    public System.DateTime Picked;
    public Color Accent = Color.FromArgb(47, 111, 219);
    public event System.EventHandler DayPicked;
    public event System.EventHandler MonthChanged;
    int hover = -1;   // 0..41 a day, 100 = back, 101 = forward
    static readonly string[] Names = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" };
    const int Head = 40, NamesH = 22;

    public DrMonth() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
    }
    public System.DateTime GridStart {
        get { int dow = ((int)Month.DayOfWeek + 6) % 7; return Month.AddDays(-dow); }
    }
    public void ShowMonth(System.DateTime anyDay) {
        System.DateTime m = new System.DateTime(anyDay.Year, anyDay.Month, 1);
        if (m != Month) { Month = m; Invalidate(); if (MonthChanged != null) { MonthChanged(this, System.EventArgs.Empty); } }
        else { Invalidate(); }
    }
    Rectangle ArrowRect(bool fwd) { return new Rectangle(Width - (fwd ? 32 : 66), 6, 30, 30); }
    RectangleF CellRect(int i) {
        float cw = Width / 7f, ch = (Height - Head - NamesH) / 6f;
        return new RectangleF((i % 7) * cw, Head + NamesH + (i / 7) * ch, cw, ch);
    }
    int HitTest(Point p) {
        if (ArrowRect(false).Contains(p)) { return 100; }
        if (ArrowRect(true).Contains(p)) { return 101; }
        if (p.Y < Head + NamesH) { return -1; }
        for (int i = 0; i < 42; i++) { if (CellRect(i).Contains(p)) { return i; } }
        return -1;
    }
    protected override void OnMouseMove(MouseEventArgs e) {
        int h = HitTest(e.Location);
        if (h != hover) { hover = h; Cursor = h >= 0 ? Cursors.Hand : Cursors.Default; Invalidate(); }
        base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(System.EventArgs e) { hover = -1; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseEnter(System.EventArgs e) {
        Form f = FindForm();
        if (f != null && f.ContainsFocus && !(f.ActiveControl is TextBox)) { Focus(); }   // so the wheel works right away
        base.OnMouseEnter(e);
    }
    protected override void OnMouseWheel(MouseEventArgs e) { ShowMonth(Month.AddMonths(e.Delta > 0 ? -1 : 1)); base.OnMouseWheel(e); }
    protected override void OnMouseUp(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left) {
            int h = HitTest(e.Location);
            if (h == 100) { ShowMonth(Month.AddMonths(-1)); }
            else if (h == 101) { ShowMonth(Month.AddMonths(1)); }
            else if (h >= 0) {
                Picked = GridStart.AddDays(h);
                if (DayPicked != null) { DayPicked(this, System.EventArgs.Empty); }
            }
        }
        base.OnMouseUp(e);
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        Color back = DrUi.Back(Parent);
        g.Clear(back);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Color text = DrUi.Hex("#1B1F24"), faint = DrUi.Hex("#A9B0BA"), dim = DrUi.Hex("#8A929E");
        using (Font big = DrUi.F(Font, 2.5f, true))
        using (Font bold = DrUi.F(Font, 0f, true))
        using (Font small = new Font(Font.FontFamily, Font.Size - 1.5f)) {
            TextRenderer.DrawText(g, Month.ToString("MMMM yyyy", System.Globalization.CultureInfo.InvariantCulture), big,
                new Rectangle(2, 4, Width - 72, 34), text, back, TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.NoPrefix);
            for (int k = 0; k < 2; k++) {
                Rectangle ar = ArrowRect(k == 1);
                if (hover == 100 + k) { using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(ar, 8)) { using (SolidBrush b = new SolidBrush(DrUi.Mix(back, Color.Black, 0.06))) { g.FillPath(b, p); } } }
                DrUi.Icon(g, k == 1 ? "right" : "left", new RectangleF(ar.X + 6, ar.Y + 6, 18, 18), DrUi.Hex("#3D4652"));
            }
            float cw = Width / 7f;
            for (int i = 0; i < 7; i++) {
                TextRenderer.DrawText(g, Names[i], small, new Rectangle((int)(i * cw), Head, (int)cw, NamesH), dim, back,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix);
            }
            System.DateTime start = GridStart;
            for (int i = 0; i < 42; i++) {
                System.DateTime d = start.AddDays(i);
                RectangleF c = CellRect(i);
                float dia = System.Math.Min(32, System.Math.Min(c.Width, c.Height) - 4);
                RectangleF circ = new RectangleF(c.X + (c.Width - dia) / 2, c.Y + (c.Height - dia) / 2, dia, dia);
                bool sel = d.Date == Selected.Date, today = d.Date == Today.Date, inMonth = d.Month == Month.Month;
                Color ink = inMonth ? text : faint;
                if (sel) {
                    using (SolidBrush b = new SolidBrush(Accent)) { g.FillEllipse(b, circ); }
                    ink = Color.White;
                } else if (hover == i) {
                    using (SolidBrush b = new SolidBrush(DrUi.Mix(back, Color.Black, 0.06))) { g.FillEllipse(b, circ); }
                }
                if (today && !sel) {
                    using (Pen pen = new Pen(Accent, 1.6f)) { g.DrawEllipse(pen, circ.X + 1, circ.Y + 1, circ.Width - 2, circ.Height - 2); }
                    ink = Accent;
                }
                Rectangle tr = Rectangle.Round(new RectangleF(c.X, circ.Y, c.Width, circ.Height));
                Color under = sel ? Accent : (hover == i ? DrUi.Mix(back, Color.Black, 0.06) : back);
                TextRenderer.DrawText(g, d.Day.ToString(), (sel || today) ? bold : Font, tr, ink, under,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix);
            }
        }
    }
}

// One schedule in the side panel: switch (shared only), colour dot, name, details and a menu button
public class DrSchedRow : Control {
    public string Title = "", Sub = "";
    public Color Dot = Color.FromArgb(47, 111, 219);
    public Color Accent = Color.FromArgb(47, 111, 219);
    public bool IsOn = true, ShowToggle = true, Selected;
    public string Action = "";
    public event System.EventHandler RowAction;
    int hover;   // 0 none, 1 row, 2 switch, 3 menu
    public DrSchedRow() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        Cursor = Cursors.Hand;
    }
    Rectangle SwitchRect() { return new Rectangle(10, (Height - 20) / 2, 36, 20); }
    Rectangle MenuRect() { return new Rectangle(Width - 34, (Height - 28) / 2, 28, 28); }
    int Hit(Point p) {
        if (ShowToggle && SwitchRect().Contains(p)) { return 2; }
        if (MenuRect().Contains(p)) { return 3; }
        return ClientRectangle.Contains(p) ? 1 : 0;
    }
    void Raise(string a) { Action = a; if (RowAction != null) { RowAction(this, System.EventArgs.Empty); } }
    protected override void OnMouseMove(MouseEventArgs e) { int h = Hit(e.Location); if (h != hover) { hover = h; Invalidate(); } base.OnMouseMove(e); }
    protected override void OnMouseLeave(System.EventArgs e) { hover = 0; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseUp(MouseEventArgs e) {
        int h = Hit(e.Location);
        if (e.Button == MouseButtons.Right) { Raise("menu"); }
        else if (e.Button == MouseButtons.Left) { Raise(h == 2 ? "toggle" : h == 3 ? "menu" : "select"); }
        base.OnMouseUp(e);
    }
    protected override void OnMouseDoubleClick(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left && Hit(e.Location) == 1) { Raise("open"); }
        base.OnMouseDoubleClick(e);
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        Color back = DrUi.Back(Parent);
        g.Clear(back);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        Color fill = Selected ? Color.White : (hover > 0 ? DrUi.Mix(back, Color.Black, 0.035) : back);
        using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(r, 10)) {
            using (SolidBrush b = new SolidBrush(fill)) { g.FillPath(b, p); }
            if (Selected) { using (Pen pen = new Pen(DrUi.Hex("#DADFE5"))) { g.DrawPath(pen, p); } }
        }
        int x = 14;
        if (ShowToggle) {
            Rectangle sr = SwitchRect();
            Color tc = IsOn ? Accent : DrUi.Hex("#C3C9D2");
            using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(sr, 10)) { using (SolidBrush b = new SolidBrush(tc)) { g.FillPath(b, p); } }
            float kx = IsOn ? sr.Right - 18 : sr.X + 2;
            g.FillEllipse(Brushes.White, kx, sr.Y + 2, 16, 16);
            x = 56;
        }
        int tx = ShowToggle ? x : 14, tw = Width - tx - ((hover > 0 || Selected) ? 38 : 10);
        using (Font bold = DrUi.F(Font, 0f, true))
        using (Font small = new Font(Font.FontFamily, Font.Size - 1f)) {
            TextRenderer.DrawText(g, Title, bold, new Rectangle(tx, 6, tw, 22), IsOn ? DrUi.Mix(Dot, Color.Black, 0.08) : DrUi.Hex("#9AA1AB"), fill,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
            TextRenderer.DrawText(g, Sub, small, new Rectangle(tx, 27, tw, 18), DrUi.Hex("#6B7380"), fill,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        }
        Rectangle mr = MenuRect();
        if (hover == 3) { using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(mr, 7)) { using (SolidBrush b = new SolidBrush(DrUi.Mix(fill, Color.Black, 0.07))) { g.FillPath(b, p); } } }
        if (hover > 0 || Selected) { DrUi.Icon(g, "more", new RectangleF(mr.X + 4, mr.Y + 4, 20, 20), DrUi.Hex("#5B6470")); }
    }
}

// One reminder on the day view
public class DrItem {
    public int Minute;
    public string Time = "", Title = "", Line2 = "", Chip = "", Alert = "on", IconName = "bell";
    public Color Color1 = Color.FromArgb(47, 111, 219);
    public bool Done;
    public object Tag;
    public string Key = "";
    public Rectangle Box, BellBox;
}

// The day, like a calendar's day view without boxes: hours down the left, each reminder a quiet
// line of text with a colour dot. Busy hours grow so nothing overlaps; a red line shows now.
public class DrTimeline : Panel {
    public List<DrItem> Items = new List<DrItem>();
    public int HourH = 44, RowH = 52, TopPad = 8, Gutter = 64;
    public int NowMinute = -1;
    public string EmptyText = "";
    public bool Blank;   // nothing at all yet: no hours, just the message (and the start buttons)
    public Color Accent = Color.FromArgb(47, 111, 219);
    public DrItem Selected, ActionItem;
    public string Action = "";
    public int ActionMinute;
    public event System.EventHandler ItemAction;
    int[] hourTop = new int[25];
    List<DrItem>[] perHour = new List<DrItem>[24];
    DrItem hover;
    bool hoverBell;

    public DrTimeline() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        AutoScroll = true;
        BackColor = Color.White;
        TabStop = true;
        for (int h = 0; h < 24; h++) { perHour[h] = new List<DrItem>(); }
    }
    // Where a time is (in the scrolled content): between the reminders before and after it
    public int MinuteY(int m) {
        m = System.Math.Max(0, System.Math.Min(1439, m));
        int h = m / 60;
        List<DrItem> l = perHour[h];
        if (l.Count == 0) { return hourTop[h] + (int)((hourTop[h + 1] - hourTop[h]) * (m % 60) / 60.0); }
        int k = 0;
        foreach (DrItem it in l) { if (it.Minute <= m) { k++; } }
        return hourTop[h] + 4 + k * RowH;
    }
    public void ScrollToMinute(int m) {
        AutoScrollPosition = new Point(0, System.Math.Max(0, MinuteY(m) - 16));
        Invalidate();
    }
    public void Relayout() {
        for (int h = 0; h < 24; h++) { perHour[h].Clear(); }
        List<DrItem> sorted = new List<DrItem>(Items);
        sorted.Sort(delegate(DrItem a, DrItem b) { return a.Minute.CompareTo(b.Minute); });
        foreach (DrItem it in sorted) { perHour[System.Math.Max(0, System.Math.Min(23, it.Minute / 60))].Add(it); }
        int y = TopPad;
        int x0 = Gutter + 4;
        int w = System.Math.Max(160, ClientSize.Width - x0 - 12);
        for (int h = 0; h < 24; h++) {
            hourTop[h] = y;
            int k = 0;
            foreach (DrItem it in perHour[h]) {
                it.Box = new Rectangle(x0, y + 4 + k * RowH, w, RowH - 2);
                it.BellBox = new Rectangle(it.Box.Right - 32, it.Box.Y + (it.Box.Height - 28) / 2, 28, 28);
                k++;
            }
            y += System.Math.Max(HourH, 8 + k * RowH);
        }
        hourTop[24] = y;
        AutoScrollMinSize = Blank ? Size.Empty : new Size(0, y + TopPad);
        Invalidate();
    }
    protected override void OnResize(System.EventArgs e) { base.OnResize(e); Relayout(); }
    protected override void OnScroll(ScrollEventArgs se) { base.OnScroll(se); Invalidate(); }
    protected override void OnMouseWheel(MouseEventArgs e) { base.OnMouseWheel(e); Invalidate(); }

    DrItem HitItem(Point p, out bool onBell) {
        onBell = false;
        foreach (DrItem it in Items) {
            if (it.Box.Contains(p)) { onBell = it.BellBox.Contains(p); return it; }
        }
        return null;
    }
    Point Doc(Point p) { return new Point(p.X - AutoScrollPosition.X, p.Y - AutoScrollPosition.Y); }
    int MinuteAt(int y) {
        for (int h = 0; h < 24; h++) {
            if (y < hourTop[h + 1]) {
                double frac = System.Math.Max(0, (y - hourTop[h]) / (double)System.Math.Max(1, hourTop[h + 1] - hourTop[h]));
                return System.Math.Min(1425, h * 60 + (int)System.Math.Floor(frac * 4) * 15);
            }
        }
        return 1425;
    }
    void Raise(string a, DrItem it, Point docPoint) {
        Action = a; ActionItem = it;
        ActionMinute = MinuteAt(docPoint.Y);
        if (ItemAction != null) { ItemAction(this, System.EventArgs.Empty); }
    }
    protected override void OnMouseMove(MouseEventArgs e) {
        bool b;
        DrItem h = HitItem(Doc(e.Location), out b);
        if (h != hover || b != hoverBell) { hover = h; hoverBell = b; Cursor = h != null ? Cursors.Hand : Cursors.Default; Invalidate(); }
        base.OnMouseMove(e);
    }
    protected override void OnMouseLeave(System.EventArgs e) { hover = null; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { Focus(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) {
        Point d = Doc(e.Location);
        bool b;
        DrItem it = HitItem(d, out b);
        if (it != null) {
            Selected = it; Invalidate();
            if (e.Button == MouseButtons.Right) { Raise("menu", it, d); }
            else if (e.Button == MouseButtons.Left) { Raise(b ? "bell" : "select", it, d); }
        } else {
            Selected = null; Invalidate();
            Raise(e.Button == MouseButtons.Right ? "emptymenu" : "none", null, d);
        }
        base.OnMouseUp(e);
    }
    protected override void OnMouseDoubleClick(MouseEventArgs e) {
        Point d = Doc(e.Location);
        bool b;
        DrItem it = HitItem(d, out b);
        if (e.Button == MouseButtons.Left && !b) { Raise(it != null ? "edit" : "add", it, d); }
        base.OnMouseDoubleClick(e);
    }

    static Color Hx(string s) { return DrUi.Hex(s); }

    // Note: no TranslateTransform here - Windows' text drawing ignores it, so every position is
    // worked out with the scroll offset added by hand.
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        int oy = AutoScrollPosition.Y;
        int view = ClientSize.Height;
        if (Blank) {
            TextRenderer.DrawText(g, EmptyText, Font, new Rectangle(82, 24, System.Math.Max(50, ClientSize.Width - 120), 44), Hx("#5B6470"), BackColor,
                TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
            return;
        }
        int right = ClientSize.Width - 10;
        TextFormatFlags one = TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding;
        using (Font small = new Font(Font.FontFamily, Font.Size - 1f))
        using (Font titleF = DrUi.F(Font, 0.5f, true)) {
            int nowY = NowMinute >= 0 ? MinuteY(NowMinute) : -10000;
            // Hours
            using (Pen pen = new Pen(Hx("#EEF0F3"))) {
                for (int h = 0; h < 24; h++) {
                    int y = hourTop[h] + oy;
                    if (y > view || hourTop[h + 1] + oy < 0) { continue; }
                    g.DrawLine(pen, Gutter, y, right, y);
                    if (System.Math.Abs(nowY - hourTop[h]) > 14) {
                        TextRenderer.DrawText(g, h.ToString("00") + ":00", small, new Rectangle(0, y - 1, Gutter - 12, 20), Hx("#9AA1AB"), BackColor,
                            TextFormatFlags.Right | TextFormatFlags.Top | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
                    }
                }
            }
            // Reminders
            foreach (DrItem it in Items) {
                Rectangle bx = it.Box;
                bx.Offset(0, oy);
                if (bx.Bottom < 0 || bx.Y > view) { continue; }
                bool other = it.Alert == "off";
                bool faded = it.Done || other;
                Color back = BackColor;
                if (it == Selected) { back = DrUi.Mix(it.Color1, Color.White, 0.9); }
                else if (it == hover) { back = Hx("#F5F7FA"); }
                if (back != BackColor) {
                    using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(bx, 9)) { using (SolidBrush b = new SolidBrush(back)) { g.FillPath(b, p); } }
                }
                // Time, a soft round icon, then the title (in the schedule's colour) with details below
                Color timeInk = faded ? Hx("#AEB4BD") : Hx("#6B7380");
                Color titleInk = faded ? DrUi.Mix(it.Color1, Color.White, 0.55) : DrUi.Mix(it.Color1, Color.Black, 0.08);
                Color detailInk = faded ? Hx("#B7BCC4") : Hx("#7A828E");
                int x = bx.X + 12;
                TextRenderer.DrawText(g, it.Time, Font, new Rectangle(x, bx.Y, 52, bx.Height), timeInk, back, one);
                x += 58;
                RectangleF circ = new RectangleF(x, bx.Y + (bx.Height - 34) / 2f, 34, 34);
                Color tint = faded ? Hx("#F0F2F5") : DrUi.Mix(it.Color1, Color.White, 0.87);
                using (SolidBrush b = new SolidBrush(tint)) { g.FillEllipse(b, circ); }
                DrUi.Icon(g, it.IconName, new RectangleF(circ.X + 8.5f, circ.Y + 8.5f, 17, 17), faded ? DrUi.Mix(it.Color1, Color.White, 0.5) : it.Color1);
                x += 48;
                int end = bx.Right - 40;
                if (it.Chip != "") {
                    Size cs = TextRenderer.MeasureText(g, it.Chip, small, new Size(9999, 20), one);
                    int cw = System.Math.Min(cs.Width, 180);
                    if (end - cw - 12 > x + 80) {
                        Color chipInk = faded ? Hx("#AEB4BD") : DrUi.Mix(it.Color1, Color.Black, 0.2);
                        TextRenderer.DrawText(g, it.Chip, small, new Rectangle(end - cw, bx.Y, cw, bx.Height), chipInk, back, one);
                        end = end - cw - 14;
                    }
                }
                int midY = bx.Y + bx.Height / 2;
                bool two = it.Line2 != "";
                TextRenderer.DrawText(g, it.Title, titleF, new Rectangle(x, two ? midY - 21 : bx.Y, System.Math.Max(40, end - x), two ? 22 : bx.Height), titleInk, back, one);
                if (two) {
                    TextRenderer.DrawText(g, it.Line2, small, new Rectangle(x, midY + 1, System.Math.Max(30, end - x), 18), detailInk, back, one);
                }
                // Bell (or megaphone): quiet until you point at the reminder
                Rectangle bb = it.BellBox; bb.Offset(0, oy);
                if (it == hover && hoverBell) {
                    using (System.Drawing.Drawing2D.GraphicsPath p = DrUi.Round(bb, 8)) { using (SolidBrush b = new SolidBrush(DrUi.Mix(back, Color.Black, 0.06))) { g.FillPath(b, p); } }
                }
                string icon = it.Alert == "shout" ? "megaphone" : (it.Alert == "on" ? "bell" : "bell-off");
                Color ink = it.Alert == "shout" ? Hx("#B5541B") : it.Alert == "muted" ? Hx("#8A929E") : other ? Hx("#C9CED6")
                          : (it == hover || it == Selected) ? Hx("#3D4652") : Hx("#C3C9D2");
                DrUi.Icon(g, icon, new RectangleF(bb.X + 6, bb.Y + 6, 16, 16), ink);
            }
            // Now
            if (NowMinute >= 0) {
                int y = nowY + oy;
                Color red = Hx("#E5484D");
                using (Pen pen = new Pen(red, 1.6f)) { g.DrawLine(pen, Gutter, y, right, y); }
                using (SolidBrush b = new SolidBrush(red)) { g.FillEllipse(b, Gutter - 5, y - 5, 10, 10); }
                string t = (NowMinute / 60).ToString("00") + ":" + (NowMinute % 60).ToString("00");
                TextRenderer.DrawText(g, t, small, new Rectangle(0, y - 10, Gutter - 12, 20), red, BackColor,
                    TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
            }
            if (Items.Count == 0 && EmptyText != "") {
                TextRenderer.DrawText(g, EmptyText, Font, new Rectangle(Gutter + 16, 16, System.Math.Max(50, ClientSize.Width - Gutter - 40), 44), Hx("#8A929E"), BackColor,
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
            }
        }
    }
}
// Menu colours for dark mode
public class DarkMenuColors : ProfessionalColorTable {
    static Color Bg = Color.FromArgb(43, 45, 49), Sel = Color.FromArgb(58, 68, 88), Line = Color.FromArgb(70, 72, 78), Bar = Color.FromArgb(32, 33, 36);
    public override Color MenuItemSelected { get { return Sel; } }
    public override Color MenuItemSelectedGradientBegin { get { return Sel; } }
    public override Color MenuItemSelectedGradientEnd { get { return Sel; } }
    public override Color MenuItemPressedGradientBegin { get { return Sel; } }
    public override Color MenuItemPressedGradientMiddle { get { return Sel; } }
    public override Color MenuItemPressedGradientEnd { get { return Sel; } }
    public override Color MenuItemBorder { get { return Sel; } }
    public override Color MenuBorder { get { return Line; } }
    public override Color MenuStripGradientBegin { get { return Bar; } }
    public override Color MenuStripGradientEnd { get { return Bar; } }
    public override Color ToolStripDropDownBackground { get { return Bg; } }
    public override Color ImageMarginGradientBegin { get { return Bg; } }
    public override Color ImageMarginGradientMiddle { get { return Bg; } }
    public override Color ImageMarginGradientEnd { get { return Bg; } }
    public override Color SeparatorDark { get { return Line; } }
    public override Color SeparatorLight { get { return Line; } }
    public override Color ToolStripBorder { get { return Line; } }
}
public class QuietForm : Form {
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
    [System.Runtime.InteropServices.DllImport("uxtheme.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    static extern int SetWindowTheme(System.IntPtr hwnd, string app, string idList);
    // Dark title bar (Windows 10 2004+ / 11)
    public static void DarkTitle(System.IntPtr h) {
        int on = 1;
        if (DwmSetWindowAttribute(h, 20, ref on, 4) != 0) { DwmSetWindowAttribute(h, 19, ref on, 4); }
    }
    // Dark scrollbars in lists
    public static void DarkScroll(System.IntPtr h) { SetWindowTheme(h, "DarkMode_Explorer", null); }
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
    # Already running: ask it to open its window (and allow it to come to the front), then stop
    try {
        [DrUi]::AllowAnyForeground()
        $ev = [System.Threading.EventWaitHandle]::OpenExisting('Local\DeskReminders.Show')
        [void]$ev.Set()
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Desk Reminders is already running (check the tray).', 'Desk Reminders') | Out-Null
    }
    return
}
$script:showEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\DeskReminders.Show')

[System.Windows.Forms.Application]::EnableVisualStyles()
# Older "Start with Windows" shortcuts left a PowerShell window open on Windows 11: update them
try {
    if (Test-StartupLink) {
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-StartupLinkPath))
        if ($lnk.TargetPath -notlike '*conhost.exe' -or -not ([string]$lnk.Arguments).Contains($PSCommandPath) -or -not ([string]$lnk.Arguments).Contains('-Startup')) { Install-StartupLink }
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

# --- Fonts -------------------------------------------------------------------
# The app uses Albert Sans (in the assets folder; free, SIL Open Font License). A font file you put
# in a 'fonts' folder next to this script is used instead. Fonts are only loaded for this app:
# nothing is installed on the PC. Without either: Segoe UI Variable (Windows 11) or Segoe UI.
$script:fontFiles = New-Object System.Drawing.Text.PrivateFontCollection
$script:AppFamily = $null
foreach ($dir in @((Join-Path $PSScriptRoot 'fonts'), (Join-Path $PSScriptRoot 'assets'))) {
    if ($script:AppFamily -or -not (Test-Path -LiteralPath $dir)) { continue }
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    foreach ($ff in @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Extension -in @('.ttf', '.otf') } | Sort-Object Name)) {
        try {
            [DrUi]::LoadFontForGdi($ff.FullName)      # so ordinary labels and buttons can draw it too
            $pfc.AddFontFile($ff.FullName)
        } catch {}
    }
    if ($pfc.Families.Count -gt 0) { $script:fontFiles = $pfc; $script:AppFamily = $pfc.Families[0] }
}
if (-not $script:AppFamily) {
    foreach ($n in @('Segoe UI Variable Text', 'Segoe UI')) {
        try { $script:AppFamily = New-Object System.Drawing.FontFamily($n); break } catch {}
    }
}

# A font in the app's family. A style the font doesn't have (e.g. bold) falls back to regular.
function New-UiFont([single]$size, [string]$style = 'Regular') {
    $st = [System.Drawing.FontStyle]$style
    try {
        if ($script:AppFamily) {
            if (-not $script:AppFamily.IsStyleAvailable($st)) { $st = [System.Drawing.FontStyle]::Regular }
            return New-Object System.Drawing.Font($script:AppFamily, $size, $st)
        }
    } catch {}
    return New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]$style)
}
# Headings: no bold (cleaner), just a little bigger
function New-HeadFont([single]$size) { New-UiFont ($size + 0.5) }

$UiFont     = New-UiFont 10
$BoldFont   = New-HeadFont 10
$SmallFont  = New-UiFont 9
$SmallBold  = New-HeadFont 8.5
$ItalicFont = New-UiFont 9 'Italic'
$Accent     = [System.Drawing.ColorTranslator]::FromHtml($MineColor)
$Dot        = [string][char]0x25CF
$MFont      = New-UiFont 10
$MBold      = New-HeadFont 10
$MSmall     = New-UiFont 9
$MSmallBold = New-HeadFont 8.5
$MBig       = New-HeadFont 12
$MHeadSmall = New-HeadFont 11
$MHead      = New-HeadFont 12.5
$MTitle     = New-HeadFont 18
$UiAccent   = [System.Drawing.ColorTranslator]::FromHtml('#2F6FDB')   # buttons, selected day, switches

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

# --- Light / dark mode -----------------------------------------------------------
function New-Rgb([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

function Test-DarkTheme {
    return $false      # Desk Reminders always uses its light look
}

# Colours used by the windows (light = the classic look)
function Set-Palette {
    $script:Dark = Test-DarkTheme
    if ($script:Dark) {
        $script:P = @{
            Back = New-Rgb 32 33 36; Surface = New-Rgb 43 45 49; Raised = New-Rgb 54 57 63
            Text = New-Rgb 232 233 235; Dim = New-Rgb 170 173 180; Faint = New-Rgb 140 143 150
            Grey = New-Rgb 105 108 115; OtherMonth = New-Rgb 95 98 105; DayText = New-Rgb 232 233 235
            Border = New-Rgb 88 91 98; Divider = New-Rgb 70 72 78; Footer = New-Rgb 24 25 28
            Hover = New-Rgb 58 68 88; Track = New-Rgb 70 72 78; Error = New-Rgb 240 120 120
        }
    } else {
        $script:P = @{
            Back = [System.Drawing.SystemColors]::Control; Surface = [System.Drawing.Color]::White; Raised = [System.Drawing.SystemColors]::Control
            Text = [System.Drawing.SystemColors]::ControlText; Dim = [System.Drawing.Color]::DimGray; Faint = [System.Drawing.Color]::Gray
            Grey = New-Rgb 160 160 160; OtherMonth = New-Rgb 185 185 185; DayText = New-Rgb 30 30 30
            Border = [System.Drawing.SystemColors]::ControlText; Divider = [System.Drawing.Color]::Gainsboro; Footer = New-Rgb 243 245 248
            Hover = New-Rgb 228 236 247; Track = New-Rgb 226 232 240; Error = [System.Drawing.Color]::Firebrick
        }
    }
}

# A schedule colour as text: lighter in dark mode so it stays readable
function To-TextColor($c) {
    if ($script:Dark) { return Get-Tint $c 0.45 }
    return $c
}

# A soft background version of a colour (towards white, or towards the dark surface)
function Get-Soft($c, [double]$k) {
    if (-not $script:Dark) { return Get-Tint $c $k }
    $s = $script:P.Surface
    [System.Drawing.Color]::FromArgb([int]($c.R + ($s.R - $c.R) * $k), [int]($c.G + ($s.G - $c.G) * $k), [int]($c.B + ($s.B - $c.B) * $k))
}

function Test-SameColor($a, $b) { return ($a.ToArgb() -eq $b.ToArgb()) }

function Reset-MenuTheme($menu) {
    $menu.RenderMode = 'ManagerRenderMode'
    $menu.BackColor = [System.Drawing.SystemColors]::Control
    $menu.ForeColor = [System.Drawing.SystemColors]::ControlText
    foreach ($i in $menu.Items) { if (-not ($i.Font.Bold)) { $i.ForeColor = [System.Drawing.SystemColors]::ControlText } else { $i.ForeColor = [System.Drawing.SystemColors]::ControlText } }
}

function Set-MenuTheme($menu) {
    if (-not $script:Dark) { return }
    $menu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer((New-Object DarkMenuColors))
    $menu.BackColor = $script:P.Back
    $menu.ForeColor = $script:P.Text
    $stack = New-Object System.Collections.Stack
    foreach ($i in $menu.Items) { $stack.Push($i) }
    while ($stack.Count -gt 0) {
        $i = $stack.Pop()
        if (Test-SameColor $i.ForeColor ([System.Drawing.SystemColors]::ControlText)) { $i.ForeColor = $script:P.Text }
        if ($i -is [System.Windows.Forms.ToolStripMenuItem]) {
            $i.DropDown.BackColor = $script:P.Surface
            foreach ($j in $i.DropDownItems) { $stack.Push($j) }
        }
    }
}

# Dark list header (the rows themselves draw normally)
function Set-ListViewDark($lv) {
    $lv.OwnerDraw = $true
    $lv.Add_DrawColumnHeader({
        param($s, $e)
        $b = New-Object System.Drawing.SolidBrush($script:P.Raised)
        $e.Graphics.FillRectangle($b, $e.Bounds); $b.Dispose()
        $pen = New-Object System.Drawing.Pen($script:P.Divider)
        $e.Graphics.DrawLine($pen, $e.Bounds.Right - 1, $e.Bounds.Top + 4, $e.Bounds.Right - 1, $e.Bounds.Bottom - 4)
        $e.Graphics.DrawLine($pen, $e.Bounds.Left, $e.Bounds.Bottom - 1, $e.Bounds.Right, $e.Bounds.Bottom - 1); $pen.Dispose()
        $r = New-Object System.Drawing.Rectangle(($e.Bounds.X + 6), $e.Bounds.Y, ($e.Bounds.Width - 8), $e.Bounds.Height)
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $e.Header.Text, $s.Font, $r, $script:P.Text, [System.Windows.Forms.TextFormatFlags]'VerticalCenter, Left, EndEllipsis')
    })
    $lv.Add_DrawItem({ $_.DrawDefault = $true })
    $lv.Add_DrawSubItem({ $_.DrawDefault = $true })
}

# Recolours a window and everything in it for dark mode (light mode is left as it is)
function Set-Theme($root) {
    if (-not $script:Dark -or -not $root) { return }
    $P = $script:P
    $white = [System.Drawing.Color]::White
    $ctrl = [System.Drawing.SystemColors]::Control
    $ctrlText = [System.Drawing.SystemColors]::ControlText
    $lightFooter = New-Rgb 243 245 248
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $c = $stack.Pop()
        foreach ($k in $c.Controls) { $stack.Push($k) }
        if ($c -is [System.Windows.Forms.Form]) {
            $c.BackColor = $P.Back; $c.ForeColor = $P.Text
            try { [void][QuietForm]::DarkTitle($c.Handle) } catch {}
            continue
        }
        if ($c -is [System.Windows.Forms.MenuStrip]) { Set-MenuTheme $c; continue }
        if ($c -is [System.Windows.Forms.DateTimePicker]) { continue }   # Windows draws it itself
        # Backgrounds
        if (Test-SameColor $c.BackColor $white) { $c.BackColor = $P.Surface }
        elseif (Test-SameColor $c.BackColor $lightFooter) { $c.BackColor = $P.Footer }
        # Text
        $fc = $c.ForeColor
        if ((Test-SameColor $fc $ctrlText) -or (Test-SameColor $fc ([System.Drawing.Color]::Black))) { $c.ForeColor = $P.Text }
        elseif (Test-SameColor $fc ([System.Drawing.Color]::DimGray)) { $c.ForeColor = $P.Dim }
        elseif (Test-SameColor $fc ([System.Drawing.Color]::Gray)) { $c.ForeColor = $P.Faint }
        elseif (Test-SameColor $fc $Accent) { $c.ForeColor = To-TextColor $Accent }
        elseif (Test-SameColor $fc ([System.Drawing.Color]::Firebrick)) { $c.ForeColor = $P.Error }
        if ($c -is [System.Windows.Forms.Button]) {
            if ((Test-SameColor $c.BackColor $ctrl) -or (Test-SameColor $c.BackColor $P.Back)) {
                $c.FlatStyle = 'Flat'
                $c.BackColor = $P.Raised
                $c.FlatAppearance.BorderColor = $P.Border
                $c.FlatAppearance.MouseOverBackColor = $P.Hover
            }
            if (Test-SameColor $c.BackColor $P.Surface) { $c.FlatAppearance.MouseOverBackColor = $P.Hover }
        }
        elseif ($c -is [System.Windows.Forms.TextBox] -or $c -is [System.Windows.Forms.ComboBox] -or $c -is [System.Windows.Forms.NumericUpDown] -or
                $c -is [System.Windows.Forms.ListBox] -or $c -is [System.Windows.Forms.ListView]) {
            $c.BackColor = $P.Surface; $c.ForeColor = $P.Text
            if ($c -is [System.Windows.Forms.ComboBox]) { $c.FlatStyle = 'Flat' }
            if ($c -is [System.Windows.Forms.TextBox]) { $c.BorderStyle = 'FixedSingle' }
            if ($c -is [System.Windows.Forms.ListView] -and -not $c.OwnerDraw) { Set-ListViewDark $c }
            try { [void][QuietForm]::DarkScroll($c.Handle) } catch {}
        }
        elseif ($c -is [System.Windows.Forms.ScrollableControl] -and $c.AutoScroll) {
            try { [void][QuietForm]::DarkScroll($c.Handle) } catch {}
        }
        elseif ($c -is [System.Windows.Forms.TrackBar]) { $c.BackColor = $c.Parent.BackColor }
    }
}

Set-Palette

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

# Small drawn icons (16x16) for the legend: the same bell / muted bell / megaphone as on the day view
function New-AlertIcon([string]$kind) {
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $name = switch ($kind) { 'on' { 'bell' } 'shout' { 'megaphone' } default { 'bell-off' } }
    $ink = switch ($kind) {
        'on'    { [System.Drawing.Color]::FromArgb(61, 70, 82) }
        'muted' { [System.Drawing.Color]::FromArgb(138, 146, 158) }
        'off'   { [System.Drawing.Color]::FromArgb(201, 206, 214) }
        'shout' { [System.Drawing.ColorTranslator]::FromHtml('#B5541B') }
    }
    [DrUi]::Icon($g, $name, (New-Object System.Drawing.RectangleF(0, 0, 16, 16)), $ink)
    $g.Dispose()
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
    $mid = [string][char]0x00B7
    $W = 400
    $white = [System.Drawing.Color]::White
    $dim = New-Rgb 74 82 96

    $form = New-Object QuietForm
    $form.FormBorderStyle = 'None'
    $form.StartPosition   = 'Manual'
    $form.ShowInTaskbar   = $false
    $form.TopMost         = $true
    $form.BackColor       = $white
    $form.Font            = $MFont
    $form.Width = $W
    $popTip = New-Object System.Windows.Forms.ToolTip

    $shown = [math]::Min($items.Count, 4)
    $single = ($items.Count -eq 1)
    $colours = @($items[0..($shown - 1)] | ForEach-Object { (To-Color $_.Colour).ToArgb() } | Select-Object -Unique)
    $mainColor = if ($colours.Count -gt 1) { $UiAccent } else { To-Color $items[0].Colour }

    $controls = @()
    $closers = @()
    $y = 4
    $textX = if ($single) { 74 } else { 18 }
    for ($i = 0; $i -lt $shown; $i++) {
        $it = $items[$i]
        $col = To-Color $it.Colour
        $ink = [DrUi]::Mix($col, [System.Drawing.Color]::Black, 0.08)
        $label = if ($it.IsMine) { Get-MineName } else { $it.Source }
        if (@($it.For).Count -gt 0) { $label += "  $mid  " + (@($it.For) -join ', ') }
        if ($it.Snoozed) { $label = "Snoozed  $mid  $label" }
        $bodyText = $it.Text
        if ($it.Kind -eq 'notice') {
            $bodyText = "Starts in $($it.Notice) minutes." + $(if ($it.Text) { ' ' + $it.Text } else { '' })
        }
        $textW = $W - $textX - 52

        if ($i -gt 0) {
            $sep = New-Object System.Windows.Forms.Panel
            $sep.BackColor = New-Rgb 238 240 243
            $sep.SetBounds(16, $y, ($W - 32), 1)
            $controls += $sep
        }
        $y += 12
        $rowTop = $y
        if ($single) {
            $tile = New-Object DrIconTile
            $tile.Color1 = $col
            $tile.IconName = Get-ReminderIcon $it
            $tile.SetBounds(16, ($y + 4), 44, 44)
            $controls += $tile
            $closers += $tile
            $close = New-DrBtn '' 'ghost' 'close' ($W - 42) ($y - 2) 28 28
            $close.Radius = 7
            $close.Add_Click({ $this.FindForm().Close() })
            $controls += $close
        }
        # Schedule and time in grey, the title in the schedule's colour (like the day view)
        $lab = New-UiLabel "$label  $mid  $($it.EventTime)" $MSmall (New-Rgb 107 115 128) $textX $y $textW 18
        $title = New-UiLabel $it.Title $MBig $ink $textX ($y + 19) $textW 26
        $controls += @($lab, $title)
        $closers += @($lab, $title)
        $y += 46
        if ($bodyText) {
            $sz = [System.Windows.Forms.TextRenderer]::MeasureText($bodyText, $MFont, (New-Object System.Drawing.Size($textW, 1000)), [System.Windows.Forms.TextFormatFlags]'WordBreak')
            $bh = [math]::Min(62, [math]::Max(20, $sz.Height + 2))
            $body = New-UiLabel $bodyText $MFont $dim $textX $y $textW $bh
            $body.AutoEllipsis = $true
            $controls += $body
            $closers += $body
            $y += $bh
        }
        if (-not $single -and $it.AlertKey) {
            # Bell per reminder: mute it (or stop "notify me too") without opening the window
            $bell = New-DrBtn '' 'ghost' 'bell' ($W - 48) ($rowTop - 4) 32 32
            $bell.Radius = 8
            $bell.Tag = $it
            $popTip.SetToolTip($bell, $(if ($it.AlertState -eq 'shout') { 'Stop notifying me about this one' } else { 'Mute this reminder' }))
            $bell.Add_Click({
                $script:pendingAlert = $this.Tag
                $this.IconName = 'bell-off'
                $this.Invalidate()
                Invoke-Later { Switch-Alert $script:pendingAlert }
            })
            $controls += $bell
        }
        $y += 8
    }
    if ($items.Count -gt $shown) {
        $more = New-UiLabel "+ $($items.Count - $shown) more (open Desk Reminders to see them)" $MSmall $dim $textX $y ($W - $textX - 16) 20
        $controls += $more
        $closers += $more
        $y += 24
    }
    $y += 4

    $snoozeList = $script:snoozed   # closures below can't see $script: variables
    $btnX = $textX
    foreach ($spec in @(@('Snooze 5 min', 5, 112), @('15 min', 15, 76))) {
        $sb = New-DrBtn $spec[0] 'outline' '' $btnX $y $spec[2] 32
        $sb.Font = $MSmall
        $sb.Radius = 16
        $sb.Tag = $spec[1]
        $sb.Add_Click({
            $later = (Get-Date).AddMinutes([int]$this.Tag)
            $copies = @($items | ForEach-Object { $c = $_.PSObject.Copy(); $c | Add-Member -NotePropertyName Snoozed -NotePropertyValue $true -Force; $c })
            [void]$snoozeList.Add(@{ At = $later; Items = $copies })
            $form.Close()
        }.GetNewClosure())
        $popTip.SetToolTip($sb, "Show this again in $($spec[1]) minutes")
        $controls += $sb
        $btnX += $spec[2] + 8
    }
    $done = New-DrBtn 'Done' 'primary' '' ($W - 16 - 86) $y 86 32
    $done.Font = $MSmallBold
    $done.Radius = 16
    $done.Accent = $mainColor
    $done.Add_Click({ $form.Close() }.GetNewClosure())
    $controls += $done
    $y += 32 + 16

    # A thin line along the bottom shows how long until it closes by itself
    $track = New-Object System.Windows.Forms.Panel
    $track.BackColor = New-Rgb 238 240 243
    $track.SetBounds(0, $y, $W, 3)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = $mainColor
    $fill.SetBounds(0, 0, $W, 3)
    $track.Controls.Add($fill)
    $controls += $track
    $form.Height = $y + 3

    foreach ($ctl in $closers) { $ctl.Add_Click({ $form.Close() }.GetNewClosure()) }
    $form.Controls.AddRange([System.Windows.Forms.Control[]]$controls)

    $area = Get-PopupArea
    $x = if ($script:settings.Corner -like '*Left') { $area.Left + 24 } else { $area.Right - $form.Width - 24 }
    $yPos = if ($script:settings.Corner -like 'Top*') { $area.Top + 24 } else { $area.Bottom - $form.Height - 24 }
    $form.Location = New-Object System.Drawing.Point($x, $yPos)

    # Rounded corners (Windows 11 adds its own border and shadow; elsewhere we draw a thin border)
    if (-not [DrUi]::RoundWindow($form, 12)) {
        $form.Add_Paint({
            param($s, $e)
            $e.Graphics.SmoothingMode = 'AntiAlias'
            $p = [DrUi]::Round((New-Object System.Drawing.RectangleF(0, 0, ($s.Width - 1), ($s.Height - 1))), 12)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205, 211, 219))
            $e.Graphics.DrawPath($pen, $p)
            $pen.Dispose(); $p.Dispose()
        })
    }

    $lifeMs = $PopupSeconds * 1000 + [math]::Max(0, $shown - 1) * 5000
    $clockW = [System.Diagnostics.Stopwatch]::StartNew()
    $life = New-Object System.Windows.Forms.Timer
    $life.Interval = 40
    $life.Add_Tick({
        $left = 1 - $clockW.ElapsedMilliseconds / $lifeMs
        if ($left -le 0) { $life.Stop(); if (-not $form.IsDisposed) { $form.Close() }; return }
        $fill.Width = [int]($W * $left)
    }.GetNewClosure())
    $form.Add_FormClosed({ $life.Stop(); $life.Dispose(); $popTip.Dispose() }.GetNewClosure())
    $life.Start()

    $script:current = $form
    $form.Show()
    Play-Chime -Sound (Get-ScheduleSound $items[0])
}

# The sound for a reminder: its schedule's own sound, or the one from Settings
function Get-ScheduleSound($item) {
    $key = if ($item.IsMine) { 'schedule.csv' } elseif ($item.File) { [System.IO.Path]::GetFileName([string]$item.File) } else { '' }
    if ($key -and $script:settings.Sounds.ContainsKey($key) -and $script:settings.Sounds[$key]) { return [string]$script:settings.Sounds[$key] }
    return ''
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
    Publish-Copies $src.FileName
    Sync-Schedule -Force
    return $true
}

function Invoke-Undo {
    $u = $script:undo
    if (-not $u) { Show-Msg $script:sw 'There is nothing to undo.' 'Undo' | Out-Null; return }
    if ($u.Kind -eq 'file') {
        [System.IO.File]::WriteAllLines($u.File, [string[]]$u.Lines, (New-Object System.Text.UTF8Encoding($true)))
        Publish-Copies ([System.IO.Path]::GetFileName($u.File))
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
    Set-Theme $d
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
function Show-ReminderDialog([string]$Mode = 'Add', $Entry = $null, [string]$TargetFile = '', [int]$AtMinute = -1) {
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
    # Double-clicked a time on the timeline: start there (to the nearest quarter of an hour)
    if ($AtMinute -ge 0 -and -not $row) { $start = $day.Date.AddMinutes([math]::Min(1425, [math]::Round($AtMinute / 15) * 15)) }

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
    if (-not $c.Timeline -or -not $c.Timeline.Selected) { return $null }
    return $c.Timeline.Selected.Tag
}

function Edit-Selected {
    $e = Get-SelectedEntry
    if (-not $e) { Show-Msg $script:sw 'Click a reminder on the timeline first.' 'Edit' | Out-Null; return }
    if (-not $e.Editable) {
        Show-Msg $script:sw "'$($e.Title)' comes from '$($e.Source)', a shared schedule you imported. Only the person who made it can change it. You can hide it for yourself with Remove." 'Edit' | Out-Null
        return
    }
    Show-ReminderDialog 'Edit' $e
}

# --- Remove / hide ----------------------------------------------------------
function Remove-Selected {
    $e = Get-SelectedEntry
    if (-not $e) { Show-Msg $script:sw 'Click a reminder on the timeline first.' 'Remove' | Out-Null; return }
    $dayText = $script:selDay.ToString('dddd d MMMM', $En)

    if (-not $e.Editable) {
        $msg = "'$($e.Title)' at $($e.EventTime) comes from the shared schedule '$($e.Source)'.`n`nHide it only on $dayText, or every time? This only changes what you see; the shared file stays as it is. You can show them again: the ... button on the schedule (left) > Options."
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
    foreach ($h in @($st.Colors, $st.MyGroups, $st.QuietAllow, $st.Links, $st.Publish, $st.Sounds)) { if ($h.ContainsKey($fileName)) { $h.Remove($fileName) } }
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
    $dlg.Title = 'Import a shared schedule or a calendar'
    $dlg.Filter = 'Schedules and calendars (*.csv;*.ics)|*.csv;*.ics|All files (*.*)|*.*'
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = $dlg.FileName
    # A calendar file (.ics): turn it into a schedule first
    $icsTmp = $null
    $head = ''
    try { $head = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) } catch {}
    if ($head -match 'BEGIN:VCALENDAR') {
        $content = Read-LinkContent $head ([IO.Path]::GetFileNameWithoutExtension($path))
        $icsTmp = Join-Path ([IO.Path]::GetTempPath()) ((Get-SafeName $content.Name) + '.csv')
        [IO.File]::WriteAllLines($icsTmp, [string[]]$content.Lines.ToArray(), (New-Object Text.UTF8Encoding($true)))
        $path = $icsTmp
    }

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
                     else { "`nYou didn't pick a group, so only events for everyone pop up. Change it any time: the ... button on the schedule (left) > Options." }
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

# --- Links: follow a schedule or calendar online, or a file in a synced folder ---
# Only downloads; nothing about you is sent. Checked every $LinkMinutes minutes.
$LinkMinutes = 20

# Turns the link people paste into the address of the file itself
function ConvertTo-LinkUrl([string]$u) {
    $u = $u.Trim().Trim('"').Trim("'")
    if ($u -match '^webcals?://') { $u = $u -replace '^webcals?://', 'https://' }
    if ($u -match '^http://') { $u = $u -replace '^http://', 'https://' }
    if ($u -notmatch '^https://') { return $null }
    # GitHub Gist page -> raw (always the newest version)
    if ($u -match '^https://gist\.github\.com/([^/]+)/([0-9a-fA-F]+)/?$') { return "https://gist.githubusercontent.com/$($Matches[1])/$($Matches[2])/raw" }
    if ($u -match '^https://gist\.github\.com/([0-9a-fA-F]+)/?$') { return "https://gist.githubusercontent.com/anonymous/$($Matches[1])/raw" }
    # A file shown on github.com -> raw
    if ($u -match '^https://github\.com/([^/]+)/([^/]+)/blob/(.+)$') { return "https://raw.githubusercontent.com/$($Matches[1])/$($Matches[2])/$($Matches[3])" }
    # Dropbox share link -> direct download
    if ($u -match '^https://(www\.)?dropbox\.com/' ) { return ($u -replace '([?&])dl=0', '$1dl=1') + $(if ($u -notmatch '[?&]dl=') { $(if ($u.Contains('?')) { '&dl=1' } else { '?dl=1' }) } else { '' }) }
    # Google Drive file page -> direct download
    if ($u -match '^https://drive\.google\.com/file/d/([^/]+)') { return "https://drive.google.com/uc?export=download&id=$($Matches[1])" }
    # Pastebin page -> raw
    if ($u -match '^https://pastebin\.com/([A-Za-z0-9]+)/?$') { return "https://pastebin.com/raw/$($Matches[1])" }
    return $u
}

# Downloads a link (also run in the background). HTTPS only, max 2 MB, 15 s timeout.
$LinkFetch = {
    param([string]$url)
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
        $req = [Net.HttpWebRequest]::Create($url)
        $req.UserAgent = 'DeskReminders'
        $req.Accept = 'text/calendar, text/csv, text/plain, application/json, */*'
        $req.Timeout = 15000
        $req.ReadWriteTimeout = 15000
        $req.AllowAutoRedirect = $true
        $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $resp = $req.GetResponse()
        try {
            if ($resp.ResponseUri.Scheme -ne 'https') { throw 'The link redirected to an unsafe (http) address.' }
            $in = $resp.GetResponseStream()
            $ms = New-Object IO.MemoryStream
            $buf = New-Object byte[] 65536
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $ms.Write($buf, 0, $n)
                if ($ms.Length -gt 2MB) { throw 'The file is bigger than 2 MB.' }
            }
            $bytes = $ms.ToArray()
        } finally { $resp.Close() }
        $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
        return @{ Ok = $true; Text = $text }
    } catch {
        $m = $_.Exception.Message
        if ($_.Exception.InnerException) { $m = $_.Exception.InnerException.Message }
        return @{ Ok = $false; Error = ($m -replace '^Exception calling "GetResponse" with "0" argument\(s\): ', '').Trim('"') }
    }
}

# --- Calendar (.ics) -> schedule rows --------------------------------------------
function ConvertFrom-IcsText([string]$v) {
    ($v -replace '\\[nN]', ' ' -replace '\\,', ',' -replace '\\;', ';' -replace '\\\\', '\').Trim()
}

# Returns @{ Utc = <datetime UTC>; AllDay = bool } or $null
function ConvertFrom-IcsDate([string]$value, [hashtable]$params) {
    $v = $value.Trim()
    $ci = [Globalization.CultureInfo]::InvariantCulture
    if ($v -match '^\d{8}$' -or $params['VALUE'] -eq 'DATE') {
        $d = [datetime]::MinValue
        if ([datetime]::TryParseExact($v.Substring(0, 8), 'yyyyMMdd', $ci, [Globalization.DateTimeStyles]::None, [ref]$d)) { return @{ Utc = $d; AllDay = $true; Wall = $d; Tz = $null } }
        return $null
    }
    $isUtc = $v.EndsWith('Z')
    $core = $v.TrimEnd('Z')
    $d = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($core, [string[]]@("yyyyMMdd'T'HHmmss", "yyyyMMdd'T'HHmm"), $ci, [Globalization.DateTimeStyles]::None, [ref]$d)) { return $null }
    if ($isUtc) { return @{ Utc = $d; AllDay = $false; Wall = $d; Tz = [TimeZoneInfo]::Utc } }
    $tz = $null
    if ($params['TZID']) { $tz = Resolve-TimeZone ($params['TZID'] -replace '^/', '') }
    if (-not $tz) { $tz = [TimeZoneInfo]::Local }
    try { $u = [TimeZoneInfo]::ConvertTimeToUtc([datetime]::SpecifyKind($d, 'Unspecified'), $tz) } catch { $u = $d }
    return @{ Utc = $u; AllDay = $false; Wall = $d; Tz = $tz }
}

function ConvertTo-UtcWall([datetime]$wall, $tz) {
    try { return [TimeZoneInfo]::ConvertTimeToUtc([datetime]::SpecifyKind($wall, 'Unspecified'), $tz) } catch { return $null }
}

# Expands a recurring event (in its own time zone, so summer/winter time stays right)
function Get-IcsOccurrences($start, [hashtable]$rule, [datetime]$fromUtc, [datetime]$toUtc) {
    $out = New-Object System.Collections.Generic.List[datetime]
    $freq = $rule['FREQ']
    $interval = if ($rule['INTERVAL']) { [math]::Max(1, [int]$rule['INTERVAL']) } else { 1 }
    $count = if ($rule['COUNT']) { [int]$rule['COUNT'] } else { [int]::MaxValue }
    $until = $null
    if ($rule['UNTIL']) { $u = ConvertFrom-IcsDate $rule['UNTIL'] @{}; if ($u) { $until = if ($u.AllDay) { $u.Utc.AddDays(1) } else { $u.Utc } } }
    $wall = $start.Wall; $tz = $start.Tz
    $tod = $wall.TimeOfDay
    $dayCodes = @{ MO = 1; TU = 2; WE = 3; TH = 4; FR = 5; SA = 6; SU = 7 }
    $byDay = @(); if ($rule['BYDAY']) { $byDay = @($rule['BYDAY'] -split ',') }
    $byMonthDay = @(); if ($rule['BYMONTHDAY']) { $byMonthDay = @($rule['BYMONTHDAY'] -split ',' | ForEach-Object { [int]$_ }) }
    $n = 0; $guard = 0
    $emit = {
        param([datetime]$w)
        if ($w -lt $wall) { return $true }
        $script:icsN++
        if ($script:icsN -gt $count) { return $false }
        $utc = ConvertTo-UtcWall $w $tz
        if ($null -eq $utc) { return $true }
        if ($until -and $utc -gt $until) { return $false }
        if ($utc -gt $toUtc) { return $false }
        if ($utc -ge $fromUtc) { $out.Add($utc) }
        return $true
    }
    $script:icsN = 0
    switch ($freq) {
        'DAILY' {
            for ($i = 0; $guard -lt 5000; $i += $interval) { $guard++; if (-not (& $emit $wall.AddDays($i))) { break } }
        }
        'WEEKLY' {
            $dow = [int]$wall.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
            $weekStart = $wall.Date.AddDays(1 - $dow)
            $days = if ($byDay.Count -gt 0) { @($byDay | ForEach-Object { $dayCodes[($_ -replace '^[+-]?\d+', '')] } | Where-Object { $_ } | Sort-Object) } else { @($dow) }
            $go = $true
            for ($w = 0; $go -and $guard -lt 5000; $w += $interval) {
                foreach ($dd in $days) { $guard++; if (-not (& $emit ($weekStart.AddDays($w * 7 + $dd - 1) + $tod))) { $go = $false; break } }
            }
        }
        'MONTHLY' {
            $go = $true
            for ($m = 0; $go -and $guard -lt 5000; $m += $interval) {
                $first = (New-Object DateTime($wall.Year, $wall.Month, 1)).AddMonths($m)
                $dim = [DateTime]::DaysInMonth($first.Year, $first.Month)
                $dates = @()
                if ($byMonthDay.Count -gt 0) {
                    foreach ($md in $byMonthDay) { $d = if ($md -lt 0) { $dim + $md + 1 } else { $md }; if ($d -ge 1 -and $d -le $dim) { $dates += $first.AddDays($d - 1) } }
                } elseif ($byDay.Count -gt 0) {
                    foreach ($bd in $byDay) {
                        if ($bd -notmatch '^([+-]?\d+)?([A-Z]{2})$') { continue }
                        $want = $dayCodes[$Matches[2]]; if (-not $want) { continue }
                        $ord = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
                        $all = @(); for ($d = 0; $d -lt $dim; $d++) { $x = $first.AddDays($d); $xd = [int]$x.DayOfWeek; if ($xd -eq 0) { $xd = 7 }; if ($xd -eq $want) { $all += $x } }
                        if ($ord -eq 0) { $dates += $all } elseif ($ord -gt 0 -and $ord -le $all.Count) { $dates += $all[$ord - 1] } elseif ($ord -lt 0 -and -$ord -le $all.Count) { $dates += $all[$all.Count + $ord] }
                    }
                } elseif ($wall.Day -le $dim) { $dates += $first.AddDays($wall.Day - 1) }
                foreach ($d in ($dates | Sort-Object)) { $guard++; if (-not (& $emit ($d.Date + $tod))) { $go = $false; break } }
            }
        }
        'YEARLY' {
            for ($y = 0; $guard -lt 500; $y += $interval) {
                $guard++
                $yr = $wall.Year + $y
                if ($wall.Month -eq 2 -and $wall.Day -eq 29 -and -not [DateTime]::IsLeapYear($yr)) { continue }
                if (-not (& $emit (New-Object DateTime($yr, $wall.Month, $wall.Day, $wall.Hour, $wall.Minute, 0)))) { break }
            }
        }
        default {
            if ($start.Utc -ge $fromUtc -and $start.Utc -le $toUtc) { $out.Add($start.Utc) }
        }
    }
    return ,$out
}

# Reads a calendar and returns @{ Name; Rows = list of @{ Utc; Title; Text; Notice }; AllDaySkipped }
function ConvertFrom-Ics([string]$text, [datetime]$fromUtc, [datetime]$toUtc) {
    $lines = ($text -replace "\r\n", "`n" -replace "\r", "`n" -replace "\n[ \t]", '') -split "`n"
    $calName = ''
    $events = New-Object System.Collections.Generic.List[object]
    $ev = $null; $inAlarm = $false
    foreach ($line in $lines) {
        if ($line -eq '') { continue }
        $ci = $line.IndexOf(':')
        if ($ci -lt 0) { continue }
        $left = $line.Substring(0, $ci); $value = $line.Substring($ci + 1)
        $parts = $left -split ';'
        $name = $parts[0].ToUpper()
        $params = @{}
        foreach ($p in ($parts | Select-Object -Skip 1)) { $kv = $p -split '=', 2; if ($kv.Count -eq 2) { $params[$kv[0].ToUpper()] = $kv[1].Trim('"') } }
        if ($name -eq 'BEGIN' -and $value -eq 'VEVENT') { $ev = @{ Ex = @() }; continue }
        if ($name -eq 'END' -and $value -eq 'VEVENT') { if ($ev) { $events.Add($ev) }; $ev = $null; continue }
        if ($name -eq 'BEGIN' -and $value -eq 'VALARM') { $inAlarm = $true; continue }
        if ($name -eq 'END' -and $value -eq 'VALARM') { $inAlarm = $false; continue }
        if (-not $ev) { if ($name -eq 'X-WR-CALNAME') { $calName = ConvertFrom-IcsText $value }; continue }
        if ($inAlarm) {
            if ($name -eq 'TRIGGER' -and $params['RELATED'] -ne 'END' -and $value -match '^-P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$') {
                $mins = [int]$Matches[1] * 10080 + [int]$Matches[2] * 1440 + [int]$Matches[3] * 60 + [int]$Matches[4]
                if ($mins -gt 0 -and $mins -le 1440 -and (-not $ev.Notice -or $mins -lt $ev.Notice)) { $ev.Notice = $mins }
            }
            continue
        }
        switch ($name) {
            'SUMMARY'       { $ev.Title = ConvertFrom-IcsText $value }
            'DESCRIPTION'   { $ev.Text = ConvertFrom-IcsText $value }
            'LOCATION'      { $ev.Location = ConvertFrom-IcsText $value }
            'UID'           { $ev.Uid = $value }
            'STATUS'        { $ev.Status = $value.ToUpper() }
            'DTSTART'       { $ev.Start = ConvertFrom-IcsDate $value $params }
            'RRULE'         { $r = @{}; foreach ($kv in ($value -split ';')) { $x = $kv -split '=', 2; if ($x.Count -eq 2) { $r[$x[0].ToUpper()] = $x[1].ToUpper() } }; $ev.Rule = $r }
            'EXDATE'        { foreach ($x in ($value -split ',')) { $d = ConvertFrom-IcsDate $x $params; if ($d) { $ev.Ex += $d.Utc } } }
            'RECURRENCE-ID' { $ev.RecurId = ConvertFrom-IcsDate $value $params }
        }
    }
    # Moved or cancelled single dates of a repeating event
    $overrides = @{}
    foreach ($e in $events) { if ($e.RecurId -and $e.Uid) { $overrides["$($e.Uid)|$($e.RecurId.Utc.ToString('yyyyMMddHHmm'))"] = $true } }
    $rows = New-Object System.Collections.Generic.List[object]
    $allDay = 0
    foreach ($e in $events) {
        if (-not $e.Start) { continue }
        if ($e.Start.AllDay) { $allDay++; continue }
        if ($e.Status -eq 'CANCELLED') { continue }
        $title = if ($e.Title) { $e.Title } else { '(no title)' }
        $txt = if ($e.Text) { $e.Text } elseif ($e.Location) { $e.Location } else { '' }
        if ($txt.Length -gt 120) { $txt = $txt.Substring(0, 117) + '...' }
        $times = if ($e.Rule -and -not $e.RecurId) { Get-IcsOccurrences $e.Start $e.Rule $fromUtc $toUtc } else { @($e.Start.Utc | Where-Object { $_ -ge $fromUtc -and $_ -le $toUtc }) }
        foreach ($t in $times) {
            $key = $t.ToString('yyyyMMddHHmm')
            if ($e.Rule -and -not $e.RecurId) {
                if ($overrides.ContainsKey("$($e.Uid)|$key")) { continue }
                if (@($e.Ex | Where-Object { $_.ToString('yyyyMMddHHmm') -eq $key }).Count -gt 0) { continue }
            }
            $rows.Add(@{ Utc = $t; Title = $title; Text = $txt; Notice = [int]$e.Notice })
            if ($rows.Count -ge 3000) { break }
        }
    }
    return @{ Name = $calName; Rows = @($rows | Sort-Object { $_.Utc }); AllDaySkipped = $allDay }
}

# Writes the schedule-file lines for a calendar (times in UTC; each PC shows its own local time)
function ConvertTo-ScheduleLines($ics, [string]$name) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Days,Time,Colour,Title,Text,Notice,For')
    $lines.Add("#! name = $name")
    $lines.Add('#! timezone = UTC')
    $lines.Add('# Followed from a calendar link by Desk Reminders. This file is replaced at every check.')
    foreach ($r in $ics.Rows) {
        $lines.Add((New-CsvLine @($r.Utc.ToString('yyyy-MM-dd'), $r.Utc.ToString('HH:mm'), '', $r.Title, $r.Text, $(if ($r.Notice -gt 0) { [string]$r.Notice } else { '' }), '') ','))
    }
    return ,$lines
}

# What changed between two versions of a schedule, for you
function Get-ChangeSummary($oldRows, $newRows, [string[]]$myGroups) {
    $keyOf = { param($row) "$($row.DaysText)|$($row.TimeText)|$($row.Title)|$(@($row.For) -join '+')" }
    $oldKeys = @($oldRows | Where-Object { $_.Colour -ne 'skip' } | ForEach-Object { & $keyOf $_ })
    $nRows = @($newRows | Where-Object { $_.Colour -ne 'skip' })
    $newKeys = @($nRows | ForEach-Object { & $keyOf $_ })
    $added = @($nRows | Where-Object { $oldKeys -notcontains (& $keyOf $_) })
    $removed = @($oldKeys | Where-Object { $newKeys -notcontains $_ }).Count
    $forMe = @($added | Where-Object { @($_.For).Count -eq 0 -or @($_.For | Where-Object { @($myGroups) -contains $_ }).Count -gt 0 }).Count
    $parts = @()
    if ($added.Count -gt 0) {
        $p = "$($added.Count) new or changed: $forMe for you"
        if ($added.Count - $forMe -gt 0) { $p += ", $($added.Count - $forMe) for other groups" }
        $parts += $p
    }
    if ($removed -gt 0) { $parts += "$removed removed or changed" }
    return @{ Added = $added.Count; ForMe = $forMe; Removed = $removed; Text = ($parts -join '; ') }
}

# --- Following links and synced files ------------------------------------------
$script:linkJobs = @{}

function Get-SourceByName([string]$fileName) {
    foreach ($s in $script:loaded.All) { if ($s.FileName -eq $fileName) { return $s } }
    return $null
}

function Get-LinkEntry([string]$fileName) {
    if ($script:settings.Links.ContainsKey($fileName)) { return $script:settings.Links[$fileName] }
    return $null
}

function Get-LinkLabel($entry) {
    if (-not $entry) { return '' }
    if ($entry.Kind -eq 'file') { return 'Synced file' }
    if ($entry.Calendar) { return 'Calendar link' }
    return 'Link'
}

# A file name in the shared folder that isn't taken by another schedule
function Get-FreeFileName([string]$name) {
    $safe = Get-SafeName $name
    $fileName = "$safe.csv"; $i = 2
    while (Test-Path -LiteralPath (Join-Path $SharedDir $fileName)) { $fileName = "$safe ($i).csv"; $i++ }
    return $fileName
}

# Turns downloaded text (a schedule file or a calendar) into schedule-file lines
function Read-LinkContent([string]$text, [string]$nameHint) {
    if ($text -match 'BEGIN:VCALENDAR') {
        $now = (Get-Date).ToUniversalTime()
        $ics = ConvertFrom-Ics $text $now.AddDays(-1) $now.AddDays(120)
        $name = if ($nameHint) { $nameHint } elseif ($ics.Name) { $ics.Name } else { 'Calendar' }
        $lines = ConvertTo-ScheduleLines $ics $name
        return @{ Ok = $true; Lines = $lines; Name = $name; Calendar = $true; Count = @($ics.Rows).Count; AllDay = $ics.AllDaySkipped; Groups = @() }
    }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('DeskRemindersLink-' + [guid]::NewGuid().ToString('N') + '.csv')
    try {
        [IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding($false)))
        $r = Read-ScheduleFile $tmp
        $good = @($r.Rows | Where-Object { $_.Colour -ne 'skip' }).Count
        if (-not $r.HasHeader -or $good -eq 0) {
            $hint = if ($text -match '<html|<!DOCTYPE') { ' It looks like a web page, not the file itself. For a GitHub Gist, use the "Raw" link; for Google Calendar, the "Secret address in iCal format".' } else { '' }
            return @{ Ok = $false; Error = "This link doesn't contain a schedule or a calendar.$hint" }
        }
        $name = if ($r.Name) { $r.Name } elseif ($nameHint) { $nameHint } else { 'Shared schedule' }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($l in ($text -split "\r?\n")) { $lines.Add($l) }
        while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        return @{ Ok = $true; Lines = $lines; Name = $name; Calendar = $false; Count = $good; AllDay = 0; Groups = @($r.Groups) }
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

# Writes the new version if something changed. Returns the change summary text, or $null when nothing changed.
function Save-LinkContent([string]$fileName, $content, [switch]$First) {
    if (-not (Test-Path -LiteralPath $SharedDir)) { New-Item -ItemType Directory -Path $SharedDir | Out-Null }
    $dest = Join-Path $SharedDir $fileName
    $strip = { param($ls) @($ls | Where-Object { $_ -notmatch '^\s*"?#!\s*updated\s*[=:]' }) -join "`n" }
    $old = $null
    if (Test-Path -LiteralPath $dest) {
        $cur = [IO.File]::ReadAllLines($dest, [Text.Encoding]::UTF8)
        if ((& $strip $cur) -eq (& $strip $content.Lines)) { return $null }
        $old = Read-ScheduleFile $dest
    }
    [IO.File]::WriteAllLines($dest, [string[]]$content.Lines.ToArray(), (New-Object Text.UTF8Encoding($true)))
    if ($First -or -not $old) { return '' }
    $new = Read-ScheduleFile $dest
    $mine = if ($script:settings.MyGroups.ContainsKey($fileName)) { @($script:settings.MyGroups[$fileName]) } else { @() }
    $sum = Get-ChangeSummary $old.Rows $new.Rows $mine
    if ($sum.Text) { return $sum.Text }
    return 'Updated (no change to the events)'
}

# Handles a finished check of one link
function Complete-LinkCheck([string]$fileName, $result) {
    $entry = Get-LinkEntry $fileName
    if (-not $entry) { return }
    $entry.Checked = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    $hadError = [bool]$entry.Error
    if (-not $result -or -not $result.Ok) {
        $entry.Error = if ($result) { [string]$result.Error } else { 'No answer' }
        if (-not $hadError) { $tray.ShowBalloonTip(6000, "Couldn't check '$($entry.Name)'", "$($entry.Error)`nThe last version you have keeps working.", 'Warning') }
        Save-Settings
        Refresh-ScheduleWindow
        return
    }
    $content = Read-LinkContent $result.Text $(if ($entry.Calendar) { $entry.Name } else { '' })
    if (-not $content.Ok) {
        $entry.Error = $content.Error
        if (-not $hadError) { $tray.ShowBalloonTip(6000, "Couldn't read '$($entry.Name)'", $content.Error, 'Warning') }
        Save-Settings
        Refresh-ScheduleWindow
        return
    }
    $entry.Error = ''
    $entry.Calendar = [bool]$content.Calendar
    $summary = Save-LinkContent $fileName $content
    Save-Settings
    if ($null -ne $summary) {
        Sync-Schedule -Force
        if ($summary) { $tray.ShowBalloonTip(8000, "'$($entry.Name)' was updated", $summary, 'Info') }
        # New groups appeared and you haven't picked one yet
        if (@($content.Groups).Count -gt 0 -and @($script:settings.MyGroups[$fileName]).Count -eq 0 -and -not $entry.AskedGroups) {
            $entry.AskedGroups = $true; Save-Settings
            $tray.ShowBalloonTip(8000, "'$($entry.Name)' has groups", 'Pick yours: the ... button on it in the Schedules list > Options.', 'Info')
        }
    } else {
        Refresh-ScheduleWindow
    }
}

# Starts background checks for links that are due (every $LinkMinutes minutes, or now with -Force)
function Start-LinkChecks([switch]$Force, [string]$Only = '') {
    foreach ($fileName in @($script:settings.Links.Keys)) {
        if ($Only -and $fileName -ne $Only) { continue }
        $e = $script:settings.Links[$fileName]
        if ($e.Kind -ne 'url' -or $script:linkJobs.ContainsKey($fileName)) { continue }
        if (@($script:settings.Disabled) -contains $fileName -and -not $Force) { continue }
        $due = $true
        if (-not $Force -and $e.Checked) {
            $last = [datetime]::MinValue
            if ([datetime]::TryParseExact([string]$e.Checked, 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$last)) {
                $due = ((Get-Date) - $last).TotalMinutes -ge $LinkMinutes
            }
        }
        if (-not $due) { continue }
        $ps = [powershell]::Create()
        [void]$ps.AddScript($LinkFetch.ToString()).AddArgument([string]$e.Url)
        $script:linkJobs[$fileName] = @{ PS = $ps; Handle = $ps.BeginInvoke(); Started = Get-Date }
    }
}

# Collects finished background checks (called by the clock)
function Receive-LinkChecks {
    foreach ($fileName in @($script:linkJobs.Keys)) {
        $j = $script:linkJobs[$fileName]
        if (-not $j.Handle.IsCompleted) {
            if (((Get-Date) - $j.Started).TotalSeconds -gt 60) { try { $j.PS.Stop() } catch {}; $j.PS.Dispose(); $script:linkJobs.Remove($fileName) }
            continue
        }
        $res = $null
        try { $out = $j.PS.EndInvoke($j.Handle); if ($out.Count -gt 0) { $res = $out[0] } } catch { $res = @{ Ok = $false; Error = $_.Exception.Message } }
        $j.PS.Dispose()
        $script:linkJobs.Remove($fileName)
        if ($fileName -eq '__update__') { Complete-UpdateCheck $res } else { Complete-LinkCheck $fileName $res }
    }
}

# Synced-folder files: copy in the new version as soon as the file changes
function Update-FileLinks {
    foreach ($fileName in @($script:settings.Links.Keys)) {
        $e = $script:settings.Links[$fileName]
        if ($e.Kind -ne 'file') { continue }
        $path = [string]$e.Url
        if (-not (Test-Path -LiteralPath $path)) {
            if (-not $e.Missing) { $e.Missing = $true; $e.Error = 'The file is missing (is the synced folder still there?)'; Save-Settings; Refresh-ScheduleWindow }
            continue
        }
        $stamp = (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks
        if ($e.Missing) { $e.Missing = $false; $e.Error = ''; $e.Stamp = '' }      # it's back
        if ([string]$stamp -eq [string]$e.Stamp) { continue }
        $e.Stamp = [string]$stamp
        try { $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) } catch { continue }   # still being written: next tick
        Complete-LinkCheck $fileName @{ Ok = $true; Text = $text }
    }
}

# Asks which groups you're in (when the schedule has groups)
function Request-MyGroups([string]$fileName, [string]$name, $groups, $owner) {
    $groups = @($groups)
    if ($groups.Count -eq 0) { return '' }
    $mine = if ($script:settings.MyGroups.ContainsKey($fileName)) { @($script:settings.MyGroups[$fileName] | Where-Object { $groups -contains $_ }) } else { @() }
    $picked = Show-GroupPicker $name $groups $mine $owner
    if ($null -ne $picked) { $mine = @($picked) }
    $script:settings.MyGroups[$fileName] = @($mine)
    if ($mine.Count -gt 0) { return "`nYour groups: $($mine -join ', ')." }
    return "`nNo group picked: only events for everyone pop up. Change it under Options."
}

# Import > From a link
function Add-LinkSubscription($owner) {
    $d = New-Dialog 'Follow a link' 560 330
    $intro = New-Note "Paste the link to a shared schedule or a calendar. Desk Reminders checks it every $LinkMinutes minutes and tells you what changed." 16 12 528 40
    $intro.ForeColor = [System.Drawing.SystemColors]::ControlText
    $urlBox = New-Object System.Windows.Forms.TextBox
    $urlBox.SetBounds(16, 60, 528, 28)
    try { $clip = [System.Windows.Forms.Clipboard]::GetText(); if ($clip -match '^(https?|webcals?)://\S+$') { $urlBox.Text = $clip.Trim() } } catch {}
    $examples = New-Note ("Works with:`n" +
        "- a GitHub Gist (or any https link to a schedule .csv file)`n" +
        "- Google Calendar: Settings > your calendar > 'Secret address in iCal format'`n" +
        "- Outlook: Settings > Calendar > Shared calendars > Publish > ICS link`n" +
        "- Apple iCloud public calendars, Teamup and other .ics links") 16 96 528 92
    $nameLbl = New-Label 'Name (optional)' 16 196 120
    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.SetBounds(140, 196, 404, 28)
    $privacy = New-Note 'Only downloads: nothing about you is sent. Your groups, mutes and other settings stay on this PC.' 16 236 528 36
    $ok = New-Btn 'Follow' 340 282 96 34; $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Btn 'Cancel' 448 282 96 34; $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel
    $d.Controls.AddRange(@($intro, $urlBox, $examples, $nameLbl, $nameBox, $privacy, $ok, $cancel))
    $res = Show-Dialog $d $owner
    $raw = $urlBox.Text; $nameHint = ($nameBox.Text -replace '[\r\n=:]', ' ').Trim()
    $d.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK -or -not $raw.Trim()) { return }

    $url = ConvertTo-LinkUrl $raw
    if (-not $url) { Show-Msg $owner "That doesn't look like a web link. It should start with https:// (or webcal:// for calendars)." 'Follow a link' | Out-Null; return }
    foreach ($k in @($script:settings.Links.Keys)) {
        if ($script:settings.Links[$k].Url -eq $url) { Show-Msg $owner "You already follow this link ('$($script:settings.Links[$k].Name)')." 'Follow a link' | Out-Null; return }
    }
    $old = [System.Windows.Forms.Cursor]::Current
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
    $result = & $LinkFetch $url
    [System.Windows.Forms.Cursor]::Current = $old
    if (-not $result.Ok) { Show-Msg $owner "Couldn't open the link:`n$($result.Error)`n`nCheck that it's public (or a secret/share link) and try again." 'Follow a link' 'OK' 'Warning' | Out-Null; return }
    $content = Read-LinkContent $result.Text $nameHint
    if (-not $content.Ok) { Show-Msg $owner $content.Error 'Follow a link' 'OK' 'Warning' | Out-Null; return }

    $fileName = Get-FreeFileName $content.Name
    [void](Save-LinkContent $fileName $content -First)
    Clear-ScheduleSettings $fileName
    $script:settings.Links[$fileName] = @{ Kind = 'url'; Url = $url; Name = $content.Name; Calendar = [bool]$content.Calendar; Checked = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Error = '' }
    $groupNote = Request-MyGroups $fileName $content.Name $content.Groups $owner
    Save-Settings
    $script:selSource = $fileName
    Sync-Schedule -Force
    $what = if ($content.Calendar) { "$($content.Count) event(s) in the next 4 months" + $(if ($content.AllDay -gt 0) { " (all-day events are left out)" } else { '' }) } else { "$($content.Count) reminder(s)" }
    Show-Msg $owner "Now following '$($content.Name)': $what.$groupNote`n`nIt's checked every $LinkMinutes minutes (or click Check now under Options). When it changes, you'll see what's new for you." 'Follow a link' | Out-Null
}

# Import > Linked file in a synced folder
function Add-FileLink($owner) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Pick the schedule in your synced folder (OneDrive, Google Drive, Dropbox, ...)'
    $dlg.Filter = 'Schedules and calendars (*.csv;*.ics)|*.csv;*.ics|All files (*.*)|*.*'
    $res = if ($owner) { $dlg.ShowDialog($owner) } else { $dlg.ShowDialog() }
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = $dlg.FileName
    foreach ($k in @($script:settings.Links.Keys)) {
        if ($script:settings.Links[$k].Url -eq $path) { Show-Msg $owner "You already follow this file ('$($script:settings.Links[$k].Name)')." 'Linked file' | Out-Null; return }
    }
    $content = Read-LinkContent ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)) ''
    if (-not $content.Ok) { Show-Msg $owner $content.Error 'Linked file' 'OK' 'Warning' | Out-Null; return }
    $fileName = Get-FreeFileName $content.Name
    [void](Save-LinkContent $fileName $content -First)
    Clear-ScheduleSettings $fileName
    $script:settings.Links[$fileName] = @{ Kind = 'file'; Url = $path; Name = $content.Name; Calendar = [bool]$content.Calendar; Stamp = [string](Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks; Checked = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Error = '' }
    $groupNote = Request-MyGroups $fileName $content.Name $content.Groups $owner
    Save-Settings
    $script:selSource = $fileName
    Sync-Schedule -Force
    Show-Msg $owner "Now following '$($content.Name)' from:`n$path$groupNote`n`nWhen the file changes (e.g. the organiser updates it in the shared folder), you get the new version within seconds." 'Linked file' | Out-Null
}

# Stop following: keep the last version as a normal imported copy
function Stop-Following([string]$fileName) {
    if ($script:settings.Links.ContainsKey($fileName)) { $script:settings.Links.Remove($fileName) }
    Save-Settings
    Sync-Schedule -Force
}

# The Import button: three ways
function Show-ImportMenu($anchor) {
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.Font = $UiFont
    $a = $m.Items.Add('From a file (a copy)'); $a.Add_Click({ Import-SharedSchedule $script:sw })
    $b = $m.Items.Add('From a link (stays up to date)'); $b.Add_Click({ Add-LinkSubscription $script:sw })
    $c = $m.Items.Add('Linked file in a synced folder (stays up to date)'); $c.Add_Click({ Add-FileLink $script:sw })
    $b.Font = $BoldFont
    $b.ToolTipText = 'A GitHub Gist, Google Calendar, Outlook or any .ics / .csv link'
    $c.ToolTipText = 'OneDrive, Google Drive, Dropbox or a network folder'
    Set-MenuTheme $m
    $m.Show($anchor, (New-Object System.Drawing.Point(0, $anchor.Height)))
}

# --- Export: a copy, a copy kept up to date in a folder, or text for a link -------
function Copy-ForLink($s) {
    $text = [IO.File]::ReadAllText($s.File, [Text.Encoding]::UTF8)
    try { [System.Windows.Forms.Clipboard]::SetText($text) } catch { Show-Msg $script:sw "Couldn't copy: $($_.Exception.Message)" 'Export' | Out-Null; return }
    $ans = Show-Msg $script:sw ("'$($s.Name)' is copied.`n`nTo share it as a link with a free GitHub Gist:`n" +
        "1. Click OK: gist.github.com opens.`n" +
        "2. File name: $((Get-SafeName $s.Name)).csv - paste into the big box.`n" +
        "3. Click 'Create secret gist' and copy the page's link.`n" +
        "4. Post that link: members choose Import > From a link.`n`n" +
        "After a change: Export > Copy for a link again, then Edit the gist, paste, Update.") 'Copy for a link' 'OKCancel' 'Information'
    if ($ans -eq [System.Windows.Forms.DialogResult]::OK) { Open-Url 'https://gist.github.com/' }
}

function Set-PublishFolder($s) {
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Pick a synced folder (OneDrive, Google Drive, Dropbox, ...). A copy of '$($s.Name)' is kept up to date there after every change."
    if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $path = Join-Path $fb.SelectedPath ((Get-SafeName $s.Name) + '.csv')
    $script:settings.Publish[$s.FileName] = $path
    Save-Settings
    Publish-Copies $s.FileName
    Show-Msg $script:sw "From now on, every change to '$($s.Name)' is copied to:`n$path`n`nShare that folder (or the file) with your members and tell them: Import > Linked file in a synced folder. They get your changes within seconds." 'Keep a copy updated' | Out-Null
}

# Copies a schedule you made to the folder you picked (after each change)
function Publish-Copies([string]$fileName = '') {
    foreach ($k in @($script:settings.Publish.Keys)) {
        if ($fileName -and $k -ne $fileName) { continue }
        $src = Join-Path $SharedDir $k
        if (-not (Test-Path -LiteralPath $src)) { continue }
        try { Copy-Item -LiteralPath $src -Destination $script:settings.Publish[$k] -Force } catch {
            $tray.ShowBalloonTip(6000, "Couldn't update the copy of '$k'", $_.Exception.Message, 'Warning')
        }
    }
}

function Add-ExportItems($menuItems, $s) {
    $x = New-Object System.Windows.Forms.ToolStripMenuItem 'Save a copy as a file'
    $x.Tag = $s.FileName
    $x.Add_Click({ $t = Get-SourceByName ([string]$this.Tag); if ($t) { Share-Schedule $t $script:sw } })
    [void]$menuItems.Add($x)
    if ($s.Owned) {
        if ($script:settings.Publish.ContainsKey($s.FileName)) {
            $y = New-Object System.Windows.Forms.ToolStripMenuItem 'Stop keeping a copy updated'
            $y.ToolTipText = "Now kept up to date in: $($script:settings.Publish[$s.FileName])"
            $y.Tag = $s.FileName
            $y.Add_Click({ $script:settings.Publish.Remove([string]$this.Tag); Save-Settings })
        } else {
            $y = New-Object System.Windows.Forms.ToolStripMenuItem 'Keep a copy updated in a folder'
            $y.ToolTipText = 'For a synced folder (OneDrive, Google Drive, Dropbox): members follow it and get your changes within seconds'
            $y.Tag = $s.FileName
            $y.Add_Click({ $t = Get-SourceByName ([string]$this.Tag); if ($t) { Set-PublishFolder $t } })
        }
        [void]$menuItems.Add($y)
        $z = New-Object System.Windows.Forms.ToolStripMenuItem 'Copy for a link (GitHub Gist)'
        $z.Tag = $s.FileName
        $z.Add_Click({ $t = Get-SourceByName ([string]$this.Tag); if ($t) { Copy-ForLink $t } })
        [void]$menuItems.Add($z)
    }
}

# Export = share a schedule: pick it (when needed), then how
function Export-SharedSchedule($anchor) {
    $shared = @($script:loaded.All | Where-Object { -not $_.IsMine })
    if ($shared.Count -eq 0) {
        Show-Msg $script:sw "There is no shared schedule to export yet.`n`nClick '+ New shared schedule' to make one for your guild or team, add events, then Export it." 'Export' | Out-Null
        return
    }
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.Font = $UiFont
    $sel = Get-SideSource
    if (-not $sel.IsMine) { Add-ExportItems $m.Items $sel }
    elseif ($shared.Count -eq 1) { Add-ExportItems $m.Items $shared[0] }
    else {
        foreach ($s in $shared) {
            $mi = New-Object System.Windows.Forms.ToolStripMenuItem("$Dot  $($s.Name)")
            $mi.ForeColor = To-TextColor (To-Color $s.Color)
            Add-ExportItems $mi.DropDownItems $s
            [void]$m.Items.Add($mi)
        }
    }
    Set-MenuTheme $m
    $m.Show($anchor, (New-Object System.Drawing.Point(0, $anchor.Height)))
}

# --- New version available? (once a day; only asks GitHub for the latest version number) ---
$script:newVersion = $null
function Start-UpdateCheck([switch]$Force) {
    if (-not $script:settings.CheckUpdates -and -not $Force) { return }
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if (-not $Force -and $script:settings.UpdateChecked -eq $today) { return }
    if ($script:linkJobs.ContainsKey('__update__')) { return }
    $ps = [powershell]::Create()
    [void]$ps.AddScript($LinkFetch.ToString()).AddArgument("https://api.github.com/repos/7ab9ne3021sn4b/DeskReminders/releases/latest")
    $script:linkJobs['__update__'] = @{ PS = $ps; Handle = $ps.BeginInvoke(); Started = Get-Date }
}

function Complete-UpdateCheck($res) {
    if (-not $res -or -not $res.Ok) { return }      # offline or GitHub busy: try again tomorrow
    $script:settings.UpdateChecked = (Get-Date).ToString('yyyy-MM-dd')
    try { $tag = [string]($res.Text | ConvertFrom-Json).tag_name } catch { $tag = '' }
    $v = $tag.TrimStart('v', 'V')
    $latest = $null; $mine = $null
    if ([version]::TryParse($v, [ref]$latest) -and [version]::TryParse($AppVersion, [ref]$mine) -and $latest -gt $mine) {
        $script:newVersion = $v
        if ($script:settings.LatestSeen -ne $v) {
            $script:settings.LatestSeen = $v
            $tray.ShowBalloonTip(10000, "Desk Reminders $v is available", 'Open Desk Reminders and click the green link at the bottom, or see GitHub > What''s new.', 'Info')
        }
        Update-UpdateNotice
    }
    Save-Settings
}

function Update-UpdateNotice {
    if (-not $script:sw -or $script:sw.IsDisposed -or -not $script:swc.UpdateLink) { return }
    $l = $script:swc.UpdateLink
    if ($script:newVersion) {
        $l.Text = "New version $($script:newVersion) available - download"
        $l.Visible = $true
    } else { $l.Visible = $false }
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
    $h += 50                                   # sound
    $link = Get-LinkEntry $fileName
    if ($link) { $h += 104 }
    $pub = if ($script:settings.Publish.ContainsKey($fileName)) { $script:settings.Publish[$fileName] } else { $null }
    if ($pub) { $h += 64 }
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

    # Its own sound (or the one from Settings)
    $ctl += New-Label 'Sound' 16 $y
    $sndBox = New-Object System.Windows.Forms.ComboBox
    $sndBox.DropDownStyle = 'DropDownList'
    $sndBox.SetBounds(140, $y, 270, 28)
    $script:optSounds = @('') + @($SoundChoices)
    [void]$sndBox.Items.Add("Same as Settings ($(Get-SoundLabel $script:settings.Sound))")
    foreach ($x in $SoundChoices) { [void]$sndBox.Items.Add((Get-SoundLabel $x)) }
    $cur = if ($script:settings.Sounds.ContainsKey($fileName)) { [string]$script:settings.Sounds[$fileName] } else { '' }
    $sndBox.SelectedIndex = [math]::Max(0, [array]::IndexOf([string[]]$script:optSounds, $cur))
    $sndPlay = New-Btn 'Play' 418 ($y - 1) 86 30
    $sndPlay.Tag = $sndBox
    $sndPlay.Add_Click({ $i = $this.Tag.SelectedIndex; $snd = if ($i -gt 0) { $script:optSounds[$i] } else { $script:settings.Sound }; Play-Chime -Preview -Sound $snd })
    $sndBox.Add_SelectedIndexChanged({ $i = $this.SelectedIndex; $snd = if ($i -gt 0) { $script:optSounds[$i] } else { $script:settings.Sound }; Play-Chime -Preview -Sound $snd })
    $ctl += @($sndBox, $sndPlay)
    $y += 50

    # Followed link or synced file
    if ($link) {
        $ctl += New-Label $(if ($link.Kind -eq 'file') { 'Synced file' } else { 'Link' }) 16 $y
        $lnk = New-Object System.Windows.Forms.TextBox
        $lnk.ReadOnly = $true
        $lnk.Text = [string]$link.Url
        $lnk.SetBounds(140, $y, 364, 28)
        $ctl += $lnk
        $state = if ($link.Error) { "Problem: $($link.Error)" } else { "Last checked: $($link.Checked). " + $(if ($link.Kind -eq 'file') { 'Changes come in within seconds.' } else { "Checked every $LinkMinutes minutes." }) }
        $ctl += New-Note $state 140 ($y + 30) 364 36
        $chk = New-Btn 'Check now' 140 ($y + 66) 120 30
        $chk.Tag = $fileName
        $chk.Add_Click({
            $fn = [string]$this.Tag
            $e = Get-LinkEntry $fn
            if (-not $e) { return }
            if ($e.Kind -eq 'file') { $e.Stamp = ''; Update-FileLinks } else {
                $cur = [System.Windows.Forms.Cursor]::Current
                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
                Complete-LinkCheck $fn (& $LinkFetch ([string]$e.Url))
                [System.Windows.Forms.Cursor]::Current = $cur
            }
            $this.Text = 'Checked'
            $this.Enabled = $false
        })
        $stop = New-Btn 'Stop following' 268 ($y + 66) 140 30
        $stop.Tag = $fileName
        $stop.Add_Click({
            $ans = Show-Msg $this.FindForm() 'Stop following this link? You keep the last version as a normal copy (it no longer updates).' 'Stop following' 'YesNo' 'Question'
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            Stop-Following ([string]$this.Tag)
            $this.Text = 'Stopped'; $this.Enabled = $false
        })
        $ctl += @($chk, $stop)
        $y += 104
    }

    # A copy kept up to date in a folder (for schedules you made)
    if ($pub) {
        $ctl += New-Label 'Kept up to date' 16 $y 120
        $ctl += New-Note "A copy is updated after every change in:`n$pub" 140 $y 364 40
        $unpub = New-Btn 'Stop' 418 ($y + 2) 86 30
        $unpub.Tag = $fileName
        $unpub.Add_Click({ $script:settings.Publish.Remove([string]$this.Tag); Save-Settings; $this.Text = 'Stopped'; $this.Enabled = $false })
        $ctl += $unpub
        $y += 64
    }

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
    $newSound = $script:optSounds[[math]::Max(0, $sndBox.SelectedIndex)]
    $newName = if ($nameBox) { ($nameBox.Text -replace '[\r\n]', ' ').Trim() } else { $null }
    $newMine = $null; $newGroups = $null
    if ($groupList) { $newMine = @($groupList.CheckedItems | ForEach-Object { [string]$_ }) }
    if ($groupEdit) { $newGroups = Get-CleanGroups $groupEdit.Text }
    $d.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $script:settings.Colors[$fileName] = $newColor
    $script:settings.QuietAllow[$fileName] = [bool]$newQuiet
    if ($newSound) { $script:settings.Sounds[$fileName] = $newSound } elseif ($script:settings.Sounds.ContainsKey($fileName)) { $script:settings.Sounds.Remove($fileName) }
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


# Runs a scriptblock right after the current click has finished
# (for actions that rebuild the control that was clicked)
function Invoke-Later([scriptblock]$action) {
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 1
    $t.Tag = $action
    $t.Add_Tick({ $this.Stop(); $a = $this.Tag; $this.Dispose(); & $a })
    $t.Start()
}

# A schedule in the side panel: switch (shared ones), colour, name and details; the ... button opens a menu
function New-ScheduleCard($s, [bool]$selected) {
    $mid = [string][char]0x00B7
    $r = New-Object DrSchedRow
    $r.Size = New-Object System.Drawing.Size(268, 52)
    $r.Margin = New-Object System.Windows.Forms.Padding(4, 0, 0, 4)
    $r.Font = $MFont
    $r.Accent = $UiAccent
    $r.Dot = To-Color $s.Color
    $r.IsOn = ($s.IsMine -or [bool]$s.Enabled)
    $r.ShowToggle = -not $s.IsMine
    $r.Selected = $selected
    $r.Title = if ($s.IsMine) { Get-MineName } else { $s.Name }
    $count = @($s.Rows | Where-Object { $_.Colour -ne 'skip' }).Count
    $parts = @()
    if ($s.IsMine) { $parts = @('Your reminders', "$count row(s)") }
    else {
        if (-not $s.Enabled) { $parts += 'Off' }
        $le = Get-LinkEntry $s.FileName
        if ($le -and $le.Error) { $parts += 'link problem' }
        $parts += $(if ($le) { Get-LinkLabel $le } elseif ($s.Owned) { 'Made by you' } else { 'Shared' })
        $parts += "$count event(s)"
        if (@($s.Groups).Count -gt 0) { $parts += $(if (@($s.MyGroups).Count -gt 0) { @($s.MyGroups) -join ', ' } else { 'no group picked' }) }
    }
    $r.Sub = $parts -join "  $mid  "
    $r.Tag = $s.FileName
    $script:sideTip.SetToolTip($r, $(if ($s.IsMine) { $r.Sub } else { $r.Sub + "`nThe switch turns it on or off. Double-click for options." }))
    $r.Add_RowAction({ Invoke-RowAction $this })
    return $r
}

# Rows fill the panel, leaving room for the scroll bar when there is one
function Set-RowWidths {
    $c = $script:swc
    if (-not $c.Cards) { return }
    $rows = @($c.Cards.Controls | Where-Object { $_ -is [DrSchedRow] })
    $need = ($rows.Count * 56) -gt $c.Cards.ClientSize.Height
    $w = $c.Cards.Width - 8 - $(if ($need) { [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { 0 })
    foreach ($r in $rows) { if ($r.Width -ne $w) { $r.Width = $w } }
}

function Refresh-Sidebar {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    if (-not (@($script:loaded.All | ForEach-Object { $_.FileName }) -contains $script:selSource)) { $script:selSource = 'schedule.csv' }
    $sig = "name=$(Get-MineName);" + ($script:loaded.All | ForEach-Object { "$($_.FileName)=$($_.Name)=$($_.Color)=$($_.Enabled)=$(@($_.Rows).Count)=$(@($_.MyGroups) -join ',')=$($_.Owned)=$((Get-LinkEntry $_.FileName).Error)" }) -join ';'
    if ($c.SideSig -ne $sig) {
        $c.SideSig = $sig
        $c.Cards.SuspendLayout()
        foreach ($old in @($c.Cards.Controls)) { $old.Dispose() }
        $c.Cards.Controls.Clear()
        foreach ($s in $script:loaded.All) { $c.Cards.Controls.Add((New-ScheduleCard $s ($s.FileName -eq $script:selSource))) }
        if (@($script:loaded.All).Count -le 1) {
            $hint = New-Object System.Windows.Forms.Label
            $hint.Text = "No shared schedules yet.`n`nImport one your guild or team shared with you, or make your own with New shared schedule."
            $hint.ForeColor = New-Rgb 107 115 128
            $hint.Font = $MSmall
            $hint.Size = New-Object System.Drawing.Size(250, 80)
            $hint.Margin = New-Object System.Windows.Forms.Padding(10, 8, 4, 0)
            $c.Cards.Controls.Add($hint)
        }
        $c.Cards.ResumeLayout()
        Set-RowWidths
    }
    # Highlight the selected schedule (the rows stay, so clicks on them are safe)
    foreach ($r in @($c.Cards.Controls)) {
        if (-not ($r -is [DrSchedRow])) { continue }
        $sel = ([string]$r.Tag -eq $script:selSource)
        if ($r.Selected -ne $sel) { $r.Selected = $sel; $r.Invalidate() }
    }
}

# --- Templates: ready-made sets of reminders you can adjust ---------------------------
function Show-PacksDialog($owner, [switch]$Welcome) {
    $d = New-Dialog $(if ($Welcome) { 'Welcome to Desk Reminders' } else { 'Templates' }) 700 560
    $intro = New-Note '' 16 12 668 44
    $intro.ForeColor = [System.Drawing.SystemColors]::ControlText
    $intro.Text = if ($Welcome) { "Pick a few ready-made reminders to start with and adjust them to how you like it. You can change or remove each one later on the timeline. More any time under Templates (top right)." }
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
    $d = New-Dialog 'Settings - Desk Reminders' 1108 420
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
    $qNote = New-Note 'Each schedule can still be let through: the ... button on it in the Schedules list > Options. Missed pop-ups are not shown later.' 14 60 510 36
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
    $gWin = New-Object System.Windows.Forms.GroupBox; $gWin.Text = 'Windows'; $gWin.SetBounds(560, 8, 536, 170)
    $startup = New-Object System.Windows.Forms.CheckBox; $startup.Text = 'Start Desk Reminders when I log in to Windows'
    $startup.Checked = [bool](Test-StartupLink); $startup.SetBounds(14, 24, 500, 26)
    $splashOn = New-Object System.Windows.Forms.CheckBox; $splashOn.Text = 'Also open the window when it starts with Windows (else just the tray)'
    $splashOn.Checked = [bool]$st.OpenAtLogin; $splashOn.SetBounds(14, 52, 510, 26)
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

    # Look and updates
    $gLook = New-Object System.Windows.Forms.GroupBox; $gLook.Text = 'Updates'; $gLook.SetBounds(560, 186, 536, 120)
    $updOn = New-Object System.Windows.Forms.CheckBox; $updOn.Text = 'Tell me when a new version is out (checks once a day)'
    $updOn.Checked = [bool]$st.CheckUpdates; $updOn.SetBounds(14, 26, 510, 26)
    $updNow = New-Object System.Windows.Forms.Button; $updNow.Text = 'Check now'; $updNow.SetBounds(14, 62, 120, 30)
    $updNow.Add_Click({ Start-UpdateCheck -Force; $this.Text = 'Checking'; $this.Enabled = $false })
    $updNote = New-Note 'Only asks GitHub for the latest version number. Nothing about you is sent.' 142 62 380 40
    $gLook.Controls.AddRange(@($updOn, $updNow, $updNote))

    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Save'; $ok.SetBounds(896, 372, 96, 34)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = 'Cancel'; $cancel.SetBounds(1000, 372, 96, 34)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $ok; $d.CancelButton = $cancel
    $d.Controls.AddRange(@($gSound, $gQuiet, $gPop, $gWin, $gLook, $ok, $cancel))
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
        $st.OpenAtLogin = [bool]$splashOn.Checked
        $st.CheckUpdates = [bool]$updOn.Checked
        Save-Settings
        if ($st.CheckUpdates) { Start-UpdateCheck }
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
# Left: month calendar and your schedules. Right: the chosen day as a timeline.
function Set-WeekValues([datetime]$anyDay, [datetime]$select) {
    $dow = [int]$anyDay.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
    $script:weekStart = $anyDay.Date.AddDays(1 - $dow)
    $script:selDay = $select.Date
}

function Set-Week([datetime]$anyDay, [datetime]$select) {
    Set-WeekValues $select $select
    Refresh-ScheduleWindow
}

function Move-Day([int]$days) { $d = $script:selDay.AddDays($days); Set-Week $d $d }

function Update-Banner {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    $mid = [string][char]0x00B7
    $right = ''
    if ((Get-Date) -lt $script:pauseUntil) {
        $col = New-Rgb 107 115 128
        $label = 'PAUSED'
        $title = 'No pop-ups until ' + $script:pauseUntil.ToString('HH:mm')
        $right = 'Right-click the bell in the tray > Resume'
        $icon = 'bell-off'
    } else {
        $n = Get-Next
        $icon = 'bell'
        if ($n) {
            $icon = Get-ReminderIcon $n
            $col = To-Color $n.Colour
            $label = "NEXT UP  $mid  " + (Format-Until $n.At).ToUpper()
            $what = if ($n.Kind -eq 'notice') { "Heads-up: $($n.Title) at $($n.EventTime)" } else { $n.Title }
            $day = if ($n.At.Date -ne (Get-Date).Date) { 'Tomorrow ' } else { '' }
            $title = "$day$($n.Time)   $what"
            $right = if ($n.IsMine) { Get-MineName } else { $n.Source + $(if (@($n.For).Count -gt 0) { "  $mid  " + (@($n.For) -join ', ') } else { '' }) }
        } else {
            $col = $UiAccent
            $label = 'NEXT UP'
            $title = 'Nothing coming up in the next 24 hours'
        }
    }
    $sig = "$label|$title|$right|$icon|$($col.ToArgb())"
    if ($c.BannerSig -eq $sig) { return }
    $c.BannerSig = $sig
    $c.Banner.Color1 = $col
    $c.Banner.IconName = $icon
    $c.Banner.Label = $label
    $c.Banner.Title = $title
    $c.Banner.RightText = $right
    $c.Banner.Invalidate()
}

# A small icon for a reminder, picked from its words (falls back to a bell)
function Get-ReminderIcon($e) {
    $t = (" $($e.Title) $($e.Text) ").ToLower()
    $map = @(
        @('drop',   @('water', 'drink', 'hydrat', 'glass', 'bottle')),
        @('eye',    @('eye', 'screen', '20-20', '20 m', 'look away')),
        @('food',   @('breakfast', 'lunch', 'dinner', 'meal', 'eat', 'food', 'cook', 'snack', 'supper')),
        @('swords', @('raid', 'dungeon', 'boss', 'pvp', 'arena', 'guild', 'flask', 'mythic', 'battleground', 'quest')),
        @('moon',   @('bed', 'sleep', 'night', 'wind down', 'screens off')),
        @('move',   @('move', 'stretch', 'walk', 'stand', 'exercise', 'gym', 'posture', 'workout', 'run ')),
        @('pill',   @('pill', 'medic', 'vitamin', 'tablet')),
        @('cup',    @('coffee', 'tea ', 'break')),
        @('calendar', @('meeting', 'call', 'appointment', 'standup', 'stand-up'))
    )
    foreach ($m in $map) { foreach ($w in $m[1]) { if ($t.Contains($w)) { return $m[0] } } }
    return 'bell'
}

function Get-RelativeDay([datetime]$day) {
    $diff = [int]($day - (Get-Date).Date).TotalDays
    switch ($diff) {
        0 { return 'Today' }
        1 { return 'Tomorrow' }
        -1 { return 'Yesterday' }
    }
    if ($diff -gt 0) { return "In $diff days" }
    return "$(-$diff) days ago"
}

function Refresh-ScheduleWindow([switch]$Tick) {
    if (-not $script:sw -or $script:sw.IsDisposed) { return }
    $c = $script:swc
    $now = Get-Date
    $today = $now.Date
    $day = $script:selDay
    $isToday = ($day -eq $today)
    $mid = [string][char]0x00B7

    Refresh-Sidebar
    $c.Month.Today = $today
    $c.Month.Selected = $day
    if ($c.MonthDay -ne $day) { $c.MonthDay = $day; $c.Month.ShowMonth($day) }
    $c.Month.Invalidate()

    $script:refreshError = $null
    try {
        $entries = @(Add-Alerts @(Get-Occurrences $script:loaded.All $day $day $script:settings.Hidden) | Where-Object { $_.Kind -eq 'event' -and $_.At.Date -eq $day })
    } catch {
        $entries = @()
        $script:refreshError = $_.Exception.Message
    }
    $doneCount = 0
    if ($isToday) {
        $doneCount = @($entries | Where-Object { $_.At.AddMinutes(1) -le $now }).Count
        if ($script:settings.HidePast) { $entries = @($entries | Where-Object { $_.At.AddMinutes(1) -gt $now }) }
    }
    $c.Heading.Text = $day.ToString('dddd d MMMM yyyy', $En)
    $sub = Get-RelativeDay $day
    $total = $entries.Count + $(if ($isToday -and $script:settings.HidePast) { $doneCount } else { 0 })
    if ($isToday -and $total -gt 0) { $sub += "  $mid  $doneCount of $total done" }
    elseif ($entries.Count -gt 0) { $sub += "  $mid  $($entries.Count) reminder$(if ($entries.Count -ne 1) { 's' })" }
    $c.SubHeading.Text = $sub
    # How much of today is done: a slim bar right after the text
    $c.Progress.Visible = ($isToday -and $total -gt 0)
    if ($c.Progress.Visible) {
        $c.Progress.Value = $doneCount / $total
        $tw = [System.Windows.Forms.TextRenderer]::MeasureText($sub, $c.SubHeading.Font).Width
        $c.Progress.Left = $c.SubHeading.Left + $tw + 10
        $c.Progress.Invalidate()
    }
    $c.HidePast.Visible = $isToday
    $script:hidePastLoading = $true
    $c.HidePast.Checked = [bool]$script:settings.HidePast
    $script:hidePastLoading = $false
    $script:listMinute = $now.ToString('yyyy-MM-dd HH:mm')

    # The timeline (keeps what you selected when it refreshes by itself)
    $tl = $c.Timeline
    $keep = if ($tl.Selected) { $tl.Selected.Key } else { '' }
    $tl.Selected = $null
    $tl.Items.Clear()
    foreach ($e in $entries) {
        $it = New-Object DrItem
        $it.Minute = $e.At.Hour * 60 + $e.At.Minute
        $it.Time = $e.Time
        $it.Title = $e.Title
        $parts = @($(if ($e.IsMine) { Get-MineName } elseif ($e.Owned) { "$($e.Source) (yours)" } else { $e.Source }))
        if ($e.Text) { $parts += $e.Text }
        if ($e.Notice -gt 0) { $parts += "heads-up $($e.Notice) min before" }
        if (-not $e.IsMine -and $e.TzText) { $parts += $e.TzText }
        $it.Line2 = $parts -join "  $mid  "
        $it.Chip = if (@($e.For).Count -eq 0) { '' }
                   else { (@($e.For) -join ', ') + $(if ($e.ForMe) { '' } elseif ($e.AlertState -eq 'shout') { ' (you too)' } else { ' (not you)' }) }
        $it.Color1 = To-Color $e.Colour
        $it.Alert = $e.AlertState
        $it.IconName = Get-ReminderIcon $e
        $it.Done = $isToday -and ($e.At.AddMinutes(1) -le $now)
        $it.Tag = $e
        $it.Key = "$($e.File)|$($e.Line)|$($e.At)"
        [void]$tl.Items.Add($it)
        if ($keep -and $it.Key -eq $keep) { $tl.Selected = $it }
    }
    $tl.NowMinute = if ($isToday) { $now.Hour * 60 + $now.Minute } else { -1 }
    $nothingYet = (@($script:loaded.Mine.Rows).Count -eq 0 -and @($script:loaded.All).Count -le 1)
    $c.StartTpl.Visible = $nothingYet; $c.StartNew.Visible = $nothingYet
    $tl.Blank = $nothingYet
    $tl.EmptyText = if ($nothingYet) { 'No reminders yet. Start with a few ready-made ones (water, breaks, meals, bedtime), or add your own.' }
                    elseif ($isToday -and $doneCount -gt 0) { "Nothing left for today. Turn off ""Hide what's done"" to see the $doneCount earlier one(s)." }
                    else { 'No reminders on this day. Double-click a time to add one.' }
    $tl.Relayout()
    if ($nothingYet) { $tl.AutoScrollPosition = New-Object System.Drawing.Point(0, 0) }
    elseif ($script:tlScrolledDay -ne $day) {
        # A new day: scroll to now (today), or to the first reminder, or to the morning
        $script:tlScrolledDay = $day
        $first = if ($isToday) { $now.Hour * 60 + $now.Minute - 60 }
                 elseif ($entries.Count -gt 0) { ($entries[0].At.Hour * 60 + $entries[0].At.Minute) - 30 }
                 else { 8 * 60 }
        $tl.ScrollToMinute([math]::Max(0, $first))
    }

    if ($script:refreshError) {
        $c.Status.ForeColor = $script:P.Error
        $c.Status.Text = 'Could not show this day: ' + $script:refreshError
    } elseif ($script:errors.Count -gt 0) {
        $c.Status.ForeColor = $script:P.Error
        $c.Status.Text = "$($script:errors.Count) row(s) have a problem and are ignored. First: " + $script:errors[0]
    } else {
        $c.Status.ForeColor = $script:P.Dim
        $c.Status.Text = if ($script:settings.Quiet.On) { "Quiet hours $($script:settings.Quiet.From)-$($script:settings.Quiet.To)" } else { '' }
    }
    $canUndo = [bool]$script:undo
    $c.Undo.Enabled = $canUndo
    $c.UndoTip.SetToolTip($c.Undo, $(if ($canUndo) { "Undo $($script:undo.What) (Ctrl+Z)" } else { 'Nothing to undo' }))
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

# A rounded button for the main window: primary (blue), outline, ghost or soft
function New-DrBtn([string]$text, [string]$kind, [string]$icon, [int]$x, [int]$y, [int]$w, [int]$h = 34) {
    $b = New-Object DrButton
    $b.Text = $text
    $b.Kind = $kind
    $b.IconName = $icon
    $b.Accent = $UiAccent
    $b.Font = if ($kind -eq 'primary') { $MBold } else { $MFont }
    $b.SetBounds($x, $y, $w, $h)
    return $b
}

function New-UiLabel([string]$text, $font, $color, [int]$x, [int]$y, [int]$w, [int]$h) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Font = $font
    $l.ForeColor = $color
    $l.AutoSize = $false
    $l.AutoEllipsis = $true
    $l.UseMnemonic = $false
    $l.SetBounds($x, $y, $w, $h)
    return $l
}

# --- Go to a date typed by hand ---------------------------------------------------
# Understands: 24-12-2026, 24/12/2026, 24.12.2026, 2026-12-24,
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
    $c = $script:swc
    $d = ConvertFrom-TypedDate $c.Typed.Text
    if (-not $d) {
        $c.TypedCard.Border = $script:P.Error
        $c.TypedCard.Invalidate()
        $c.Status.ForeColor = $script:P.Error
        $c.Status.Text = "Can't read that date. Try 24-12-2026 or 24 dec 2026."
        return
    }
    $c.TypedCard.Border = New-Rgb 218 223 229
    $c.TypedCard.Invalidate()
    $c.Typed.Text = ''
    Set-Week $d $d
}

# --- Clicks on the timeline ----------------------------------------------------
function Show-ItemMenu {
    $e = Get-SelectedEntry
    if (-not $e) { return }
    $m = $script:swc.ItemMenu
    $m.Items[0].Text = if ($e.Editable) { 'Edit' } else { 'Edit (shared, read-only)' }
    $m.Items[0].Enabled = [bool]$e.Editable
    $m.Items[1].Text = if ($e.Editable) { 'Remove' } else { 'Hide' }
    $m.Items[3].Text = switch ($e.AlertState) { 'on' { 'Mute' } 'muted' { 'Unmute' } 'off' { 'Notify me too' } 'shout' { 'Stop notifying me' } }
    $m.Show([System.Windows.Forms.Cursor]::Position)
}

function Invoke-TimelineAction($tl) {
    switch ($tl.Action) {
        'bell' { $script:pendingAlert = $tl.ActionItem.Tag; Invoke-Later { Switch-Alert $script:pendingAlert } }
        'edit' { Invoke-Later { Edit-Selected } }
        'menu' { Show-ItemMenu }
        'emptymenu' { $script:pendingMinute = $tl.ActionMinute; $script:swc.EmptyMenu.Show([System.Windows.Forms.Cursor]::Position) }
        'add' { $script:pendingMinute = $tl.ActionMinute; Invoke-Later { Add-ReminderHere $script:pendingMinute } }
    }
}

# New reminder: in the schedule selected on the left (when you can add to it), at a time if given
function Add-ReminderHere([int]$minute = -1) {
    $t = Get-SideSource
    $file = if ($t.IsMine -or $t.Owned) { $t.File } else { '' }
    Show-ReminderDialog 'Add' -TargetFile $file -AtMinute $minute
}

# --- Schedules on the left -------------------------------------------------------
function Invoke-RowAction($r) {
    $file = [string]$r.Tag
    switch ($r.Action) {
        'toggle' {
            $r.IsOn = -not $r.IsOn
            $r.Invalidate()
            $others = @($script:settings.Disabled | Where-Object { $_ -ne $file })
            $script:settings.Disabled = if ($r.IsOn) { $others } else { $others + $file }
            Save-Settings
            Invoke-Later { Sync-Schedule -Force }
        }
        'select' { $script:selSource = $file; Refresh-Sidebar }
        'open' { $script:selSource = $file; Invoke-Later { Show-ScheduleOptions (Get-SideSource) $script:sw } }
        'menu' { $script:selSource = $file; Refresh-Sidebar; Show-ScheduleMenu $r }
    }
}

function Show-ScheduleMenu($anchor) {
    $s = Get-SideSource
    $m = $script:swc.SchedMenu
    foreach ($old in @($m.Items)) { $old.Dispose() }
    $m.Items.Clear()
    $o = New-MenuItem $m 'Options' { Invoke-Later { Show-ScheduleOptions (Get-SideSource) $script:sw } }
    $o.Font = $MBold
    $o.ToolTipText = if ($s.IsMine) { 'Name, colour, sound and quiet hours' } else { 'Colour, your groups, sound and quiet hours' }
    if ($s.IsMine -or $s.Owned) {
        [void](New-MenuItem $m 'New reminder here' { Invoke-Later { Add-ReminderHere } })
    }
    if (-not $s.IsMine) {
        $x = New-MenuItem $m 'Export' $null
        Add-ExportItems $x.DropDownItems $s
    }
    [void]$m.Items.Add('-')
    [void](New-MenuItem $m $(if ($s.IsMine) { 'Remove all reminders' } else { 'Remove from this PC' }) {
        Invoke-Later { $t = Get-SideSource; if ($t.IsMine) { Clear-MySchedule } else { Remove-SharedSchedule $t } }
    })
    $m.Show($anchor, (New-Object System.Drawing.Point(($anchor.Width - 34), ($anchor.Height - 8))))
}

function Open-ScheduleWindow {
    if ($script:sw -and -not $script:sw.IsDisposed) {
        if ($script:sw.WindowState -eq 'Minimized') { $script:sw.WindowState = 'Normal' }
        [DrUi]::ToFront($script:sw); return
    }
    $W = 1160; $H = 760
    $topH = 60; $footH = 34; $sideW = 300
    $line = New-Rgb 230 233 237
    $text = New-Rgb 27 31 36
    $dim = New-Rgb 91 100 112
    $faint = New-Rgb 138 146 158
    $sideBack = New-Rgb 247 248 250
    $white = [System.Drawing.Color]::White

    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Desk Reminders $AppVersion"
    $f.Font = $MFont
    $f.BackColor = $white
    $f.StartPosition = 'CenterScreen'
    $f.ClientSize = New-Object System.Drawing.Size($W, $H)
    $f.MinimumSize = New-Object System.Drawing.Size(980, 620)
    $f.KeyPreview = $true
    if ($script:appIcon) { $f.Icon = $script:appIcon }
    $c = @{}
    $script:sideTip = New-Object System.Windows.Forms.ToolTip
    $tip = $script:sideTip

    # --- Top bar: name on the left, actions on the right ---
    $top = New-Object System.Windows.Forms.Panel
    $top.Size = New-Object System.Drawing.Size($W, $topH)
    $top.BackColor = $white
    $topLine = New-Object System.Windows.Forms.Panel
    $topLine.Height = 1; $topLine.Dock = 'Bottom'; $topLine.BackColor = $line
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.SetBounds(20, 16, 28, 28)
    $logo.SizeMode = 'Zoom'
    try { $logo.Image = (New-Object System.Drawing.Icon($IconFile, 32, 32)).ToBitmap() } catch {}
    $name = New-UiLabel 'Desk Reminders' $MHead $text 56 0 260 $topH
    $name.TextAlign = 'MiddleLeft'
    $bx = $W - 20
    $newBtn = New-DrBtn 'New reminder' 'primary' 'plus' ($bx - 156) 13 156; $bx -= 164
    $tplBtn = New-DrBtn 'Templates' 'outline' 'templates' ($bx - 124) 13 124; $bx -= 132
    $ghBtn = New-DrBtn 'GitHub' 'ghost' 'code' ($bx - 100) 13 100; $bx -= 104
    $setBtn = New-DrBtn '' 'ghost' 'gear' ($bx - 36) 13 36; $bx -= 40
    $c.Undo = New-DrBtn '' 'ghost' 'undo' ($bx - 36) 13 36
    foreach ($b in @($newBtn, $tplBtn, $ghBtn, $setBtn, $c.Undo)) { $b.Anchor = 'Top, Right' }
    $newBtn.Add_Click({ Add-ReminderHere })
    $tip.SetToolTip($newBtn, 'Add a reminder (to the schedule selected on the left, if it is yours)')
    $tplBtn.Add_Click({ Show-PacksDialog $script:sw })
    $tip.SetToolTip($tplBtn, 'Ready-made reminders you can adjust: water, moving, eye breaks, meals, bedtime')
    $setBtn.Add_Click({ Show-SettingsDialog $script:sw })
    $tip.SetToolTip($setBtn, 'Settings')
    $c.Undo.Add_Click({ Invoke-Undo })
    $c.UndoTip = $tip
    # GitHub: everything online, in one small menu
    $gh = New-Object System.Windows.Forms.ContextMenuStrip
    $gh.Font = $MFont
    [void](New-MenuItem $gh 'Code and downloads' { Open-Url $RepoUrl })
    [void](New-MenuItem $gh 'How to use' { Open-Url "$RepoUrl#readme" })
    [void](New-MenuItem $gh 'Shared schedules and groups' { Open-Url "$RepoUrl/blob/main/docs/shared-schedules.md" })
    [void](New-MenuItem $gh 'Schedule file format' { Open-Url "$RepoUrl/blob/main/docs/schedule-format.md" })
    [void](New-MenuItem $gh 'Troubleshooting' { Open-Url "$RepoUrl/blob/main/docs/troubleshooting.md" })
    [void]$gh.Items.Add('-')
    [void](New-MenuItem $gh "What's new (releases)" { Open-Url "$RepoUrl/releases" })
    [void](New-MenuItem $gh 'Report a problem or idea' { Open-Url "$RepoUrl/issues/new/choose" })
    foreach ($mi in $gh.Items) { if ($mi -is [System.Windows.Forms.ToolStripMenuItem]) { $mi.ToolTipText = 'Opens in your browser' } }
    $c.GhMenu = $gh
    $ghBtn.Add_Click({ $script:swc.GhMenu.Show($this, (New-Object System.Drawing.Point(0, ($this.Height + 2)))) })
    $top.Controls.AddRange(@($topLine, $logo, $name, $c.Undo, $setBtn, $ghBtn, $tplBtn, $newBtn))

    # --- Left: month calendar, go to a date, schedules ---
    $sideH = $H - $topH - $footH
    $side = New-Object System.Windows.Forms.Panel
    $side.Size = New-Object System.Drawing.Size($sideW, $sideH)
    $side.BackColor = $sideBack
    $sideLine = New-Object System.Windows.Forms.Panel
    $sideLine.Width = 1; $sideLine.Dock = 'Right'; $sideLine.BackColor = $line

    $c.Month = New-Object DrMonth
    $c.Month.Font = $MFont
    $c.Month.Accent = $UiAccent
    $c.Month.SetBounds(16, 12, 268, 268)
    $c.Month.Add_DayPicked({ $d = $script:swc.Month.Picked; Set-Week $d $d })

    $c.TypedCard = New-Object DrCard
    $c.TypedCard.Radius = 8
    $c.TypedCard.Border = New-Rgb 218 223 229
    $c.TypedCard.SetBounds(16, 290, 268, 34)
    $c.TypedCard.BackColor = $white
    $cal = New-Object DrIconTile
    $cal.IconName = 'calendar'; $cal.Color1 = $dim; $cal.Tile = $false
    $cal.SetBounds(8, 5, 24, 24)
    $c.Typed = New-Object System.Windows.Forms.TextBox
    $c.Typed.BorderStyle = 'None'
    $c.Typed.BackColor = $white
    $c.Typed.Font = $MFont
    $c.Typed.SetBounds(38, 8, 222, 20)
    $c.Typed.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $_.SuppressKeyPress = $true; Invoke-TypedDate } })
    $c.Typed.Add_HandleCreated({ [DrUi]::Cue($this, 'Go to a date, e.g. 24 dec') })
    $tip.SetToolTip($c.Typed, 'Type a date and press Enter, e.g. 24 dec, 24-12-2026 or 2026-12-24')
    $c.TypedCard.Controls.AddRange(@($cal, $c.Typed))

    $schedTitle = New-UiLabel 'Schedules' $MHeadSmall $text 18 340 200 24
    $c.Cards = New-Object System.Windows.Forms.FlowLayoutPanel
    $c.Cards.SetBounds(12, 368, 280, ($sideH - 368 - 96))
    $c.Cards.Anchor = 'Top, Bottom, Left'
    $c.Cards.FlowDirection = 'TopDown'
    $c.Cards.WrapContents = $false
    $c.Cards.AutoScroll = $true
    $c.Cards.BackColor = $sideBack
    $c.Cards.Add_Resize({ Set-RowWidths })
    $imp = New-DrBtn 'Import' 'outline' 'import' 16 ($sideH - 88) 130
    $exp = New-DrBtn 'Export' 'outline' 'export' 154 ($sideH - 88) 130
    $newSh = New-DrBtn 'New shared schedule' 'ghost' 'plus' 16 ($sideH - 48) 268
    foreach ($b in @($imp, $exp, $newSh)) { $b.Anchor = 'Bottom, Left' }
    $imp.Add_Click({ Show-ImportMenu $this })
    $tip.SetToolTip($imp, 'Add a schedule someone shared: a file, a link (stays up to date) or a file in a synced folder')
    $exp.Add_Click({ Export-SharedSchedule $this })
    $tip.SetToolTip($exp, 'Share a schedule you made: as a file, kept up to date in a synced folder, or as a link')
    $newSh.Add_Click({ $n = @(New-SharedSchedule $script:sw)[-1]; if ($n) { $script:selSource = [System.IO.Path]::GetFileName($n); Refresh-ScheduleWindow } })
    $tip.SetToolTip($newSh, 'Make a schedule for your guild, team or community')
    $c.SchedMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $c.SchedMenu.Font = $MFont
    $c.SchedMenu.ShowItemToolTips = $true
    $side.Controls.AddRange(@($sideLine, $c.Month, $c.TypedCard, $schedTitle, $c.Cards, $imp, $exp, $newSh))

    # --- Right: the day ---
    $mainW = $W - $sideW
    $mainH = $sideH
    $main = New-Object System.Windows.Forms.Panel
    $main.Size = New-Object System.Drawing.Size($mainW, $mainH)
    $main.BackColor = $white
    $x0 = 28; $cw = $mainW - 56

    $c.Heading = New-UiLabel '' $MTitle $text $x0 18 ($cw - 260) 36
    $c.Heading.Anchor = 'Top, Left, Right'
    $c.SubHeading = New-UiLabel '' $MFont $dim ($x0 + 1) 54 ($cw - 260) 22
    $c.SubHeading.Anchor = 'Top, Left, Right'
    $nx = $x0 + $cw
    $fwd = New-DrBtn '' 'outline' 'right' ($nx - 36) 20 36
    $todayBtn = New-DrBtn 'Today' 'outline' '' ($nx - 36 - 6 - 76) 20 76
    $back = New-DrBtn '' 'outline' 'left' ($nx - 36 - 6 - 76 - 6 - 36) 20 36
    foreach ($b in @($back, $todayBtn, $fwd)) { $b.Anchor = 'Top, Right' }
    $back.Add_Click({ Move-Day -1 })
    $fwd.Add_Click({ Move-Day 1 })
    $todayBtn.Add_Click({ Set-Week (Get-Date) (Get-Date) })
    $tip.SetToolTip($back, 'Previous day')
    $tip.SetToolTip($fwd, 'Next day')
    $c.HidePast = New-Object DrToggle
    $c.HidePast.Text = "Hide what's done"
    $c.HidePast.Font = $MSmall
    $c.HidePast.ForeColor = $dim
    $c.HidePast.Accent = $UiAccent
    $c.HidePast.SetBounds(($nx - 166), 58, 166, 24)
    $c.HidePast.Anchor = 'Top, Right'
    $c.HidePast.Add_CheckedChanged({
        if ($script:hidePastLoading) { return }
        $script:settings.HidePast = $this.Checked
        Save-Settings
        Refresh-ScheduleWindow
    })

    # Next up
    $c.Banner = New-Object DrBanner
    $c.Banner.Font = $MFont
    $c.Banner.SetBounds($x0, 92, $cw, 72)
    $c.Banner.Anchor = 'Top, Left, Right'
    $c.Progress = New-Object DrProgress
    $c.Progress.SetBounds(($x0 + 200), 62, 140, 10)
    $c.Progress.From = $UiAccent
    $c.Progress.Visible = $false

    # The timeline, in a card with a thin border
    $tlTop = 180
    $tlH = $mainH - $tlTop - 44
    $tlCard = New-Object DrCard
    $tlCard.Radius = 14
    $tlCard.SetBounds($x0, $tlTop, $cw, $tlH)
    $tlCard.Anchor = 'Top, Bottom, Left, Right'
    $c.Timeline = New-Object DrTimeline
    $c.Timeline.Font = $MFont
    $c.Timeline.Accent = $UiAccent
    $c.Timeline.SetBounds(2, 8, ($cw - 4), ($tlH - 16))
    $c.Timeline.Anchor = 'Top, Bottom, Left, Right'
    $icons = New-Object System.Windows.Forms.ImageList
    $icons.ImageSize = New-Object System.Drawing.Size(16, 16)
    $icons.ColorDepth = 'Depth32Bit'
    foreach ($k in @('on', 'muted', 'off', 'shout')) { $icons.Images.Add($k, (New-AlertIcon $k)) }
    $c.Timeline.Add_ItemAction({ Invoke-TimelineAction $this })
    $tlCard.Controls.Add($c.Timeline)
    # When there are no reminders at all: start here (instead of a window popping up)
    $c.StartTpl = New-DrBtn 'Start from a template' 'soft' 'templates' 82 76 206 36
    $c.StartNew = New-DrBtn 'New reminder' 'outline' 'plus' 296 76 150 36
    $c.StartTpl.Add_Click({ Show-PacksDialog $script:sw })
    $c.StartNew.Add_Click({ Add-ReminderHere })
    foreach ($b in @($c.StartTpl, $c.StartNew)) { $b.Visible = $false; $c.Timeline.Controls.Add($b) }
    # Right-click menus for the timeline
    $c.ItemMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $c.ItemMenu.Font = $MFont
    [void](New-MenuItem $c.ItemMenu 'Edit' { Invoke-Later { Edit-Selected } })
    [void](New-MenuItem $c.ItemMenu 'Remove' { Invoke-Later { Remove-Selected } })
    [void]$c.ItemMenu.Items.Add('-')
    [void](New-MenuItem $c.ItemMenu 'Mute' { $script:pendingAlert = Get-SelectedEntry; Invoke-Later { if ($script:pendingAlert) { Switch-Alert $script:pendingAlert } } })
    $c.EmptyMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $c.EmptyMenu.Font = $MFont
    [void](New-MenuItem $c.EmptyMenu 'New reminder at this time' { Invoke-Later { Add-ReminderHere $script:pendingMinute } })

    # Status on the left, what the icons mean on the right
    $legY = $mainH - 34
    $c.Status = New-UiLabel '' $MSmall $dim $x0 $legY ($cw - 560) 24
    $c.Status.TextAlign = 'MiddleLeft'
    $c.Status.Anchor = 'Bottom, Left, Right'
    $legend = New-Object System.Windows.Forms.Panel
    $legend.SetBounds(($x0 + $cw - 556), $legY, 556, 24)
    $legend.Anchor = 'Bottom, Right'
    $legend.BackColor = $white
    $lx = 0
    foreach ($spec in @(@('on', 'pops up'), @('muted', 'muted'), @('shout', 'you too'))) {
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = $icons.Images[$spec[0]]
        $pic.SetBounds($lx, 4, 16, 16)
        $lbl = New-UiLabel $spec[1] $MSmall $dim ($lx + 19) 0 60 24
        $lbl.TextAlign = 'MiddleLeft'
        $legend.Controls.AddRange(@($pic, $lbl))
        $lx += 82
    }
    $hintL = New-UiLabel 'Double-click to edit, right-click for more' $MSmall $faint $lx 0 (556 - $lx) 24
    $hintL.TextAlign = 'MiddleRight'
    $legend.Controls.Add($hintL)
    $main.Controls.AddRange(@($c.Progress, $c.Heading, $c.SubHeading, $back, $todayBtn, $fwd, $c.HidePast, $c.Banner, $tlCard, $c.Status, $legend))

    # --- Footer ---
    $foot = New-Object System.Windows.Forms.Panel
    $foot.Size = New-Object System.Drawing.Size($W, $footH)
    $foot.BackColor = $sideBack
    $footLine = New-Object System.Windows.Forms.Panel
    $footLine.Height = 1; $footLine.Dock = 'Top'; $footLine.BackColor = $line
    $hello = New-UiLabel $Greeting $ItalicFont $dim 18 0 260 $footH
    $hello.TextAlign = 'MiddleLeft'
    # New version notice (only shown when there is one)
    $c.UpdateLink = New-Object System.Windows.Forms.LinkLabel
    $c.UpdateLink.Font = $MSmallBold
    $c.UpdateLink.LinkColor = New-Rgb 30 120 60
    $c.UpdateLink.ActiveLinkColor = $c.UpdateLink.LinkColor
    $c.UpdateLink.LinkBehavior = 'HoverUnderline'
    $c.UpdateLink.TextAlign = 'MiddleCenter'
    $c.UpdateLink.SetBounds(280, 0, ($W - 280 - 540), $footH)
    $c.UpdateLink.Anchor = 'Top, Left, Right'
    $c.UpdateLink.Visible = $false
    $c.UpdateLink.Add_LinkClicked({ Open-Url "$RepoUrl/releases/latest" })
    $free = New-UiLabel 'Free, open source and offline - only connects for updates and links you follow' $MSmall $faint ($W - 548) 0 530 $footH
    $free.TextAlign = 'MiddleRight'
    $free.Anchor = 'Top, Right'
    $foot.Controls.AddRange(@($footLine, $hello, $c.UpdateLink, $free))

    # Docking happens in reverse order: top bar and footer full width, then the side, then the rest
    $main.Dock = 'Fill'; $side.Dock = 'Left'; $foot.Dock = 'Bottom'; $top.Dock = 'Top'
    $f.Controls.AddRange(@($main, $side, $foot, $top))

    # Keys: Delete removes the selected reminder, Ctrl+Z undoes, Ctrl+N adds
    $f.Add_KeyDown({
        if ($this.ActiveControl -is [System.Windows.Forms.TextBox]) { return }
        if ($_.KeyCode -eq 'Delete' -and $script:swc.Timeline.Selected) { $_.Handled = $true; Remove-Selected }
        elseif ($_.Control -and $_.KeyCode -eq 'Z') { $_.Handled = $true; Invoke-Undo }
        elseif ($_.Control -and $_.KeyCode -eq 'N') { $_.Handled = $true; Add-ReminderHere }
        elseif ($_.Alt -and $_.KeyCode -eq 'Left') { $_.Handled = $true; Move-Day -1 }
        elseif ($_.Alt -and $_.KeyCode -eq 'Right') { $_.Handled = $true; Move-Day 1 }
    })
    $f.Add_FormClosed({ $script:sw = $null; $script:swc = @{}; $script:tlScrolledDay = $null })

    $script:sw = $f
    $script:swc = $c
    if (-not $script:selSource) { $script:selSource = 'schedule.csv' }
    $script:tlScrolledDay = $null
    Set-Week (Get-Date) (Get-Date)
    Update-UpdateNotice
    # Fade in (a quarter of a second) and come to the front
    $f.Opacity = 0
    $f.Show()
    [DrUi]::ToFront($f)
    $script:fadeClock = [System.Diagnostics.Stopwatch]::StartNew()
    $fade = New-Object System.Windows.Forms.Timer
    $fade.Interval = 15
    $fade.Add_Tick({
        $w = $script:sw
        $k = [math]::Min(1.0, $script:fadeClock.ElapsedMilliseconds / 250.0)
        if (-not $w -or $w.IsDisposed) { $this.Stop(); $this.Dispose(); return }
        $w.Opacity = 1 - [math]::Pow(1 - $k, 3)
        if ($k -ge 1) { $w.Opacity = 1; $this.Stop(); $this.Dispose() }
    })
    $fade.Start()
    # Scroll the timeline again now that it has its real size
    $script:tlScrolledDay = $null
    Refresh-ScheduleWindow
    $c.Timeline.Focus() | Out-Null
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
    if ($lines.Count -eq 0) { $lines = @('No reminders today. Open Desk Reminders and click New reminder.') }
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
    Receive-LinkChecks
    Update-FileLinks
    Start-LinkChecks
    Start-UpdateCheck
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
Set-MenuTheme $menu
$clock.Start()
Update-TrayText
# Followed links: check right away in the background, then every $LinkMinutes minutes
Start-LinkChecks -Force
Start-UpdateCheck

# Started it yourself: the window opens right away. Started with Windows: quietly in the tray
# (unless Settings says to open the window then too).
if (-not $Startup -or $script:settings.OpenAtLogin) {
    Open-ScheduleWindow
} else {
    $tray.ShowBalloonTip(5000, 'Desk Reminders is running', $tray.Text, 'Info')
}

# Started again while already running: the running one opens its window (see the top of the app)
$showCheck = New-Object System.Windows.Forms.Timer
$showCheck.Interval = 250
$showCheck.Add_Tick({ if ($script:showEvent.WaitOne(0)) { Open-ScheduleWindow } })
$showCheck.Start()

[System.Windows.Forms.Application]::Run()
$script:mutex.ReleaseMutex()
