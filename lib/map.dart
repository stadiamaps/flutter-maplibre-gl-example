import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// FIXME: Be sure to set your own API key here. You can register for a free one at https://client.stadiamaps.com/.
const apiKey = "YOUR-API-KEY";

enum OfflineDataState { unknown, downloaded, downloading, notDownloaded }

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Map();
  }
}

class Map extends StatefulWidget {
  const Map({super.key});

  @override
  State createState() => MapState();
}

class MapState extends State<Map> {
  MapLibreMapController? mapController;
  static const clusterLayer = "clusters";
  static const unclusteredPointLayer = "unclustered-point";

  OfflineDataState offlineDataState = OfflineDataState.unknown;
  double? downloadProgress;

  @override
  void dispose() {
    mapController?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;

    // Event listener that fires for the cluster layer (not due to an explicit
    // filter; only a consequence of the current mix of layers used).
    controller.onFeatureTapped.add(_onFeatureTapped);

    // Determine if we have data stored offline. Note that this is a fairly
    // crude check, and if you are dealing with multiple styles or regions,
    // you will want to do something a bit more advanced.
    final result = await getListOfRegions();
    setState(() {
      if (result.isEmpty) {
        offlineDataState = OfflineDataState.notDownloaded;
      } else {
        offlineDataState = OfflineDataState.downloaded;
      }
    });
  }

  void _onStyleLoadedCallback() async {
    const sourceId = "locations";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Style loaded"),
      backgroundColor: Theme.of(context).primaryColor,
      duration: const Duration(seconds: 1),
    ));

    // Alternate form when using hard-coded local data; load this however you like
    // await addClusteredPointSource(sourceId, {
    //   "type": "FeatureCollection",
    //   "features": [
    //     {
    //       "type": "Feature",
    //       "geometry": {
    //         "type": "Point",
    //         "coordinates": [-77.03238901390978, 38.913188059745586]
    //       },
    //       "properties": {"title": "Washington, DC"}
    //     },
    //     {
    //       "type": "Feature",
    //       "geometry": {
    //         "type": "Point",
    //         "coordinates": [-122.414, 37.776]
    //       },
    //       "properties": {"title": "San Francisco"}
    //     }
    //   ]
    // });
    await addClusteredPointSource(sourceId,
        "https://maplibre.org/maplibre-gl-js/docs/assets/earthquakes.geojson");
    await addClusteredPointLayers(sourceId);
  }

  // Logic for interacting with clusters on iOS.
  // See bug report: https://github.com/m0nac0/flutter-maplibre-gl/issues/160
  void _onFeatureTapped(
      dynamic featureId, Point<double> point, LatLng coords) async {
    var features =
        await mapController?.queryRenderedFeatures(point, [clusterLayer], null);
    if (features?.isNotEmpty ?? false) {
      // Naive zoom += 2. There is a `getClusterExpansionZoom` method
      // on sources, but the Flutter wrapper does not actually expose
      // sources at the moment so we're just falling back to a simple
      // approach.
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          coords, mapController!.cameraPosition!.zoom + 2));
    }
  }

  // This method handles interaction with the actual earthquake points on iOS.
  // See bug report: https://github.com/m0nac0/flutter-maplibre-gl/issues/160
  void _onMapClick(Point<double> point, LatLng coordinates) async {
    var messenger = ScaffoldMessenger.of(context);
    var color = Theme.of(context).primaryColor;

    var features = await mapController?.queryRenderedFeatures(
        point, [unclusteredPointLayer], null);
    if (features?.isNotEmpty ?? false) {
      var feature = HashMap.from(features!.first);
      messenger.showSnackBar(SnackBar(
        content: Text("Magnitude ${feature["properties"]["mag"]} earthquake"),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // Adds a data source to the map via a GeoJSON layer. The data is assumed
  // to be a PointCollection
  Future<void>? addClusteredPointSource(String sourceId, Object? data) {
    return mapController?.addSource(
        sourceId, GeojsonSourceProperties(data: data, cluster: true));
  }

  Future<void> addClusteredPointLayers(String sourceId) async {
    await mapController?.addCircleLayer(
        sourceId,
        clusterLayer,
        const CircleLayerProperties(circleColor: [
          "step",
          ["get", "point_count"],
          "#51bbd6",
          100,
          "#f1f075",
          750,
          "#f28cb1"
        ], circleRadius: [
          "step",
          ["get", "point_count"],
          20,
          100,
          30,
          750,
          40
        ]),
        filter: ["has", "point_count"]);

    await mapController?.addSymbolLayer(
        sourceId,
        "cluster-count",
        const SymbolLayerProperties(
            // NOTE: I would expect to be able to do something like "{point_count_abbreviated}", but this breaks on Android
            textField: [Expressions.get, "point_count_abbreviated"],
            textFont: ["Open Sans Regular"]),
        filter: ["has", "point_count"]);

    await mapController?.addCircleLayer(
        sourceId,
        unclusteredPointLayer,
        const CircleLayerProperties(
            circleColor: "#11b4da",
            circleRadius: 8,
            circleStrokeWidth: 1,
            circleStrokeColor: "#fff"),
        filter: [
          "!",
          ["has", "point_count"]
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    switch (offlineDataState) {
      case OfflineDataState.downloaded:
        child = const Icon(Icons.delete);
        break;
      case OfflineDataState.notDownloaded:
        child = const Icon(Icons.download_for_offline_outlined);
        break;
      case OfflineDataState.downloading:
      case OfflineDataState.unknown:
        // Indeterminate progress indicator
        child = CircularProgressIndicator(
          value: downloadProgress,
          color: Colors.white,
        );
        break;
    }

    final Widget? actionButton;
    if (kIsWeb) {
      // Offline tiles are not supported in the browser
      actionButton = null;
    } else {
      actionButton =
          FloatingActionButton(onPressed: _actionButtonPressed, child: child);
    }

    return Scaffold(
      body: MapLibreMap(
        styleString: _mapStyleUrl(),
        myLocationEnabled: true,
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoadedCallback,
        onMapClick: _onMapClick,
        trackCameraPosition: true,
      ),
      floatingActionButton: actionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  String _mapStyleUrl() {
    const styleUrl =
        "https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json";
    return "$styleUrl?api_key=$apiKey";
  }

  void _actionButtonPressed() async {
    switch (offlineDataState) {
      case OfflineDataState.downloaded:
        _deleteOfflineRegion();
        break;
      case OfflineDataState.notDownloaded:
        await _downloadOfflineRegion();
        break;
      case OfflineDataState.downloading:
      case OfflineDataState.unknown:
        return;
    }
  }

  Future<OfflineRegion?> _downloadOfflineRegion() async {
    setState(() {
      offlineDataState = OfflineDataState.downloading;
    });

    try {
      // Bounding box around Manhattan. Note that this will consume
      // approximately 200 API credits.
      final bounds = LatLngBounds(
        southwest: const LatLng(40.69, -74.03),
        northeast: const LatLng(40.84, -73.86),
      );
      final regionDefinition = OfflineRegionDefinition(
          bounds: bounds, mapStyleUrl: _mapStyleUrl(), minZoom: 0, maxZoom: 14);
      final region = await downloadOfflineRegion(regionDefinition,
          metadata: {
            'name': 'Manhattan',
          },
          onEvent: _onDownloadEvent);

      return region;
    } on Exception catch (_) {
      setState(() {
        offlineDataState = OfflineDataState.notDownloaded;
        downloadProgress = null;
      });
      return null;
    }
  }

  void _onDownloadEvent(DownloadRegionStatus status) {
    // Event listener for download progress; MapLibre uses a repeated
    // callback API, and the download command, while async, completes early.
    if (status is Success) {
      setState(() {
        offlineDataState = OfflineDataState.downloaded;
        downloadProgress = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Manhattan Downloaded for Offline Use"),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 3),
      ));
    } else if (status is Error) {
      setState(() {
        offlineDataState = OfflineDataState.notDownloaded;
        downloadProgress = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Data Downloaded Failed!"),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ));
    } else if (status is InProgress) {
      setState(() {
        offlineDataState = OfflineDataState.downloading;
        downloadProgress = status.progress / 100;
      });
    }
  }

  void _deleteOfflineRegion() async {
    setState(() {
      offlineDataState = OfflineDataState.unknown;
    });

    final regions = await getListOfRegions();

    for (final region in regions) {
      // NOTE: The term "delete" here is a bit of a misnomer. From the docs:
      //
      // When you remove an offline pack, any resources that are required by
      // that pack, but not other packs, become eligible for deletion from
      // offline storage. Because the backing store used for offline storage
      // is also used as a general purpose cache for map resources, such
      // resources may not be immediately removed if the implementation
      // determines that they remain useful for general performance of the map.
      //
      // Ambient cache controls also exist, but these are not currently wrapped
      // for Flutter. This is not normally an issue, and the storage engine will
      // eventually clear these tiles out.
      //
      // Source: https://maplibre.org/maplibre-gl-native/ios/api/Classes/MGLOfflineStorage.html#/c:objc(cs)MGLOfflineStorage(im)removePack:withCompletionHandler:
      await deleteOfflineRegion(
        region.id,
      );
    }

    setState(() {
      offlineDataState = OfflineDataState.notDownloaded;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Offline data marked for removal"),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 1),
      ));
    }
  }
}
