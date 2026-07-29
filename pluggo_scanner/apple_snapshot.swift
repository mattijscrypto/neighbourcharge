//
// apple_snapshot.swift — CLI wrapper rond MKLookAroundSnapshotter
//
// Compileren (eenmalig):
//   swiftc apple_snapshot.swift -o apple_snapshot -framework MapKit -framework AppKit -framework CoreLocation
//
// Gebruik:
//   ./apple_snapshot <lat> <lng> <heading> <pitch> <width> <height> <out.png>
//
// (heading en pitch worden op dit moment genegeerd — MKLookAroundSnapshotter.Options
//  heeft geen publieke POV control. Signature blijft zo staan zodat de Python-driver
//  niet hoeft te veranderen als we ooit een private-API workaround toevoegen.)
//
// Exit codes:
//   0 = succes, PNG geschreven
//   1 = args verkeerd
//   2 = geen Look Around scene beschikbaar op die coord
//   3 = snapshotter faalde
//   4 = PNG encoding faalde
//   5 = write faalde
//
// stderr bevat error-detail (1 regel), stdout wordt niet gebruikt.
//

import Foundation
import MapKit
import AppKit
import CoreLocation

@available(macOS 13.0, *)
func fetchScene(_ coord: CLLocationCoordinate2D) async -> (MKLookAroundScene?, Error?) {
    let request = MKLookAroundSceneRequest(coordinate: coord)
    return await withCheckedContinuation { (cont: CheckedContinuation<(MKLookAroundScene?, Error?), Never>) in
        request.getSceneWithCompletionHandler { scene, err in
            cont.resume(returning: (scene, err))
        }
    }
}

@available(macOS 13.0, *)
func takeSnapshot(_ scene: MKLookAroundScene, size: CGSize) async -> (NSImage?, Error?) {
    let options = MKLookAroundSnapshotter.Options()
    options.size = size
    let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
    return await withCheckedContinuation { (cont: CheckedContinuation<(NSImage?, Error?), Never>) in
        snapshotter.getSnapshotWithCompletionHandler { snap, err in
            cont.resume(returning: (snap?.image, err))
        }
    }
}

@available(macOS 13.0, *)
func run(
    lat: Double,
    lng: Double,
    heading _: Double,
    pitch _: Double,
    width: Int,
    height: Int,
    outPath: String
) async -> Int32 {
    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)

    // 1. Fetch de Look Around scene op deze coord.
    let (sceneOpt, sceneErr) = await fetchScene(coord)
    guard let scene = sceneOpt else {
        let msg = sceneErr.map { "\($0)" } ?? "no scene available"
        FileHandle.standardError.write("scene_unavailable: \(msg)\n".data(using: .utf8)!)
        return 2
    }

    // 2. Snapshot (default POV — Apple aimt normaal op de query-coord).
    let (imageOpt, snapErr) = await takeSnapshot(scene, size: CGSize(width: width, height: height))
    guard let image = imageOpt else {
        let msg = snapErr.map { "\($0)" } ?? "snapshot returned nil"
        FileHandle.standardError.write("snapshot_failed: \(msg)\n".data(using: .utf8)!)
        return 3
    }

    // 3. PNG encode + schrijf.
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("png_encode_failed\n".data(using: .utf8)!)
        return 4
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: outPath))
        return 0
    } catch {
        FileHandle.standardError.write("write_failed: \(error)\n".data(using: .utf8)!)
        return 5
    }
}

// ─────────────────────────────────────────────────────────────
// CLI entrypoint — kritiek: dispatchMain() ipv semaphore.wait()
// zodat MapKit's completion-handlers op de main queue kunnen firen.

let args = CommandLine.arguments
guard args.count == 8 else {
    FileHandle.standardError.write("usage: apple_snapshot <lat> <lng> <heading> <pitch> <width> <height> <out.png>\n".data(using: .utf8)!)
    exit(1)
}

guard #available(macOS 13.0, *) else {
    FileHandle.standardError.write("requires_macos_13_or_newer\n".data(using: .utf8)!)
    exit(1)
}

let lat     = Double(args[1]) ?? Double.nan
let lng     = Double(args[2]) ?? Double.nan
let heading = Double(args[3]) ?? 0.0
let pitch   = Double(args[4]) ?? 0.0
let width   = Int(args[5]) ?? 1280
let height  = Int(args[6]) ?? 720
let outPath = args[7]

guard lat.isFinite, lng.isFinite else {
    FileHandle.standardError.write("bad_coord\n".data(using: .utf8)!)
    exit(1)
}

Task {
    let code = await run(
        lat: lat, lng: lng,
        heading: heading, pitch: pitch,
        width: width, height: height,
        outPath: outPath
    )
    exit(code)
}

// dispatchMain() blokkeert de main thread MAAR laat de main dispatch queue
// events verwerken — precies wat MapKit's completion-handlers nodig hebben.
dispatchMain()
