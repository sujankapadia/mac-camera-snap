# mac-camera-snap

Let an AI coding agent take a photo with your Mac's built-in camera — or with
your iPhone acting as a Continuity Camera — and look at the result.

Packaged as a [Claude Code](https://claude.com/claude-code) skill (`/snap`),
but `snap.sh` is a standalone script with no agent dependency.

## The problem it solves

`imagesnap -w 6` warms the sensor for six seconds and then fires. Fine for a
script; useless for a human, because the countdown prints to the agent's
terminal, not to the person holding up the thing being photographed. They end
up aiming blind at a camera that fires at an unknown moment.

`snap.sh` fixes that two ways:

- **Spoken countdown** — the Mac says "3, 2, 1" out loud before firing.
- **Burst mode** — N shots a few seconds apart. Timing stops mattering; the
  person keeps adjusting and the agent picks the best frame.

With Continuity Camera there's a second problem: the iPhone shows a "Connected
to Mac" status screen rather than a viewfinder, so there's no way to see the
shot. `snap.sh` opens a live `ffplay` preview window on the Mac and lets it
settle before the aiming window begins.

## Install

```bash
brew install imagesnap        # required
brew install ffmpeg           # optional, for the live preview

git clone https://github.com/sujankapadia/mac-camera-snap.git
ln -s "$PWD/mac-camera-snap" ~/.claude/skills/snap     # for Claude Code
```

The symlink is only needed to register it as a Claude Code skill. To use it as
a plain script, just run `snap.sh`.

## Usage

```bash
./snap.sh -l                  # list cameras
./snap.sh                     # countdown capture, built-in camera
./snap.sh -i                  # countdown capture, iPhone
./snap.sh -b                  # burst: 6 shots over ~12s
./snap.sh -i -b -n 10 -e 1.5  # iPhone burst, 10 shots, 1.5s apart
./snap.sh -s 10               # 10-second countdown
./snap.sh -o ~/Desktop        # keep the files somewhere durable
./snap.sh -P                  # no live preview
./snap.sh -q                  # no spoken countdown
```

It prints the path(s) it wrote.

## Gotchas found the hard way

- **`imagesnap` reports "the file doesn't exist" when the _parent directory_
  is missing.** The message points squarely at the wrong problem — it reads
  like a permissions failure. `snap.sh` mkdirs first.
- **`imagesnap --help` is not a flag.** It isn't recognized, so imagesnap falls
  through to its default behavior and *takes a photo* into `snapshot.jpg` in
  the current directory. Use `-h`.
- **Camera permission belongs to the terminal app**, not to the agent running
  inside it. If captures come back black, check System Settings → Privacy &
  Security → Camera.
- **Continuity Camera is opportunistic.** The iPhone only advertises itself
  when it's locked, stationary, nearby, with rear cameras unobstructed. It
  drops off on its own. `snap.sh` detects this and prints recovery steps
  rather than failing silently.
- **A cold Continuity link hands `ffplay` dark frames** while the phone wakes
  and auto-exposes, and ffplay never re-exposes. The preview is therefore
  started and allowed to settle *before* the user's aiming window opens.
- `objc[...] NSKVONotifying_AVCapturePhotoOutput not linked` prints on every
  run. Cosmetic — imagesnap 0.3.0.2 is built against an older SDK.
- The green camera LED is hardware-wired and cannot be suppressed. Good.

## Privacy

Taking a photo of someone's room is not a neutral tool call. The skill
instructs the agent to capture only when asked in the current exchange — not
speculatively, and not on its own initiative. Files land in `$TMPDIR/snap` by
default and vanish with the session.

## License

MIT
