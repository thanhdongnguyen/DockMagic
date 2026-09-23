# Custom Dock Gate 0 probes

These are standalone experiments, not part of the DockMagic app target. Build with
`./build.sh`. The output is `/private/tmp/dockmagic-shelf-probe` by default.
`placement.txt` accepts `bottom`, `left`, or `right`; restart the app after
changing it. The probe uses a floating, nonactivating AppKit panel, an opt-in
edge watcher, and a local `CFMessagePort` named `DockMagicProbeHandoff`.

`FastDockHandoff <seconds> <edge>` reads the native Dock's Accessibility frame,
sends state to the probe, and writes a timestamped `fast-handoff-*.csv` plus
`fast-handoff.csv` as the latest copy. It requires existing
Accessibility access for the process that runs it. The app never changes Dock
preferences. `DockWindowDump` and `PointerTrace` are read-only diagnostics;
`DockAXObserverProbe` records which AX notifications the native Dock supports.
The probe starts hidden until the watcher confirms Apple Dock is offscreen,
and hides again if watcher heartbeats stop for 150 ms. The watcher reacquires
the Dock AXList after a Dock restart and reports candidate overlap samples.
The watcher also reads the foreground window's public `AXFullScreen` attribute
and hides the probe while that window is full-screen. `FrontmostFullScreen`
prints the same Accessibility state for manual verification. This covers the
foreground full-screen window on the test machine; per-display Spaces and
switching between full-screen apps still need separate validation.

The opt-in XCUITest `testCustomDockProbeYieldsToNativeDockAtPhysicalEdge` in
`DockMagicUITests.swift` moves the actual pointer to the selected edge and
checks `replacement.log`. It passed 46 edge cycles across bottom, left and
right; this does not pass Gate 0 because a separate System Settings handoff
recorded overlapping bounds. The test remains opt-in so ordinary tests do not
alter the physical pointer. After building the UI test, launch the prototype
and `FastDockHandoff`, enable native Dock auto-hide, then run
`./run-gate0-ui-test.sh bottom 1` (or `left`/`right`; up to 100 cycles). The
script checks Dock preferences and never changes them.

`DockFrameCapture` records a narrow strip of the main display using public
ScreenCaptureKit. New captures include `frame-index.csv` with presentation,
WindowServer display, and callback times, plus `event-index.csv` for complete
and idle frame events. Use display time for correlation: callback/PNG handling
can lag by tens of milliseconds. On the macOS 26.2 test machine, presentation
and display times matched to the printed microsecond.
`SettingsDockAX` locates and can press the actual auto-hide
checkbox in System Settings when that pane is open. For a controlled
right-edge diagnostic, `bash run-gate0-frame-capture.sh settings-ax` records
one Settings AX action; use `settings-pointer` to post mouse down/up events to
the checkbox. `bash run-gate0-burst-settings-ax.sh ax` or `pointer` records ten
corresponding transitions. The pointer variant reproduced a 2 pt geometric
overlap in one of ten clicks.
`SettingsValueObserver` subscribes to `AXValueChanged` on the auto-hide
checkbox and logs notification uptime. With `--preempt`, it sends an
acknowledged hide message to the panel before reading the new checkbox value.
`run-gate0-burst-settings-ax.sh ax-observer bottom 20` exercises this path with
validated, separate Dock calls and a bounded capture. The observer only covers
this System Settings control; it is not a general signal that Apple Dock will
appear through other apps, shortcuts or process state changes.
`run-gate0-burst-settings-ax.sh applescript-observer bottom 10` makes the
auto-hide change from another process while the Settings observer is active.
Across bottom/left/right it completed ten valid transitions on each edge; every
Settings value-0 notification arrived after the watcher had seen Apple Dock
begin to move. Two bottom-edge `CGWindowList` bounds intersections were logged,
but the captured display frames around them did not show both surfaces.
Seven `ax-observer` runs completed 100/100 acknowledged Settings transitions
across bottom/left/right and both displays on macOS 26.2, with no sampled bounds
intersection. See the QA report for the full counts and remaining failures in
other paths. `pointer-slow` holds synthetic mouse-down for 80 ms; the ordinary
10 ms `pointer` click once failed to change the setting and must not be counted
as a transition without checking the preference.
`validate_settings_observer.py RUN_DIR CYCLES` pairs each native Dock show with
an acknowledged observer event and checks the watcher for bounds intersections.
It deliberately does not treat zero sampled intersections as frame-perfect proof.
`scan_composited_frames.py EDGE FRAME_DIRECTORY` scans the captured PNGs for a
fixed probe `+` template and bright Apple Dock icons in a separate region. It
is calibrated only for the macOS 26.2 desktop/crops documented in the QA report;
zero co-detections do not prove arbitrary pixels or uncaptured frames are safe.
`DockInputPreflight` is a separate, opt-in CLI experiment: it watches the
Settings auto-hide checkbox with a public Quartz event tap and waits for the
prototype panel to acknowledge hiding before passing the click through.
It now accepts `DockInputPreflight <seconds> edge <bottom|left|right>` to
preempt mouse movement at the physical Dock edge, or `all` for both routes.
`run-gate0-edge-burst.sh <edge> <cycles>` (up to 24 per captured session)
temporarily changes Dock orientation and auto-hide, then verifies the pointer
position, native Dock visibility, one edge ACK paired with each Dock show, and
zero watcher overlap candidates. It records frames and restores the original
Dock settings even on failure. `validate_edge_burst.py` checks event pairing
from the run's logs; it does not inspect every captured pixel.
With Dock magnification at the System Settings slider value `0.5`, ten cycles
on each edge passed event pairing with no sampled bounds intersection; the
calibrated image scanner found no frame with both Dock markers among 6,010
complete frames. The magnification slider was restored to its original value
`0` after these runs. This covers the pointer-edge route only.
`bash run-gate0-frame-capture.sh settings-orca-helper` runs one driver click;
`bash run-gate0-burst-settings-ax.sh orca-helper <bottom|left|right>` runs ten.
Across three runs it recorded zero geometric overlap in 30 validated Settings
click cycles on macOS 26.2. The left run recorded eight alpha-positive samples
while the native Dock bounds were still offscreen. `DockFrameCapture` selects
the display for the requested edge, including the secondary left display.
`orca-no-helper` repeats Computer clicks without the event tap; one of ten
validated bottom-edge clicks reproduced geometric overlap. `ax` invokes the
checkbox Accessibility action, and `applescript` changes the preference through
System Events; both confirm the preference transition before counting a cycle.
`pointer-helper` runs one edge movement and ten synthetic Settings clicks with
the combined input helper. A 10 ms synthetic click was ACKed but did not toggle
the checkbox in one trial; the 80 ms variant toggled it ten times. The edge
movement in that mixed run did not make Apple Dock appear, so it is not counted
as a handoff cycle.
`run-gate0-dock-restart.sh bottom 10` captures ten Dock process restarts and
checks the watcher’s fail-closed recovery while auto-hide is enabled.
`run-gate0-interaction-session.sh bottom 90` opens a bounded interactive probe
session, then restores auto-hide. `MovePointer` and `PointerClick` post pointer
events at global display coordinates; `PointerPosition` reads the actual cursor
position, `SetWindowPosition <pid> <window-title> <x> <y>` moves a test window
through its public Accessibility position attribute, and `ProbeAXAction` inspects the prototype's
Accessibility tree. These diagnostics verified hover, the trailing `+`, two
Weather slots with distinct IDs, Finder/Safari activation, and yielding to the
native Dock while a dashboard was open on the bottom and right edges. Adding a
feature through `+` was exercised on all three edges. The probe still uses
placeholder feature tiles, so those checks do not prove production renderer
parity. The right-edge interaction session was not captured frame by frame.
The helper needs Accessibility and Input Monitoring grants. Its checkbox frame
and the Orca window coordinates in the scripts are specific to the current
diagnostic desktop, not production geometry logic.
These scripts change the native Dock auto-hide setting temporarily and restore
its original value through a shell trap. The burst script requires the native
Dock to be on the selected edge and an existing Accessibility grant. Open the
Desktop & Dock pane in System Settings before using helper mode; it does not
navigate from another pane. The single-frame script still requires the right
edge. The captured desktop
strips remain in `/private/tmp/dockmagic-shelf-probe`, outside the repository.

Run experiments only with Apple Dock auto-hide temporarily enabled. Restore
the original Dock position and auto-hide preference after testing. The current
Gate 0 status and measured limitations are in
[`CUSTOM_DOCK_GATE0_QA_2026-09-20.md`](../../../CUSTOM_DOCK_GATE0_QA_2026-09-20.md).
