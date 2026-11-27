import 'models.dart';

class SermonCompanionAttachment {
  const SermonCompanionAttachment({required this.id, required this.kind, required this.originalName, required this.status, this.extractedText, this.isUnclear = false, this.processingError});
  final int id;
  final String kind, originalName, status;
  final String? extractedText, processingError;
  final bool isUnclear;

  factory SermonCompanionAttachment.fromJson(Map<String, dynamic> json) => SermonCompanionAttachment(
        id: intValue(json['id']),
        kind: textValue(json['kind']),
        originalName: textValue(json['original_name']),
        status: textValue(json['status']),
        extractedText: json['extracted_text']?.toString(),
        isUnclear: json['is_unclear'] as bool? ?? false,
        processingError: json['processing_error']?.toString(),
      );
}

class SermonCompanionPlan {
  const SermonCompanionPlan({required this.id, required this.daysCount, required this.status, this.processingError, this.completedDays = const []});
  final int id, daysCount;
  final String status;
  final String? processingError;
  final List<int> completedDays;

  factory SermonCompanionPlan.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] is Map ? (json['progress'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return SermonCompanionPlan(
      id: intValue(json['id']),
      daysCount: intValue(json['days_count']),
      status: textValue(json['status']),
      processingError: json['processing_error']?.toString(),
      completedDays: listValue(progress['completed_days']).whereType<num>().map((value) => value.toInt()).toList(),
    );
  }
}

class SermonCompanionDay {
  const SermonCompanionDay({required this.id, required this.dayNumber, required this.title, required this.theme, required this.reference, required this.translation, required this.scriptureText, required this.reflection, required this.question, required this.application, required this.prayer, this.completedAt});
  final int id, dayNumber;
  final String title, theme, reference, translation, scriptureText, reflection, question, application, prayer;
  final String? completedAt;
  bool get completed => completedAt != null;

  factory SermonCompanionDay.fromJson(Map<String, dynamic> json) => SermonCompanionDay(
        id: intValue(json['id']),
        dayNumber: intValue(json['day_number']),
        title: textValue(json['title']),
        theme: textValue(json['theme']),
        reference: textValue(json['scripture_reference']),
        translation: textValue(json['translation']),
        scriptureText: textValue(json['scripture_text']),
        reflection: textValue(json['reflection']),
        question: textValue(json['reflection_question']),
        application: textValue(json['practical_application']),
        prayer: textValue(json['prayer']),
        completedAt: json['completed_at']?.toString(),
      );
}

class SermonCompanionJournalEntry {
  const SermonCompanionJournalEntry({required this.id, required this.entryType, required this.content, this.dayId, this.clientKey});
  final int id;
  final String entryType, content;
  final int? dayId;
  final String? clientKey;

  factory SermonCompanionJournalEntry.fromJson(Map<String, dynamic> json) => SermonCompanionJournalEntry(id: intValue(json['id']), entryType: textValue(json['entry_type']), content: textValue(json['content']), dayId: intValue(json['devotional_day_id'], -1) < 0 ? null : intValue(json['devotional_day_id']), clientKey: json['client_key']?.toString());
}

class SermonCompanionMemoryCard {
  const SermonCompanionMemoryCard({required this.id, required this.reference, required this.translation, required this.verseText, required this.fillInBlank, required this.correctAnswers, this.completed = false, this.attempts = 0});
  final int id;
  final String reference, translation, verseText;
  final List<dynamic> fillInBlank, correctAnswers;
  final bool completed;
  final int attempts;

  factory SermonCompanionMemoryCard.fromJson(Map<String, dynamic> json) {
    final practice = json['practice'] is Map ? (json['practice'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return SermonCompanionMemoryCard(id: intValue(json['id']), reference: textValue(json['reference']), translation: textValue(json['translation']), verseText: textValue(json['verse_text']), fillInBlank: listValue(json['fill_in_blank']), correctAnswers: listValue(json['correct_answers']), completed: practice['completed'] as bool? ?? false, attempts: intValue(practice['attempts']));
  }
}

class SermonCompanion {
  const SermonCompanion({required this.id, required this.title, this.speaker, this.churchName, this.sermonDate, this.youtubeUrl, this.personalNotes = '', this.scriptureReferences = const [], this.keyTakeaways = const [], this.personalReflections = '', this.confirmedNotes, this.recap, required this.status, this.processingError, this.attachments = const [], this.plans = const []});
  final int id;
  final String title, status;
  final String? speaker, churchName, sermonDate, youtubeUrl, confirmedNotes, processingError;
  final String personalNotes, personalReflections;
  final List<String> scriptureReferences, keyTakeaways;
  final Map<String, dynamic>? recap;
  final List<SermonCompanionAttachment> attachments;
  final List<SermonCompanionPlan> plans;

  factory SermonCompanion.fromJson(Map<String, dynamic> json) => SermonCompanion(
        id: intValue(json['id']), title: textValue(json['title']), speaker: json['speaker']?.toString(), churchName: json['church_name']?.toString(), sermonDate: json['sermon_date']?.toString(), youtubeUrl: json['youtube_url']?.toString(), personalNotes: textValue(json['personal_notes']), scriptureReferences: listValue(json['scripture_references']).map(textValue).toList(), keyTakeaways: listValue(json['key_takeaways']).map(textValue).toList(), personalReflections: textValue(json['personal_reflections']), confirmedNotes: json['confirmed_notes']?.toString(), recap: json['recap'] is Map ? (json['recap'] as Map).cast<String, dynamic>() : null, status: textValue(json['status']), processingError: json['processing_error']?.toString(), attachments: listValue(json['attachments']).whereType<Map>().map((item) => SermonCompanionAttachment.fromJson(item.cast<String, dynamic>())).toList(), plans: listValue(json['devotional_plans']).whereType<Map>().map((item) => SermonCompanionPlan.fromJson(item.cast<String, dynamic>())).toList());
}
