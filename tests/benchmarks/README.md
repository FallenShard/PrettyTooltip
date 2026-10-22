Run `python tests/benchmarks/placement.py` from the repository root. It compares
the retained native placement route with Pretty placement in isolated Lua 5.1
runtimes, with profiling disabled. Runs alternate mode order, warm up first,
and report the median of repeated elapsed-time samples. Use `--json PATH` to
save the samples and operation counts.

Pretty now uses relative frame anchors: comparisons attach vertically to the
main panel and horizontally to their neighbour. The main panel reserves their
horizontal space; columns clamp vertically on their own, including the equipped
labels above them. Taller comparisons do not hold the main above the bottom edge.
There is no stationary placement OnUpdate. The existing cursor tracker carries
cursor movement; a sticky drag enables input-area synchronization only while
dragging and reconsiders the side when crossing its available-space boundary.
Reports identify this implementation as `placement strategy: frame anchors`.

Workloads simulate 60 frames per second: one tooltip, two comparisons refreshed
every 12 frames, moving comparisons, stationary and dragged sticky comparisons,
a different item every frame, and all tooltips closed. The dragging workload
moves the native frame before calling the drag-only input synchronization;
movement stays within one comparison side. Native padding resets on Show are simulated.
Sticky workloads include both native and Pretty close buttons. Close-button
setup runs at placement completion; drag frames only synchronize the mouse area
and check comparison space. Insets reuse their stored values between updates.
Transient allocation is measured separately with garbage collection paused;
timed samples use normal garbage collection. Allocation is not retained memory.

These are harness timings. Frame geometry and clamp rectangles are implemented in Lua, and native
layout, rendering, GPU work and other addons are absent. Ratios cannot establish
in-game parity. The old route is selected with the same diagnostic toggle used
in-game; it is not a separate installation of a historical release.

Before removing that route, compare in-game captures:

1. `/reload`, then `/ptip placement native` and hover the item again.
2. `/ptip perf 10`. Perform one workload for the full capture.
3. `/ptip placement pretty`, hover the item again, and repeat `/ptip perf 10`.
4. Repeat at least three captures per mode, alternating the order. Use the same
   items, location, addons and frame-rate limit. Do not run `/ptip trace` during
   performance captures.

Capture each workload separately: all tooltips closed; one stationary tooltip;
stationary comparisons; moving between the same items; dragging the same sticky
tooltip with comparisons. Include opening links outside hover and returning
from the native-tooltip modifier when checking correctness.

Compare the non-overlapping `instrumented work` total in milliseconds per frame,
capture durations, frame counts, reader/render counts and anchor/padding writes.
Per-function rows are inclusive: adding them double-counts nested calls. Profiling
adds overhead in both modes, so also compare smoothness with profiling off.
Memory deltas in-game include collection and are not allocation rates.

Measure AH price hovering separately from dragging. Compare item reads/renders
per `auction content ready` call: a normal refill with two comparisons should
need three completed item renders. `partial render deferred` counts the main
item pass avoided while waiting for the auction completion callback.

Keep native placement until repeated real captures establish parity or better
for these workloads, with unchanged content and visibility. Treat a repeatable
slowdown as a failed comparison. A faster refill path does not compensate for a
regression while holding a stationary tooltip.
