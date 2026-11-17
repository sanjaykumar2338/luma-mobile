import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';
import 'config.dart';

enum SubscriptionState {
  disabled,
  unavailable,
  idle,
  pending,
  purchased,
  restored,
  error,
}

class SubscriptionStatus {
  const SubscriptionStatus(this.state, {this.message});
  final SubscriptionState state;
  final String? message;
}

/// StoreKit/Play purchase coordinator. Store products and verification stay
/// disabled until product IDs and a Laravel verification endpoint are set.
class SubscriptionManager {
  SubscriptionManager({required this.api, this.onStatus}) {
    _updates = InAppPurchase.instance.purchaseStream.listen(_onPurchases);
  }
  final ApiClient api;
  final void Function(SubscriptionStatus status)? onStatus;
  late final StreamSubscription<List<PurchaseDetails>> _updates;
  final products = <ProductDetails>[];

  Set<String> get productIds => {
        if (AppConfig.monthlyProductId.isNotEmpty) AppConfig.monthlyProductId,
        if (AppConfig.annualProductId.isNotEmpty) AppConfig.annualProductId,
      };

  Future<void> loadProducts() async {
    if (!AppConfig.billingEnabled || productIds.isEmpty) {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.disabled));
      return;
    }
    if (!await InAppPurchase.instance.isAvailable()) {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.unavailable));
      return;
    }
    final response =
        await InAppPurchase.instance.queryProductDetails(productIds);
    products
      ..clear()
      ..addAll(response.productDetails);
    if (response.error != null) {
      onStatus?.call(SubscriptionStatus(
        SubscriptionState.error,
        message: response.error!.message,
      ));
    } else {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.idle));
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!AppConfig.billingEnabled) {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.disabled));
      return;
    }
    onStatus?.call(const SubscriptionStatus(SubscriptionState.pending));
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restore() async {
    if (!AppConfig.billingEnabled) {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.disabled));
      return;
    }
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        onStatus?.call(const SubscriptionStatus(SubscriptionState.pending));
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        onStatus?.call(SubscriptionStatus(
          SubscriptionState.error,
          message: purchase.error?.message ?? 'Purchase failed.',
        ));
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verify(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    if (AppConfig.purchaseVerificationPath.isEmpty) {
      onStatus?.call(const SubscriptionStatus(SubscriptionState.disabled));
      return;
    }
    final source = purchase.verificationData.source.toLowerCase();
    final store = source.contains('google') || source.contains('play')
        ? 'play_store'
        : source.contains('apple') || source.contains('app')
            ? 'app_store'
            : purchase.verificationData.source;
    await api.request(
      AppConfig.purchaseVerificationPath,
      method: 'POST',
      auth: true,
      body: {
        'store': store,
        'product_id': purchase.productID,
        'transaction_id': purchase.purchaseID,
        'verification_data': purchase.verificationData.serverVerificationData,
      },
    );
    onStatus?.call(SubscriptionStatus(
      purchase.status == PurchaseStatus.restored
          ? SubscriptionState.restored
          : SubscriptionState.purchased,
    ));
  }

  Future<void> dispose() => _updates.cancel();
}
