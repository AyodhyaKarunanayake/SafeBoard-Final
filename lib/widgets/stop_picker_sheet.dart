import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/route_model.dart';
import '../services/places_service.dart';

// Bottom sheet for picking a boarding/alighting stop. Besides the plain
// Route 87 stop list, it lets the user search for any real-world place via
// Google Places; picking a search result snaps to the nearest stop this bus
// actually halts at (since a bus can only board/alight passengers at its
// fixed stops), so downstream arrival-time calculations keep working.
class StopPickerSheet extends StatefulWidget {
  final String title;
  final List<String> stops;
  final RouteModel route;
  final ValueChanged<String> onSelected;

  const StopPickerSheet({
    super.key,
    required this.title,
    required this.stops,
    required this.route,
    required this.onSelected,
  });

  @override
  State<StopPickerSheet> createState() => _StopPickerSheetState();
}

class _StopPickerSheetState extends State<StopPickerSheet> {
  final _placesService = PlacesService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  String? _notice;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<String> get _filteredStops {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return widget.stops;
    return widget.stops.where((s) => s.toLowerCase().contains(query)).toList();
  }

  void _onQueryChanged(String value) {
    setState(() => _notice = null);
    _debounce?.cancel();

    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await _placesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectPlace(PlaceSuggestion place) async {
    setState(() => _isSearching = true);
    final latLng = await _placesService.getPlaceLatLng(place.placeId);
    if (!mounted) return;

    if (latLng == null) {
      setState(() {
        _isSearching = false;
        _notice = 'Could not locate "${place.description}". Pick a stop from the list below instead.';
      });
      return;
    }

    final match = widget.route.nearestStopMatch(latLng.lat, latLng.lng);
    setState(() => _isSearching = false);
    if (match == null) return;

    widget.onSelected(match.stopName);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search a town or landmark near Route 87',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _notice!,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (_suggestions.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text(
                        'MATCHES NEAREST ROUTE 87 STOP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ..._suggestions.map(
                      (s) => ListTile(
                        leading: const Icon(Icons.map_outlined, color: AppColors.primaryNavy, size: 20),
                        title: Text(s.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                        onTap: () => _selectPlace(s),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      'ROUTE 87 STOPS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_filteredStops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Text(
                        'No stops match "${_controller.text}".',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  else
                    ..._filteredStops.map(
                      (stop) => ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: AppColors.primaryNavy, size: 20),
                        title: Text(stop, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                        onTap: () {
                          widget.onSelected(stop);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
