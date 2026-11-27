import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/core/sermon_companion_models.dart';

void main() {
  test('parses queued companion resources without inventing content', () {
    final companion = SermonCompanion.fromJson({
      'id': 4,
      'title': 'Sunday notes',
      'status': 'awaiting_transcript',
      'personal_notes': 'Listen and obey.',
      'scripture_references': ['James 1:22'],
      'attachments': [
        {'id': 8, 'kind': 'audio', 'original_name': 'sermon.m4a', 'status': 'queued'},
      ],
      'devotional_plans': [
        {'id': 9, 'days_count': 5, 'status': 'generating', 'progress': {'completed_days': []}},
      ],
    });

    expect(companion.status, 'awaiting_transcript');
    expect(companion.attachments.single.status, 'queued');
    expect(companion.plans.single.daysCount, 5);
    expect(companion.recap, isNull);
  });

  test('reads stable journal client keys and completion state', () {
    final entry = SermonCompanionJournalEntry.fromJson({
      'id': 3,
      'entry_type': 'reflection',
      'content': 'Apply it this week.',
      'client_key': 'companion-4-reflection',
    });
    final day = SermonCompanionDay.fromJson({
      'id': 2,
      'day_number': 1,
      'title': 'Listen',
      'theme': 'Practice',
      'scripture_reference': 'James 1:22',
      'translation': 'KJV',
      'scripture_text': 'Be doers.',
      'reflection': 'Reflect.',
      'reflection_question': 'What will you do?',
      'practical_application': 'Act today.',
      'prayer': 'Help me.',
      'completed_at': '2026-11-27T08:00:00Z',
    });

    expect(entry.clientKey, 'companion-4-reflection');
    expect(day.completed, isTrue);
  });
}
