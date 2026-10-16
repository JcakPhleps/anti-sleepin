' ===========================================================================
' Anti SleepIn - main scene logic
'
' Idle:    black screen (tiny looping black video keeps the channel alive)
'          with a box at the top showing the alarm time + repeat days.
' Star(*): opens the settings menu.
' Settings: alarm time, dismissal method, pattern length, per-day repeat
'          checkboxes (Sun-Sat), test alarm, skip-next (double confirm), close.
' Ringing: background pulses black/white, custom sound loops; dismissal is
'          OK or a random on-screen button pattern.
' ===========================================================================

sub init()
    ' Node references
    m.bgVideo        = m.top.findNode("bgVideo")
    m.idleBox        = m.top.findNode("idleBox")
    m.idleTimeLabel  = m.top.findNode("idleTimeLabel")
    m.pulseBg        = m.top.findNode("pulseBg")
    m.ringTitle      = m.top.findNode("ringTitle")
    m.dismissInstr   = m.top.findNode("dismissInstr")
    m.patternLabel   = m.top.findNode("patternLabel")
    m.settingsGroup  = m.top.findNode("settingsGroup")
    m.menuList       = m.top.findNode("menuList")
    m.confirmGroup   = m.top.findNode("confirmGroup")
    m.confirmMsg     = m.top.findNode("confirmMsg")
    m.confirmYes     = m.top.findNode("confirmYes")
    m.confirmNo      = m.top.findNode("confirmNo")
    m.alarmAudio     = m.top.findNode("alarmAudio")
    m.clockTimer     = m.top.findNode("clockTimer")
    m.pulseTimer     = m.top.findNode("pulseTimer")

    ' Seed RNG so patterns vary each run
    Rnd(0)

    ' ---- State ----
    m.alarmHour     = 7
    m.alarmMinute   = 0
    m.dismissMode   = "ok"      ' "ok" or "pattern"
    m.patternLength = 5         ' 3-8
    m.dayNames      = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    m.dayAbbr       = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    m.days          = [true, true, true, true, true, true, true]  ' index 0=Sun .. 6=Sat
    m.skipNext      = false

    ' Override defaults with anything saved from a previous run
    loadSettings()

    m.settingsOpen  = false
    m.menuIndex     = 0

    m.ringing       = false
    m.pulseWhite    = false
    m.firedKey      = -1

    m.pattern       = []
    m.patternIndex  = 0

    ' Confirm overlay
    m.confirmOpen   = false
    m.confirmStep   = 0         ' 1 = first prompt, 2 = second prompt
    m.confirmSel    = 1         ' 0 = YES, 1 = NO (default NO)

    ' ---- Menu definition (drives the dynamic row list) ----
    m.menuDefs = [
        { kind: "hour" },
        { kind: "minute" },
        { kind: "ampm" },
        { kind: "dismiss" },
        { kind: "length" },
        { kind: "day", day: 0 },
        { kind: "day", day: 1 },
        { kind: "day", day: 2 },
        { kind: "day", day: 3 },
        { kind: "day", day: 4 },
        { kind: "day", day: 5 },
        { kind: "day", day: 6 },
        { kind: "test" },
        { kind: "skip" },
        { kind: "close" }
    ]
    m.menuRows = []
    for i = 0 to m.menuDefs.count() - 1
        m.menuRows.push(m.top.findNode("row" + i.ToStr()))
    end for

    ' ---- Looping black background video ----
    vcontent = CreateObject("roSGNode", "ContentNode")
    vcontent.url = "pkg:/videos/black.mp4"
    vcontent.streamFormat = "mp4"
    m.bgVideo.content = vcontent
    m.bgVideo.observeField("state", "onVideoState")
    m.bgVideo.control = "play"

    ' ---- Custom alarm sound ----
    acontent = CreateObject("roSGNode", "ContentNode")
    acontent.url = "pkg:/sounds/alarm.mp3"
    acontent.streamFormat = "mp3"
    m.alarmAudio.content = acontent

    ' ---- Timers ----
    m.clockTimer.observeField("fire", "onClockTick")
    m.clockTimer.control = "start"
    m.pulseTimer.observeField("fire", "onPulse")

    updateIdleLabel()
    m.top.setFocus(true)
end sub

sub onVideoState()
    ' Loop the keep-alive video, but DON'T auto-restart while the alarm is
    ' ringing (we stop it on purpose so the Audio node can use the audio
    ' pipeline - a Video + Audio node can't both own audio at once).
    if m.ringing then return
    st = m.bgVideo.state
    if st = "finished" or st = "error"
        m.bgVideo.control = "play"
    end if
end sub

' ---------------------------------------------------------------------------
' Clock tick
' ---------------------------------------------------------------------------
sub onClockTick()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    nowKey = dt.GetHours() * 100 + dt.GetMinutes()
    alarmKey = m.alarmHour * 100 + m.alarmMinute
    dow = dt.GetDayOfWeek()   ' 0 = Sunday

    if nowKey <> alarmKey then m.firedKey = -1

    if (not m.ringing) and nowKey = alarmKey and m.firedKey <> alarmKey and m.days[dow]
        m.firedKey = alarmKey
        if m.skipNext
            ' Skip this one occurrence
            m.skipNext = false
            saveSettings()
            updateIdleLabel()
        else
            startRinging()
        end if
    end if
end sub

sub updateIdleLabel()
    txt = "Alarm " + hour12(m.alarmHour).ToStr() + ":" + twoDigit(m.alarmMinute) + " " + periodOf(m.alarmHour) + "   -   " + daysSummary()
    if m.skipNext then txt = txt + "   (skipping next)"
    m.idleTimeLabel.text = txt
end sub

function daysSummary() as string
    count = 0
    for i = 0 to 6
        if m.days[i] then count = count + 1
    end for
    if count = 0 then return "no days set"
    if count = 7 then return "every day"
    s = ""
    for i = 0 to 6
        if m.days[i]
            if s <> "" then s = s + " "
            s = s + m.dayAbbr[i]
        end if
    end for
    return s
end function

' ---------------------------------------------------------------------------
' Ringing
' ---------------------------------------------------------------------------
sub startRinging()
    m.settingsOpen = false
    m.settingsGroup.visible = false
    m.confirmOpen = false
    m.confirmGroup.visible = false

    m.ringing = true
    m.idleBox.visible = false
    m.pulseBg.visible = true

    ' Free the audio pipeline from the background video, then play the alarm
    m.bgVideo.control = "stop"
    m.alarmAudio.control = "stop"
    m.alarmAudio.loop = true
    m.alarmAudio.control = "play"

    if m.dismissMode = "pattern"
        generatePattern()
        m.patternLabel.visible = true
        updatePatternDisplay()
    else
        m.patternLabel.visible = false
        m.patternLabel.text = ""
        m.dismissInstr.text = "Press OK to dismiss"
    end if

    m.pulseWhite = false
    applyPulse()
    m.pulseTimer.control = "start"
end sub

sub stopRinging()
    m.pulseTimer.control = "stop"
    m.alarmAudio.control = "stop"
    m.ringing = false
    m.pulseBg.visible = false
    m.idleBox.visible = true
    ' Resume the keep-alive background video
    m.bgVideo.control = "play"
    updateIdleLabel()
end sub

sub onPulse()
    m.pulseWhite = not m.pulseWhite
    applyPulse()
end sub

sub applyPulse()
    if m.pulseWhite
        m.pulseBg.color  = "0xFFFFFFFF"
        m.ringTitle.color    = "0xB00020FF"
        m.dismissInstr.color = "0x222222FF"
        m.patternLabel.color = "0x000000FF"
    else
        m.pulseBg.color  = "0x000000FF"
        m.ringTitle.color    = "0xFF2A2AFF"
        m.dismissInstr.color = "0xCCCCCCFF"
        m.patternLabel.color = "0xFFCC00FF"
    end if
end sub

' ---------------------------------------------------------------------------
' Dismissal pattern
' ---------------------------------------------------------------------------
sub generatePattern()
    choices = ["up", "down", "left", "right", "OK", "rewind", "play", "fastforward"]
    m.pattern = []
    for i = 1 to m.patternLength
        m.pattern.push(choices[Rnd(choices.count()) - 1])
    end for
    m.patternIndex = 0
end sub

sub updatePatternDisplay()
    s = ""
    for i = 0 to m.pattern.count() - 1
        arrow = arrowFor(m.pattern[i])
        if i < m.patternIndex
            s = s + "[" + arrow + "] "
        else
            s = s + arrow + " "
        end if
    end for
    m.patternLabel.text = s
    m.dismissInstr.text = "Enter the pattern:  " + m.patternIndex.ToStr() + " / " + m.pattern.count().ToStr()
end sub

function arrowFor(dir as string) as string
    if dir = "up"          then return chr(9650)   ' up triangle
    if dir = "down"        then return chr(9660)   ' down triangle
    if dir = "left"        then return chr(9668)   ' left pointer (in Arial)
    if dir = "right"       then return chr(9658)   ' right pointer (in Arial)
    if dir = "OK"          then return "OK"
    if dir = "rewind"      then return "REW"
    if dir = "play"        then return "PLAY"
    if dir = "fastforward" then return "FF"
    return "?"
end function

sub handlePatternPress(key as string)
    expected = m.pattern[m.patternIndex]
    if key = expected
        m.patternIndex = m.patternIndex + 1
        if m.patternIndex >= m.pattern.count()
            stopRinging()
            return
        end if
        updatePatternDisplay()
    else
        m.patternIndex = 0
        updatePatternDisplay()
        m.dismissInstr.text = "Wrong button - start over"
    end if
end sub

' ---------------------------------------------------------------------------
' Remote input
' ---------------------------------------------------------------------------
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    ' ===== RINGING: nothing escapes except correct dismissal =====
    ' (settings can't be opened here - every key is handled/swallowed below)
    if m.ringing
        if m.dismissMode = "pattern"
            if isPatternKey(key)
                handlePatternPress(key)
            end if
        else
            if key = "OK" then stopRinging()
        end if
        return true
    end if

    ' ===== CONFIRM overlay =====
    if m.confirmOpen
        return handleConfirmKey(key)
    end if

    ' ===== SETTINGS MENU =====
    if m.settingsOpen
        return handleMenuKey(key)
    end if

    ' ===== IDLE =====
    if key = "play"              ' the Play/Pause button opens settings
        openSettings()
        return true
    end if

    return false
end function

' Buttons allowed in a dismissal pattern
function isPatternKey(key as string) as boolean
    return key = "up" or key = "down" or key = "left" or key = "right" or key = "OK" or key = "rewind" or key = "play" or key = "fastforward"
end function

' ---------------------------------------------------------------------------
' Settings menu
' ---------------------------------------------------------------------------
sub openSettings()
    m.settingsOpen = true
    m.menuIndex = 0
    m.settingsGroup.visible = true
    renderMenu()
end sub

sub closeSettings()
    m.settingsOpen = false
    m.settingsGroup.visible = false
    updateIdleLabel()
end sub

function handleMenuKey(key as string) as boolean
    if key = "play" or key = "back"
        closeSettings()
        return true
    end if

    count = m.menuDefs.count()
    if key = "up"
        m.menuIndex = (m.menuIndex - 1 + count) mod count
        renderMenu()
    else if key = "down"
        m.menuIndex = (m.menuIndex + 1) mod count
        renderMenu()
    else if key = "left"
        adjustRow(-1)
    else if key = "right"
        adjustRow(1)
    else if key = "OK"
        activateRow()
    end if
    return true
end function

sub adjustRow(delta as integer)
    def = m.menuDefs[m.menuIndex]
    k = def.kind
    if k = "hour"
        ' cycle 1..12 within the current AM/PM period
        pm = (m.alarmHour >= 12)
        h = hour12(m.alarmHour)
        h = ((h - 1 + delta + 12) mod 12) + 1
        base = h
        if base = 12 then base = 0
        if pm then base = base + 12
        m.alarmHour = base
    else if k = "minute"
        m.alarmMinute = (m.alarmMinute + delta + 60) mod 60
    else if k = "ampm"
        m.alarmHour = (m.alarmHour + 12) mod 24
    else if k = "dismiss"
        if m.dismissMode = "ok" then m.dismissMode = "pattern" else m.dismissMode = "ok"
    else if k = "length"
        m.patternLength = m.patternLength + delta
        if m.patternLength < 3 then m.patternLength = 3
        if m.patternLength > 8 then m.patternLength = 8
    else if k = "day"
        m.days[def.day] = not m.days[def.day]
    end if
    renderMenu()
    saveSettings()
end sub

sub activateRow()
    def = m.menuDefs[m.menuIndex]
    k = def.kind
    if k = "ampm"
        m.alarmHour = (m.alarmHour + 12) mod 24
        renderMenu()
        saveSettings()
    else if k = "dismiss"
        if m.dismissMode = "ok" then m.dismissMode = "pattern" else m.dismissMode = "ok"
        renderMenu()
        saveSettings()
    else if k = "day"
        m.days[def.day] = not m.days[def.day]
        renderMenu()
        saveSettings()
    else if k = "test"
        closeSettings()
        startRinging()
    else if k = "skip"
        openConfirm(1)
    else if k = "close"
        closeSettings()
    else
        renderMenu()
    end if
end sub

sub renderMenu()
    dismissText = "OK button"
    if m.dismissMode = "pattern" then dismissText = "Button pattern"

    for i = 0 to m.menuDefs.count() - 1
        def = m.menuDefs[i]
        k = def.kind
        t = ""
        if k = "hour"
            t = "Alarm hour:        < " + hour12(m.alarmHour).ToStr() + " >"
        else if k = "minute"
            t = "Alarm minute:      < " + twoDigit(m.alarmMinute) + " >"
        else if k = "ampm"
            t = "AM / PM:           < " + periodOf(m.alarmHour) + " >"
        else if k = "dismiss"
            t = "Dismiss with:      < " + dismissText + " >"
        else if k = "length"
            t = "Pattern length:    < " + m.patternLength.ToStr() + " >"
        else if k = "day"
            chk = "[ ]"
            if m.days[def.day] then chk = "[x]"
            t = "Repeat " + chk + "  " + m.dayNames[def.day]
        else if k = "test"
            t = "Test alarm now"
        else if k = "skip"
            s = "Skip next alarm"
            if m.skipNext then s = "Skip next alarm   (ON)"
            t = s
        else if k = "close"
            t = "Close"
        end if
        m.menuRows[i].text = t

        if i = m.menuIndex
            m.menuRows[i].color = "0xFFCC00FF"
        else
            m.menuRows[i].color = "0xFFFFFFFF"
        end if
    end for
end sub

' ---------------------------------------------------------------------------
' Confirm overlay (Skip next alarm -> two confirmations)
' ---------------------------------------------------------------------------
sub openConfirm(stepNum as integer)
    m.confirmOpen = true
    m.confirmStep = stepNum
    m.confirmSel = 1   ' default NO
    if stepNum = 1
        m.confirmMsg.text = "Are you sure you want to skip the next alarm? You may sleep in on accident."
    else
        m.confirmMsg.text = "Are you REALLY sure that you dont have to wake up at a set time tomorrow?"
    end if
    m.confirmGroup.visible = true
    renderConfirm()
end sub

sub closeConfirm()
    m.confirmOpen = false
    m.confirmGroup.visible = false
end sub

sub renderConfirm()
    if m.confirmSel = 0
        m.confirmYes.color = "0xFFCC00FF"
        m.confirmNo.color  = "0x888888FF"
    else
        m.confirmYes.color = "0x888888FF"
        m.confirmNo.color  = "0xFFCC00FF"
    end if
end sub

function handleConfirmKey(key as string) as boolean
    if key = "left"
        m.confirmSel = 0
        renderConfirm()
    else if key = "right"
        m.confirmSel = 1
        renderConfirm()
    else if key = "back"
        ' treat as NO
        closeConfirm()
    else if key = "OK"
        if m.confirmSel = 0
            ' YES
            if m.confirmStep = 1
                openConfirm(2)
            else
                m.skipNext = true
                saveSettings()
                closeConfirm()
                renderMenu()
            end if
        else
            ' NO
            closeConfirm()
        end if
    end if
    return true
end function

' ---------------------------------------------------------------------------
' Persistence (Roku registry)
' ---------------------------------------------------------------------------
sub loadSettings()
    reg = CreateObject("roRegistrySection", "AntiSleepIn")

    if reg.Exists("alarmHour")   then m.alarmHour   = reg.Read("alarmHour").ToInt()
    if reg.Exists("alarmMinute") then m.alarmMinute = reg.Read("alarmMinute").ToInt()
    if reg.Exists("dismissMode") then m.dismissMode = reg.Read("dismissMode")
    if reg.Exists("patternLength") then m.patternLength = reg.Read("patternLength").ToInt()
    if reg.Exists("skipNext")    then m.skipNext    = (reg.Read("skipNext") = "1")

    if reg.Exists("days")
        s = reg.Read("days")
        if len(s) = 7
            for i = 0 to 6
                m.days[i] = (mid(s, i + 1, 1) = "1")
            end for
        end if
    end if
end sub

sub saveSettings()
    reg = CreateObject("roRegistrySection", "AntiSleepIn")

    reg.Write("alarmHour",     m.alarmHour.ToStr())
    reg.Write("alarmMinute",   m.alarmMinute.ToStr())
    reg.Write("dismissMode",   m.dismissMode)
    reg.Write("patternLength", m.patternLength.ToStr())

    if m.skipNext then reg.Write("skipNext", "1") else reg.Write("skipNext", "0")

    s = ""
    for i = 0 to 6
        if m.days[i] then s = s + "1" else s = s + "0"
    end for
    reg.Write("days", s)

    reg.Flush()
end sub

' ---------------------------------------------------------------------------
' Helpers
' ---------------------------------------------------------------------------
function twoDigit(n as integer) as string
    s = n.ToStr()
    if n < 10 then s = "0" + s
    return s
end function

' 24h hour (0-23) -> 12h number (1-12)
function hour12(h as integer) as integer
    x = h mod 12
    if x = 0 then x = 12
    return x
end function

function periodOf(h as integer) as string
    if h < 12 then return "AM"
    return "PM"
end function
