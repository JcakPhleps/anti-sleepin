# Custom Alarm (Roku channel)

A Roku app that stays on a black screen showing your alarm time, plays a
**custom sound** on a loop when it fires, **pulses black/white**, and makes you
dismiss it with either the **OK button** or a **randomly generated button
pattern** shown on screen.

## Screens

- **Idle** — black screen (a tiny looping black video keeps the channel
  alive) with a small box at the top: `Alarm set for HH:MM`.
- **Settings** — press the **Play/Pause** button to open it. (The `*` button
  is avoided because Roku reserves it for its own accessibility/volume menu.)
- **Ringing** — background pulses black ↔ white, your sound loops, and the
  dismissal UI is shown. Settings **cannot** be opened while ringing.

## Settings menu

Open with **Play/Pause**. Navigate with **Up/Down**, change values with
**Left/Right**, activate/toggle with **OK**, close with **Play** or **Back**.

| Row | What it does |
|-----|--------------|
| **Alarm hour** | Left/Right to set the hour (0–23) |
| **Alarm minute** | Left/Right to set the minute (0–59) |
| **Dismiss with** | Toggle between **OK button** and **Button pattern** |
| **Pattern length** | 3–8 buttons (used in pattern mode) |
| **Repeat [ ] Sunday … Saturday** | 7 checkboxes — OK (or Left/Right) toggles each day the alarm repeats on |
| **Test alarm now** | OK to trigger the alarm immediately |
| **Skip next alarm** | OK to skip the next occurrence — requires **two** confirmations (see below) |
| **Close** | OK to close the menu |

The idle box at the top summarizes everything, e.g.
`Alarm 07:00  -  Mo Tu We Th Fr   (skipping next)`.

### Repeat days

The alarm only fires on checked days (`roDateTime` weekday, 0=Sun). All days
are checked by default (every day). If no days are checked it never fires.

### Skip next alarm

Selecting it asks twice, defaulting to **NO** both times:
1. *"Are you sure you want to skip the next alarm? You may sleep in on accident."*
2. *"Are you REALLY sure that you dont have to wake up at a set time tomorrow?"*

Only **YES → YES** skips the next occurrence (then it auto-resumes).

## Dismissal

- **OK button** — press OK to stop the alarm.
- **Button pattern** — a random sequence is generated and shown on screen each
  time the alarm fires. The pool is **▲ ▼ ◀ ▶ OK REW PLAY FF** (up, down, left,
  right, OK, rewind, play, fast-forward). Enter it in order. A wrong press
  restarts the sequence. Only completing it stops the alarm.

While ringing, **every other button is ignored** — no way to escape except the
correct dismissal.

## Add your custom sound

Drop your audio file into `sounds/` named **`alarm.mp3`**
(MP3, AAC, WAV, or FLAC — rename/convert to `alarm.mp3`, or edit the URL in
`components/MainScene.brs`).

## Project structure

```
roku-alarm/
├── manifest
├── source/main.brs            # entry point / event loop
├── components/
│   ├── MainScene.xml          # UI layout
│   └── MainScene.brs          # alarm logic, settings, pattern, remote input
├── sounds/alarm.mp3           # <-- you add this
├── videos/black.mp4           # tiny looping black video (already generated)
├── images/                    # channel icon + splash (already generated)
├── make_icons.sh              # regenerates the icon/splash art via rsvg-convert
└── README.md
```

## Run it on your Roku (sideload)

1. Roku: **Settings → System → Advanced system settings → Developer mode** →
   enable, set a password, note the Roku's IP.
2. Zip the **contents** of this folder (manifest at the zip root):

   ```sh
   cd roku-alarm
   zip -r ../roku-alarm.zip . -x '*.DS_Store'
   ```

3. Browse to `http://<your-roku-ip>`, log in as `rokudev` + your password,
   upload `roku-alarm.zip`, and **Install**.

Times use the Roku's local time zone.
