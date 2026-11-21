import 'package:flutter_test/flutter_test.dart';

import 'package:luma_mobile/core/api_client.dart';
import 'package:luma_mobile/core/config.dart';
import 'package:luma_mobile/core/models.dart';
import 'package:luma_mobile/core/subscriptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('billing defaults stay disabled until store configuration is supplied', () async {
    expect(AppConfig.billingEnabled, isFalse);
    expect(AppConfig.monthlyProductId, isEmpty);
    expect(AppConfig.annualProductId, isEmpty);

    final statuses = <SubscriptionStatus>[];
    final manager = SubscriptionManager(
      api: ApiClient(),
      onStatus: statuses.add,
    );
    await manager.loadProducts();
    await manager.restore();
    await manager.dispose();

    expect(statuses.map((status) => status.state), contains(SubscriptionState.disabled));
  });

  test('membership updates preserve native and website status fields', () {
    final entitlement = Entitlements.fromJson({
      'membership': {
        'plan': 'premium',
        'status': 'active',
        'renews_or_ends_at': '2027-01-01T00:00:00Z',
        'billing_enabled': true,
      },
      'usage': {
        'features': {
          'bible_study': {'used': 1, 'limit': 30, 'remaining': 29},
        },
      },
    });

    expect(entitlement.membership.plan, 'premium');
    expect(entitlement.membership.status, 'active');
    expect(entitlement.membership.endsAt, '2027-01-01T00:00:00Z');
    expect(entitlement.membership.billingEnabled, isTrue);
    expect(entitlement.usage['features'], isA<Map>());
  });

  test('purchase states expose pending, verifying, and failure states', () {
    expect(SubscriptionState.values,
        containsAll([SubscriptionState.pending, SubscriptionState.verifying, SubscriptionState.error]));
    expect(const SubscriptionStatus(SubscriptionState.error, message: 'Store failed').message,
        'Store failed');
  });
}
