import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_localizations.dart';
import '../../services/impact_store.dart';
import '../../ui/widgets.dart';

class ImpactScreen extends StatefulWidget {
  const ImpactScreen({
    super.key,
    required this.prefs,
    required this.allowCreate,
    required this.onFinish,
  });
  final SharedPreferences? prefs;
  final bool allowCreate;
  final VoidCallback onFinish;
  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  final map = MapController();
  final ScrollController _scrollController = ScrollController();
  final place = TextEditingController();
  late ImpactStore store;
  List<ImpactEntry> entries = [];
  LatLng? point;
  Uint8List? photo;
  bool busy = false, confirmed = false, readFailed = false;
  String? error;
  List<(String, LatLng)> get stops => [
    (tr('impact.region.samlar'), const LatLng(41.123, 28.731)),
    (tr('impact.region.sazlidere'), const LatLng(41.101, 28.741)),
    (tr('impact.region.kucukcekmece'), const LatLng(41.016, 28.751)),
  ];
  @override
  void initState() {
    super.initState();
    store = ImpactStore(widget.prefs);
    try {
      entries = store.read();
    } catch (e) {
      readFailed = true;
      error = tr('impact.loadError');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    map.dispose();
    place.dispose();
    super.dispose();
  }

  String _localizedError(Object error, String prefix) {
    final message = error.toString().replaceFirst(prefix, '');
    return message.startsWith('impact.') ? tr(message) : message;
  }

  Future<void> choosePhoto() async {
    setState(() => error = null);
    try {
      final types = XTypeGroup(
        label: tr('impact.photos'),
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      );
      final file = await openFile(acceptedTypeGroups: [types]);
      if (file == null) return;
      if (await file.length() > 12 * 1024 * 1024) {
        throw FormatException(tr('impact.maxSize'));
      }
      if (!mounted) return;
      setState(() => busy = true);
      final prepared = await ImpactStore.preparePhoto(await file.readAsBytes());
      if (mounted) setState(() => photo = prepared);
    } catch (e) {
      if (mounted) {
        setState(() => error = _localizedError(e, 'FormatException: '));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (readFailed) return;
    if (photo == null ||
        point == null ||
        place.text.trim().isEmpty ||
        !confirmed) {
      setState(() => error = tr('impact.missingFields'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final now = DateTime.now();
    final entry = ImpactEntry(
      id: now.microsecondsSinceEpoch.toString(),
      place: place.text.trim(),
      lat: point!.latitude,
      lng: point!.longitude,
      photo: base64Encode(photo!),
      date: now.toIso8601String(),
    );
    try {
      await store.write([...entries, entry]);
      if (mounted) widget.onFinish();
    } catch (e) {
      if (mounted) setState(() => error = _localizedError(e, 'Bad state: '));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(ImpactEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('impact.deleteTitle')),
        content: Text(entry.place),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final updated = entries.where((e) => e.id != entry.id).toList();
      await store.write(updated);
      if (mounted) setState(() => entries = updated);
    } catch (e) {
      if (mounted) setState(() => error = tr('impact.deleteError'));
    }
  }

  void showEntry(ImpactEntry e) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: cream,
      title: Text(e.place),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(e.bytes, height: 240, fit: BoxFit.contain),
            const SizedBox(height: 10),
            Text(
              tr('impact.record', {'date': e.date.substring(0, 10)}),
              style: const TextStyle(fontSize: 11),
            ),
            Text(tr('impact.userReported'), style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(tr('common.close')),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        // Webde ikinci bir otomatik kaydırma çubuğu oluşmasın.
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(8),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) => SingleChildScrollView(
    controller: _scrollController,
    primary: false,
    physics: const ClampingScrollPhysics(),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(18, 18, 30, 24),
    child: Paper(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.allowCreate
                ? tr('impact.taskEyebrow')
                : tr('impact.mapEyebrow'),
            style: const TextStyle(
              color: ink,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.allowCreate ? tr('impact.taskTitle') : tr('impact.mapTitle'),
            style: const TextStyle(
              fontFamily: 'StorySerif',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.allowCreate ? tr('impact.taskBody') : tr('impact.mapBody'),
            style: const TextStyle(color: ink, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 12),
          if (widget.allowCreate) ...[
            Text(
              tr('impact.safety'),
              style: TextStyle(color: ink, fontSize: 10, height: 1.6),
            ),
            const SizedBox(height: 12),
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  photo!,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            StoryButton(
              busy
                  ? tr('impact.preparing')
                  : photo == null
                  ? tr('impact.selectPhoto')
                  : tr('impact.changePhoto'),
              secondary: true,
              icon: Icons.add_photo_alternate_outlined,
              onPressed: busy ? null : choosePhoto,
            ),
            const SizedBox(height: 15),
          ],
          Wrap(
            spacing: 5,
            children: [
              for (final stop in stops)
                ActionChip(
                  label: Text(stop.$1, style: const TextStyle(fontSize: 10)),
                  onPressed: () => map.move(stop.$2, 13),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.allowCreate)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tr('impact.mapHelp'),
                style: TextStyle(color: ink, fontSize: 10),
              ),
            ),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: entries.isNotEmpty && !widget.allowCreate
                      ? LatLng(entries.last.lat, entries.last.lng)
                      : const LatLng(41.071, 28.739),
                  initialZoom: 10.7,
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: widget.allowCreate
                      ? (_, p) => setState(() => point = p)
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'org.esma.suyunkoruyucusu',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final e in entries)
                        Marker(
                          point: LatLng(e.lat, e.lng),
                          width: 42,
                          height: 48,
                          child: IconButton(
                            tooltip: e.place,
                            onPressed: () => showEntry(e),
                            icon: const Icon(
                              Icons.location_on,
                              size: 38,
                              color: ink,
                            ),
                          ),
                        ),
                      if (point != null)
                        Marker(
                          point: point!,
                          width: 44,
                          height: 50,
                          child: const Icon(
                            Icons.add_location_alt,
                            size: 40,
                            color: coral,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: Text(
              tr('impact.osmAttribution'),
              style: const TextStyle(fontSize: 9),
            ),
          ),
          Text(
            tr('impact.mapPrivacy'),
            style: TextStyle(color: ink, fontSize: 9, height: 1.5),
          ),
          if (widget.allowCreate) ...[
            if (point != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tr('impact.selectedPoint', {
                    'lat': point!.latitude.toStringAsFixed(5),
                    'lng': point!.longitude.toStringAsFixed(5),
                  }),
                  style: const TextStyle(color: ink, fontSize: 10),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: place,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: tr('impact.placeLabel'),
                hintText: tr('impact.placeHint'),
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (v) => setState(() => confirmed = v ?? false),
              title: Text(
                tr('impact.confirmPhoto'),
                style: TextStyle(fontSize: 11, color: ink),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Text(
              tr('impact.disclaimer'),
              style: TextStyle(fontSize: 9, color: ink),
            ),
            const SizedBox(height: 14),
            StoryButton(
              tr('impact.add'),
              icon: Icons.add_location_alt_outlined,
              onPressed: busy || readFailed ? null : save,
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              tr('impact.count', {'count': entries.length}),
              style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr('impact.empty'),
                  style: TextStyle(color: ink, fontSize: 12),
                ),
              ),
            for (final e in entries.reversed)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      e.bytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    e.place,
                    style: const TextStyle(fontSize: 12, color: ink),
                  ),
                  subtitle: Text(
                    e.date.substring(0, 10),
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () => showEntry(e),
                  trailing: IconButton(
                    tooltip: tr('impact.deleteTooltip'),
                    onPressed: () => remove(e),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            StoryButton(tr('common.continue'), onPressed: widget.onFinish),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xff9c3b29), fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}
