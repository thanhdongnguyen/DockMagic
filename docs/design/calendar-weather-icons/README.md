# Calendar weather pictograms

Eight pictograms were generated with ImageGen for the approved Option 2 Calendar
design, then traced to true-color SVGs. The original transparent PNGs remain in
`sources/`; the production vectors are in
`DockMagic/DockMagic/Assets.xcassets/CalendarWeather*.imageset/`.

The shared prompt direction was: one isolated, rounded geometric weather
pictogram centered on a fully transparent square canvas, with crisp solid
colors, no outline, shadow, text or background, legible at 12 px. The
partly-cloudy sun/cloud icon established the visual reference. Separate
generations provided sun, cloud, rain, storm, snow/ice, moon, and wind.

To regenerate the vectors, install `Pillow` and `vtracer` in a temporary Python
environment, then run `script/convert_calendar_weather_icons.py` with that
environment's `PYTHONPATH`. The script thresholds stray transparent pixels,
reduces colors, traces spline paths and writes Xcode vector asset manifests.
No embedded raster data is used in the SVGs.

The [approved concept](approved-option-2.png) and [visual QA](verification/option2-comparison.jpg)
are retained separately from the production assets.

The follow-up Calendar render uses 18 pt pictograms in month cells, 44 pt in
the selected-day summary, and 25 pt at hourly stops. Summary and hourly icons
sit directly on the weather scene without a white circular badge or border.
The [current light](verification/dashboard-light.png) and
[dark](verification/dashboard-dark.png) captures show the implemented sizing.
