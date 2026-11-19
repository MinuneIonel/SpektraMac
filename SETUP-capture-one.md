# Setting up SpektraMac + Capture One on a new Mac

This builds the Capture One version of SpektraMac (Save Back to Original, Copy / Paste Look) and the
SpektraDroplet batch app from the `capture-one-roundtrip` branch of the fork, then sets up Capture One.
It takes about 15 minutes, most of it the first build.

## Doing it with Claude Code

On the new Mac, install Xcode 27 and open it once (step 1). Then start Claude Code in your home
folder or any projects folder and paste this:

> Set up SpektraMac for Capture One on this Mac. Clone https://github.com/MinuneIonel/SpektraMac.git
> on the `capture-one-roundtrip` branch into ~/Projects/SpektraMac (or `git pull` there if it
> already exists), then follow SETUP-capture-one.md in that repo: steps 3 to 6. Use
> `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` instead of sudo xcode-select.
> Ask me before deleting anything in /Applications. When done, confirm that
> /Applications/SpektraMac.app and /Applications/SpektraDroplet.app exist, and that SpektraMac's
> menus include Save Back to Original, Copy Look and Paste Look (check the strings in the app
> binary, or open the app). Then show me step 7, the Capture One setup, which I'll do myself.

Claude Code can't change Capture One's settings for you, so step 7 is yours to do.

## 1. What you need

- macOS 26.5 or newer
- **Xcode 27** from the App Store or developer.apple.com. You need the full app, not just the Command
  Line Tools. Open it once after installing so it can finish setting up and you can accept the licence.
- Capture One 16.5 or newer
- git, which comes with Xcode

## 2. Get the code

```bash
git clone -b capture-one-roundtrip https://github.com/MinuneIonel/SpektraMac.git ~/Projects/SpektraMac
```

```bash
cd ~/Projects/SpektraMac
```

If upstream ([nainajnahO/SpektraMac](https://github.com/nainajnahO/SpektraMac)) has merged these
changes by the time you read this, clone it instead and use its `main` branch.

## 3. Point the build tools at Xcode

On many Macs `xcode-select` points at the Command Line Tools, and then `xcodebuild` fails with
"requires Xcode". Set this in the Terminal window you build from:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Or fix it for good. This asks for your password:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 4. Build the app

This builds a Release copy, signed to run on this Mac only, so you don't need an Apple developer account:

```bash
xcodebuild -project SpektraMac.xcodeproj -scheme SpektraMac -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual build
```

When it finishes it prints `** BUILD SUCCEEDED **`, and the app is at
`build/Build/Products/Release/SpektraMac.app`.

You can build from Xcode instead: open `SpektraMac.xcodeproj`, choose **Sign to Run Locally**
under the SpektraMac target's **Signing & Capabilities**, then **Product › Build** (⌘B). That build lands in Xcode's DerivedData folder, not `build/`. **Product › Show Build Folder in Finder** finds it.

## 5. Build the droplet (for batches)

```bash
tools/capture-one/make-droplet.sh
```

This builds `spektra-cli` and writes `build/SpektraDroplet.app` with the CLI inside it.

## 6. Install

Quit any SpektraMac that's running. If there's an older SpektraMac in /Applications, it gets
replaced. The older one has the bug that duplicates half of each row in large TIFFs.

```bash
rm -rf /Applications/SpektraMac.app /Applications/SpektraDroplet.app
```

```bash
cp -R build/Build/Products/Release/SpektraMac.app build/SpektraDroplet.app /Applications/
```

Open SpektraMac once from /Applications so macOS registers it as an editor for TIFF and PNG files.

**Check:** SpektraMac's **File** menu has **Save Back to Original** (⌥⌘S), and its **Edit** menu has
**Copy Look** (⌥⌘C) and **Paste Look** (⌥⌘V). If they're missing, you're running an old build.

## 7. Set up Capture One

### Develop the RAW for film

Before you send a photo to SpektraMac:

1. **Base Characteristics › Curve: Linear Response.** The default curve already adds a film-like
   tone curve, and SpektraMac would add a second one on top of it.
2. Expose so nothing important clips.
3. Leave out contrast, saturation and styles. White balance, lens corrections, crops and spot
   removal are fine.

Tip: save these settings as a user preset or a style so you can apply them in one click.

### One photo at a time: Edit With

1. Right-click a photo › **Edit With…**
2. Choose **TIFF**, **16 bit**, and the ICC profile **ProPhoto RGB** or **Adobe RGB (1998)**.
   Under **Open With** choose **SpektraMac**, then click **Edit Variant**.
3. Choose the film and paper in SpektraMac and adjust the photo.
4. **File › Save Back to Original** (⌥⌘S). Capture One updates the variant's thumbnail.

Capture One remembers these settings, so next time Edit With is a single click.

### The same look on more photos: Copy / Paste Look

- On a finished photo: **Edit › Copy Look** (⌥⌘C). This copies every setting except exposure.
- On the next photo, open it with Edit With, then **Edit › Paste Look** (⌥⌘V). It keeps that photo's
  own exposure. ⌘Z undoes the paste. Then press ⌥⌘S.

### Many photos at once: SpektraDroplet

1. In SpektraMac, set up a look on a typical photo, then **Preset › Save Preset…**.
2. Open **SpektraDroplet** from /Applications by itself. Choose that preset and an exposure
   (0 = as shot). It remembers both until you change them.
3. In Capture One, make a process recipe with **TIFF**, **16 bit** and **ProPhoto RGB**, and set
   its **Open With** to **SpektraDroplet**.
4. Process photos with that recipe. The droplet renders each TIFF in place in the recipe's output
   folder, then shows a notification. Import the results if you want them in the catalog.

Every photo in a droplet batch gets the same preset and the same exposure. For photos that need
their own exposure, use Edit With and Copy / Paste Look instead.

## 8. Updating later

```bash
cd ~/Projects/SpektraMac && git pull
```

Then repeat steps 4 to 6.

## Troubleshooting

| Problem | Fix |
|---|---|
| `xcodebuild` says it requires Xcode, or `swift build` can't find Metal | Do step 3. |
| macOS says the app "can't be opened" or "is damaged" | This happens when you copy the built app from another Mac. Build it on the Mac you'll use it on, or try to open it once, then click **Open Anyway** in System Settings › Privacy & Security. |
| The image comes back into Capture One duplicated or half-repeated | You're running an old SpektraMac. Repeat step 6 and check the menus. |
| **Save Back to Original** is greyed out | It only works on a TIFF or PNG that SpektraMac opened (which is what Edit With makes). RAW, JPEG and HEIC files are never written over. |
| Capture One doesn't update the thumbnail | Make sure you used **Save Back to Original**, not **Save…**, which saves a copy. |
| SpektraMac or SpektraDroplet doesn't appear in **Open With** | Choose **Other…** and pick it in /Applications. Opening the app once first also helps. |
| The droplet does nothing | Open it by itself and choose a preset first. Run it from Terminal to see errors: `/Applications/SpektraDroplet.app/Contents/Resources/spektra/spektra-cli save in.tif out.tif --preset look.json` |

## Optional: run the tests

```bash
swift test -c release -Xswiftc -enable-testing --package-path Engine
```

The tests take a few minutes. The 20 parity tests, which compare against the Python spektrafilm,
are skipped unless you generate their reference data with `tools/golden.py`.
