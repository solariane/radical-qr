#!/usr/bin/env python3
"""edit.py sb1|sb2 LANG -> out/<name>-<locale>.mp4 (886x1920, 30 fps, H.264, stereo AAC).

The raw simulator recording only holds frames where the screen changed, and every
action in it was preceded by a wall-clock mark written by the UI test. For each
beat the edit keeps the real changes between its mark and the next one (scene
score above noise), squeezes the pauses the loaded machine put between them, then
holds the settled state. So XCTest's own latency never reaches the cut."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
S = os.environ.get("PREVIEW_WORK", "/tmp/radicalqr-previews")
POST = f"{S}/layers"
OUTNAMES = {"sb1": "preview-1-paste", "sb2": "preview-2-style"}
LOCALES = {"en": "en-US", "fr": "fr-FR", "de": "de-DE", "es": "es-ES"}
SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H = 109, 394, 668, 1452
FPS = 30

# (mark, still seconds held once settled, caption key, driven by a change)
PLANS = {
    "sb1": [("intro", 2.0, "intro", False), ("event", 2.6, "event", True),
            ("clear1", 0.3, "wifi", True), ("wifi", 2.3, "wifi", True),
            ("clear2", 0.3, "signature", True), ("signature", 2.3, "signature", True),
            ("clear3", 0.3, "address", True), ("address", 2.1, "address", True),
            ("palette", 0.4, "outro", True), ("gradient", 2.4, "outro", True)],
    "sb2": [("intro", 1.6, "intro", False), ("url", 1.9, "intro", True),
            ("palette", 0.4, "color", True), ("gradient1", 0.9, "color", True), ("gradient2", 1.4, "color", True),
            ("shape", 0.4, "shape", True), ("modules", 1.0, "shape", True), ("eyes", 1.5, "shape", True),
            ("brand", 0.4, "logo", True), ("logo", 1.5, "logo", True), ("caption", 1.8, "logo", True),
            ("export", 0.4, "export", True), ("svg", 0.9, "export", True), ("size", 2.2, "export", True)],
}
THRESHOLD = 0.0012  # scene score below this is noise (caret, shimmer)
STALL = 0.45        # a longer pause between real changes is lag, not animation
KEEP = 0.12         # how much of a stalled intermediate state survives
LEAD = 0.10
TAIL = 0.35         # lets the last animation finish before the still hold
FADE = 0.16

# Preview 1's pastes: pause on an appointment's text as pasted, skip the encoded
# flashes (BEGIN:VEVENT, WIFI:T:…) the field passes through, then play the change
# into the form in slow motion so the eye can follow it.
FORM_BEATS = {"sb1": {"event", "wifi", "signature", "address"}}
RAW_HOLD = 0.7      # seconds on the pasted, still unstructured text
SLOW = 0.55         # playback speed of the raw -> form transition
TARGETS = {"sb1": 22.0}


class Range:
    """A stretch of the recording: source [r0, r1], played at speed, or frozen
    to a forced output length (the last frame is held)."""
    def __init__(self, r0, r1, speed=1.0, forced=None):
        self.r0, self.r1, self.speed, self.forced = r0, r1, speed, forced

    @property
    def out(self):
        return self.forced if self.forced is not None else (self.r1 - self.r0) / self.speed

    def __str__(self):
        extra = f" x{self.speed}" if self.speed != 1 else (f" hold{self.forced:.2f}" if self.forced else "")
        return f"[{self.r0:.2f}-{self.r1:.2f}{extra}]"


def form_ranges(beat, frames, nxt):
    """frames: (time, score) of the real changes after a paste mark.

    Only an appointment shows the text as pasted: it stays in the field while
    the date is read. Wi-Fi, contacts and places are re-encoded at once, so the
    field never shows the human text and there is nothing honest to pause on."""
    groups = []
    for t, sc in frames:
        if groups and t - groups[-1][-1][0] <= STALL:
            groups[-1].append((t, sc))
        else:
            groups.append([(t, sc)])
    final = max(groups, key=lambda g: max(sc for _, sc in g))   # the switch to the form
    big = [t for t, sc in final if sc >= 0.1]                   # skips encoded-text flashes
    start, settle = (big[0] if big else final[0][0]), final[-1][0]
    ranges = []
    # The typed-in text barely changes the frame; an encoded block replacing it does.
    if beat == "event" and frames[0][1] < 0.02 and frames[0][0] < start - 0.05:
        raw_t = frames[0][0]
        ranges.append(Range(raw_t - LEAD, min(raw_t + 0.05, start - 0.01), forced=LEAD + RAW_HOLD))
    ranges.append(Range(start + 0.001, min(settle + TAIL, nxt), speed=SLOW))
    return ranges

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"FAILED: {' '.join(cmd)}\n{r.stderr[-2000:]}")
    return r.stdout


def scene_scores(raw, cache):
    if not os.path.exists(cache):
        subprocess.run(["ffmpeg", "-v", "quiet", "-i", raw, "-vf",
                        f"scale=132:-2,select='gte(scene\\,0)',metadata=print:file={cache}",
                        "-an", "-f", "null", "-"], check=True)
    rows, t = [], None
    for line in open(cache):
        if line.startswith("frame:"):
            t = float(line.split("pts_time:")[1])
        elif "scene_score" in line and t is not None:
            rows.append((t, float(line.split("=")[1])))
    return rows


def main(sb, lang):
    name = f"{sb}_{lang}"
    raw = f"{S}/raw/{name}.mov"
    start = float(open(f"{S}/raw/{name}.start").read())
    marks = {}
    for line in open(f"{S}/raw/{name}.marks"):
        t, label = line.strip().split(" ", 1)
        marks.setdefault(label, float(t) - start)
    work = f"{S}/work/{name}"
    os.makedirs(work, exist_ok=True)
    for f in os.listdir(work):
        if f.startswith("seg"):
            os.remove(f"{work}/{f}")
    scores = scene_scores(raw, f"{work}/scores.txt")
    pts = [t for t, _ in scores]
    plan = PLANS[sb]
    forms = FORM_BEATS.get(sb, set())
    report, beats = [], []
    for i, (beat, hold, cap, on_change) in enumerate(plan):
        if beat not in marks:
            sys.exit(f"{name}: mark '{beat}' missing")
        m = marks[beat]
        nxt = marks[plan[i + 1][0]] if i + 1 < len(plan) else marks.get("end", m + 30)
        frames = [(t, sc) for t, sc in scores if m < t < nxt and sc > THRESHOLD] if on_change else []
        sig = [t for t, _ in frames]
        if not sig:
            if on_change:
                report.append(f"WARNING no change after {beat}")
            ranges = [Range(m, m)]
        elif beat in forms and len(frames) > 1:
            ranges = form_ranges(beat, frames, nxt)
        else:
            ranges, cur, prev = [], sig[0] - LEAD, sig[0]
            for t in sig[1:]:
                if t - prev > STALL:
                    ranges.append(Range(cur, prev + KEEP))
                    cur = t - 0.04
                prev = t
            ranges.append(Range(cur, min(prev + TAIL, nxt)))
        beats.append({"beat": beat, "ranges": ranges, "hold": hold, "cap": cap})

    # Keep the preview at its target length (always inside Apple's 15-30 s) by
    # scaling the still holds: slower transitions leave less of the final state.
    fixed = sum(r.out for b in beats for r in b["ranges"])
    holds = sum(b["hold"] for b in beats)
    target = TARGETS.get(sb) or fixed + holds
    target = min(max(target, 16.0), 29.0)
    k = max((target - fixed) / holds, 0.2)

    segs, n = [], 0
    for b in beats:
        last = b["ranges"][-1]
        if last.speed == 1 and last.forced is None:
            last.r1 += b["hold"] * k
        else:
            b["ranges"].append(Range(last.r1, last.r1 + b["hold"] * k))
        for r in b["ranges"]:
            count = round(r.out * FPS)
            if count < 1:
                continue
            dur = count / FPS
            before = [p for p in pts if p <= r.r0]
            p0 = before[-1] if before else 0.0
            seg = f"{work}/seg{n:03d}.mp4"
            n += 1
            vf = (f"setpts=(PTS-STARTPTS)/{r.speed},fps={FPS},trim=start={(r.r0 - p0) / r.speed:.4f},"
                  f"setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration={dur + 1:.3f},trim=end_frame={count},"
                  f"scale={SCREEN_W}:{SCREEN_H}:flags=lanczos,setsar=1,format=yuv420p")
            run(["ffmpeg", "-v", "error", "-y", "-ss", f"{max(p0 - 0.001, 0):.4f}", "-i", raw,
                 "-t", f"{r.r1 - p0 + 0.5:.4f}", "-vf", vf, "-an",
                 "-c:v", "libx264", "-preset", "medium", "-crf", "14", "-r", str(FPS), seg])
            segs.append((seg, dur, b["cap"]))
        report.append(f"{b['beat']:10s} " + " ".join(str(r) for r in b["ranges"]))

    listfile = f"{work}/list.txt"
    with open(listfile, "w") as fh:
        fh.write("".join(f"file '{seg}'\n" for seg, _, _ in segs))
    body = f"{work}/body.mp4"
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listfile, "-c", "copy", body])
    total = sum(d for _, d, _ in segs)

    groups, t = [], 0.0
    for _, d, cap in segs:
        if groups and groups[-1][0] == cap:
            groups[-1][2] = t + d
        else:
            groups.append([cap, t, t + d])
        t += d

    loop = ["-loop", "1", "-framerate", str(FPS), "-t", f"{total:.3f}"]
    inputs = [*loop, "-i", f"{POST}/bg.png", "-i", body, *loop, "-i", f"{POST}/mask.png"]
    fg = ["[1:v]format=rgba[b1]", "[2:v]format=gray[mk]", "[b1][mk]alphamerge[scr]",
          f"[0:v][scr]overlay={SCREEN_X}:{SCREEN_Y}:shortest=1[v0]"]
    for k2, (cap, a, b) in enumerate(groups):
        inputs += [*loop, "-i", f"{POST}/cap/{sb}_{lang}_{cap}.png"]
        idx = 3 + k2
        chain = "format=rgba"
        if k2 > 0:
            chain += f",fade=in:st={a:.3f}:d={FADE:.3f}:alpha=1"
        if k2 < len(groups) - 1:
            chain += f",fade=out:st={b - FADE:.3f}:d={FADE:.3f}:alpha=1"
        fg.append(f"[{idx}:v]{chain}[c{k2}]")
        fg.append(f"[v{k2}][c{k2}]overlay=0:0[v{k2 + 1}]")
    fg.append(f"[v{len(groups)}]fps={FPS},format=yuv420p[vout]")
    out_dir = f"{HERE}/out"
    os.makedirs(out_dir, exist_ok=True)
    out = f"{out_dir}/{OUTNAMES[sb]}-{LOCALES[lang]}.mp4"
    run(["ffmpeg", "-v", "error", "-y", *inputs,
         "-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
         "-filter_complex", ";".join(fg), "-map", "[vout]", "-map", f"{3 + len(groups)}:a",
         "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "16", "-r", str(FPS),
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-ac", "2", "-ar", "48000",
         "-t", f"{total:.3f}", "-movflags", "+faststart", out])
    with open(f"{work}/report.txt", "w") as fh:
        fh.write("\n".join(report) + f"\ntotal={total:.2f}s\n")
    print("\n".join(report))
    print(f"total={total:.2f}s -> {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
