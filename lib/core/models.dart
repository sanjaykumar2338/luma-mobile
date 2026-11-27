class User {
  const User(
      {required this.id,
      required this.name,
      required this.email,
      required this.isAdmin,
      required this.createdAt});
  final int id;
  final String name;
  final String email;
  final bool isAdmin;
  final String createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class Membership {
  const Membership(
      {required this.plan,
      required this.status,
      this.endsAt,
      required this.billingEnabled,
      this.source,
      this.canceled = false});
  final String plan;
  final String status;
  final String? endsAt;
  final bool billingEnabled;
  final String? source;
  final bool canceled;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        plan: json['plan'] as String? ?? 'free',
        status: json['status'] as String? ?? 'free',
        endsAt: json['renews_or_ends_at'] as String?,
        billingEnabled: json['billing_enabled'] as bool? ?? false,
        source: json['source']?.toString(),
        canceled: json['canceled'] as bool? ?? false,
      );
}

class Entitlements {
  const Entitlements({required this.membership, this.usage = const {}});
  final Membership membership;
  final Map<String, dynamic> usage;

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final rawMembership =
        (json['membership'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    if (rawMembership['source'] == null && json['source'] != null) {
      rawMembership['source'] = json['source'];
    }
    if (rawMembership['canceled'] == null && json['canceled'] != null) {
      rawMembership['canceled'] = json['canceled'];
    }
    return Entitlements(
      membership: Membership.fromJson(rawMembership),
      usage: (json['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.sermonProcessing = true,
    this.devotionalReminders = true,
    this.subscriptionUpdates = true,
    this.readingPlanReminders = true,
    this.sermonCompanionReminders = true,
    this.sermonCompanionMidweekCheckIns = true,
    this.reminderTime = '08:00',
    this.timezone,
  });
  final bool enabled;
  final bool sermonProcessing;
  final bool devotionalReminders;
  final bool subscriptionUpdates;
  final bool readingPlanReminders;
  final bool sermonCompanionReminders;
  final bool sermonCompanionMidweekCheckIns;
  final String reminderTime;
  final String? timezone;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: json['enabled'] as bool? ?? true,
        sermonProcessing: json['sermon_processing'] as bool? ?? true,
        devotionalReminders: json['devotional_reminders'] as bool? ?? true,
        subscriptionUpdates: json['subscription_updates'] as bool? ?? true,
        readingPlanReminders: json['reading_plan_reminders'] as bool? ?? true,
        sermonCompanionReminders: json['sermon_companion_reminders'] as bool? ?? true,
        sermonCompanionMidweekCheckIns: json['sermon_companion_midweek_check_ins'] as bool? ?? true,
        reminderTime: json['reminder_time']?.toString() ?? '08:00',
        timezone: json['timezone']?.toString(),
      );

  NotificationPreferences copyWith({
    bool? enabled,
    bool? sermonProcessing,
    bool? devotionalReminders,
    bool? subscriptionUpdates,
    bool? readingPlanReminders,
    bool? sermonCompanionReminders,
    bool? sermonCompanionMidweekCheckIns,
    String? reminderTime,
    String? timezone,
  }) =>
      NotificationPreferences(
        enabled: enabled ?? this.enabled,
        sermonProcessing: sermonProcessing ?? this.sermonProcessing,
        devotionalReminders: devotionalReminders ?? this.devotionalReminders,
        subscriptionUpdates: subscriptionUpdates ?? this.subscriptionUpdates,
        readingPlanReminders: readingPlanReminders ?? this.readingPlanReminders,
        sermonCompanionReminders: sermonCompanionReminders ?? this.sermonCompanionReminders,
        sermonCompanionMidweekCheckIns: sermonCompanionMidweekCheckIns ?? this.sermonCompanionMidweekCheckIns,
        reminderTime: reminderTime ?? this.reminderTime,
        timezone: timezone ?? this.timezone,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sermon_processing': sermonProcessing,
        'devotional_reminders': devotionalReminders,
        'subscription_updates': subscriptionUpdates,
        'reading_plan_reminders': readingPlanReminders,
        'sermon_companion_reminders': sermonCompanionReminders,
        'sermon_companion_midweek_check_ins': sermonCompanionMidweekCheckIns,
        'reminder_time': reminderTime,
        if (timezone != null) 'timezone': timezone,
      };
}

String textValue(dynamic value) => value?.toString() ?? '';
List<dynamic> listValue(dynamic value) => value is List ? value : const [];

int intValue(dynamic value, [int fallback = 0]) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

class Sermon {
  const Sermon(
      {required this.id,
      required this.title,
      required this.sourceType,
      required this.status,
      this.sourceUrl,
      this.error,
      this.transcript,
      this.notes,
      this.createdAt});
  final int id;
  final String title, sourceType, status;
  final String? sourceUrl, error, transcript, createdAt;
  final SermonNote? notes;
  factory Sermon.fromJson(Map<String, dynamic> j) => Sermon(
      id: j['id'] as int,
      title: textValue(j['title']).isEmpty
          ? 'Untitled sermon'
          : textValue(j['title']),
      sourceType: textValue(j['source_type']),
      status: textValue(j['processing_status']),
      sourceUrl: j['source_url']?.toString(),
      error: j['processing_error']?.toString(),
      transcript: j['transcript']?.toString(),
      notes: j['notes'] is Map
          ? SermonNote.fromJson((j['notes'] as Map).cast<String, dynamic>())
          : null,
      createdAt: j['created_at']?.toString());
}

class SermonNote {
  const SermonNote(
      {this.summary = '',
      this.mainIdea = '',
      this.outline = const [],
      this.keyPoints = const [],
      this.scriptures = const [],
      this.themes = const [],
      this.applications = const [],
      this.questions = const []});
  final String summary, mainIdea;
  final List<dynamic> outline,
      keyPoints,
      scriptures,
      themes,
      applications,
      questions;
  factory SermonNote.fromJson(Map<String, dynamic> j) => SermonNote(
      summary: textValue(j['summary']),
      mainIdea: textValue(j['main_idea']),
      outline: listValue(j['outline']),
      keyPoints: listValue(j['key_points']),
      scriptures: listValue(j['scripture_references']),
      themes: listValue(j['themes']),
      applications: listValue(j['applications']),
      questions: listValue(j['discussion_questions']));
}

class SermonMessage {
  const SermonMessage(
      {required this.role, required this.content, this.sources = const []});
  final String role, content;
  final List<dynamic> sources;
  factory SermonMessage.fromJson(Map<String, dynamic> j) => SermonMessage(
      role: textValue(j['role']),
      content: displayMessageText(textValue(j['content'])),
      sources: listValue(j['sources']));
}

/// Repairs legacy URL-encoded API records without changing ordinary literal
/// percent text typed by a user.
String displayMessageText(String value) {
  if (!RegExp(r'%[0-9a-fA-F]{2}').hasMatch(value) ||
      value.contains(RegExp(r'\s'))) {
    return value;
  }
  try {
    final decoded = Uri.decodeComponent(value);
    return decoded == value || !decoded.contains(RegExp(r'[\s.,?!]'))
        ? value
        : decoded;
  } on FormatException {
    return value;
  }
}

class Devotional {
  const Devotional(
      {required this.id,
      required this.title,
      required this.reference,
      required this.text,
      required this.reflection,
      required this.application,
      required this.prayer,
      this.translation = ''});
  final int id;
  final String title,
      reference,
      text,
      reflection,
      application,
      prayer,
      translation;
  factory Devotional.fromJson(Map<String, dynamic> j) => Devotional(
      id: j['id'] as int? ?? 0,
      title: textValue(j['title']),
      reference: textValue(j['scripture_reference']),
      text: textValue(j['scripture_text']),
      reflection: textValue(j['reflection']),
      application: textValue(j['application']),
      prayer: textValue(j['prayer']),
      translation: textValue(j['translation']));
}

class BibleBook {
  const BibleBook({required this.slug, required this.name, this.chapters = 0});
  final String slug, name;
  final int chapters;
  factory BibleBook.fromJson(Map<String, dynamic> j) => BibleBook(
      slug: textValue(j['id'] ?? j['slug'] ?? j['key']),
      name: textValue(j['name']),
      chapters: intValue(j['chapter_count'] ?? j['chapters']) != 0
          ? intValue(j['chapter_count'] ?? j['chapters'])
          : j['chapters'] is List
              ? (j['chapters'] as List).length
              : 0);
}

class BiblePassage {
  const BiblePassage(
      {required this.reference, required this.text, this.verses = const []});
  final String reference, text;
  final List<dynamic> verses;
  factory BiblePassage.fromJson(Map<String, dynamic> j) {
    final rawVerses = listValue(j['verses']);
    final verseTexts = rawVerses
        .whereType<Map>()
        .map((verse) => textValue(verse['text']))
        .where((text) => text.isNotEmpty)
        .toList();
    final book = j['book'] is Map
        ? textValue((j['book'] as Map)['name'])
        : textValue(j['book']);
    final chapter = textValue(j['chapter']);
    final start = intValue(j['verse_start']);
    final end = intValue(j['verse_end'], start);
    final derivedReference = [
      if (book.isNotEmpty) book,
      if (chapter.isNotEmpty) '$chapter${start > 0 ? ':$start' : ''}',
      if (end > start && start > 0) '-$end',
    ].join(' ');
    return BiblePassage(
        reference: textValue(j['reference']).isNotEmpty
            ? textValue(j['reference'])
            : derivedReference,
        text: textValue(j['text']).isNotEmpty
            ? textValue(j['text'])
            : verseTexts.join('\n'),
        verses: rawVerses);
  }
}

class BibleStudy {
  const BibleStudy(
      {required this.id,
      required this.title,
      required this.reference,
      required this.content,
      this.notes = ''});
  final int id;
  final String title, reference, content, notes;
  factory BibleStudy.fromJson(Map<String, dynamic> j) {
    final rawContent = j['content'];
    final content = rawContent is Map
        ? rawContent.entries
            .map((entry) => '${entry.key}: ${textValue(entry.value)}')
            .join('\n\n')
        : textValue(rawContent);
    return BibleStudy(
        id: j['id'] as int? ?? 0,
        title: textValue(j['title']),
        reference: textValue(j['scripture_reference']),
        content: content,
        notes: textValue(j['personal_notes']));
  }
}

class ReadingPlan {
  const ReadingPlan(
      {required this.id,
      required this.title,
      required this.description,
      required this.days,
      this.completeCanon = false,
      this.enrollmentId,
      this.completedDayIds = const []});
  final int id;
  final String title, description;
  final List<dynamic> days;
  final bool completeCanon;
  final int? enrollmentId;
  final List<int> completedDayIds;
  factory ReadingPlan.fromJson(Map<String, dynamic> j) => ReadingPlan(
      id: j['id'] as int? ?? 0,
      title: textValue(j['title']),
      description: textValue(j['description']),
      days: listValue(j['days']),
      completeCanon: j['complete_canon'] as bool? ?? false,
      enrollmentId: (j['enrollment'] as Map?)?['id'] as int?,
      completedDayIds:
          ((j['enrollment'] as Map?)?['completed_day_ids'] as List?)
                  ?.whereType<int>()
                  .toList() ??
              const []);
}

class ReadingAssignment {
  const ReadingAssignment({
    required this.reference,
    this.translation = 'WEB',
    this.book,
    this.chapter,
  });
  final String reference;
  final String translation;
  final String? book;
  final int? chapter;

  factory ReadingAssignment.fromJson(dynamic value) {
    if (value is String) return ReadingAssignment(reference: value);
    final json = value is Map
        ? value.cast<String, dynamic>()
        : const <String, dynamic>{};
    final reference =
        textValue(json['reference'] ?? json['scripture_reference']);
    final book = textValue(json['book'] ?? json['book_name']);
    final chapter = intValue(json['chapter'] ?? json['chapter_start'], -1);
    final start = intValue(json['verse_start'], -1);
    final end = intValue(json['verse_end'], -1);
    final derived = [
      if (book.isNotEmpty) book,
      if (chapter >= 0) '$chapter${start >= 0 ? ':$start' : ''}',
      if (end > start && start >= 0) '-$end',
    ].join(' ');
    return ReadingAssignment(
      reference: reference.isNotEmpty ? reference : derived,
      translation: textValue(json['translation']).isEmpty
          ? 'WEB'
          : textValue(json['translation']),
      book: book.isEmpty ? null : book,
      chapter: chapter < 0 ? null : chapter,
    );
  }
}
