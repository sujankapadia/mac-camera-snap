---
name: snap
description: "Take a photo with the Mac's built-in camera or the iPhone Continuity camera, then read it. Use when the user asks to take a picture, snap a photo, capture a frame, show you something via the camera, read a whiteboard or document they're holding up, or invokes /snap by name. Also use when the user says they want to show you something physical and no camera workflow is set up yet."
---

## What this does

Captures a still from a macOS camera and reads it back so I can see it. Two
cameras are typically available: the built-in FaceTime camera, and the user's
iPhone acting as a Continuity Camera (better glass, needs the phone positioned).

The helper is `snap.sh` in this skill's directory.

## The timing problem this solves

`imagesnap -w N` warms the sensor for N seconds then fires. But the user cannot
see that countdown — the progress dots print in my terminal, not on their
screen. Left raw, they aim blind. `snap.sh` fixes this with a spoken countdown,
or with burst mode, which removes timing from the equation entirely.

## Usage

```bash
S=~/.claude/skills/snap/snap.sh

"$S" -l                  # list cameras
"$S"                     # countdown capture, built-in camera
"$S" -i                  # countdown capture, iPhone
"$S" -b                  # burst: 6 shots over ~12s
"$S" -i -b -n 10 -e 1.5  # iPhone burst, 10 shots, 1.5s apart
"$S" -s 10               # 10-second countdown
"$S" -o ~/Desktop        # keep the files somewhere durable
```

It prints the path(s) it wrote. **Always `Read` the resulting file** — that is
the entire point; the capture alone shows me nothing.

## Choosing a mode

- **Burst is the default choice** when the user is aiming at something by hand
  (a document, a whiteboard, hardware). They move, I pick the best frame. No
  pressure, no retakes.
- **Countdown** when the subject is static and framing is already set, or when
  the user is in the shot themselves.
- For a burst, read the frames and say which one I used and why; offer another
  burst if every frame is blurred or badly framed.

## Continuity Camera notes

- The iPhone shows a "Connected to Mac" status screen, **not a viewfinder**.
  To aim, the user needs a preview on the Mac:
  ```bash
  ffplay -f avfoundation -framerate 30 -i "1"   # q to quit
  ```
  Photo Booth and QuickTime (New Movie Recording) also work.
- **Preview and capture can run simultaneously** — verified on this machine.
  So: open a preview, let the user aim, then fire. Capture takes ~1-2s longer
  while sharing the device; keep warmup at 4s or more.
- Continuity needs a longer wake than the built-in camera. Don't trim warmup.
- `Desk View` is a virtual device derived from the iPhone's ultrawide, aimed
  down at the desk. It requires the phone mounted above the display, and
  `imagesnap -l` may not list it even when `ffmpeg` does.

## Gotchas

- **`imagesnap` reports "the file doesn't exist" when the *parent directory*
  is missing.** Misleading — it reads like a permissions error. `snap.sh`
  mkdir's first.
- `objc[...] NSKVONotifying_AVCapturePhotoOutput not linked` prints on every
  run. Cosmetic; imagesnap 0.3.0.2 is built against an older SDK.
- `imagesnap --help` is not a flag — it ignores it and **takes a photo** into
  `snapshot.jpg` in the current directory. Use `-h`.
- Camera access is granted to the *terminal app* hosting Claude Code, not to
  Claude Code itself. First use may raise a system prompt; if capture silently
  returns black, check System Settings → Privacy & Security → Camera.
- The green camera LED is hardware-wired and cannot be suppressed.

## Privacy

Taking a photo of someone's room is not a neutral tool call. Capture when the
user has asked for it or clearly agreed to it in the current exchange — not
speculatively, and not "to check something" on my own initiative. Files land in
`$TMPDIR/snap` by default and vanish with the session; use `-o` when the user
wants to keep them.
