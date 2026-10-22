"""Compare retained native placement and Pretty placement in the Lua 5.1 harness.

This measures Lua stand-ins, not the game's layout engine. Use /ptip perf in
both modes before drawing an in-game performance conclusion.
"""

import argparse
import json
from pathlib import Path
import statistics
import sys
from time import perf_counter_ns

TESTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TESTS))
import run as test_runner  # noqa: E402

SCENARIOS = ("closed", "single", "comparisons", "moving comparisons", "sticky comparisons", "sticky dragging", "refills")


def create(mode, scenario):
    lua, load, harness = test_runner.new_runtime()
    factory = load(Path(__file__).with_suffix(".lua").read_text(encoding="utf-8"), "benchmarks/placement.lua")
    worker = factory(harness["wow"], test_runner.sources_table(lua, test_runner.every_source()), mode, scenario)
    return lua, worker


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames", type=int, default=1200)
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--warmup", type=int, default=240)
    parser.add_argument("--json", type=Path, help="write results to this optional output file")
    args = parser.parse_args()
    if args.frames < 120 or args.repeat < 3 or args.warmup < 120:
        parser.error("use at least 120 frames, 3 repeats and 120 warmup frames")
    results = []
    print(f"Lua 5.1 harness; {args.frames} frames/run, {args.repeat} repeats, {args.warmup} warmup frames.")
    print("Profiler OFF; median elapsed us/frame includes normal GC. Synthetic 60 Hz; comparisons refill every 12 frames.")
    print("This does NOT measure WoW's engine layout, rendering, or real FPS.")
    print(f"{'workload':23} {'native us/f':>12} {'pretty us/f':>12} {'ratio':>8} {'native KB/f':>12} {'pretty KB/f':>12}")
    for scenario in SCENARIOS:
        workers = {mode: create(mode, scenario) for mode in ("native", "pretty")}
        samples = {mode: [] for mode in workers}
        for _, worker in workers.values():
            worker.run(args.warmup)
            worker.validate()
        for repeat in range(args.repeat):
            for mode in (("native", "pretty") if repeat % 2 == 0 else ("pretty", "native")):
                worker = workers[mode][1]
                worker.collect()
                started = perf_counter_ns()
                worker.run(args.frames)
                samples[mode].append((perf_counter_ns() - started) / args.frames / 1000)
                worker.validate()
        row = {"scenario": scenario, "modes": {}}
        for mode, (_, worker) in workers.items():
            row["modes"][mode] = {
                "median_us_per_frame": statistics.median(samples[mode]),
                "samples_us_per_frame": samples[mode],
                "allocated_kb_per_frame_gc_paused": worker.allocation(120),
                "writes_per_120_frames": dict(worker.counts(120).items()),
            }
        old, new = row["modes"]["native"], row["modes"]["pretty"]
        row["ratio"] = new["median_us_per_frame"] / old["median_us_per_frame"]
        results.append(row)
        print(f"{scenario:23} {old['median_us_per_frame']:12.2f} {new['median_us_per_frame']:12.2f} {row['ratio']:8.2f}"
              f" {old['allocated_kb_per_frame_gc_paused']:12.2f} {new['allocated_kb_per_frame_gc_paused']:12.2f}", flush=True)
    print("KB/frame is transient Lua allocation with GC paused in a separate pass, not retained memory.")
    print("Native mode is the retained diagnostic route in this checkout; both modes share the same harness and content.")
    for row in results:
        print(row["scenario"] + " writes/120 frames: " + "; ".join(
            mode + " " + json.dumps(data["writes_per_120_frames"], sort_keys=True)
            for mode, data in row["modes"].items()))
    if args.json:
        args.json.write_text(json.dumps({"frames": args.frames, "repeat": args.repeat, "warmup": args.warmup,
                                         "results": results}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
