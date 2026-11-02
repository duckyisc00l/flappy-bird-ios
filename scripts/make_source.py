#!/usr/bin/env python3
"""Writes source.json: a SideStore / AltStore source for the iPhone app.
Add this URL in SideStore (Sources, then +):
  https://raw.githubusercontent.com/duckyisc00l/flappy-bird-ios/ipa/source.json
usage: make_source.py OUT.json IPA VERSION BUILD DOWNLOAD_URL "what's new" [screenshot names...]
"""
import json, os, sys, datetime

out, ipa, version, build, url, notes = sys.argv[1:7]
shots = sys.argv[7:]
RAW = 'https://raw.githubusercontent.com/duckyisc00l/flappy-bird-ios/ipa/'
SITE = 'https://duckyisc00l.github.io/flappy-bird/'
size = os.path.getsize(ipa)
date = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
desc = ('My own Flappy Bird remix, all in Swift: 2,000+ birds and a bird maker, game modes and a Daily Challenge, '
        'seasons with their own pipes, live Florida weather, trails, ghosts, race links and live duels with friends, '
        'leaderboards, and a secret ending if you make it far enough.')
notes = (notes or '').strip() or 'Build ' + build
app = {
    'name': 'Flappy Bird',
    'bundleIdentifier': 'com.jordanvalladares.flappybird',
    'developerName': 'Jordan Valladares',
    'subtitle': 'Flap through the pipes. Then keep going.',
    'localizedDescription': desc,
    'iconURL': RAW + 'icon.png',
    'tintColor': '#4EC0CA',
    'category': 'games',
    'screenshots': [RAW + 'shots/' + s for s in shots],
    'screenshotURLs': [RAW + 'shots/' + s for s in shots],     # older SideStore / AltStore versions
    'versions': [{
        'version': version,
        'buildVersion': build,
        'date': date,
        'localizedDescription': notes,
        'downloadURL': url,
        'size': size,
        'minOSVersion': '16.0',
    }],
    # the same, for sources read by older versions
    'version': version,
    'versionDate': date,
    'versionDescription': notes,
    'downloadURL': url,
    'size': size,
    'appPermissions': {
        'entitlements': [],
        'privacy': {'NSPhotoLibraryAddUsageDescription': 'Save your score cards and replay clips to Photos.'},
    },
}
src = {
    'name': 'Flappy Bird',
    'identifier': 'com.jordanvalladares.flappybird.source',
    'subtitle': "Jordan's Flappy Bird remix",
    'description': desc,
    'iconURL': RAW + 'icon.png',
    'headerURL': RAW + 'shots/' + shots[0] if shots else RAW + 'icon.png',
    'website': SITE,
    'tintColor': '#4EC0CA',
    'featuredApps': [app['bundleIdentifier']],
    'apps': [app],
    'news': [],
}
json.dump(src, open(out, 'w'), indent=2)
print('source.json:', version, build, size, 'bytes')
