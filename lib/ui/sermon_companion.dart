import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import '../core/api_client.dart';
import '../core/sermon_companion_api.dart';
import '../core/sermon_companion_models.dart';
import 'luma_design.dart';

String companionLabel(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
void companionError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));

class SermonCompanionHub extends StatefulWidget {
  const SermonCompanionHub({required this.api, super.key});
  final ApiClient api;
  @override
  State<SermonCompanionHub> createState() => _SermonCompanionHubState();
}

class _SermonCompanionHubState extends State<SermonCompanionHub> {
  late final service = SermonCompanionApi(widget.api);
  var loading = true;
  String? error;
  List<SermonCompanion> companions = [];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final value = await service.list();
      if (mounted) {
        setState(() {
          companions = value;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> create() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SermonCompanionEditor(api: widget.api)));
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Sermon Companion'), actions: [
        IconButton(onPressed: create, icon: const Icon(Icons.add))
      ]),
      body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text('Keep Sunday close all week.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Write notes, capture what you heard, and turn it into a practice you can live.',
                style: TextStyle(color: lumaMuted, fontSize: 16, height: 1.45)),
            const SizedBox(height: 20),
            LumaDarkCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const LumaTag('Private capture', dark: true),
                  const SizedBox(height: 12),
                  const Text('Start with the way you remember it.',
                      style: TextStyle(
                          color: lumaCream,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                      'Use written notes, photographs, or a recording you own.',
                      style: TextStyle(color: lumaMuted2)),
                  const SizedBox(height: 16),
                  LumaAccentButton(label: 'Create companion', onPressed: create)
                ])),
            const SizedBox(height: 24),
            const LumaEyebrow('Your companions'),
            const SizedBox(height: 10),
            if (loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator())),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (!loading && error == null && companions.isEmpty)
              const Text(
                  'No companions yet. Create your first Sunday companion.',
                  style: TextStyle(color: lumaMuted)),
            ...companions.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                    title: Text(item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${companionLabel(item.status)} · ${item.sermonDate ?? 'No date'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SermonCompanionDetail(
                                  api: widget.api, initial: item)));
                      if (mounted) refresh();
                    })))
          ])));
}

class SermonCompanionEditor extends StatefulWidget {
  const SermonCompanionEditor({required this.api, this.initial, super.key});
  final ApiClient api;
  final SermonCompanion? initial;
  @override
  State<SermonCompanionEditor> createState() => _SermonCompanionEditorState();
}

class _SermonCompanionEditorState extends State<SermonCompanionEditor> {
  late final service = SermonCompanionApi(widget.api);
  late final title = TextEditingController(text: widget.initial?.title ?? '');
  late final speaker =
      TextEditingController(text: widget.initial?.speaker ?? '');
  late final church =
      TextEditingController(text: widget.initial?.churchName ?? '');
  late final date =
      TextEditingController(text: widget.initial?.sermonDate ?? '');
  late final youtube =
      TextEditingController(text: widget.initial?.youtubeUrl ?? '');
  late final notes =
      TextEditingController(text: widget.initial?.personalNotes ?? '');
  late final references = TextEditingController(
      text: widget.initial?.scriptureReferences.join(', ') ?? '');
  late final confirmed =
      TextEditingController(text: widget.initial?.confirmedNotes ?? '');
  final picker = ImagePicker();
  final recorder = AudioRecorder();
  final images = <XFile>[];
  String? audioPath;
  var mode = 0;
  var recording = false;
  var paused = false;
  var busy = false;
  @override
  void dispose() {
    for (final c in [
      title,
      speaker,
      church,
      date,
      youtube,
      notes,
      references,
      confirmed
    ]) {
      c.dispose();
    }
    recorder.dispose();
    super.dispose();
  }

  Future<void> pickImages({required bool camera}) async {
    if (camera) {
      final image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (image != null && mounted) setState(() => images.add(image));
      return;
    }
    final picked = await picker.pickMultiImage(imageQuality: 90);
    if (mounted) setState(() => images.addAll(picked));
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (mounted && result?.files.single.path != null) {
      setState(() => audioPath = result!.files.single.path);
    }
  }

  Future<void> toggleRecording() async {
    try {
      if (recording) {
        final path = await recorder.stop();
        if (mounted) {
          setState(() {
            audioPath = path;
            recording = false;
            paused = false;
          });
        }
        return;
      }
      if (!await recorder.hasPermission()) {
        if (mounted) {
          companionError(context, 'Microphone permission is required.');
        }
        return;
      }
      final path =
          '${Directory.systemTemp.path}/luma-companion-${DateTime.now().millisecondsSinceEpoch}.wav';
      await recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: path);
      if (mounted) {
        setState(() {
          audioPath = path;
          recording = true;
          paused = false;
        });
      }
    } catch (e) {
      if (mounted) companionError(context, e);
    }
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      companionError(context, 'Add a sermon title first.');
      return;
    }
    setState(() => busy = true);
    try {
      final scriptureReferences = references.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      var saved = widget.initial == null
          ? await service.create(
              title: title.text,
              speaker: speaker.text,
              churchName: church.text,
              sermonDate: date.text,
              youtubeUrl: youtube.text,
              personalNotes: notes.text,
              scriptureReferences: scriptureReferences)
          : await service.update(widget.initial!.id, {
              'title': title.text.trim(),
              'speaker': speaker.text.trim(),
              'church_name': church.text.trim(),
              'sermon_date': date.text.trim(),
              'youtube_url': youtube.text.trim(),
              'personal_notes': notes.text,
              'scripture_references': scriptureReferences,
              'confirmed_notes': confirmed.text
            });
      for (final image in images) {
        saved = await service.upload(saved.id, image.path, 'image');
      }
      if (audioPath != null) {
        saved = await service.upload(saved.id, audioPath!, 'audio');
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) companionError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String label, TextEditingController controller,
          {String? hint, int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(labelText: label, hintText: hint)));
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const LumaEyebrow('Sermon Companion'),
      const SizedBox(height: 8),
      const Text('Capture what you heard.',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      SegmentedButton<int>(segments: const [
        ButtonSegment(value: 0, label: Text('Write notes')),
        ButtonSegment(value: 1, label: Text('Photograph')),
        ButtonSegment(value: 2, label: Text('Audio'))
      ], selected: {
        mode
      }, onSelectionChanged: (v) => setState(() => mode = v.first)),
      const SizedBox(height: 20),
      field('Sermon title *', title),
      field('Speaker', speaker),
      field('Church', church),
      field('Sermon date', date, hint: 'YYYY-MM-DD'),
      field('Scripture references', references,
          hint: 'James 1:22, Matthew 7:24'),
      field('Optional YouTube link', youtube),
      field('Personal notes', notes, maxLines: 6)
    ];
    if (mode == 1) {
      children.addAll([
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => pickImages(camera: true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'))),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => pickImages(camera: false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery')))
        ]),
        if (images.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('${images.length} image(s) ready for private upload'))
      ]);
    }
    if (mode == 2) {
      children.addAll([
        OutlinedButton.icon(
            onPressed: recording ? null : pickAudio,
            icon: const Icon(Icons.audio_file_outlined),
            label: const Text('Choose audio')),
        OutlinedButton.icon(
            onPressed: toggleRecording,
            icon: Icon(recording ? Icons.stop : Icons.mic),
            label: Text(recording ? 'Stop recording' : 'Record sermon')),
        if (recording)
          TextButton(
              onPressed: () async {
                if (paused) {
                  await recorder.resume();
                } else {
                  await recorder.pause();
                }
                if (mounted) setState(() => paused = !paused);
              },
              child: Text(paused ? 'Resume' : 'Pause')),
        if (audioPath != null && !recording)
          const Text('Audio ready for private upload',
              style: TextStyle(color: lumaMuted))
      ]);
    }
    if (widget.initial != null) {
      children.add(field('Corrected extracted/transcribed notes', confirmed,
          maxLines: 8, hint: 'Review backend extraction and correct it here.'));
    }
    children.addAll([
      const SizedBox(height: 12),
      FilledButton(
          onPressed: busy || recording ? null : save,
          child: Text(busy ? 'Saving…' : 'Save companion'))
    ]);
    return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.initial == null ? 'New companion' : 'Edit companion')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: children));
  }
}

class SermonCompanionDetail extends StatefulWidget {
  const SermonCompanionDetail(
      {required this.api, required this.initial, super.key});
  final ApiClient api;
  final SermonCompanion initial;
  @override
  State<SermonCompanionDetail> createState() => _SermonCompanionDetailState();
}

class _SermonCompanionDetailState extends State<SermonCompanionDetail> {
  late final service = SermonCompanionApi(widget.api);
  late SermonCompanion companion;
  late final journal = TextEditingController();
  late final String journalKey;
  Timer? autosave;
  String journalState = 'Not started';
  List<SermonCompanionDay> days = [];
  List<SermonCompanionMemoryCard> memory = [];
  int? selectedPlanId;
  bool busy = false;
  bool refreshing = false;
  @override
  void initState() {
    companion = widget.initial;
    journalKey = 'companion-${widget.initial.id}-reflection';
    super.initState();
    load();
    journal.addListener(scheduleSave);
  }

  @override
  void dispose() {
    autosave?.cancel();
    journal.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final entries = await service.journal(companion.id);
      final existing =
          entries.where((e) => e.clientKey == journalKey).firstOrNull;
      final cards = await service.memoryCards(companion.id);
      if (mounted) {
        setState(() {
          if (existing != null) {
            journal.removeListener(scheduleSave);
            journal.text = existing.content;
            journal.addListener(scheduleSave);
            journalState = 'Saved';
          }
          memory = cards;
        });
      }
    } catch (e) {
      if (mounted) companionError(context, e);
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      final updated = await service.detail(companion.id);
      final cards = await service.memoryCards(companion.id);
      final currentDays =
          selectedPlanId == null ? days : await service.days(selectedPlanId!);
      if (mounted) {
        setState(() {
          companion = updated;
          memory = cards;
          days = currentDays;
        });
      }
    } catch (e) {
      if (mounted) companionError(context, e);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void scheduleSave() {
    autosave?.cancel();
    if (journal.text.trim().isEmpty) return;
    setState(() => journalState = 'Saving soon…');
    autosave = Timer(const Duration(milliseconds: 800), saveJournal);
  }

  Future<void> saveJournal() async {
    setState(() => journalState = 'Saving…');
    try {
      await service.saveJournal(companion.id,
          entryType: 'reflection',
          content: journal.text,
          clientKey: journalKey);
      if (mounted) setState(() => journalState = 'Saved');
    } catch (_) {
      if (mounted) {
        setState(() => journalState = 'Save failed — retry by editing');
      }
    }
  }

  Future<void> recap() async {
    setState(() => busy = true);
    try {
      final value = await service.queueRecap(companion.id);
      if (mounted) setState(() => companion = value);
    } catch (e) {
      if (mounted) companionError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> plan(int count) async {
    setState(() => busy = true);
    try {
      await service.queuePlan(companion.id, count);
      final value = await service.detail(companion.id);
      if (mounted) setState(() => companion = value);
    } catch (e) {
      if (mounted) companionError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openPlan(SermonCompanionPlan selected) async {
    try {
      final value = await service.days(selected.id);
      if (mounted) {
        setState(() {
          selectedPlanId = selected.id;
          days = value;
        });
      }
    } catch (e) {
      if (mounted) companionError(context, e);
    }
  }

  Widget recapView() {
    final data = companion.recap;
    if (data == null) {
      return OutlinedButton.icon(
          onPressed: busy ? null : recap,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate Sunday in One Page'));
    }
    final sections = {
      'Main sermon idea': data['main_idea'],
      'Supporting Scripture': data['supporting_scripture'],
      'Key takeaways': data['key_takeaways'],
      'Practical applications': data['practical_applications'],
      'Personal reflections': data['personal_reflections']
    };
    final content = <Widget>[
      const LumaEyebrow('Sunday in One Page', dark: true),
      const SizedBox(height: 12)
    ];
    for (final entry in sections.entries) {
      if (entry.value != null) {
        content.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.key,
                  style: const TextStyle(
                      color: lumaLime, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  entry.value is List
                      ? (entry.value as List).join('\n')
                      : entry.value.toString(),
                  style: const TextStyle(color: lumaCream, height: 1.45))
            ])));
      }
    }
    return LumaDarkCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: content));
  }

  Widget planView() {
    final content = <Widget>[
      Row(children: [
        Expanded(
            child: LumaAccentButton(
                label: '5 days', onPressed: busy ? null : () => plan(5))),
        const SizedBox(width: 8),
        Expanded(
            child: OutlinedButton(
                onPressed: busy ? null : () => plan(7),
                child: const Text('7 days')))
      ])
    ];
    for (final p in companion.plans) {
      content.add(Card(
          margin: const EdgeInsets.only(top: 10),
          child: ListTile(
              title: Text('${p.daysCount}-day devotional plan'),
              subtitle: Text([
                companionLabel(p.status),
                if (p.processingError?.isNotEmpty == true) p.processingError!
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPlan(p))));
    }
    for (final d in days) {
      content.add(Card(
          margin: const EdgeInsets.only(top: 10),
          child: ExpansionTile(
              title: Text('Day ${d.dayNumber}: ${d.title}'),
              subtitle: Text(d.completed ? 'Completed' : d.theme),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Text(d.reference,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(d.scriptureText),
                const SizedBox(height: 12),
                Text(d.reflection),
                const SizedBox(height: 8),
                Text('Question: ${d.question}'),
                const SizedBox(height: 8),
                Text('Application: ${d.application}'),
                const SizedBox(height: 8),
                Text('Prayer: ${d.prayer}'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: d.completed
                        ? null
                        : () async {
                            try {
                              await service.completeDay(d.id);
                              final plan = companion.plans
                                  .where((p) => p.id == selectedPlanId)
                                  .firstOrNull;
                              if (plan != null) await openPlan(plan);
                            } catch (e) {
                              if (mounted) companionError(context, e);
                            }
                          },
                    child: Text(d.completed ? 'Completed' : 'Complete day'))
              ])));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  Future<void> practice(SermonCompanionMemoryCard card, bool value) async {
    try {
      final updated = await service.practiceMemory(card.id, value);
      if (mounted) {
        setState(() => memory = memory
            .map((item) => item.id == updated.id ? updated : item)
            .toList());
      }
    } catch (e) {
      if (mounted) companionError(context, e);
    }
  }

  Widget memoryView() => Column(children: [
        for (final card in memory)
          Card(
              child: ListTile(
                  title: Text(card.reference),
                  subtitle: Text(card.verseText),
                  trailing: Checkbox(
                      value: card.completed,
                      onChanged: (value) {
                        if (value != null) practice(card, value);
                      })))
      ]);
  Widget sourceView() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (companion.processingError?.isNotEmpty == true)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(companion.processingError!,
                  style: const TextStyle(color: Colors.red))),
        if (companion.personalNotes.isNotEmpty)
          Card(
              child: ListTile(
                  title: const Text('Written notes'),
                  subtitle: Text(companion.personalNotes))),
        if (companion.confirmedNotes?.isNotEmpty == true)
          Card(
              child: ListTile(
                  title: const Text('Confirmed notes'),
                  subtitle: Text(companion.confirmedNotes!))),
        for (final attachment in companion.attachments)
          Card(
              child: ExpansionTile(
                  title: Text(
                      '${companionLabel(attachment.kind)} · ${companionLabel(attachment.status)}'),
                  subtitle: Text(attachment.originalName),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                if (attachment.processingError?.isNotEmpty == true)
                  Text(attachment.processingError!,
                      style: const TextStyle(color: Colors.red)),
                if (attachment.isUnclear)
                  const Text(
                      'Some content was unclear. Review the extracted text.'),
                if (attachment.extractedText?.isNotEmpty == true)
                  SelectableText(attachment.extractedText!)
              ])),
      ]);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Companion'), actions: [
        IconButton(
            tooltip: 'Refresh companion',
            onPressed: refreshing ? null : refresh,
            icon: refreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh)),
        IconButton(
            onPressed: () async {
              final updated = await Navigator.push<SermonCompanion>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SermonCompanionEditor(
                          api: widget.api, initial: companion)));
              if (updated != null && mounted) {
                setState(() => companion = updated);
              }
            },
            icon: const Icon(Icons.edit_outlined))
      ]),
      body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const LumaTag('Companion'),
                const SizedBox(height: 10),
                Text(companion.title,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700)),
                Text(
                    '${companionLabel(companion.status)} · ${companion.speaker ?? 'Personal notes'}',
                    style: const TextStyle(color: lumaMuted)),
                const SizedBox(height: 18),
                sourceView(),
                LumaDarkCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const LumaEyebrow('Journal', dark: true),
                      const SizedBox(height: 10),
                      TextField(
                          controller: journal,
                          minLines: 4,
                          maxLines: 8,
                          style: const TextStyle(color: lumaCream),
                          decoration: const InputDecoration(
                              hintText: 'Write a reflection or prayer',
                              hintStyle: TextStyle(color: lumaMuted2),
                              fillColor: lumaCard2)),
                      const SizedBox(height: 6),
                      Text(journalState,
                          style:
                              const TextStyle(color: lumaMuted2, fontSize: 12))
                    ])),
                const SizedBox(height: 20),
                recapView(),
                const SizedBox(height: 20),
                const LumaEyebrow('Personalized plans'),
                planView(),
                const SizedBox(height: 20),
                const LumaEyebrow('Scripture memory'),
                memoryView()
              ])));
}
