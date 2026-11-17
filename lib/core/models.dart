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
      required this.billingEnabled});
  final String plan;
  final String status;
  final String? endsAt;
  final bool billingEnabled;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        plan: json['plan'] as String? ?? 'free',
        status: json['status'] as String? ?? 'free',
        endsAt: json['renews_or_ends_at'] as String?,
        billingEnabled: json['billing_enabled'] as bool? ?? false,
      );
}

class Entitlements {
  const Entitlements({required this.membership, this.usage = const {}});
  final Membership membership;
  final Map<String, dynamic> usage;

  factory Entitlements.fromJson(Map<String, dynamic> json) => Entitlements(
        membership: Membership.fromJson(
            (json['membership'] as Map?)?.cast<String, dynamic>() ?? const {}),
        usage: (json['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.sermonProcessing = true,
    this.devotionalReminders = true,
    this.subscriptionUpdates = true,
  });
  final bool enabled;
  final bool sermonProcessing;
  final bool devotionalReminders;
  final bool subscriptionUpdates;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: json['enabled'] as bool? ?? true,
        sermonProcessing: json['sermon_processing'] as bool? ?? true,
        devotionalReminders: json['devotional_reminders'] as bool? ?? true,
        subscriptionUpdates: json['subscription_updates'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sermon_processing': sermonProcessing,
        'devotional_reminders': devotionalReminders,
        'subscription_updates': subscriptionUpdates,
      };
}

String textValue(dynamic value) => value?.toString() ?? '';
List<dynamic> listValue(dynamic value) => value is List ? value : const [];

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
      content: textValue(j['content']),
      sources: listValue(j['sources']));
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
      slug: textValue(j['slug'] ?? j['key']),
      name: textValue(j['name']),
      chapters: j['chapters'] as int? ?? 0);
}

class BiblePassage {
  const BiblePassage(
      {required this.reference, required this.text, this.verses = const []});
  final String reference, text;
  final List<dynamic> verses;
  factory BiblePassage.fromJson(Map<String, dynamic> j) => BiblePassage(
      reference: textValue(j['reference']),
      text: textValue(j['text']),
      verses: listValue(j['verses']));
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
  factory BibleStudy.fromJson(Map<String, dynamic> j) => BibleStudy(
      id: j['id'] as int? ?? 0,
      title: textValue(j['title']),
      reference: textValue(j['scripture_reference']),
      content: textValue(j['content']),
      notes: textValue(j['personal_notes']));
}

class ReadingPlan {
  const ReadingPlan(
      {required this.id,
      required this.title,
      required this.description,
      required this.days});
  final int id;
  final String title, description;
  final List<dynamic> days;
  factory ReadingPlan.fromJson(Map<String, dynamic> j) => ReadingPlan(
      id: j['id'] as int? ?? 0,
      title: textValue(j['title']),
      description: textValue(j['description']),
      days: listValue(j['days']));
}
