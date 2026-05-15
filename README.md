# Roku Picture Frame

Turn a Roku into a wall-mountable digital picture frame that displays your own
photos from any static image host.

The app is a native Roku channel (BrightScript + SceneGraph) with a programmatic
matte, crossfade transitions, a slow Ken Burns pan/zoom, and an optional clock
and caption overlay. It reads a JSON **manifest** (a list of image URLs) so you
can host your photos anywhere you like — S3, Cloudflare R2, a NAS, GitHub Pages,
your own server — without rebuilding the app.

## How it works

```
config/config.json            ──►  manifestUrl
                                       │
                                       ▼
                                 JSON manifest (yours or the bundled sample)
                                       │
                                       ▼
                                 list of image URLs ──►  Roku Poster nodes
                                                              │
                                                              ▼
                                                    matte + bevel + Ken Burns
```

* The app fetches `manifestUrl` from `config/config.json` at startup.
* The manifest is a JSON file shaped like `sample/manifest.json`.
* Each entry's `url` is loaded into one of two `Poster` nodes that crossfade
  back and forth as the slideshow advances.
* Four `Rectangle` strips draw a matte around the photo; their colour and width
  are configurable.

## Install (sideload)

1. Enable **Developer Mode** on your Roku: `Home` ×3, `Up` ×2, `Right`, `Left`,
   `Right`, `Left`, `Right`. Set a developer password and note the device IP.
2. Build the channel zip:
   ```bash
   ./build.sh
   ```
   That produces `picture-frame.zip`.
3. In a browser open `http://<roku-ip>/` and upload `picture-frame.zip`.
   Or use the one-shot upload:
   ```bash
   ./build.sh 192.168.1.42 rokudev YOUR_DEV_PASSWORD
   ```

The first launch shows the bundled sample gallery (eight photos from
picsum.photos) so you can confirm everything works before configuring your own
feed.

## Use your own photos

1. Upload your photos to any static host (S3, R2, GitHub Pages, a NAS that
   serves over HTTPS, etc.).
2. Create a JSON manifest pointing at them — copy `sample/manifest.json` and
   edit the `images` array:
   ```json
   {
       "title": "My Photos",
       "images": [
           { "url": "https://photos.example.com/2024/beach.jpg", "caption": "Beach trip" },
           { "url": "https://photos.example.com/2024/wedding.jpg" }
       ]
   }
   ```
   `caption` is optional. Entries can also be plain strings if you don't want
   captions.
3. Upload the manifest somewhere reachable from your Roku (same host is fine).
4. Edit `config/config.json` and change `manifestUrl` to its public HTTPS URL.
5. Re-run `./build.sh` and re-sideload.

## Configuration

All settings live in `config/config.json`:

| Setting                    | Default                         | Notes                                                                          |
| -------------------------- | ------------------------------- | ------------------------------------------------------------------------------ |
| `manifestUrl`              | `pkg:/sample/manifest.json`     | HTTPS URL or `pkg:/` path to a JSON manifest                                   |
| `slideDurationSeconds`     | `8`                             | Seconds each photo holds before advancing                                      |
| `crossfadeDurationSeconds` | `1.2`                           | Length of the fade between photos                                              |
| `kenBurns`                 | `true`                          | Slow randomised zoom + pan on each photo                                       |
| `shuffle`                  | `true`                          | Randomise order on each launch                                                 |
| `imageFit`                 | `"fill"`                        | `"fill"` (crop to fill), `"fit"` (letterbox), or `"stretch"`                   |
| `matteColor`               | `"0xF2EBDDFF"`                  | ARGB hex of the matte board                                                    |
| `matteWidth`               | `80`                            | Matte thickness in pixels at 1920×1080                                         |
| `bevelEnabled`             | `true`                          | Thin shadow line inside the matte opening                                      |
| `bevelColor`               | `"0x000000AA"`                  | ARGB hex                                                                       |
| `backgroundColor`          | `"0x0F0F0FFF"`                  | Visible only if the matte doesn't fully cover (shouldn't be)                   |
| `showCaption`              | `true`                          | Show the caption inside the bottom matte                                       |
| `captionColor`             | `"0x303030FF"`                  | Caption text colour                                                            |
| `showClock`                | `true`                          | Show a clock in a matte corner                                                 |
| `clockColor`               | `"0x303030FF"`                  | Clock text colour                                                              |
| `clockPosition`            | `"bottom-right"`                | `top-left`, `top-right`, `bottom-left`, or `bottom-right`                      |
| `use24Hour`                | `false`                         | 12-hour vs 24-hour clock                                                       |

## Remote controls during the slideshow

| Button             | Action                          |
| ------------------ | ------------------------------- |
| `OK` / `Play/Pause`| Pause / resume                  |
| `▶` / `▶▶`         | Next photo                      |
| `◀` / `◀◀`         | Previous photo                  |
| `*` (Options/Info) | Open the on-device settings    |
| `Back`             | Exit channel                    |

## On-device settings

Press the `*` button on the remote to open the settings panel. All effects
configurable in `config.json` are also tweakable on the TV:

* Slide duration, crossfade duration
* Ken Burns motion on/off
* Shuffle on/off
* Image fit (fill / fit / stretch)
* Matte width and matte colour (9 presets)
* Bevel line on/off
* Caption and clock visibility, clock position, 12/24-hour clock
* **Reset to defaults** (clears all on-device overrides)
* **Done** (closes the panel)

Use `Up` / `Down` to navigate, `OK` or `◀ ▶` to cycle a value, and `Back` (or
`*` again) to close. Every change is applied live and persisted in the Roku's
per-channel registry — they survive restarts and reinstalls. `config.json`
remains the authoritative defaults; the registry only stores overrides.

## Repository layout

```
manifest                Roku channel manifest
source/main.brs         Entry point
components/             SceneGraph components
  MainScene.xml/.brs      slideshow scene
  ManifestTask.xml/.brs   background JSON fetch
config/config.json      User settings
sample/manifest.json    Example image feed
images/                 Channel icons + splash (generated)
scripts/gen_assets.py   Regenerate the icons + splash
build.sh                Zip + optional sideload
```

## Notes & limits

* The Roku can't browse a bucket or folder directly — that's what the manifest
  is for. If you want hands-off updates, regenerate the manifest from your photo
  source (e.g. a tiny script that lists an S3 prefix and writes JSON).
* HTTPS sources need a valid certificate. `roUrlTransfer` is initialised with
  the system CA bundle so any normal CA-signed host works.
* All UI sizes are authored for `1920×1080` (FHD). Roku scales automatically
  for HD/4K displays.
