import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/event_repository.dart';


class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _repo = EventRepository();

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _otherType = TextEditingController();

  String _type = 'Birthday';
  DateTime? _startDate;
  DateTime? _endDate;

  Uint8List? _coverBytes;
  String _coverContentType = 'image/jpeg';

  String _privacy = 'signed_in_only';
  bool _loading = false;
  String? _error;

  bool get _canSubmit {
    if (_title.text.trim().isEmpty) return false;
    if (_startDate == null) return false;
    if (_endDate == null) return false;
    if (_coverBytes == null) return false;
    if (_type == 'Other' && _otherType.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _pickCover() async {
    if (_loading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Cover image'),
              subtitle: Text('Choose from gallery or take a photo'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return;

    final name = x.name.toLowerCase();
    final isImage = name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');

    if (!isImage) {
      setState(() => _error = 'Please select an image file (jpg/png/webp).');
      return;
    }

    final bytes = await x.readAsBytes();
    final ct = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';

    setState(() {
      _coverBytes = bytes;
      _coverContentType = ct;
      _error = null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final start = _startDate ?? now;
    final end = _endDate ??
        (_startDate?.add(const Duration(days: 1)) ?? now.add(const Duration(days: 1)));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(start: start, end: end),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // NOTE: repo expects a single date today. We pass start date for now.
      // We can extend EventModel later to include endDate.
      final eventId = await _repo
          .createEvent(
        title: _title.text.trim(),
        type: _type,
        typeOtherLabel: _type == 'Other' ? _otherType.text.trim() : null,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        eventDate: _startDate!,
        privacy: _privacy,
        coverBytes: _coverBytes!,
        coverContentType: _coverContentType,
      )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      context.go('/event/$eventId');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _otherType.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) => d == null ? '--/--/----' : '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Taller / portrait-friendly cover area without going full 9:16 (too tall)
    final width = MediaQuery.of(context).size.width;
    final coverHeight = ((width - 32) * 0.72).clamp(240.0, 340.0); // feels “vertical” and pushes fields down

    final fromText = _fmt(_startDate);
    final toText = _fmt(_endDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null) ...[
              _SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.withOpacity(0.9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.withOpacity(0.95)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Cover picker (taller + smoother)
            GestureDetector(
              onTap: _loading ? null : _pickCover,
              child: Container(
                height: coverHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: scheme.surface,
                  border: Border.all(color: scheme.outline.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: _coverBytes == null
                      ? null
                      : DecorationImage(
                    image: MemoryImage(_coverBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.center,
                child: _coverBytes == null
                    ? Text(
                  'Tap to pick cover image\n(portrait works best)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.70)),
                )
                    : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Change cover',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _SoftCard(
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Event name (required)',
                    ),
                    onChanged: (_) => setState(() {}),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Event type'),
                    items: const [
                      DropdownMenuItem(value: 'Birthday', child: Text('Birthday')),
                      DropdownMenuItem(value: 'Wedding', child: Text('Wedding')),
                      DropdownMenuItem(value: 'Memorial', child: Text('Memorial')),
                      DropdownMenuItem(value: 'Church', child: Text('Church')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _type = v ?? 'Birthday'),
                  ),

                  if (_type == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otherType,
                      decoration: const InputDecoration(labelText: 'Custom label (required)'),
                      onChanged: (_) => setState(() {}),
                      enabled: !_loading,
                    ),
                  ],

                  const SizedBox(height: 12),

                  TextField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                    maxLines: 3,
                    enabled: !_loading,
                  ),

                  const SizedBox(height: 12),

                  // Date range (From / To)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _pickDateRange,
                          child: Text('From: $fromText'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _pickDateRange,
                          child: Text('To: $toText'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Public toggle (copy can be refined later)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Public event'),
                    subtitle: const Text('Default is signed-in users only'),
                    value: _privacy == 'public',
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _privacy = v ? 'public' : 'signed_in_only'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (_loading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Create Event'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
