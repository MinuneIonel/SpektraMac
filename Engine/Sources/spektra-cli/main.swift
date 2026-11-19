import CoreImage
import Foundation
import SpektraEngine
import UniformTypeIdentifiers

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "photo":
    // spektra-cli photo <width> <height> <file.jpg>: writes a test photo, the synthetic image below,
    // so tools/benchmark.sh doesn't depend on a photo being there.
    let numbers = arguments.dropFirst().prefix(2).compactMap { Int($0) }
    guard numbers.count == 2, let path = arguments.dropFirst(3).first else { usage() }
    try writeTestPhoto(width: numbers[0], height: numbers[1], to: URL(filePath: path))
case "save":
    // spektra-cli save <photo> <file.jpg|png|tiff> [lens | enlarger] [--film <stock>]: saves the photo
    // as the app does, timed.
    var paths = Array(arguments.dropFirst())
    func option(_ name: String) -> String? {
        guard let index = paths.firstIndex(of: name) else { return nil }
        guard index + 1 < paths.count else { usage() }
        defer { paths.removeSubrange(index...index + 1) }
        return paths[index + 1]
    }
    let film = option("--film")
    let preset = option("--preset").map { URL(filePath: $0) }
    let ev = option("--ev").map { Double($0) ?? { usage() }() }
    let diffusion = paths.count == 3 ? paths[2] : nil
    guard paths.count == 2 || ["lens", "enlarger"].contains(diffusion) else { usage() }
    try await save(URL(filePath: paths[0]), to: URL(filePath: paths[1]), film: film, preset: preset, ev: ev,
                   diffusion: diffusion)
case "preset":
    // spektra-cli preset <file.json> [--film <stock>]: writes the default settings, or what choosing
    // `stock` sets, as a preset, as the app's Save Preset does, to edit or pass to save --preset.
    var rest = Array(arguments.dropFirst())
    var controls = Controls()
    if let index = rest.firstIndex(of: "--film") {
        guard index + 1 < rest.count else { usage() }
        let films = try Engine().films
        guard films.contains(where: { $0.stock == rest[index + 1] }) else {
            print("No film \(rest[index + 1]). Films: \(films.map(\.stock).joined(separator: ", "))")
            exit(1)
        }
        controls = controls.choosing(film: rest[index + 1], from: films)
        rest.removeSubrange(index...index + 1)
    }
    guard rest.count == 1 else { usage() }
    try controls.preset().write(to: URL(filePath: rest[0]))
case "benchmark":
    if let path = arguments.dropFirst().first, Int(path) == nil {
        // spektra-cli benchmark <photo>: times the app's renders of a photo (the README's figures).
        try await benchmarkRenders(of: URL(filePath: path))
    } else {
        // spektra-cli benchmark [width height]: times each ported stage on a synthetic image.
        let numbers = arguments.dropFirst().compactMap { Int($0) }
        let (width, height) = numbers.count == 2 ? (numbers[0], numbers[1]) : (6000, 4000)
        try benchmark(width: width, height: height)
    }
default:
    print("spektra-cli — port of Spektrafilm at \(SpektraEngine.referenceCommit.prefix(7))")
    print("GPU: \(try GPU().device.name)")
    usage()
}

func usage() -> Never {
    print("""
        Usage: spektra-cli benchmark [width height | photo]
               spektra-cli save <photo> <file.jpg|png|tiff> [lens | enlarger] [--film <stock>]
                                [--preset <file.json>] [--ev <stops>]
               spektra-cli preset <file.json> [--film <stock>]
               spektra-cli photo <width> <height> <file.jpg>
        """)
    exit(1)
}

/// Saves the photo at `url` at `destination` the way the app does, as a JPEG, PNG or TIFF by its
/// extension, in a process of its own: opens it, renders the preview, then times
/// ``Engine/export(controls:as:)`` and the write, as the app's Save reports them. The default
/// settings (Portra 400 printed on Portra Endura), or what choosing `film` sets
/// (tools/looks.sh), with the default diffusion filter (Black Pro-Mist 1/2) on the `lens` or the
/// `enlarger` if asked. tools/benchmark.sh reads the process's peak memory footprint.
///
/// A `preset` (as the app's Save Preset writes) sets every control instead, checked as the app
/// checks one; `film` then picks a film on top of it. `ev` is the exposure in stops over the photo
/// as shot, which a preset doesn't carry. The photo's EXIF, GPS and IPTC are kept, as the app keeps
/// them, and `destination` may be the photo itself: it's decoded before the render is written.
func save(_ url: URL, to destination: URL, film: String?, preset: URL?, ev: Double?,
          diffusion: String?) async throws {
    guard let type = UTType(filenameExtension: destination.pathExtension),
          [UTType.jpeg, .png, .tiff].contains(where: { type.conforms(to: $0) }) else { usage() }
    let engine = try Engine()
    let metadata = PhotoMetadata(contentsOf: url)
    _ = try await engine.open(RGBImage.decode(contentsOf: url))
    var controls = Controls()
    if let preset {
        controls = try Controls(preset: Data(contentsOf: preset))
        guard engine.films.contains(where: { $0.stock == controls.film }),
              engine.papers.contains(where: { $0.stock == controls.paper }) else {
            print("Unknown film or paper in \(preset.lastPathComponent): \(controls.film), \(controls.paper)")
            exit(1)
        }
        controls = controls.checked(films: engine.films).controls
    }
    if let ev {
        controls.exposureEV = ev
    }
    if let film {
        guard engine.films.contains(where: { $0.stock == film }) else {
            print("No film \(film). Films: \(engine.films.map(\.stock).joined(separator: ", "))")
            exit(1)
        }
        controls = controls.choosing(film: film, from: engine.films)
    }
    if let diffusion {
        controls.cameraDiffusion.active = diffusion == "lens"
        controls.enlargerDiffusion.active = diffusion == "enlarger"
    }
    _ = try await engine.render(controls: controls, mode: .preview)
    let start = ContinuousClock.now
    let image = try await engine.export(controls: controls, as: type)
    let record = EditRecord(software: "spektra-cli",
                            summary: controls.scanFilm ? "\(controls.film), scanned" : "\(controls.film) printed on \(controls.paper)",
                            keywords: (controls.scanFilm ? [controls.film] : [controls.film, controls.paper]) + ["SpektraMac"],
                            controls: controls)
    if FileManager.default.fileExists(atPath: destination.path) {
        try image.overwrite(destination, as: type, metadata: metadata, record: record)
    } else {
        try image.write(to: destination, as: type, metadata: metadata, record: record)
    }
    // Plain milliseconds, for the script to read in any locale.
    print("save: \(Int(((ContinuousClock.now - start) / .milliseconds(1)).rounded())) ms")
}

/// A smooth gradient with texture: values span the exposure range like a photo.
func syntheticPixel(x: Int, y: Int, width: Int, height: Int) -> SIMD3<Float> {
    SIMD3(Float(x) / Float(width), Float(y) / Float(height), Float((x ^ y) & 255) / 255)
}

/// The synthetic image as an 8-bit sRGB JPEG at quality 0.98, as the app saves one.
func writeTestPhoto(width: Int, height: Int, to url: URL) throws {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let pixel = (syntheticPixel(x: x, y: y, width: width, height: height) * 255).rounded(.toNearestOrAwayFromZero)
            let index = (y * width + x) * 4
            bytes[index] = UInt8(pixel.x)
            bytes[index + 1] = UInt8(pixel.y)
            bytes[index + 2] = UInt8(pixel.z)
        }
    }
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    let image = CIImage(bitmapData: Data(bytes), bytesPerRow: width * 4, size: CGSize(width: width, height: height),
                        format: .RGBA8, colorSpace: sRGB)
    try CIContext().writeJPEGRepresentation(
        of: image, to: url, colorSpace: sRGB,
        options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.98])
}

/// The app's renders of `url` with the default settings (Portra 400 printed on Portra Endura): the
/// full render with every effect, as a save makes it, and the live preview that follows each change.
/// The best of several runs, each through every stage.
func benchmarkRenders(of url: URL) async throws {
    let engine = try Engine()
    let image = try RGBImage.decode(contentsOf: url)
    _ = try await engine.open(image)
    print("\(url.lastPathComponent), \(Int(image.extent.width)) × \(Int(image.extent.height)), on \(try GPU().device.name)")
    for (label, mode, runs) in [("full render", RenderMode.full, 3), ("preview", .preview, 10)] {
        var best = Duration.seconds(Int.max)
        for run in 0...runs {
            // A different exposure each time: the engine keeps the film's steps for renders that
            // only change the print, and this times every stage.
            var controls = Controls()
            controls.exposureEV = Double(run) * 0.01
            let start = ContinuousClock.now
            _ = try await engine.render(controls: controls, mode: mode)
            best = min(best, ContinuousClock.now - start)
        }
        print("\(label): \(best.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 0))))")
    }
}

func benchmark(width: Int, height: Int) throws {
    let gpu = try GPU()
    gpu.heap = gpu.reservedMemory(width: width, height: height)  // as the app does for a full render
    let film = try Profile.load("kodak_portra_400")
    let paper = try Profile.load("kodak_portra_endura")
    var parameters = Parameters()
    parameters.applyNeutralPrintFilters(film: film, print: paper, database: try Tables.loadNeutralPrintFilters())
    parameters.applyFilmSpecifics(film)
    var clock = ContinuousClock.now
    func lap(_ label: String) {
        let now = ContinuousClock.now
        print("\(label.padding(toLength: 40, withPad: " ", startingAt: 0)) \((now - clock).formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
        clock = now
    }

    let simulation = try Simulation(parameters: parameters, film: film, print: paper, gpu: gpu, tables: Tables.load())
    lap("setup (tc LUT, print constants, C_max)")
    var pixels = [Float](repeating: 0, count: width * height * 3)
    for y in 0..<height {
        for x in 0..<width {
            let pixel = syntheticPixel(x: x, y: y, width: width, height: height)
            let index = (y * width + x) * 3
            pixels[index] = pixel.x
            pixels[index + 1] = pixel.y
            pixels[index + 2] = pixel.z
        }
    }
    let image = RGBImage(width: width, height: height, pixels: pixels)
    print("\(width) × \(height) on \(gpu.device.name)")
    clock = .now

    // Stage by stage; the scope frees the stage outputs before the whole chain runs.
    do {
        let rgbPre = try gpu.run { simulation.encodePreprocess(image, on: $0) }
        lap("rgb_in → rgb_pre (AE on CPU, upload)")
        let logEFilm = try gpu.run { simulation.encodeExpose(rgbPre, on: $0) }
        lap("rgb_pre → log_e_film (halation)")
        let cmyFilm = try gpu.run { simulation.encodeDevelop(logEFilm, on: $0) }
        lap("log_e_film → cmy_film (couplers)")
        let logEPrint = try gpu.run { simulation.encodePrintExpose(cmyFilm, on: $0) }
        lap("cmy_film → log_e_print (81 bands)")
        let cmyPrint = try gpu.run { simulation.encodePrintDevelop(logEPrint, on: $0) }
        lap("log_e_print → cmy_print")
        let scanned = try gpu.run { simulation.encodeDensityToRGB(cmyPrint, on: $0) }
        lap("cmy_print → scanned RGB (81 bands)")
        _ = try gpu.run { simulation.encodeOutputCompression(scanned, on: $0) }
        lap("output gamut compression (cam16ucs)")
        print("allocated on the GPU (incl. reserved): \(gpu.device.currentAllocatedSize / 1_000_000) MB")
    }

    // The app's path: the whole chain in one run.
    var peak = 0
    _ = try gpu.run { encoder in
        defer { peak = encoder.peakAllocatedSize }
        return simulation.encode(image, on: encoder)
    }
    lap("whole chain (rgb_in → rgb_out)")
    print("peak in use on the GPU: \(peak / 1_000_000) MB")
}
