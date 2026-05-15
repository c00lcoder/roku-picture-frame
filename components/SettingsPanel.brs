' SettingsPanel -- on-device settings overlay.
'
' The panel is hidden by default. MainScene shows it (and shifts focus to it)
' when the user presses the * (info) button. Each settings row supports either
' a boolean toggle, cycling through a fixed value list, or an action.
'
' On any value change the panel mutates the shared config assocarray AND
' notifies via the `settingChanged` field so MainScene can apply the change
' live and persist it. The `config` reference is shared (assocarray = ref
' semantics in BrightScript), so MainScene reads the new value through its
' own m.config too.

sub init()
    m.top.visible = false
    m.focusedIndex = 0
    m.rowEntries = []

    m.dim     = m.top.findNode("dim")
    m.title   = m.top.findNode("title")
    m.footer  = m.top.findNode("footer")
    m.rowsContainer = m.top.findNode("rowsContainer")

    setupChrome()
    m.top.observeField("config", "onConfigSet")
end sub

sub setupChrome()
    m.title.font = makeFont(48)
    m.title.color = "0xFFFFFFFF"
    m.title.horizAlign = "center"
    m.title.width = 1920
    m.title.translation = [0, 60]
    m.title.text = "Picture Frame Settings"

    m.footer.font = makeFont(22)
    m.footer.color = "0xB0B0B0FF"
    m.footer.horizAlign = "center"
    m.footer.width = 1920
    m.footer.translation = [0, 990]
    m.footer.text = "Up / Down: navigate     OK or " + Chr(9666) + " " + Chr(9658) + ": change value     Back or " + Chr(8902) + ": close"
end sub

function makeFont(size as integer) as object
    f = CreateObject("roSGNode", "Font")
    f.size = size
    return f
end function

sub onConfigSet()
    rebuildRows()
end sub

sub rebuildRows()
    cfg = m.top.config
    if cfg = invalid then return

    while m.rowsContainer.getChildCount() > 0
        m.rowsContainer.removeChildIndex(0)
    end while

    defs = settingDefs()
    m.rowEntries = []

    rowHeight = 56
    panelLeft = 360
    panelWidth = 1200
    yStart = 150

    for i = 0 to defs.Count() - 1
        def = defs[i]
        row = CreateObject("roSGNode", "Group")
        row.translation = [panelLeft, yStart + i * rowHeight]

        bg = CreateObject("roSGNode", "Rectangle")
        bg.color = "0x00000000"
        bg.width = panelWidth
        bg.height = rowHeight
        row.appendChild(bg)

        chevron = CreateObject("roSGNode", "Label")
        chevron.font = makeFont(32)
        chevron.color = "0xE5C77BFF"
        chevron.translation = [20, 8]
        chevron.text = ""
        row.appendChild(chevron)

        nameLbl = CreateObject("roSGNode", "Label")
        nameLbl.font = makeFont(30)
        nameLbl.color = "0xCFCFCFFF"
        nameLbl.translation = [70, 10]
        nameLbl.width = 600
        nameLbl.text = def.label
        row.appendChild(nameLbl)

        valLbl = CreateObject("roSGNode", "Label")
        valLbl.font = makeFont(30)
        valLbl.color = "0xB8B8B8FF"
        valLbl.translation = [690, 10]
        valLbl.width = panelWidth - 710
        valLbl.horizAlign = "right"
        valLbl.text = displayValue(def, cfg)
        row.appendChild(valLbl)

        m.rowsContainer.appendChild(row)
        m.rowEntries.Push({ def: def, group: row, bg: bg, chevron: chevron, nameLbl: nameLbl, valLbl: valLbl })
    end for

    if m.focusedIndex >= m.rowEntries.Count() then m.focusedIndex = 0
    paintFocus()
end sub

sub paintFocus()
    for i = 0 to m.rowEntries.Count() - 1
        entry = m.rowEntries[i]
        if i = m.focusedIndex
            entry.bg.color = "0xE5C77B26"
            entry.chevron.text = Chr(9656)
            entry.nameLbl.color = "0xFFFFFFFF"
            entry.valLbl.color = "0xFFFFFFFF"
        else
            entry.bg.color = "0x00000000"
            entry.chevron.text = ""
            entry.nameLbl.color = "0xCFCFCFFF"
            entry.valLbl.color = "0xB8B8B8FF"
        end if
    end for
end sub

sub moveFocus(delta as integer)
    n = m.rowEntries.Count()
    if n = 0 then return
    m.focusedIndex = (m.focusedIndex + delta + n) mod n
    paintFocus()
end sub

sub applyChange(direction as integer)
    if m.rowEntries.Count() = 0 then return
    entry = m.rowEntries[m.focusedIndex]
    def = entry.def
    cfg = m.top.config

    if def.type = "action"
        if def.key = "_close"
            close()
        else if def.key = "_reset"
            m.top.resetRequested = true
        end if
        return
    end if

    if def.type = "bool"
        newVal = not cfg[def.key]
        cfg[def.key] = newVal
        entry.valLbl.text = displayValue(def, cfg)
        notifyChange(def.key, newVal)
        return
    end if

    if def.type = "cycle"
        n = def.values.Count()
        idx = -1
        for i = 0 to n - 1
            if compareValue(def.values[i].value, cfg[def.key])
                idx = i
                exit for
            end if
        end for
        if idx = -1 then idx = 0
        step = direction
        if step = 0 then step = 1
        idx = (idx + step + n) mod n
        newVal = def.values[idx].value
        cfg[def.key] = newVal
        entry.valLbl.text = displayValue(def, cfg)
        notifyChange(def.key, newVal)
        return
    end if
end sub

function displayValue(def as object, cfg as object) as string
    if def.type = "action"
        return "Press OK " + Chr(9656)
    end if
    val = cfg[def.key]
    if def.type = "bool"
        if val = true then return Chr(9666) + " On  " + Chr(9658)
        return Chr(9666) + " Off " + Chr(9658)
    end if
    if def.type = "cycle"
        for each item in def.values
            if compareValue(item.value, val)
                return Chr(9666) + " " + item.display + " " + Chr(9658)
            end if
        end for
        return Chr(9666) + " " + asString(val) + " " + Chr(9658)
    end if
    return ""
end function

function asString(v as dynamic) as string
    if v = invalid then return ""
    t = type(v)
    if t = "roString" or t = "String" then return v
    if t = "roBoolean" or t = "Boolean"
        if v then return "On"
        return "Off"
    end if
    if isNumeric(v) then return v.ToStr()
    return ""
end function

function compareValue(a as dynamic, b as dynamic) as boolean
    if a = invalid and b = invalid then return true
    if a = invalid or b = invalid then return false
    if isNumeric(a) and isNumeric(b)
        return Abs((a * 1.0) - (b * 1.0)) < 0.001
    end if
    if isNumeric(a) or isNumeric(b) then return false
    return asString(a) = asString(b)
end function

function isNumeric(v as dynamic) as boolean
    t = type(v)
    return t = "Integer" or t = "roInt" or t = "roInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function

sub notifyChange(key as string, value as dynamic)
    m.top.settingChanged = { key: key, value: value }
end sub

sub close()
    m.top.closeRequested = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if not m.top.visible then return false

    if key = "up"
        moveFocus(-1)
        return true
    else if key = "down"
        moveFocus(1)
        return true
    else if key = "right" or key = "fastforward"
        applyChange(1)
        return true
    else if key = "left" or key = "rewind"
        applyChange(-1)
        return true
    else if key = "OK" or key = "play"
        applyChange(0)
        return true
    else if key = "back" or key = "info"
        close()
        return true
    end if

    return false
end function

function settingDefs() as object
    return [
        { key: "slideDurationSeconds", label: "Slide duration", type: "cycle", values: [
            { value: 4,   display: "4 seconds" },
            { value: 6,   display: "6 seconds" },
            { value: 8,   display: "8 seconds" },
            { value: 12,  display: "12 seconds" },
            { value: 20,  display: "20 seconds" },
            { value: 30,  display: "30 seconds" },
            { value: 60,  display: "1 minute" },
            { value: 120, display: "2 minutes" }
        ]},
        { key: "crossfadeDurationSeconds", label: "Crossfade duration", type: "cycle", values: [
            { value: 0.4, display: "0.4 sec (snappy)" },
            { value: 0.8, display: "0.8 sec" },
            { value: 1.2, display: "1.2 sec" },
            { value: 1.8, display: "1.8 sec" },
            { value: 2.4, display: "2.4 sec (slow)" }
        ]},
        { key: "kenBurns",     label: "Ken Burns motion", type: "bool" },
        { key: "shuffle",      label: "Shuffle photos",   type: "bool" },
        { key: "imageFit",     label: "Image fit",        type: "cycle", values: [
            { value: "fill",    display: "Fill (crop)" },
            { value: "fit",     display: "Fit (letterbox)" },
            { value: "stretch", display: "Stretch" }
        ]},
        { key: "matteWidth",   label: "Matte width", type: "cycle", values: [
            { value: 0,   display: "None" },
            { value: 40,  display: "Thin (40px)" },
            { value: 60,  display: "Medium (60px)" },
            { value: 80,  display: "Standard (80px)" },
            { value: 120, display: "Wide (120px)" },
            { value: 160, display: "Gallery (160px)" }
        ]},
        { key: "matteColor",   label: "Matte color", type: "cycle", values: [
            { value: "0xF2EBDDFF", display: "Cream" },
            { value: "0xFFFFFFFF", display: "White" },
            { value: "0xEDEDE9FF", display: "Off-white" },
            { value: "0x1A1A1AFF", display: "Charcoal" },
            { value: "0x0B0B0BFF", display: "Black" },
            { value: "0xD7DCD5FF", display: "Sage" },
            { value: "0x202B3AFF", display: "Navy" },
            { value: "0xE9D7D3FF", display: "Blush" },
            { value: "0x3A2A1AFF", display: "Walnut" }
        ]},
        { key: "bevelEnabled", label: "Bevel line",       type: "bool" },
        { key: "showCaption",  label: "Show captions",    type: "bool" },
        { key: "showClock",    label: "Show clock",       type: "bool" },
        { key: "clockPosition", label: "Clock position",  type: "cycle", values: [
            { value: "bottom-right", display: "Bottom right" },
            { value: "bottom-left",  display: "Bottom left" },
            { value: "top-right",    display: "Top right" },
            { value: "top-left",     display: "Top left" }
        ]},
        { key: "use24Hour",    label: "24-hour clock",    type: "bool" },
        { key: "_reset",       label: "Reset to defaults", type: "action" },
        { key: "_close",       label: "Done",             type: "action" }
    ]
end function
