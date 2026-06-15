import 'package:flutter/material.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide TileLayer;

import '../../../../core/config/app_config.dart';
import '../../../../core/config/vector_basemap_config.dart';

/// Векторная подложка для [FlutterMap] (POC). Загружает MapLibre style JSON по сети.
class VectorBasemapLayer extends StatefulWidget {
  const VectorBasemapLayer({
    super.key,
    required this.styleUri,
    this.onLoadFailed,
  });

  final String styleUri;
  final VoidCallback? onLoadFailed;

  @override
  State<VectorBasemapLayer> createState() => _VectorBasemapLayerState();
}

class _VectorBasemapLayerState extends State<VectorBasemapLayer> {
  Style? _style;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void didUpdateWidget(VectorBasemapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleUri != widget.styleUri) {
      setState(() {
        _style = null;
        _error = null;
      });
      _loadStyle();
    }
  }

  Future<void> _loadStyle() async {
    final uris = <String>[
      widget.styleUri,
      if (widget.styleUri != VectorBasemapConfig.mapLibreDemoStyleUri)
        VectorBasemapConfig.mapLibreDemoStyleUri,
    ];

    Object? lastError;
    for (final uri in uris) {
      try {
        final style = await StyleReader(
          uri: uri,
          logger: const Logger.console(),
        ).read();
        if (!mounted) return;
        setState(() {
          _style = style;
          _error = null;
        });
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint('VectorBasemapLayer: не удалось загрузить стиль $uri: $e\n$st');
      }
    }

    if (!mounted) return;
    setState(() => _error = lastError);
    widget.onLoadFailed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      if (_error != null) return const SizedBox.shrink();
      return const SizedBox.shrink();
    }

    return VectorTileLayer(
      key: ValueKey<String>(widget.styleUri),
      tileProviders: style.providers,
      theme: style.theme,
      sprites: style.sprites,
      maximumZoom: AppConfig.maxZoom,
      tileOffset: TileOffset.DEFAULT,
      layerMode: VectorTileLayerMode.vector,
      concurrency: 2,
      maximumTileSubstitutionDifference: 2,
    );
  }
}
