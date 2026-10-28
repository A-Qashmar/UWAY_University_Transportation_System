import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/passenger_models.dart';
import '../services/uway_data_source.dart';
import '../theme/uway_theme.dart';
import '../widgets/passenger_state_panel.dart';

/// The form a passenger uses to report a lost item or a problem.
/// Pops with `true` once the report was sent.
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({
    required this.apiClient,
    this.initialCategory = 'LostItem',
    this.initialTripId,
    super.key,
  });

  final UwayDataSource apiClient;
  final String initialCategory;
  final String? initialTripId;

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  static const _minLength = 5;
  final _description = TextEditingController();
  late String _category = widget.initialCategory;
  late String? _tripId = widget.initialTripId;
  List<UwayTrip> _trips = const [];
  final List<ReportFile> _files = [];
  static const _maxFiles = 5;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = widget.apiClient.role == 'Driver'
          ? await widget.apiClient.getAssignedTrips()
          : await widget.apiClient.getTrips();
      trips.sort((a, b) => b.departureAtUtc.compareTo(a.departureAtUtc));
      if (mounted) setState(() => _trips = trips);
    } catch (_) {
      // The related trip is optional, so a failure here does not block the form.
    }
  }

  bool get _canSend =>
      !_sending && _description.text.trim().length >= _minLength;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.apiClient.createReport(
        category: _category,
        description: _description.text.trim(),
        tripId: _tripId,
        files: _files,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error =
            'Your report could not be sent. Please check your connection and try again. ($error)';
      });
    }
  }

  Future<void> _pick(String kind) async {
    if (_files.length >= _maxFiles) {
      setState(() => _error = 'You can attach up to $_maxFiles files.');
      return;
    }
    final picker = ImagePicker();
    try {
      final picked = <XFile>[];
      switch (kind) {
        case 'camera':
          final photo = await picker.pickImage(
              source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
          if (photo != null) picked.add(photo);
        case 'photos':
          picked.addAll(await picker.pickMultiImage(
              imageQuality: 80, maxWidth: 1920, limit: _maxFiles));
        default:
          final video = await picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(minutes: 1));
          if (video != null) picked.add(video);
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        for (final file in picked) {
          if (_files.length >= _maxFiles) break;
          _files.add(ReportFile(
              path: file.path, name: file.name, isVideo: kind == 'video'));
        }
      });
    } on Object {
      if (mounted) {
        setState(() => _error = 'The photo or video could not be opened.');
      }
    }
  }

  Future<void> _chooseTrip() async {
    final result = await showModalBottomSheet<_TripChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TripPickerSheet(trips: _trips, selectedId: _tripId),
    );
    if (result != null && mounted) setState(() => _tripId = result.tripId);
  }

  String _tripText(UwayTrip trip) {
    final time = trip.departureAtUtc;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final day = '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
    return '${trip.displayName} · $day $hh:$mm';
  }

  String _selectedTripText() {
    if (_tripId == null) return 'No specific trip. Tap to search';
    final trip = _trips.where((t) => t.id == _tripId).firstOrNull;
    return trip == null ? 'Selected trip' : _tripText(trip);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Send a report')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text('What is this about?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in reportCategories.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _category == entry.key,
                    onSelected: (_) => setState(() => _category = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sending ? null : _chooseTrip,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Related trip (optional)',
                  suffixIcon: _tripId == null
                      ? const Icon(Icons.search)
                      : IconButton(
                          tooltip: 'Remove trip',
                          icon: const Icon(Icons.close),
                          onPressed: _sending
                              ? null
                              : () => setState(() => _tripId = null),
                        ),
                ),
                child: Text(
                  _selectedTripText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              enabled: !_sending,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tell us what happened',
                alignLabelWithHint: true,
                helperText: _description.text.trim().length < _minLength
                    ? 'Write at least $_minLength characters to enable Send.'
                    : _category == 'LostItem'
                        ? 'Describe the item, where you sat and when you travelled.'
                        : 'The more detail you give, the faster we can help.',
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('Photos or videos (optional)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _sending ? null : () => _pick('camera'),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _sending ? null : () => _pick('photos'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photos'),
                ),
                OutlinedButton.icon(
                  onPressed: _sending ? null : () => _pick('video'),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Video'),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final file in _files)
                    InputChip(
                      avatar: Icon(
                          file.isVideo ? Icons.videocam : Icons.image_outlined,
                          size: 18),
                      label: SizedBox(
                        width: 120,
                        child: Text(file.name, overflow: TextOverflow.ellipsis),
                      ),
                      onDeleted: _sending
                          ? null
                          : () => setState(() => _files.remove(file)),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: context.uwayDanger)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _canSend ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Send report'),
            ),
            const SizedBox(height: 8),
            Text(
              'The university team reviews reports and replies here, under My reports.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

/// The passenger's own reports, with the team's status and reply.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({
    required this.apiClient,
    this.embedded = false,
    super.key,
  });

  final UwayDataSource apiClient;

  /// Inside a tab: no app bar of its own.
  final bool embedded;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late Future<List<PassengerReport>> _reports = widget.apiClient.getMyReports();
  List<PassengerReport>? _last;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Statuses and replies change on the server: refresh quietly.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _quietRefresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _quietRefresh() async {
    try {
      final fresh = await widget.apiClient.getMyReports();
      if (mounted) {
        setState(() {
          _last = fresh;
          _reports = Future.value(fresh);
        });
      }
    } on Object {
      // Keep showing what is on screen.
    }
  }

  void _reload() {
    final next = widget.apiClient.getMyReports();
    setState(() {
      _reports = next;
    });
  }

  Future<void> _newReport() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReportFormScreen(apiClient: widget.apiClient),
      ),
    );
    if (sent == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. Your report was sent.')),
      );
    }
  }

  Color _statusColor(BuildContext context, String status) => switch (status) {
        'Resolved' => context.uwaySuccess,
        'InReview' => context.uwayWarning,
        _ => Theme.of(context).colorScheme.primary,
      };

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const Text('My reports')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newReport,
          icon: const Icon(Icons.add),
          label: const Text('New report'),
        ),
        body: FutureBuilder<List<PassengerReport>>(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                _last == null) {
              return const LoadingPanel();
            }
            if (snapshot.hasError && _last == null) {
              return PassengerStatePanel(
                title: 'Reports could not load',
                message: snapshot.error.toString(),
                icon: Icons.cloud_off_outlined,
                action: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              );
            }
            final reports = snapshot.data ?? _last!;
            _last = reports;
            if (reports.isEmpty) {
              return const PassengerStatePanel(
                title: 'No reports yet',
                message:
                    'If you lose something or have a problem on a trip, send us a report and we will reply here.',
                icon: Icons.support_agent_outlined,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final report in reports)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reportCategoryLabel(report.category),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(context, report.status)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  reportStatusLabel(report.status),
                                  style: TextStyle(
                                    color: _statusColor(context, report.status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              _date(report.createdAtUtc),
                              if (report.tripLabel != null) report.tripLabel!,
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Text(report.description),
                          if (report.attachments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _AttachmentStrip(
                              attachments: report.attachments,
                              apiClient: widget.apiClient,
                            ),
                          ],
                          if (report.adminResponse != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reply from the team',
                                      style:
                                          Theme.of(context).textTheme.labelMedium),
                                  const SizedBox(height: 4),
                                  Text(report.adminResponse!),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.attachments, required this.apiClient});

  final List<ReportAttachmentInfo> attachments;
  final UwayDataSource apiClient;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final item in attachments)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: item.isVideo
                        ? ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            child: const Icon(Icons.play_circle_outline,
                                size: 34),
                          )
                        : Image.network(
                            apiClient.attachmentUrl(item.id),
                            headers: apiClient.authHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _TripChoice {
  const _TripChoice(this.tripId);
  final String? tripId;
}

/// Searchable list of trips for a report: running, finished and upcoming ones,
/// whether or not the person joined them.
class _TripPickerSheet extends StatefulWidget {
  const _TripPickerSheet({required this.trips, required this.selectedId});

  final List<UwayTrip> trips;
  final String? selectedId;

  @override
  State<_TripPickerSheet> createState() => _TripPickerSheetState();
}

class _TripPickerSheetState extends State<_TripPickerSheet> {
  static const _filters = ['All', 'Started', 'Finished', 'Scheduled'];
  String _filter = 'All';
  String _query = '';
  int _shown = 15;

  bool _matchesFilter(UwayTrip t) => switch (_filter) {
        'Started' => t.isStarted && !t.isCancelled,
        'Finished' => t.isFinished,
        'Scheduled' => t.status == 'Scheduled' && !t.isCancelled,
        _ => true,
      };

  String _statusText(UwayTrip t) => t.isCancelled
      ? 'Cancelled'
      : t.isFinished
          ? 'Finished'
          : t.isStarted
              ? 'Started'
              : 'Scheduled';

  String _when(UwayTrip t) {
    final d = t.departureAtUtc.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.trips.where(_matchesFilter).where((t) {
      if (q.isEmpty) return true;
      return '${t.displayName} ${t.busNumber ?? ''} ${_when(t)} ${_statusText(t)}'
          .toLowerCase()
          .contains(q);
    }).toList();
    final visible = matches.take(_shown).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by route, bus or date',
                ),
                onChanged: (value) => setState(() {
                  _query = value;
                  _shown = 15;
                }),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() {
                          _filter = f;
                          _shown = 15;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('No specific trip'),
                    selected: widget.selectedId == null,
                    onTap: () => Navigator.pop(context, const _TripChoice(null)),
                  ),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No trips match.')),
                    ),
                  for (final t in visible)
                    ListTile(
                      leading: Icon(t.isStarted && !t.isCancelled
                          ? Icons.directions_bus
                          : t.isFinished
                              ? Icons.check_circle_outline
                              : Icons.schedule),
                      title: Text(t.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${_when(t)} · ${_statusText(t)}${t.busNumber == null ? '' : ' · Bus ${t.busNumber}'}'),
                      selected: widget.selectedId == t.id,
                      onTap: () => Navigator.pop(context, _TripChoice(t.id)),
                    ),
                  if (matches.length > _shown)
                    TextButton(
                      onPressed: () => setState(() => _shown += 15),
                      child: Text('Show more (${matches.length - _shown})'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
