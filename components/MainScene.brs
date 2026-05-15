' Roku Picture Frame -- main scene controller.
'
' Layout (z-order, bottom to top):
'   bgFill                  -- solid background behind the frame
'   posterGroupA/B          -- two posters stacked for crossfading
'   matteTop/Bottom/Left/Right
'                           -- four strips covering photo bleed (the "matte")
'   bevel                   -- thin inner-shadow lines around the opening
'   captionLabel            -- caption text inside the bottom matte
'   clockLabel              -- clock inside one of the matte corners
'   statusLabel             -- centered loading/error/paused indicator

sub init()
    m.config = loadConfig()

    m.screenWidth = 1920
    m.screenHeight = 1080

    cacheNodes()
    setupLayout()
    setupAnimations()

    m.images = []
    m.currentIndex = -1
    m.activePoster = "A"
    m.advanceAttempts = 0
    m.paused = false

    m.posterA.observeField("loadStatus", "onPosterALoadStatus")
    m.posterB.observeField("loadStatus", "onPosterBLoadStatus")

    m.slideTimer.duration = m.config.slideDurationSeconds
    m.slideTimer.observeField("fire", "onSlideTick")

    m.clockTimer.observeField("fire", "onClockTick")
    if m.config.showClock
        updateClock()
        m.clockTimer.control = "start"
    end if

    m.top.setFocus(true)
    showStatus("Loading photos…")

    m.settingsPanel.config = m.config
    m.settingsPanel.observeField("settingChanged", "onSettingChanged")
    m.settingsPanel.observeField("closeRequested",  "onSettingsClose")
    m.settingsPanel.observeField("resetRequested",  "onSettingsReset")

    m.manifestTask = CreateObject("roSGNode", "ManifestTask")
    m.manifestTask.url = m.config.manifestUrl
    m.manifestTask.observeField("result", "onManifestResult")
    m.manifestTask.observeField("error", "onManifestError")
    m.manifestTask.control = "RUN"
end sub

function loadConfig() as object
    raw = ReadAsciiFile("pkg:/config/config.json")
    parsed = invalid
    if raw <> invalid and raw <> ""
        parsed = ParseJson(raw)
    end if
    if parsed = invalid then parsed = {}

    if parsed.manifestUrl = invalid then parsed.manifestUrl = "pkg:/sample/manifest.json"
    if parsed.slideDurationSeconds = invalid then parsed.slideDurationSeconds = 8
    if parsed.crossfadeDurationSeconds = invalid then parsed.crossfadeDurationSeconds = 1.2
    if parsed.kenBurns = invalid then parsed.kenBurns = true
    if parsed.matteColor = invalid then parsed.matteColor = "0xF2EBDDFF"
    if parsed.matteWidth = invalid then parsed.matteWidth = 80
    if parsed.bevelEnabled = invalid then parsed.bevelEnabled = true
    if parsed.bevelColor = invalid then parsed.bevelColor = "0x000000AA"
    if parsed.backgroundColor = invalid then parsed.backgroundColor = "0x0F0F0FFF"
    if parsed.imageFit = invalid then parsed.imageFit = "fill"
    if parsed.showClock = invalid then parsed.showClock = true
    if parsed.clockPosition = invalid then parsed.clockPosition = "bottom-right"
    if parsed.use24Hour = invalid then parsed.use24Hour = false
    if parsed.showCaption = invalid then parsed.showCaption = true
    if parsed.shuffle = invalid then parsed.shuffle = true
    if parsed.captionColor = invalid then parsed.captionColor = "0x303030FF"
    if parsed.clockColor = invalid then parsed.clockColor = "0x303030FF"

    ' Layer on-device overrides (from the Settings panel) over the file defaults.
    overrides = readRegistry()
    for each key in overrides
        parsed[key] = overrides[key]
    end for

    return parsed
end function

function readRegistry() as object
    out = {}
    section = CreateObject("roRegistrySection", "settings")
    keys = section.GetKeyList()
    if keys = invalid then return out
    for each key in keys
        raw = section.Read(key)
        if raw = invalid or raw = ""
            ' skip
        else
            parsed = ParseJson(raw)
            if parsed = invalid
                out[key] = raw
            else
                out[key] = parsed
            end if
        end if
    end for
    return out
end function

sub writeRegistry(key as string, value as dynamic)
    section = CreateObject("roRegistrySection", "settings")
    section.Write(key, FormatJson(value))
    section.Flush()
end sub

sub clearRegistry()
    section = CreateObject("roRegistrySection", "settings")
    keys = section.GetKeyList()
    if keys <> invalid
        for each key in keys
            section.Delete(key)
        end for
    end if
    section.Flush()
end sub

sub cacheNodes()
    m.posterA       = m.top.findNode("posterA")
    m.posterB       = m.top.findNode("posterB")
    m.posterGroupA  = m.top.findNode("posterGroupA")
    m.posterGroupB  = m.top.findNode("posterGroupB")
    m.photoArea     = m.top.findNode("photoArea")
    m.bgFill        = m.top.findNode("bgFill")
    m.matteTop      = m.top.findNode("matteTop")
    m.matteBottom   = m.top.findNode("matteBottom")
    m.matteLeft     = m.top.findNode("matteLeft")
    m.matteRight    = m.top.findNode("matteRight")
    m.bevelGroup    = m.top.findNode("bevel")
    m.bevelTop      = m.top.findNode("bevelTop")
    m.bevelBottom   = m.top.findNode("bevelBottom")
    m.bevelLeft     = m.top.findNode("bevelLeft")
    m.bevelRight    = m.top.findNode("bevelRight")
    m.captionLabel  = m.top.findNode("captionLabel")
    m.clockLabel    = m.top.findNode("clockLabel")
    m.statusLabel   = m.top.findNode("statusLabel")
    m.slideTimer    = m.top.findNode("slideTimer")
    m.clockTimer    = m.top.findNode("clockTimer")
    m.settingsPanel = m.top.findNode("settingsPanel")
end sub

sub setupLayout()
    cfg = m.config
    sw = m.screenWidth
    sh = m.screenHeight
    mw = cfg.matteWidth

    m.bgFill.color = cfg.backgroundColor
    m.bgFill.width = sw
    m.bgFill.height = sh

    winX = mw
    winY = mw
    winW = sw - 2 * mw
    winH = sh - 2 * mw

    m.photoArea.translation = [winX, winY]

    for each p in [m.posterA, m.posterB]
        p.width = winW
        p.height = winH
        p.translation = [0, 0]
        if cfg.imageFit = "fit"
            p.loadDisplayMode = "scaleToFit"
        else if cfg.imageFit = "stretch"
            p.loadDisplayMode = "scaleToFill"
        else
            p.loadDisplayMode = "scaleToZoom"
        end if
    end for

    ' Scale Ken Burns around the photo's center, not its top-left corner.
    m.posterGroupA.scaleRotateCenter = [winW / 2, winH / 2]
    m.posterGroupB.scaleRotateCenter = [winW / 2, winH / 2]

    ' Four matte strips frame the window.
    m.matteTop.color = cfg.matteColor
    m.matteTop.width = sw : m.matteTop.height = mw
    m.matteTop.translation = [0, 0]

    m.matteBottom.color = cfg.matteColor
    m.matteBottom.width = sw : m.matteBottom.height = mw
    m.matteBottom.translation = [0, sh - mw]

    m.matteLeft.color = cfg.matteColor
    m.matteLeft.width = mw : m.matteLeft.height = sh - 2 * mw
    m.matteLeft.translation = [0, mw]

    m.matteRight.color = cfg.matteColor
    m.matteRight.width = mw : m.matteRight.height = sh - 2 * mw
    m.matteRight.translation = [sw - mw, mw]

    if cfg.bevelEnabled
        m.bevelGroup.visible = true
        bColor = cfg.bevelColor
        bSize = 3
        m.bevelTop.color = bColor
        m.bevelTop.width = winW + 2 * bSize : m.bevelTop.height = bSize
        m.bevelTop.translation = [winX - bSize, winY - bSize]

        m.bevelBottom.color = bColor
        m.bevelBottom.width = winW + 2 * bSize : m.bevelBottom.height = bSize
        m.bevelBottom.translation = [winX - bSize, winY + winH]

        m.bevelLeft.color = bColor
        m.bevelLeft.width = bSize : m.bevelLeft.height = winH + 2 * bSize
        m.bevelLeft.translation = [winX - bSize, winY - bSize]

        m.bevelRight.color = bColor
        m.bevelRight.width = bSize : m.bevelRight.height = winH + 2 * bSize
        m.bevelRight.translation = [winX + winW, winY - bSize]
    else
        m.bevelGroup.visible = false
    end if

    m.captionLabel.color = cfg.captionColor
    m.captionLabel.font = makeFont(28)
    m.captionLabel.width = sw - 2 * mw
    m.captionLabel.height = mw
    m.captionLabel.horizAlign = "center"
    m.captionLabel.vertAlign = "center"
    m.captionLabel.translation = [mw, sh - mw]
    m.captionLabel.visible = cfg.showCaption

    m.clockLabel.color = cfg.clockColor
    m.clockLabel.font = makeFont(28)
    m.clockLabel.width = mw * 4
    m.clockLabel.height = mw
    m.clockLabel.vertAlign = "center"
    pos = cfg.clockPosition
    if pos = "top-left"
        m.clockLabel.horizAlign = "left"
        m.clockLabel.translation = [mw, 0]
    else if pos = "top-right"
        m.clockLabel.horizAlign = "right"
        m.clockLabel.translation = [sw - mw - m.clockLabel.width, 0]
    else if pos = "bottom-left"
        m.clockLabel.horizAlign = "left"
        m.clockLabel.translation = [mw, sh - mw]
    else
        m.clockLabel.horizAlign = "right"
        m.clockLabel.translation = [sw - mw - m.clockLabel.width, sh - mw]
    end if
    m.clockLabel.visible = cfg.showClock

    m.statusLabel.color = "0xFFFFFFCC"
    m.statusLabel.font = makeFont(36)
    m.statusLabel.width = sw
    m.statusLabel.height = 200
    m.statusLabel.horizAlign = "center"
    m.statusLabel.vertAlign = "center"
    m.statusLabel.wrap = true
    m.statusLabel.translation = [0, sh / 2 - 100]
end sub

function makeFont(size as integer) as object
    f = CreateObject("roSGNode", "Font")
    f.size = size
    return f
end function

sub setupAnimations()
    m.fadeA = buildFadeAnim("posterGroupA")
    m.fadeB = buildFadeAnim("posterGroupB")
    if m.config.kenBurns
        m.kbA = buildKenBurnsAnim("posterGroupA")
        m.kbB = buildKenBurnsAnim("posterGroupB")
    end if
end sub

function buildFadeAnim(groupId as string) as object
    anim = CreateObject("roSGNode", "Animation")
    anim.duration = m.config.crossfadeDurationSeconds
    anim.easeFunction = "outQuad"
    anim.repeat = false

    interp = CreateObject("roSGNode", "FloatFieldInterpolator")
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.0, 1.0]
    interp.fieldToInterp = groupId + ".opacity"
    anim.appendChild(interp)

    m.top.appendChild(anim)
    return anim
end function

function buildKenBurnsAnim(groupId as string) as object
    anim = CreateObject("roSGNode", "Animation")
    anim.duration = m.config.slideDurationSeconds + m.config.crossfadeDurationSeconds + 1
    anim.easeFunction = "linear"
    anim.repeat = false

    scaleInterp = CreateObject("roSGNode", "Vector2DFieldInterpolator")
    scaleInterp.key = [0.0, 1.0]
    scaleInterp.keyValue = [[1.05, 1.05], [1.15, 1.15]]
    scaleInterp.fieldToInterp = groupId + ".scale"
    anim.appendChild(scaleInterp)

    transInterp = CreateObject("roSGNode", "Vector2DFieldInterpolator")
    transInterp.key = [0.0, 1.0]
    transInterp.keyValue = [[0, 0], [0, 0]]
    transInterp.fieldToInterp = groupId + ".translation"
    anim.appendChild(transInterp)

    m.top.appendChild(anim)
    return anim
end function

sub startKenBurns(name as string)
    if not m.config.kenBurns then return
    if name = "A"
        anim = m.kbA
    else
        anim = m.kbB
    end if
    if anim = invalid then return
    anim.control = "stop"

    ' Randomise zoom direction and a small pan within the safe overscan.
    if Rnd(2) = 1
        s1 = 1.05 : s2 = 1.15
    else
        s1 = 1.15 : s2 = 1.05
    end if
    panX = Rnd(31) - 16
    panY = Rnd(21) - 11

    scaleInterp = anim.getChild(0)
    scaleInterp.keyValue = [[s1, s1], [s2, s2]]
    transInterp = anim.getChild(1)
    transInterp.keyValue = [[panX, panY], [-panX, -panY]]

    anim.control = "start"
end sub

sub showStatus(msg as string)
    m.statusLabel.text = msg
    m.statusLabel.visible = true
end sub

sub hideStatus()
    m.statusLabel.visible = false
end sub

sub onManifestResult()
    res = m.manifestTask.result
    if res = invalid then return

    list = []
    for each item in res.images
        url = invalid
        caption = ""
        if type(item) = "roAssociativeArray"
            url = item.url
            if item.caption <> invalid then caption = item.caption
        else if type(item) = "String" or type(item) = "roString"
            url = item
        end if
        if url <> invalid and url <> ""
            list.Push({ url: url, caption: caption })
        end if
    end for

    if list.Count() = 0
        showStatus("Manifest contained no usable image URLs.")
        return
    end if

    if m.config.shuffle then shuffleArray(list)
    m.images = list
    m.currentIndex = -1
    m.advanceAttempts = 0
    hideStatus()
    advance(1)
    m.slideTimer.control = "start"
end sub

sub onManifestError()
    err = m.manifestTask.error
    if err = invalid or err = "" then err = "Failed to load photos."
    showStatus(err + Chr(10) + "Edit config/config.json to set your manifest URL.")
end sub

sub shuffleArray(arr as object)
    n = arr.Count()
    i = n - 1
    while i > 0
        j = Rnd(i + 1) - 1
        tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
        i = i - 1
    end while
end sub

sub onSlideTick()
    if not m.paused then advance(1)
end sub

sub advance(direction as integer)
    n = m.images.Count()
    if n = 0 then return

    m.advanceAttempts = m.advanceAttempts + 1
    if m.advanceAttempts > n
        m.advanceAttempts = 0
        showStatus("Couldn't load any photos from the manifest.")
        return
    end if

    m.currentIndex = (m.currentIndex + direction + n) mod n
    item = m.images[m.currentIndex]

    if m.activePoster = "A"
        backPoster = m.posterB
        backGroup = m.posterGroupB
    else
        backPoster = m.posterA
        backGroup = m.posterGroupA
    end if

    ' Halt anything in flight on the back group so we don't fight the new fade.
    m.fadeA.control = "stop"
    m.fadeB.control = "stop"
    if m.kbA <> invalid then m.kbA.control = "stop"
    if m.kbB <> invalid then m.kbB.control = "stop"

    backGroup.opacity = 0
    backGroup.scale = [1.05, 1.05]
    backGroup.translation = [0, 0]

    if m.activePoster = "A"
        m.posterGroupA.opacity = 1.0
    else
        m.posterGroupB.opacity = 1.0
    end if

    m.pendingCaption = item.caption
    backPoster.uri = item.url
end sub

sub onPosterALoadStatus()
    handleLoadStatus(m.posterA, m.posterGroupA, "A", m.fadeA)
end sub

sub onPosterBLoadStatus()
    handleLoadStatus(m.posterB, m.posterGroupB, "B", m.fadeB)
end sub

sub handleLoadStatus(poster as object, group as object, name as string, fadeAnim as object)
    status = poster.loadStatus
    if status = "ready"
        if m.activePoster <> name
            m.advanceAttempts = 0
            fadeAnim.control = "start"
            startKenBurns(name)
            m.activePoster = name
            updateCaption(m.pendingCaption)
        end if
    else if status = "failed"
        advance(1)
    end if
end sub

sub updateCaption(caption as dynamic)
    if not m.config.showCaption
        m.captionLabel.visible = false
        return
    end if
    if caption = invalid then caption = ""
    m.captionLabel.text = caption
    m.captionLabel.visible = true
end sub

sub onClockTick()
    updateClock()
end sub

sub updateClock()
    if not m.config.showClock then return
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mn = dt.GetMinutes()
    suffix = ""
    if not m.config.use24Hour
        if h = 0
            h = 12 : suffix = " AM"
        else if h < 12
            suffix = " AM"
        else if h = 12
            suffix = " PM"
        else
            h = h - 12 : suffix = " PM"
        end if
    end if
    minStr = mn.ToStr()
    if mn < 10 then minStr = "0" + minStr
    m.clockLabel.text = h.ToStr() + ":" + minStr + suffix
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if key = "right" or key = "fastforward"
        advance(1)
        m.slideTimer.control = "stop"
        m.slideTimer.control = "start"
        return true
    else if key = "left" or key = "rewind"
        advance(-1)
        m.slideTimer.control = "stop"
        m.slideTimer.control = "start"
        return true
    else if key = "OK" or key = "play"
        m.paused = not m.paused
        if m.paused
            m.slideTimer.control = "stop"
            showStatus("Paused")
        else
            hideStatus()
            m.slideTimer.control = "start"
        end if
        return true
    else if key = "info"
        openSettings()
        return true
    end if

    return false
end function

' ----------------------------------------------------------------------------
' Settings panel
' ----------------------------------------------------------------------------

sub openSettings()
    if m.settingsPanel.visible then return
    m.settingsPanel.visible = true
    m.settingsPanel.setFocus(true)
end sub

sub onSettingsClose()
    m.settingsPanel.visible = false
    m.top.setFocus(true)
end sub

sub onSettingChanged()
    change = m.settingsPanel.settingChanged
    if change = invalid then return
    key = change.key
    if key = invalid or key = "" then return
    value = change.value
    m.config[key] = value
    writeRegistry(key, value)
    applySetting(key)
end sub

sub onSettingsReset()
    clearRegistry()
    m.config = loadConfig()
    m.settingsPanel.config = m.config
    setupLayout()
    applySetting("kenBurns")
    applySetting("imageFit")
    applySetting("showCaption")
    applySetting("showClock")
    applySetting("slideDurationSeconds")
    applySetting("crossfadeDurationSeconds")
end sub

sub applySetting(key as string)
    if key = "slideDurationSeconds"
        m.slideTimer.duration = m.config.slideDurationSeconds
        if m.kbA <> invalid then m.kbA.duration = m.config.slideDurationSeconds + m.config.crossfadeDurationSeconds + 1
        if m.kbB <> invalid then m.kbB.duration = m.config.slideDurationSeconds + m.config.crossfadeDurationSeconds + 1
    else if key = "crossfadeDurationSeconds"
        m.fadeA.duration = m.config.crossfadeDurationSeconds
        m.fadeB.duration = m.config.crossfadeDurationSeconds
        if m.kbA <> invalid then m.kbA.duration = m.config.slideDurationSeconds + m.config.crossfadeDurationSeconds + 1
        if m.kbB <> invalid then m.kbB.duration = m.config.slideDurationSeconds + m.config.crossfadeDurationSeconds + 1
    else if key = "kenBurns"
        if m.config.kenBurns
            if m.kbA = invalid then m.kbA = buildKenBurnsAnim("posterGroupA")
            if m.kbB = invalid then m.kbB = buildKenBurnsAnim("posterGroupB")
        else
            if m.kbA <> invalid then m.kbA.control = "stop"
            if m.kbB <> invalid then m.kbB.control = "stop"
            m.posterGroupA.scale = [1.0, 1.0]
            m.posterGroupB.scale = [1.0, 1.0]
            m.posterGroupA.translation = [0, 0]
            m.posterGroupB.translation = [0, 0]
        end if
    else if key = "shuffle"
        if m.config.shuffle and m.images <> invalid and m.images.Count() > 1
            shuffleArray(m.images)
        end if
    else if key = "imageFit"
        for each p in [m.posterA, m.posterB]
            if m.config.imageFit = "fit"
                p.loadDisplayMode = "scaleToFit"
            else if m.config.imageFit = "stretch"
                p.loadDisplayMode = "scaleToFill"
            else
                p.loadDisplayMode = "scaleToZoom"
            end if
        end for
    else if key = "matteWidth" or key = "matteColor" or key = "bevelEnabled" or key = "clockPosition"
        setupLayout()
    else if key = "showCaption"
        m.captionLabel.visible = m.config.showCaption
    else if key = "showClock"
        m.clockLabel.visible = m.config.showClock
        if m.config.showClock
            updateClock()
            m.clockTimer.control = "start"
        else
            m.clockTimer.control = "stop"
        end if
    else if key = "use24Hour"
        updateClock()
    end if
end sub
