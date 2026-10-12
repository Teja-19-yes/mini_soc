#!/usr/bin/env python3
"""
plot_vcd.py - turn a VCD waveform file into a PNG image (no GTKWave needed).

Needs only Python 3 and matplotlib   (pip install matplotlib)

Examples
--------
List the signals stored in a VCD:
    python3 plot_vcd.py axi_lite_soc_top.vcd --list

Plot chosen signals for a time window (times in ns):
    python3 plot_vcd.py axi_lite_soc_top.vcd -s ACLK M_AWVALID M_AWREADY M_WVALID \
        M_WREADY M_BVALID M_BREADY --start 100 --end 300 -o write.png

Let the script find the first write for you (window starts just before the
first rising edge of M_AWVALID and lasts --span ns):
    python3 plot_vcd.py axi_lite_soc_top.vcd -s ACLK M_AWADDR M_AWVALID M_AWREADY \
        M_WDATA M_WVALID M_WREADY M_BRESP M_BVALID M_BREADY \
        --around M_AWVALID --span 150 -o write.png

Window at the first DECERR response (BRESP == 3):
    python3 plot_vcd.py axi_lite_soc_top.vcd -s ACLK M_AWADDR M_AWVALID M_BVALID M_BRESP \
        --around M_BRESP=3 --span 100 -o error.png

Signal names can be short (M_AWVALID) or full (tb.dut.M_AWVALID). If several
signals share a short name, the one nearest the top of the hierarchy is used.
"""
import argparse
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

UNIT_TO_NS = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}


# ----------------------------------------------------------------------------
# VCD parsing
# ----------------------------------------------------------------------------
def parse_vcd(path):
    """Return (signals, changes, ns_per_tick).

    signals : {full_name: (vcd_id, width)}
    changes : {vcd_id: [(time_ns, value_string), ...]}   (value like '1' or '1010')
    """
    with open(path, "r") as f:
        tokens = f.read().split()

    signals, changes = {}, {}
    scopes = []
    ns_per_tick = 1e-3                      # default: 1 ps
    i, n = 0, len(tokens)

    def until_end(start):
        j = start
        while j < n and tokens[j] != "$end":
            j += 1
        return tokens[start:j], j + 1

    # ---- header ----
    while i < n:
        t = tokens[i]
        if t == "$timescale":
            body, i = until_end(i + 1)
            txt = "".join(body)
            num = "".join(c for c in txt if c.isdigit() or c == ".")
            unit = txt[len(num):]
            ns_per_tick = float(num or 1) * UNIT_TO_NS.get(unit, 1e-3)
        elif t == "$scope":
            body, i = until_end(i + 1)
            scopes.append(body[1] if len(body) > 1 else body[0])
        elif t == "$upscope":
            _, i = until_end(i + 1)
            if scopes:
                scopes.pop()
        elif t == "$var":
            body, i = until_end(i + 1)
            width, vid, name = int(body[1]), body[2], body[3]
            full = ".".join(scopes + [name])
            signals[full] = (vid, width)
            changes.setdefault(vid, [])
        elif t == "$enddefinitions":
            _, i = until_end(i + 1)
            break
        else:
            i += 1

    # ---- value changes ----
    now = 0.0
    while i < n:
        t = tokens[i]
        if t.startswith("#"):
            now = int(t[1:]) * ns_per_tick
            i += 1
        elif t.startswith("$"):             # $dumpvars, $end, ...
            i += 1
        elif t[0] in "bB":
            val, vid = t[1:], tokens[i + 1]
            if vid in changes:
                changes[vid].append((now, val))
            i += 2
        elif t[0] in "rR":
            i += 2
        else:                               # scalar: <value><id>
            val, vid = t[0], t[1:]
            if vid in changes:
                changes[vid].append((now, val))
            i += 1
    return signals, changes, ns_per_tick


def find_signal(signals, name):
    """Resolve a short or full signal name to its full hierarchical name."""
    if name in signals:
        return name
    hits = [s for s in signals if s == name or s.endswith("." + name)]
    if not hits:
        sys.exit(f"Signal '{name}' not found. Use --list to see available names.")
    return min(hits, key=lambda s: s.count("."))


# ----------------------------------------------------------------------------
# plotting helpers
# ----------------------------------------------------------------------------
def value_at(events, t):
    """Value of a signal at time t, given its sorted change list."""
    cur = None
    for tt, v in events:
        if tt <= t:
            cur = v
        else:
            break
    return cur


def segments(events, t0, t1):
    """Return [(start, end, value)] covering [t0, t1]."""
    first = value_at(events, t0)
    pts = [(t0, first if first is not None else "x")]
    for tt, v in events:
        if t0 < tt < t1:
            pts.append((tt, v))
    segs = []
    for k, (ts, v) in enumerate(pts):
        te = pts[k + 1][0] if k + 1 < len(pts) else t1
        segs.append((ts, te, v))
    return segs


def to_hex(v):
    if any(c in v.lower() for c in "xz"):
        return v
    return "0x%X" % int(v, 2)


def draw_bit(ax, segs):
    xs, ys = [], []
    for ts, te, v in segs:
        y = 1.0 if v == "1" else 0.0 if v == "0" else 0.5
        xs += [ts, te]
        ys += [y, y]
    ax.plot(xs, ys, drawstyle="steps-post", color="#185FA5", linewidth=1.6)
    ax.set_ylim(-0.25, 1.25)


def draw_bus(ax, segs, window):
    slant = window * 0.004
    for ts, te, v in segs:
        bad = any(c in v.lower() for c in "xz")
        col = "#A32D2D" if bad else "#0F6E56"
        a, b = ts + slant, te - slant
        if b <= a:
            a, b = ts, te
        ax.plot([ts, a, b, te], [0.5, 1, 1, 0.5], color=col, linewidth=1.2)
        ax.plot([ts, a, b, te], [0.5, 0, 0, 0.5], color=col, linewidth=1.2)
        if (te - ts) > window * 0.045:
            ax.text((ts + te) / 2, 0.5, to_hex(v), ha="center", va="center",
                    fontsize=8, color=col)
    ax.set_ylim(-0.25, 1.25)


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Convert a VCD file to a waveform PNG.")
    ap.add_argument("vcd")
    ap.add_argument("-s", "--signals", nargs="+", help="signals to plot, top to bottom")
    ap.add_argument("-o", "--out", default="waveform.png")
    ap.add_argument("--start", type=float, help="window start in ns")
    ap.add_argument("--end", type=float, help="window end in ns")
    ap.add_argument("--around", help="window starts just before the first rising edge of SIG, "
                                     "or the first time SIG==VALUE when given as SIG=VALUE (e.g. M_BRESP=3)")
    ap.add_argument("--span", type=float, default=150.0, help="window length in ns with --around")
    ap.add_argument("--lead", type=float, default=20.0, help="ns shown before the --around event")
    ap.add_argument("--title", default=None)
    ap.add_argument("--list", action="store_true", help="list all signals and exit")
    args = ap.parse_args()

    signals, changes, _ = parse_vcd(args.vcd)

    if args.list:
        for name in sorted(signals):
            print(f"{name}  [{signals[name][1]} bit]")
        return
    if not args.signals:
        sys.exit("Give signals with -s (or use --list).")

    resolved = [find_signal(signals, s) for s in args.signals]
    all_times = [t for ev in changes.values() for t, _ in ev]
    t_min, t_max = (min(all_times), max(all_times)) if all_times else (0.0, 1.0)

    if args.around:
        name, _, target = args.around.partition("=")
        ev = changes[signals[find_signal(signals, name)][0]]
        if target:                                   # SIG=VALUE (decimal or 0x..)
            want = int(target, 0)
            hits = [t for t, v in ev
                    if not any(c in v.lower() for c in "xz") and int(v, 2) == want]
        else:                                        # first rising edge
            hits = [t for t, v in ev if v == "1" and t > 0]
        if not hits:
            sys.exit(f"'{args.around}' never happens in this VCD.")
        t0 = max(t_min, hits[0] - args.lead)
        t1 = t0 + args.span
    else:
        t0 = args.start if args.start is not None else t_min
        t1 = args.end if args.end is not None else t_max
    if t1 <= t0:
        sys.exit("Window end must be after window start.")
    window = t1 - t0

    rows = len(resolved)
    fig, axes = plt.subplots(rows, 1, sharex=True,
                             figsize=(12, max(2.2, 0.62 * rows + 0.9)))
    if rows == 1:
        axes = [axes]

    for ax, full in zip(axes, resolved):
        vid, width = signals[full]
        segs = segments(changes[vid], t0, t1)
        if width == 1:
            draw_bit(ax, segs)
        else:
            draw_bus(ax, segs, window)
        ax.set_ylabel(full.split(".")[-1], rotation=0, ha="right", va="center", fontsize=9)
        ax.set_yticks([])
        ax.grid(axis="x", color="#D3D1C7", linewidth=0.5)
        for side in ("top", "right", "left"):
            ax.spines[side].set_visible(False)
        ax.spines["bottom"].set_color("#D3D1C7")

    axes[-1].set_xlim(t0, t1)
    axes[-1].set_xlabel("Time (ns)")
    if args.title:
        fig.suptitle(args.title, fontsize=11)
    fig.tight_layout()
    fig.savefig(args.out, dpi=200, facecolor="white")
    print(f"Saved {args.out}  (window {t0:.0f} - {t1:.0f} ns, {rows} signals)")


if __name__ == "__main__":
    main()
