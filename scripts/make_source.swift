#!/usr/bin/env swift
// Writes source.json: a SideStore / AltStore source for the iPhone app.
// Add this link in SideStore (Sources, then +):
//   https://raw.githubusercontent.com/duckyisc00l/flappy-bird-ios/ipa/source.json
// usage: swift make_source.swift OUT.json IPA VERSION BUILD DOWNLOAD_URL "what's new" [screenshot names...]
import Foundation

let a = CommandLine.arguments
guard a.count >= 7 else {
    FileHandle.standardError.write("usage: make_source.swift OUT.json IPA VERSION BUILD DOWNLOAD_URL NOTES [SHOTS...]\n".data(using: .utf8)!)
    exit(1)
}
let (out, ipa, version, build, url) = (a[1], a[2], a[3], a[4], a[5])
var notes = a[6].trimmingCharacters(in: .whitespacesAndNewlines)
if notes.isEmpty { notes = "Build " + build }
let shots = Array(a.dropFirst(7))

let RAW = "https://raw.githubusercontent.com/duckyisc00l/flappy-bird-ios/ipa/"
let SITE = "https://duckyisc00l.github.io/flappy-bird/"
let size = ((try? FileManager.default.attributesOfItem(atPath: ipa))?[.size] as? NSNumber)?.intValue ?? 0
let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime]
let date = df.string(from: Date())
let desc = "My own Flappy Bird remix, all in Swift: 2,000+ birds and a bird maker, game modes and a Daily Challenge, "
    + "seasons with their own pipes, the live weather and real day and night where you are (or Daytona Beach), a Home Screen widget, "
    + "trails, ghosts, race links and live duels with friends, leaderboards, and a secret ending if you make it far enough."
let shotURLs = shots.map { RAW + "shots/" + $0 }

let app: [String: Any] = [
    "name": "Flappy Bird",
    "bundleIdentifier": "com.jordanvalladares.flappybird",
    "developerName": "Jordan Valladares",
    "subtitle": "Flap through the pipes. Then keep going.",
    "localizedDescription": desc,
    "iconURL": RAW + "icon.png",
    "tintColor": "#4EC0CA",
    "category": "games",
    "screenshots": shotURLs,
    "screenshotURLs": shotURLs,                 // older SideStore / AltStore versions
    "versions": [[
        "version": version,
        "buildVersion": build,
        "date": date,
        "localizedDescription": notes,
        "downloadURL": url,
        "size": size,
        "minOSVersion": "16.0",
    ]],
    // the same, for sources read by older versions
    "version": version,
    "versionDate": date,
    "versionDescription": notes,
    "downloadURL": url,
    "size": size,
    "appPermissions": [
        "entitlements": ["com.apple.security.application-groups"],
        "privacy": [
            "NSPhotoLibraryAddUsageDescription": "Save your score cards and replay clips to Photos.",
            "NSLocationWhenInUseUsageDescription": "So the game's weather matches the weather where you are (rounded to about 1 km).",
        ],
    ],
]
let src: [String: Any] = [
    "name": "Flappy Bird",
    "identifier": "com.jordanvalladares.flappybird.source",
    "subtitle": "Jordan's Flappy Bird remix",
    "description": desc,
    "iconURL": RAW + "icon.png",
    "headerURL": shotURLs.first ?? RAW + "icon.png",
    "website": SITE,
    "tintColor": "#4EC0CA",
    "featuredApps": ["com.jordanvalladares.flappybird"],
    "apps": [app],
    "news": [],
]
do {
    let data = try JSONSerialization.data(withJSONObject: src, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try data.write(to: URL(fileURLWithPath: out))
    print("source.json: \(version) \(build) \(size) bytes")
} catch {
    FileHandle.standardError.write("couldn't write \(out): \(error)\n".data(using: .utf8)!)
    exit(1)
}
