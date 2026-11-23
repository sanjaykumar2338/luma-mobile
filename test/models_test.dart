import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/core/models.dart';

void main() {
  test('parses user and membership resources', () {
    final user = User.fromJson({
      'id': 7,
      'name': 'Ada',
      'email': 'ada@example.com',
      'is_admin': false,
      'created_at': '2026-01-01'
    });
    final membership = Membership.fromJson({
      'plan': 'premium',
      'status': 'active',
      'renews_or_ends_at': null,
      'billing_enabled': true
    });
    expect(user.name, 'Ada');
    expect(membership.plan, 'premium');
    expect(membership.billingEnabled, isTrue);
  });

  test('parses sermon notes and devotional resources', () {
    final sermon = Sermon.fromJson({
      'id': 9,
      'title': 'Grace in the wilderness',
      'source_type': 'transcript',
      'processing_status': 'completed',
      'notes': {
        'summary': 'A faithful summary',
        'key_points': ['Trust God']
      },
    });
    final devotional = Devotional.fromJson({
      'id': 2,
      'title': 'A steady hope',
      'scripture_reference': 'Romans 5:3-5',
      'scripture_text': 'Hope does not disappoint.',
      'reflection': 'Reflect',
      'application': 'Practice',
      'prayer': 'Lord, lead me.',
    });
    expect(sermon.notes?.summary, 'A faithful summary');
    expect(sermon.notes?.keyPoints.single, 'Trust God');
    expect(devotional.reference, 'Romans 5:3-5');
  });

  test('parses Bible passages and reading plans', () {
    final passage = BiblePassage.fromJson({
      'translation': {'abbreviation': 'WEB'},
      'book': {'id': 'JHN', 'name': 'John'},
      'chapter': 3,
      'verse_start': 16,
      'verse_end': 16,
      'verses': [
        {'number': 16, 'text': 'For God so loved the world.'}
      ]
    });
    final plan = ReadingPlan.fromJson({
      'id': 1,
      'title': 'Seven days',
      'description': 'A beginning',
      'days': [
        {'day_number': 1}
      ],
      'enrollment': {
        'id': 22,
        'completed_day_ids': [4, 5]
      }
    });
    expect(passage.text, contains('loved'));
    expect(passage.reference, 'John 3:16');
    expect(passage.verses, hasLength(1));
    expect(plan.days, hasLength(1));
    expect(plan.enrollmentId, 22);
    expect(plan.completedDayIds, [4, 5]);
  });

  test('uses the API Bible book id and chapter_count fields', () {
    final books = [
      BibleBook.fromJson({'id': 'GEN', 'name': 'Genesis', 'chapter_count': 50}),
      BibleBook.fromJson({'id': 'PSA', 'name': 'Psalms', 'chapter_count': 150}),
      BibleBook.fromJson({'id': 'JHN', 'name': 'John', 'chapter_count': 21}),
    ];

    expect(books.map((book) => book.slug), ['GEN', 'PSA', 'JHN']);
    expect(books.map((book) => book.chapters), [50, 150, 21]);
  });

  test('renders structured Bible study content instead of an empty object', () {
    final study = BibleStudy.fromJson({
      'id': 3,
      'title': 'A study',
      'scripture_reference': 'John 3:16',
      'content': {
        'overview': 'God gives life.',
        'application': ['Trust']
      },
    });

    expect(study.content, contains('overview: God gives life.'));
    expect(study.content, contains('application: [Trust]'));
  });

  test('decodes legacy URL-encoded sermon messages without altering literals', () {
    expect(displayMessageText('What%20is%20this%3F'), 'What is this?');
    expect(displayMessageText('Use 100%20carefully'), 'Use 100%20carefully');
    expect(displayMessageText('What is this?'), 'What is this?');
  });

  test('round-trips notification preferences using the mobile contract', () {
    final preferences = NotificationPreferences.fromJson({
      'enabled': true,
      'sermon_processing': false,
      'devotional_reminders': true,
      'subscription_updates': false,
    });

    expect(preferences.toJson(), {
      'enabled': true,
      'sermon_processing': false,
      'devotional_reminders': true,
      'subscription_updates': false,
    });
  });
}
