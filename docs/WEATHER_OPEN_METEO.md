# Open-Meteo Weather for DockMagic

## Integration decision

DockMagic is distributed directly with Developer ID, not through the Mac App
Store. Weather uses the public macOS Core Location API to obtain the current
coordinates and then calls the Open-Meteo Forecast API directly over HTTPS.
Users do not need to create a Shortcut, install a helper app, or sign in to an
account.

Default open-access endpoint:

```text
https://api.open-meteo.com/v1/forecast
```

One request retrieves both the current conditions and the daily summary:

```text
latitude=<lat>
longitude=<lon>
current=temperature_2m,apparent_temperature,weather_code,is_day
daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max
temperature_unit=celsius
timezone=auto
forecast_days=1
```

These fields map to `WeatherSnapshot`; `weather_code` uses Open-Meteo's official
WMO table. Temperature, precipitation probability, coordinates, and the HTTP
response are validated before reaching the UI.

Official sources: [Open-Meteo Forecast API](https://open-meteo.com/en/docs),
[pricing/authentication](https://open-meteo.com/en/pricing),
[terms](https://open-meteo.com/en/terms), and the
[CC BY 4.0 license](https://open-meteo.com/en/licence).

## Authentication and license

The default build uses the open-access endpoint and does not send an API key.
Under Open-Meteo's current terms, this endpoint is for non-commercial use only,
with limits of 10,000 API calls per day, 5,000 per hour, and 600 per minute; it
has no uptime guarantee.

The commercial plan uses a separate endpoint:

```text
https://customer-api.open-meteo.com/v1/forecast?...&apikey=<key>
```

`OpenMeteoWeatherProvider` supports injecting a customer endpoint and `apikey`,
with a unit test for query authentication. Before distributing DockMagic under
a commercial model, the product owner must purchase an appropriate plan and
choose how to provision the key. A key embedded in the desktop binary or
Info.plist can be extracted; a DockMagic-controlled proxy provides a stronger
security boundary when the key must remain secret.

Open-Meteo data is licensed under CC BY 4.0. Weather Settings always displays
the `Open-Meteo · CC BY 4.0` link. This attribution is a product contract and
must not be removed when simplifying the UI.

## Location, polling, and state

DockMagic refreshes automatically when the user opens Weather Settings or
selects Weather as the active Dock feature. The first refresh calls
`requestWhenInUseAuthorization()`, and macOS displays the permission prompt
based on `NSLocationUsageDescription`; Settings has no separate connection or
setup form. Once authorized, the app makes a one-shot `requestLocation()` call
with three-kilometer accuracy and a 20-second timeout. It does not continuously
track location.

Core Location reverse-geocodes the coordinates into a locality and country name
for the `Location` row in the Weather Dock preview. If reverse geocoding does
not return a name within three seconds, the app cancels this step and uses a
locality inferred from the Open-Meteo time zone before falling back to
`Current Location`. Name lookup must not hold the entire refresh cycle
indefinitely.

If authorization is not valid, the request is blocked before reaching the
provider, so DockMagic does not call Open-Meteo or send coordinates. When the
user restores authorization in System Settings and returns to DockMagic,
Weather checks again and refreshes automatically.

- Only while Weather is the active feature does `WeatherStore` refresh
  immediately and then poll every 10 minutes (`600` seconds).
- After the Mac wakes or the user session becomes active again after unlock,
  active Weather polling is re-armed and refreshed immediately instead of
  waiting for the next interval.
- Forecast requests bypass the local URL cache and require revalidation so each
  cycle reads current data from the provider.
- The refresh button calls the same provider and is deduplicated against an
  in-progress refresh.
- Switching features or quitting cancels both the polling task and the active
  refresh or location request.
- A snapshot with an `observedAt` value older than 45 minutes is marked `stale`.
- If a refresh fails, the most recent successful snapshot remains visible with
  a clock badge.
- Before the first successful refresh, Dock and Settings report `unavailable`
  rather than creating placeholder data.

## Privacy

Each refresh sends the current latitude and longitude to Open-Meteo over HTTPS.
DockMagic persists only a normalized snapshot for failure tolerance; the app
does not retain location history, API credentials, prompts, or account
identifiers. According to Open-Meteo's privacy terms, server logs may contain
the IP address and coordinates for troubleshooting and are deleted after 90
days.

The Open-Meteo cache uses a separate namespace. Legacy Weather Shortcut
snapshots are not restored, preventing Open-Meteo attribution from being
attached to old Apple Weather data.

Users can revoke authorization in `System Settings > Privacy & Security >
Location Services`. When Location Services is disabled or authorization is
denied, the Weather preview displays the corresponding Location state and any
old cached data remains stale.

## Verification contract

- Unit: URL/query construction, free endpoint without a key, paid endpoint with
  `apikey`, current/daily JSON, WMO mapping, time-zone conversion, invalid
  payloads, HTTP errors, cache/stale/deduplication/cancellation, Location
  permission preflight and recovery, location-name resolution, and the default
  600-second polling interval.
- Integration: call the real endpoint with public test coordinates without
  depending on the test machine's Location permission.
- Runtime: launch a locally signed app and verify the Location prompt,
  allow/deny flows, a real refresh, and attribution in Settings.
- Release: verify the plan and license, Developer ID, Hardened Runtime,
  notarization, Gatekeeper, and real pixels in the system Dock.

An offscreen renderer or AX tree does not replace observing pixels produced by
the system Dock compositor or manually testing VoiceOver before release.
