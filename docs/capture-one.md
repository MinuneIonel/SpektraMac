# Using SpektraMac with Capture One

Capture One has no plugin interface for processing images, so SpektraMac works with it as an
external editor. There are two ways in:

- **Edit With → SpektraMac**, for one photo at a time with the live preview: Capture One makes a
  TIFF, SpektraMac opens it, and **File › Save Back to Original** (⌥⌘S) renders over that TIFF.
  Capture One sees the file change and updates its thumbnail.
- **SpektraDroplet**, for a batch: a process recipe exports TIFFs and hands them to the droplet,
  which renders each in place with a saved preset.

Copy SpektraMac.app (`build/Build/Products/Release/` after building) and SpektraDroplet.app to
`/Applications`, so Capture One's app pickers find them.

The Capture One menu names below were written for Capture One 16.5 and haven't all been checked
against it yet.

## Develop the RAW for film

SpektraMac expects a scene-referred image: what reached the sensor, not a finished picture. In
Capture One, before sending a photo:

1. **Base Characteristics › Curve: Linear Response.** Capture One's default curve is a film-like
   tone curve of its own; leaving it on puts that curve under the simulated film's.
2. Keep the exposure so nothing important clips. The highlights are the film's to roll off.
3. Leave out any look you'd normally add (contrast, saturation, styles). White balance, lens
   corrections, crops and spot removal are fine.

## Edit With

1. Right-click a photo › **Edit With…**.
2. In the dialog choose **TIFF**, **16 bit**, and an ICC profile with a wide gamut: **ProPhoto
   RGB** or **Adobe RGB (1998)**. SpektraMac reads the embedded profile and converts to linear
   Rec. 2020 itself; it doesn't need a linear file. Under **Open With**, choose SpektraMac.app, then
   **Edit Variant**.
3. Choose the film and paper and adjust as usual.
4. **File › Save Back to Original** (⌥⌘S). It writes a 16-bit TIFF, tagged Display P3, over the
   file Capture One made, keeping the camera's metadata and recording the edit in it.

Save Back is only offered for TIFF and PNG files; a RAW, HEIC or JPEG original is never written
over. **File › Save…** still saves a copy anywhere, as before.

## Copy a look to the next photo

**Edit › Copy Look** (⌥⌘C) puts every setting but the exposure on the clipboard; on the next
photo, after Edit With, **Edit › Paste Look** (⌥⌘V) sets it, keeping that photo's own exposure,
and Edit › Undo takes it back. The copied look is also a preset's JSON as text, so it can be pasted
into a file, and a preset's JSON copied as text pastes as a look.

## SpektraDroplet (batches)

Build it once (`tools/capture-one/make-droplet.sh` writes `build/SpektraDroplet.app`; move it to
`/Applications`), then:

1. In SpektraMac, set up a look on a typical photo and **Preset › Save Preset…**. (Or make one
   without the app: `spektra-cli preset look.json --film kodak_portra_400`.)
2. Open SpektraDroplet on its own: choose that preset and an exposure in stops. They're kept in
   `~/Library/Application Support/SpektraDroplet/`.
3. In Capture One, make a process recipe: **TIFF, 16 bit, ProPhoto RGB**, and under **Open With**
   choose SpektraDroplet.
4. Process photos with that recipe. The droplet renders each exported TIFF in place and shows a
   notification. The rendered files stay in the recipe's output folder; import them if you want
   them in the catalog.

To render photos as variants in the catalog instead, select them and choose **Edit With… ›
SpektraDroplet** (TIFF, 16 bit, ProPhoto RGB): Capture One makes a TIFF variant of each and the
droplet renders each in place. (Not yet tried with several photos at once.)

The droplet uses one preset and one exposure for every photo. For photos that need their own
exposure, use Edit With and SpektraMac, with Copy Look and Paste Look.

## Command line

`spektra-cli`, which the droplet runs, also works on its own:

```
spektra-cli save in.tif out.tif --preset look.json --ev 0.3
spektra-cli save photo.tif photo.tif --film fujifilm_velvia_100     # in place
spektra-cli preset look.json --film kodak_ektar_100
```
