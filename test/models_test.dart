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
    final passage = BiblePassage.fromJson(
        {'reference': 'John 3:16', 'text': 'For God so loved the world.'});
    final plan = ReadingPlan.fromJson({
      'id': 1,
      'title': 'Seven days',
      'description': 'A beginning',
      'days': [
        {'day_number': 1}
      ]
    });
    expect(passage.text, contains('loved'));
    expect(plan.days, hasLength(1));
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
