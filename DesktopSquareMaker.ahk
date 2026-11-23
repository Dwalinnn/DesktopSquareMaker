
#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; DESKTOP SQUARE GAME
; Multi-monitor edition
; ============================================================

; ---------------- DPI / DISPLAY SETTINGS ----------------

; Request Per-Monitor DPI Awareness V2.
; Must happen before creating GUI windows.
try {
    DllCall(
        "User32\SetProcessDpiAwarenessContext",
        "ptr", -4,
        "ptr"
    )
}

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

; ---------------- CONFIGURATION ----------------

global ORANGE := "FF7F11"
global THICKNESS := 2

global SQUARE_TOLERANCE := 0.07
global MIN_SIZE := 45

global HIGHLIGHT_DURATION := 700
global COMBO_WINDOW := 2500

global SOUND_FOLDER := A_ScriptDir "\Sounds\"

; ---------------- GAME STATE ----------------

global dragging := false

global startX := 0
global startY := 0

global score := 0
global combo := 0
global lastSquare := 0

global active := true
global hideAt := 0

; ---------------- HIGHLIGHT WINDOWS ----------------

global bars := []

Loop 4 {

    bar := Gui(
        "-Caption +AlwaysOnTop +ToolWindow +E0x20"
    )

    bar.BackColor := ORANGE

    bars.Push(bar)
}

; ---------------- HUD ----------------

global hud := Gui(
    "-Caption +AlwaysOnTop +ToolWindow +E0x20"
)

hud.BackColor := "171717"

hud.SetFont("s13 bold", "Arial")

global hudTitle := hud.AddText(
    "x12 y8 w260 h25 cFF7800",
    "DESKTOP SQUARE MAKER"
)

hud.SetFont("s11 bold", "Arial")

global scoreText := hud.AddText(
    "x12 y38 w260 h25 cFFFFFF",
    "SCORE: 0"
)

global comboText := hud.AddText(
    "x12 y63 w260 h25 cFFFFFF",
    "COMBO: x0"
)

; Center HUD horizontally on the primary monitor
hudWidth := 285
hudHeight := 100

screenWidth := A_ScreenWidth

hudX := (screenWidth - hudWidth) // 2
hudY := 20

hud.Show(
    Format("NA x{} y{} w{} h{}", hudX, hudY, hudWidth, hudHeight)
)

WinSetTransparent(230, "ahk_id " hud.Hwnd)

; ---------------- START ----------------

SetTimer(GameLoop, 10)


; ============================================================
; MAIN GAME LOOP
; ============================================================

GameLoop() {

    global dragging, startX, startY
    global score, combo, lastSquare
    global active, hideAt

    global SQUARE_TOLERANCE
    global MIN_SIZE
    global COMBO_WINDOW
    global HIGHLIGHT_DURATION

    if (!active)
        return

    ; IMPORTANT:
    ; CoordMode is set inside the timer thread too.
    ; This ensures mouse coordinates are global screen
    ; coordinates across all connected monitors.

    CoordMode("Mouse", "Screen")

    MouseGetPos(&mx, &my)

    pressed := GetKeyState("LButton", "P")

    ; ---------------- MOUSE DOWN ----------------

    if (pressed && !dragging) {

        dragging := true

        startX := mx
        startY := my
    }

    ; ---------------- MOUSE UP ----------------

    if (!pressed && dragging) {

        dragging := false

        w := Abs(mx - startX)
        h := Abs(my - startY)

        tolerance := Max(
            8,
            Max(w, h) * SQUARE_TOLERANCE
        )

        ; ---------------- SQUARE DETECTION ----------------

        if (
            w >= MIN_SIZE
            && h >= MIN_SIZE
            && Abs(w - h) <= tolerance
        ) {

            now := A_TickCount

            ; ---------------- COMBO ----------------

            if (
                lastSquare != 0
                && now - lastSquare <= COMBO_WINDOW
            ) {

                combo += 1

            } else {

                combo := 1
            }

            lastSquare := now

            ; ---------------- SCORE ----------------

            multiplier := Min(combo, 8)

            points := Round(100 + (w * h / 1000))

            gained := points * multiplier

            score += gained

            ; ---------------- HIGHLIGHT ----------------

            squareX := Min(startX, mx)
            squareY := Min(startY, my)

            ShowHighlight(
                squareX,
                squareY,
                w,
                h
            )

            hideAt := now + HIGHLIGHT_DURATION

            ; ---------------- SOUND ----------------

            PlayArcadeSound(combo)

            ; ---------------- HUD ----------------

            hudTitle.Value := "PERFECT SQUARE!"

            scoreText.Value := Format(
                "SCORE: {}",
                score
            )

            comboText.Value := Format(
                "COMBO: x{}   +{}",
                combo,
                gained
            )

        } else {

            ; Failed square

            combo := 0

            hudTitle.Value := "DESKTOP SQUARE MAKER"

            comboText.Value := "COMBO BROKEN!"
        }
    }

    ; ---------------- HIDE HIGHLIGHT ----------------

    if (
        hideAt != 0
        && A_TickCount >= hideAt
    ) {

        HideHighlight()

        hideAt := 0

        hudTitle.Value := "DESKTOP SQUARE MAKER"
    }
}


; ============================================================
; MULTI-MONITOR HIGHLIGHT SYSTEM
; ============================================================

ShowHighlight(x, y, w, h) {

    global bars, THICKNESS

    ; All coordinates are physical screen coordinates.
    ; Negative X/Y values are supported for monitors
    ; positioned left or above the primary display.

    ; TOP
    bars[1].Show(
        Format(
            "NA x{} y{} w{} h{}",
            x,
            y,
            w,
            THICKNESS
        )
    )

    ; BOTTOM
    bars[2].Show(
        Format(
            "NA x{} y{} w{} h{}",
            x,
            y + h - THICKNESS,
            w,
            THICKNESS
        )
    )

    ; LEFT
    bars[3].Show(
        Format(
            "NA x{} y{} w{} h{}",
            x,
            y,
            THICKNESS,
            h
        )
    )

    ; RIGHT
    bars[4].Show(
        Format(
            "NA x{} y{} w{} h{}",
            x + w - THICKNESS,
            y,
            THICKNESS,
            h
        )
    )
}


HideHighlight() {

    global bars

    for bar in bars {
        bar.Hide()
    }
}


; ============================================================
; SOUND SYSTEM
; 8 COMBO EVOLUTIONS
; ============================================================

PlayArcadeSound(combo) {

    global SOUND_FOLDER

    soundLevel := Min(combo, 8)

    soundFile := Format(
        "{}combo{}.wav",
        SOUND_FOLDER,
        soundLevel
    )

    if FileExist(soundFile) {

        SoundPlay(soundFile)

    }
}


; ============================================================
; KEYBOARD CONTROLS
; ============================================================

; F8 = PAUSE / RESUME

F8:: {

    global active
    global dragging
    global hudTitle

    active := !active

    if (!active) {

        dragging := false

        HideHighlight()

        hudTitle.Value := "GAME PAUSED - F8 TO RESUME"

    } else {

        hudTitle.Value := "DESKTOP SQUARE MAKER"
    }
}


; F9 = RESET SCORE

F9:: {

    global score, combo, lastSquare
    global scoreText, comboText, hudTitle

    score := 0
    combo := 0
    lastSquare := 0

    scoreText.Value := "SCORE: 0"

    comboText.Value := "COMBO: x0"

    hudTitle.Value := "DESKTOP SQUARE MAKER"
}


; ESC = EXIT GAME

Esc:: {

    ExitApp()
}


; ============================================================
; END OF DESKTOP SQUARE MAKER
; ============================================================
