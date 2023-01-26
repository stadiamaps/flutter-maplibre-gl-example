# flutter_maplibre_demo

An example Flutter project demonstrating how to use the [MapLibre GL wrapper](https://github.com/m0nac0/flutter-maplibre-gl)
with annotation clustering and offline caching. (Note that offline management is only available on mobile platforms.)

## Getting Started

You *will* need to set an API key in [map.dart](lib/map.dart) before running the app. You can sign up for a free
Stadia Maps API key via our [Client Dashboard](https://client.stadiamaps.com/). Otherwise, run it like
any other Flutter app.

This project is a starting point for a Flutter application, but is by no means a comprehensive guide
to all there is to know about Flutter MapLibre GL. Please refer to the project (linked above)
and the following resources for getting started with Flutter.


- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Gotchas

There appear to be a few issues/inconsistencies between web and mobile. This repo is
currently tested against iOS and will have some quirks on Android and web as a result.
We have opened issues with the library to resolve these.

* https://github.com/m0nac0/flutter-maplibre-gl/issues/159
* https://github.com/m0nac0/flutter-maplibre-gl/issues/160

Finally, note that iOS Simulator currently has some issues rendering maps due to rendering
library issues, particularly on Apple Silicon. Reworking the rendering to use Metal is
actively underway upstream, which will solve the simulator issues. For now, we recommend
running on a device.