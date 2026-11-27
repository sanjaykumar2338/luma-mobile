// Flutter 3.50 currently reports the Material library import as deprecated
// while the app remains on the stable Material 3 API surface.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/api_client.dart';
import 'core/auth_controller.dart';
import 'core/config.dart';
import 'core/models.dart';
import 'core/push_notifications.dart';
import 'core/subscriptions.dart';
import 'ui/luma_design.dart';

const ink = lumaInk;
const cream = lumaCream;
const lime = lumaLime;

const reminderTimezones = [
  'UTC',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Asia/Singapore',
  'Europe/London',
  'Europe/Berlin',
  'America/New_York',
  'America/Los_Angeles',
  'Australia/Sydney',
];

String detectedTimezone() {
  final offset = DateTime.now().timeZoneOffset;
  if (offset == const Duration(hours: 5, minutes: 30)) return 'Asia/Kolkata';
  if (offset == const Duration(hours: 4)) return 'Asia/Dubai';
  if (offset == const Duration(hours: 8)) return 'Asia/Singapore';
  if (offset == Duration.zero) return 'UTC';
  return 'UTC';
}

String formatReminderTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

TimeOfDay parseReminderTime(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 8 : 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

void main() => runApp(const LumaApp());

dynamic dataOf(dynamic value) =>
    value is Map && value['data'] != null ? value['data'] : value;

List<Map<String, dynamic>> mapsOf(dynamic value) {
  final data = dataOf(value);
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}

String prettyStatus(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String membershipLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'free') return 'Free';
  if (normalized == 'premium') return 'Premium';
  return prettyStatus(value);
}

String usageSummary(Map<String, dynamic> usage) {
  const labels = {
    'sermon_processing': 'Sermons',
    'ask_luma': 'Ask LUMA',
    'bible_study': 'Bible studies',
    'devotional': 'Devotionals',
  };
  final rawFeatures = usage['features'];
  final features =
      rawFeatures is Map ? rawFeatures.cast<String, dynamic>() : usage;
  final items = <String>[];
  for (final entry in features.entries) {
    if (entry.value is! Map) continue;
    final values = (entry.value as Map).cast<String, dynamic>();
    final used = values['used'];
    final limit = values['limit'];
    if (used == null || limit == null) continue;
    items.add('${labels[entry.key] ?? prettyStatus(entry.key)} $used/$limit');
  }
  return items.isEmpty ? 'Unavailable' : items.join(' · ');
}

void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> copyText(BuildContext context, String text, String label) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }
}

class LumaApp extends StatefulWidget {
  const LumaApp({super.key});

  @override
  State<LumaApp> createState() => _LumaAppState();
}

class _LumaAppState extends State<LumaApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  late final ApiClient api = ApiClient();
  PushNotificationGateway? push;
  late final AuthController auth = AuthController(
      api: api,
      beforeSignOut: () async {
        await push?.unregister();
      })
    ..restore();

  @override
  void initState() {
    super.initState();
    auth.addListener(_authChanged);
    configureFirebaseBackgroundHandler();
    _authChanged();
  }

  void _authChanged() {
    if (!auth.isAuthenticated || push != null || !AppConfig.firebaseEnabled) {
      return;
    }
    final gateway = FirebasePushNotificationGateway(
        api: api,
        onMessage: _handleForegroundNotification,
        onMessageTap: _handleNotificationTap);
    push = gateway;
    gateway.register().catchError((_) {
      // Notification delivery is optional; account access must not depend on
      // provider availability or a missing Firebase configuration.
      return null;
    });
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final route = message.data['route']?.toString();
    if (route == null) return;
    final match = RegExp(r'^/sermons/(\d+)$').firstMatch(route);
    if (match != null) {
      try {
        final response =
            await api.request('/sermons/${match.group(1)}', auth: true);
        final data = dataOf(response);
        if (data is Map && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(MaterialPageRoute(
              builder: (_) => SermonDetail(
                  api: api,
                  sermon: Sermon.fromJson(data.cast<String, dynamic>()))));
        }
      } on ApiException catch (error) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) showError(context, error);
      }
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (route.startsWith('/devotionals/')) {
      navigator.push(MaterialPageRoute(builder: (_) => Devotionals(api: api)));
    } else if (route.startsWith('/reading-plans/')) {
      navigator.push(MaterialPageRoute(builder: (_) => ReadingPlans(api: api)));
    } else if (route == '/entitlements') {
      navigator.push(MaterialPageRoute(
          builder: (_) => AccountSettings(auth: auth, api: api)));
    }
  }

  void _handleForegroundNotification(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    final notification = message.notification;
    if (context == null || !context.mounted || notification == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notification.title ?? notification.body ?? 'LUMA update'),
        action: message.data['route'] == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () => _handleNotificationTap(message))));
  }

  @override
  void dispose() {
    auth.removeListener(_authChanged);
    push?.dispose();
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'LUMA',
        theme: lumaTheme(),
        home: auth.loading
            ? const SplashScreen()
            : auth.isAuthenticated
                ? AppShell(auth: auth, api: api)
                : WelcomeScreen(auth: auth),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.dark = false, this.size = 84});
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => LumaMark(dark: dark, size: size);
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(dark: true),
              SizedBox(height: 18),
              Text('LUMA',
                  style: TextStyle(
                      color: cream,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5)),
            ],
          ),
        ),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.auth, super.key});
  final AuthController auth;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Stack(children: [
            Positioned(
                right: -150,
                top: -20,
                child: Container(
                    width: 430,
                    height: 430,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                            colors: [lumaLimeSoft, Color(0x00E8F8B4)])))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    BrandMark(size: 48),
                    const SizedBox(width: 12),
                    const Text('LUMA',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4)),
                  ]),
                  const Spacer(),
                  const LumaTag('From Sunday to everyday'),
                  const SizedBox(height: 22),
                  const Text("Don't just hear\nthe Word.",
                      style: TextStyle(
                          color: ink,
                          fontSize: 44,
                          height: 1.08,
                          letterSpacing: -1.6,
                          fontWeight: FontWeight.w700)),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: lime,
                    child: const Text('Live it.',
                        style: TextStyle(
                            color: ink,
                            fontSize: 44,
                            height: 1.04,
                            letterSpacing: -1.6,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                      'Turn sermons into clear notes, explore the Scriptures behind the message, and take practical steps to live what you learn.',
                      style: TextStyle(
                          color: lumaMuted, fontSize: 17, height: 1.52)),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AuthScreen(auth: auth))),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Create your free account'),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward, size: 24)
                        ]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AuthScreen(auth: auth, login: true))),
                      child: const Text('I already have an account'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                        'Sermon study is available now. More tools are on the way.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: lumaMuted, fontSize: 13)),
                  )
                ],
              ),
            )
          ]),
        ),
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.auth, this.login = false, super.key});
  final AuthController auth;
  final bool login;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool login = widget.login;
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      if (login) {
        await widget.auth.signIn(email.text.trim(), password.text);
      } else {
        await widget.auth.register(name.text.trim(), email.text.trim(),
            password.text, confirmation.text);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController controller, String label,
      {bool secret = false, bool emailField = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: secret,
        keyboardType: emailField ? TextInputType.emailAddress : null,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter your ${label.toLowerCase()}'
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(login ? 'Welcome back' : 'Create your account')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                  login
                      ? 'Continue your journey.'
                      : 'A thoughtful space for Scripture and reflection.',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 30),
              if (!login) field(name, 'Name'),
              field(email, 'Email', emailField: true),
              field(password, 'Password', secret: true),
              if (!login) field(confirmation, 'Confirm password', secret: true),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy
                      ? 'Please wait...'
                      : login
                          ? 'Sign in'
                          : 'Create account')),
              if (login)
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ForgotPasswordScreen(auth: widget.auth))),
                    child: const Text('Forgot your password?')),
              TextButton(
                  onPressed: () => setState(() => login = !login),
                  child: Text(login
                      ? 'Create a new account'
                      : 'I already have an account')),
            ],
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.auth, super.key});
  final AuthController auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  bool sent = false;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() => busy = true);
    try {
      await widget.auth.forgotPassword(email.text.trim());
      if (mounted) setState(() => sent = true);
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: sent
              ? const Center(
                  child:
                      Text('If an account exists, a reset link has been sent.'))
              : Column(
                  children: [
                    const Text(
                        'Enter your email and we will send a reset link.',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: busy ? null : send,
                        child: Text(busy ? 'Sending...' : 'Send reset link')),
                  ],
                ),
        ),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({required this.auth, required this.api, super.key});
  final AuthController auth;
  final ApiClient api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  void select(int value) {
    if (value == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SubmitSermon(api: widget.api)));
      return;
    }
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(auth: widget.auth, api: widget.api),
      SermonLibrary(api: widget.api),
      const SizedBox.shrink(),
      ReadingPlans(api: widget.api),
      MoreHub(auth: widget.auth, api: widget.api),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: LumaBottomBar(index: index, onChanged: select),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame(
      {required this.title,
      required this.child,
      this.action,
      this.onRefresh,
      super.key});
  final String title;
  final Widget child;
  final Widget? action;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(title,
                style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6)),
            actions: action == null ? null : [action!]),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: onRefresh ?? () async {},
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: child))),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.message, super.key});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Center(
          child: Column(children: [
        const Icon(Icons.auto_awesome_outlined,
            size: 48, color: Colors.black38),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54))
      ])));
}

class RetryState extends StatelessWidget {
  const RetryState(
      {required this.title,
      required this.message,
      required this.onRetry,
      super.key});
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(children: [
        EmptyState(title: title, message: message),
        FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'))
      ]);
}

class Dashboard extends StatefulWidget {
  const Dashboard({required this.auth, required this.api, super.key});
  final AuthController auth;
  final ApiClient api;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool busy = true;
  String? error;
  Entitlements? entitlements;
  Devotional? devotional;
  List<Sermon> sermons = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        widget.api.request('/entitlements', auth: true),
        widget.api.request('/devotionals/today', auth: true),
        widget.api.request('/sermons',
            auth: true, query: {'page': '1', 'per_page': '3'}),
      ]);
      final entitlementData = dataOf(results[0]);
      final devotionalData = dataOf(results[1]);
      if (!mounted) return;
      setState(() {
        entitlements = Entitlements.fromJson(
            (entitlementData as Map).cast<String, dynamic>());
        if (devotionalData is Map) {
          devotional =
              Devotional.fromJson(devotionalData.cast<String, dynamic>());
        }
        sermons = mapsOf(results[2]).map(Sermon.fromJson).toList();
        busy = false;
      });
    } catch (value) {
      if (mounted) {
        setState(() {
          error = value.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.auth.user?.name.split(' ').first ?? 'friend';
    final featured = sermons.isNotEmpty ? sermons.first : null;
    final recent = sermons.skip(1).map((sermon) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: ink, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.play_arrow, color: lime)),
              title: Text(sermon.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${prettyStatus(sermon.sourceType)} · ${prettyStatus(sermon.status)}'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          SermonDetail(api: widget.api, sermon: sermon))),
            ),
          ),
        ));
    final recentContent = sermons.length > 1
        ? Column(children: recent.toList())
        : const EmptyState(
            title: 'Your library is ready',
            message: 'Submit a sermon to begin your study library.');
    return PageFrame(
      title: 'Good morning, $firstName',
      action: const LumaIconButton(
          icon: Icons.notifications_none,
          label: 'Notifications',
          onPressed: null),
      onRefresh: load,
      child: busy
          ? const Loading()
          : error != null
              ? RetryState(
                  title: 'Could not load your day',
                  message: error!,
                  onRetry: load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(color: lumaMuted, fontSize: 13)),
                    const SizedBox(height: 18),
                    LumaDarkCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Row(children: [
                                  Icon(Icons.circle, size: 9, color: lime),
                                  SizedBox(width: 8),
                                  Text("This week's message",
                                      style: TextStyle(color: lumaMuted2))
                                ]),
                                LumaTag('Example study', dark: true)
                              ]),
                          const SizedBox(height: 18),
                          Text(featured?.title ?? 'Bring in your first message',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: cream,
                                  fontSize: 25,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              featured == null
                                  ? 'Start your first sermon study'
                                  : prettyStatus(featured.status),
                              style: const TextStyle(color: lumaMuted2)),
                          const SizedBox(height: 18),
                          const LumaProgressBar(value: .6),
                          const SizedBox(height: 8),
                          const Text('3 of 5 study steps complete',
                              style: TextStyle(color: lumaMuted2)),
                          const SizedBox(height: 14),
                          LumaAccentButton(
                              label: 'Continue study',
                              onPressed: featured == null
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SermonDetail(
                                              api: widget.api,
                                              sermon: featured))))
                        ])),
                    const SizedBox(height: 24),
                    const LumaEyebrow("Today's next step"),
                    const SizedBox(height: 8),
                    Card(
                        child: ListTile(
                            leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: lumaLimeSoft,
                                    borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.auto_awesome_outlined,
                                    color: ink)),
                            title: Text(
                                devotional?.title ?? 'Pause before you answer',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(devotional?.reference ??
                                'Take one practical step from what you heard.'))),
                    const SizedBox(height: 24),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const LumaEyebrow('Recent messages'),
                          TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          SermonLibrary(api: widget.api))),
                              child: const Text('See all'))
                        ]),
                    recentContent,
                  ],
                ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))
          ])));
}

class UsageOverview extends StatelessWidget {
  const UsageOverview({required this.usage, super.key});
  final Map<String, dynamic> usage;

  @override
  Widget build(BuildContext context) {
    final raw = usage['features'];
    final features = raw is Map ? raw.cast<String, dynamic>() : usage;
    const labels = {
      'sermon_processing': 'Sermons',
      'ask_luma': 'Ask LUMA',
      'bible_study': 'Bible studies',
      'devotional': 'Devotionals'
    };
    final entries = features.entries
        .where((entry) => entry.value is Map)
        .map((entry) =>
            MapEntry(entry.key, (entry.value as Map).cast<String, dynamic>()))
        .where((entry) =>
            entry.value['used'] != null && entry.value['limit'] != null)
        .toList();
    if (entries.isEmpty) return const Text('Usage unavailable');
    return Column(
        children: entries.map((entry) {
      final used = intValue(entry.value['used']);
      final limit = intValue(entry.value['limit']);
      final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
      return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(labels[entry.key] ?? prettyStatus(entry.key)),
              Text('$used/$limit',
                  style: const TextStyle(color: Colors.black54))
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress)
          ]));
    }).toList());
  }
}

class SermonLibrary extends StatefulWidget {
  const SermonLibrary({required this.api, super.key});
  final ApiClient api;
  @override
  State<SermonLibrary> createState() => _SermonLibraryState();
}

class _SermonLibraryState extends State<SermonLibrary> {
  bool busy = true;
  String? error;
  int page = 1;
  String? statusFilter;
  final search = TextEditingController();
  List<Sermon> sermons = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final query = <String, String>{'page': '$page', 'per_page': '12'};
      if (search.text.trim().isNotEmpty) query['search'] = search.text.trim();
      if (statusFilter != null) query['status'] = statusFilter!;
      final response =
          await widget.api.request('/sermons', auth: true, query: query);
      if (mounted) {
        setState(() {
          sermons = mapsOf(response).map(Sermon.fromJson).toList();
          busy = false;
          error = null;
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() {
          error = value.toString();
          busy = false;
        });
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final items = sermons
        .map((sermon) => Card(
            child: ListTile(
                title: Text(sermon.title),
                subtitle: Text(prettyStatus(sermon.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SermonDetail(api: widget.api, sermon: sermon))))))
        .toList();
    return PageFrame(
      title: 'Sermon library',
      action: IconButton(
          onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SubmitSermon(api: widget.api)))
              .then((_) => load()),
          icon: const Icon(Icons.add)),
      onRefresh: load,
      child: busy
          ? const Loading()
          : error != null
              ? RetryState(
                  title: 'Library unavailable', message: error!, onRetry: load)
              : Column(children: [
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              page = 1;
                              load();
                            },
                            decoration: const InputDecoration(
                                labelText: 'Search sermons',
                                prefixIcon: Icon(Icons.search)))),
                    const SizedBox(width: 8),
                    IconButton(
                        tooltip: 'Apply search',
                        onPressed: () {
                          page = 1;
                          load();
                        },
                        icon: const Icon(Icons.arrow_forward))
                  ]),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                      value: statusFilter,
                      decoration:
                          const InputDecoration(labelText: 'Filter by status'),
                      items: const [
                        DropdownMenuItem<String?>(
                            value: null, child: Text('All sermons')),
                        DropdownMenuItem(
                            value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(
                            value: 'failed', child: Text('Needs attention')),
                        DropdownMenuItem(
                            value: 'analyzing', child: Text('Processing')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          statusFilter = value;
                          page = 1;
                        });
                        load();
                      }),
                  const SizedBox(height: 12),
                  if (sermons.isEmpty)
                    const EmptyState(
                        title: 'No sermons yet',
                        message:
                            'Submit a video link, transcript, or file to begin.')
                  else
                    ...items,
                  if (sermons.isNotEmpty)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          onPressed: page > 1
                              ? () {
                                  page--;
                                  load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left)),
                      Text('Page $page'),
                      IconButton(
                          onPressed: sermons.length == 12
                              ? () {
                                  page++;
                                  load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right))
                    ])
                ]),
    );
  }
}

class SubmitSermon extends StatefulWidget {
  const SubmitSermon({required this.api, super.key});
  final ApiClient api;
  @override
  State<SubmitSermon> createState() => _SubmitSermonState();
}

class _SubmitSermonState extends State<SubmitSermon> {
  int mode = 0;
  bool busy = false;
  String? path;
  String? fileName;
  final title = TextEditingController();
  final url = TextEditingController();
  final transcript = TextEditingController();
  static const extensions = [
    'flac',
    'mp3',
    'mp4',
    'mpeg',
    'mpga',
    'm4a',
    'ogg',
    'wav',
    'webm'
  ];
  static const maxBytes = 25600 * 1024;
  @override
  void dispose() {
    title.dispose();
    url.dispose();
    transcript.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: extensions);
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    if (file.size > maxBytes) {
      if (mounted) {
        showError(
            context, const ApiException('Choose a file smaller than 25 MB.'));
      }
      return;
    }
    setState(() {
      path = file.path;
      fileName = file.name;
    });
  }

  Future<void> submit() async {
    if ((mode == 0 && url.text.trim().isEmpty) ||
        (mode == 1 && transcript.text.trim().isEmpty)) {
      showError(context, const ApiException('Add a link or transcript first.'));
      return;
    }
    if (mode == 2 && path == null) {
      showError(
          context, const ApiException('Choose an audio or video file first.'));
      return;
    }
    setState(() => busy = true);
    try {
      Map<String, dynamic>? created;
      if (mode == 2) {
        final response =
            await widget.api.uploadSermon(path!, title: title.text);
        final data = dataOf(response);
        if (data is Map) created = data.cast<String, dynamic>();
      } else {
        final response = await widget.api
            .request('/sermons', method: 'POST', auth: true, body: {
          'source_type': mode == 0 ? 'url' : 'transcript',
          'title': title.text.trim(),
          if (mode == 0) 'source_url': url.text.trim(),
          if (mode == 1) 'transcript': transcript.text.trim(),
          'auto_process': true
        });
        final data = dataOf(response);
        if (data is Map) created = data.cast<String, dynamic>();
      }
      if (mounted) {
        final id = created?['id'];
        if (id is int) {
          await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => SermonProcessingScreen(
                      api: widget.api,
                      sermonId: id,
                      title: textValue(created?['title']).isEmpty
                          ? title.text.trim()
                          : textValue(created?['title']))));
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Sermon submitted. Processing status is not available yet.')));
        }
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('New study')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            const Text('Bring in a message.',
                style: TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8)),
            const SizedBox(height: 8),
            const Text(
                'Choose how you want to add the sermon or teaching you heard.'),
            const SizedBox(height: 22),
            _captureOption(0, Icons.link, 'Paste a link',
                'YouTube, podcast, or church site'),
            const SizedBox(height: 10),
            _captureOption(2, Icons.mic_none, 'Upload audio or video',
                'Recordings you have permission to use'),
            const SizedBox(height: 10),
            _captureOption(1, Icons.description_outlined, 'Paste a transcript',
                'Text from a sermon or teaching'),
            const SizedBox(height: 10),
            Opacity(
                opacity: .65,
                child: Card(
                    child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Start from my notes',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: const LumaEyebrow('Soon')))),
            const SizedBox(height: 16),
            TextField(
                controller: title,
                decoration:
                    const InputDecoration(labelText: 'Title (optional)')),
            const SizedBox(height: 12),
            if (mode == 0)
              TextField(
                  controller: url,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.link), hintText: 'https://...'))
            else if (mode == 1)
              TextField(
                  controller: transcript,
                  onChanged: (_) => setState(() {}),
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                      hintText: 'Paste the transcript here'))
            else
              OutlinedButton.icon(
                  onPressed: busy ? null : pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(fileName ?? 'Choose audio or video')),
            const SizedBox(height: 8),
            const Text('Only add media you own or have permission to use.',
                style: TextStyle(color: lumaMuted, fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: busy ||
                        ((mode == 0 && url.text.trim().isEmpty) ||
                            (mode == 1 && transcript.text.trim().isEmpty) ||
                            (mode == 2 && path == null))
                    ? null
                    : submit,
                child: Text(busy ? 'Creating study...' : 'Create study  →'))
          ]));

  Widget _captureOption(
      int value, IconData icon, String title, String subtitle) {
    final selected = mode == value;
    return InkWell(
      onTap: busy ? null : () => setState(() => mode = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: lumaSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? ink : lumaLine, width: selected ? 2 : 1)),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: selected ? ink : cream,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: selected ? lime : ink)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: lumaMuted, fontSize: 12))
              ])),
          if (selected)
            Container(
                width: 22,
                height: 22,
                decoration:
                    const BoxDecoration(color: lime, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 15))
        ]),
      ),
    );
  }
}

class SermonStudyShell extends StatefulWidget {
  const SermonStudyShell({required this.api, required this.sermon, super.key});
  final ApiClient api;
  final Sermon sermon;

  @override
  State<SermonStudyShell> createState() => _SermonStudyShellState();
}

class _SermonStudyShellState extends State<SermonStudyShell> {
  int tab = 0;
  final question = TextEditingController();
  final journal = TextEditingController();
  final messages = <SermonMessage>[];
  Timer? journalTimer;
  bool messagesBusy = true;
  bool asking = false;
  bool journalSaved = false;
  bool nextStepSaved = false;
  String? messagesError;

  SermonNote? get note => widget.sermon.notes;

  @override
  void initState() {
    super.initState();
    loadMessages();
    journal.addListener(scheduleJournalSave);
  }

  @override
  void didUpdateWidget(covariant SermonStudyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sermon.id != widget.sermon.id) loadMessages();
  }

  @override
  void dispose() {
    question.dispose();
    journal.removeListener(scheduleJournalSave);
    journal.dispose();
    journalTimer?.cancel();
    super.dispose();
  }

  Future<void> loadMessages() async {
    setState(() => messagesBusy = true);
    try {
      final response = await widget.api.request(
          '/sermons/${widget.sermon.id}/conversation/messages',
          auth: true);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(mapsOf(response).map(SermonMessage.fromJson));
        messagesError = null;
        messagesBusy = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          messagesError = error.message;
          messagesBusy = false;
        });
      }
    }
  }

  void scheduleJournalSave() {
    journalTimer?.cancel();
    setState(() => journalSaved = false);
    journalTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => journalSaved = true);
    });
  }

  Future<void> ask() async {
    final text = question.text.trim();
    if (text.isEmpty || asking) return;
    question.clear();
    setState(() {
      asking = true;
      messages.add(SermonMessage(role: 'user', content: text));
    });
    try {
      final response = await widget.api.request(
          '/sermons/${widget.sermon.id}/conversation/messages',
          method: 'POST',
          auth: true,
          body: {'content': text});
      final data = dataOf(response);
      if (data is Map && data['answer'] is Map) {
        final answer = SermonMessage.fromJson(
            (data['answer'] as Map).cast<String, dynamic>());
        if (mounted) setState(() => messages.add(answer));
      } else {
        throw const ApiException('LUMA returned no answer. Please retry.');
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => asking = false);
    }
  }

  List<String> references() => (note?.scriptures ?? const [])
      .map((item) => item is Map
          ? textValue(item['reference'] ?? item['scripture_reference'])
          : textValue(item))
      .where((value) => value.isNotEmpty)
      .toList();

  void openReference(String reference) {
    final match =
        RegExp(r'^([1-3]?\s?[A-Za-z]+)\s+(\d+)').firstMatch(reference);
    if (match == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BibleReader(
                api: widget.api,
                initialBook: match.group(1),
                initialChapter: int.tryParse(match.group(2)!))));
  }

  List<Widget> keyPointWidgets() {
    final points = note?.keyPoints ?? const [];
    return points
        .asMap()
        .entries
        .map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
                child: ListTile(
                    leading: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                            color: ink, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(
                                color: lime,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                    title: Text(textValue(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.w600))))))
        .toList();
  }

  Widget notesTab() {
    final chat = messages.map((message) {
      final isUser = message.role == 'user';
      return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: isUser ? ink : lumaSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: isUser ? null : Border.all(color: lumaLine)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isUser ? 'You' : 'LUMA',
                            style: TextStyle(
                                color: isUser ? lime : lumaMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(message.content,
                            style: TextStyle(
                                color: isUser ? cream : ink, height: 1.4))
                      ]))));
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LumaEyebrow('The big idea'),
      const SizedBox(height: 8),
      LumaDarkCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 4,
            height: 62,
            decoration: BoxDecoration(
                color: lime, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 14),
        Expanded(
            child: Text(
                note?.mainIdea.isNotEmpty == true
                    ? note!.mainIdea
                    : 'Faith grows when what we hear becomes a way of life.',
                style: const TextStyle(
                    color: cream,
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w600)))
      ])),
      const SizedBox(height: 24),
      const LumaEyebrow('Key points'),
      const SizedBox(height: 8),
      if (note?.keyPoints.isNotEmpty != true)
        const Text('Key points will appear when processing is complete.'),
      ...keyPointWidgets(),
      const SizedBox(height: 18),
      const LumaEyebrow('Ask LUMA'),
      if (messagesBusy) const LinearProgressIndicator(),
      if (messagesError != null)
        Text(messagesError!, style: const TextStyle(color: Colors.red)),
      ...chat,
      Row(children: [
        Expanded(
            child: TextField(
                controller: question,
                enabled: !asking,
                onSubmitted: (_) => ask(),
                decoration:
                    const InputDecoration(hintText: 'Ask about this sermon'))),
        IconButton(
            tooltip: 'Ask LUMA',
            onPressed: asking ? null : ask,
            icon: const Icon(Icons.send))
      ]),
    ]);
  }

  Widget scriptureTab() {
    final refs = references();
    final transcript = widget.sermon.transcript?.trim() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (refs.isEmpty)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'No Scripture references were returned for this sermon yet.'))),
      ...refs.map((reference) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(reference.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                      color: lumaMuted)),
                              const Text('PUBLIC DOMAIN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      color: lumaMuted))
                            ]),
                        const SizedBox(height: 14),
                        const Text(
                            'Open this reference in the Bible reader. The app only shows verse text returned by the Bible API.',
                            style: TextStyle(fontSize: 16, height: 1.45)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: () => openReference(reference),
                            icon:
                                const Icon(Icons.menu_book_outlined, size: 18),
                            label: Text('Read $reference'))
                      ]))))),
      const SizedBox(height: 8),
      const LumaEyebrow('What the speaker said'),
      const SizedBox(height: 8),
      Card(
          child: Container(
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: ink, width: 5))),
              padding: const EdgeInsets.all(16),
              child: Text(
                  transcript.isEmpty
                      ? 'No transcript is available for this sermon.'
                      : transcript,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.45)))),
      const SizedBox(height: 18),
      const LumaEyebrow('Context added by LUMA'),
      const SizedBox(height: 8),
      LumaDarkCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.circle, color: lime, size: 9),
          SizedBox(width: 8),
          Text('Generated explanation',
              style: TextStyle(color: lime, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 12),
        Text(
            note?.summary.isNotEmpty == true
                ? note!.summary
                : 'LUMA context will appear when the sermon study is complete.',
            style: const TextStyle(color: cream, height: 1.5)),
        const SizedBox(height: 16),
        const Divider(color: lumaCard2),
        const SizedBox(height: 10),
        const Text(
            'LUMA additions are labeled so you can tell them apart from the speaker’s words.',
            style: TextStyle(color: lumaMuted2, fontSize: 12, height: 1.4))
      ])),
      LumaFooterCta(
          label: 'Continue to Reflect',
          onPressed: () => setState(() => tab = 2)),
    ]);
  }

  Widget reflectTab() {
    final reflection = note?.questions.isNotEmpty == true
        ? textValue(note!.questions.first)
        : 'Where is God asking you to move from hearing to doing this week?';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LumaEyebrow('Reflection question'),
      const SizedBox(height: 8),
      Text(reflection,
          style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5)),
      const SizedBox(height: 16),
      Stack(children: [
        TextField(
            controller: journal,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
                hintText: 'Write what stands out to you.',
                alignLabelWithHint: true)),
        Positioned(
            right: 14,
            bottom: 10,
            child: Text(journalSaved ? 'Saved on this device' : 'Private',
                style: const TextStyle(color: lumaMuted, fontSize: 11)))
      ]),
      const SizedBox(height: 24),
      const LumaEyebrow('My next step'),
      const SizedBox(height: 8),
      LumaDarkCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pause before I respond',
            style: TextStyle(
                color: cream, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Check in each day this week',
            style: TextStyle(color: lumaMuted2)),
        const SizedBox(height: 18),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                7,
                (index) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: nextStepSaved && index == 0 ? lime : lumaCard2,
                        border: index == 0 && !nextStepSaved
                            ? Border.all(color: lime, width: 1.5)
                            : null,
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                        style: TextStyle(
                            color: nextStepSaved && index == 0 ? ink : cream,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)))))
      ])),
      const SizedBox(height: 18),
      const LumaEyebrow('Prayer prompt'),
      const SizedBox(height: 8),
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: lumaLimeSoft, borderRadius: BorderRadius.circular(20)),
          child: const Text(
              'Lord, help me hear Your Word and live it with patience and love.',
              style: TextStyle(
                  fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
      LumaFooterCta(
          label: nextStepSaved ? 'Saved my next step' : 'Save my next step',
          accent: true,
          onPressed: () => setState(() => nextStepSaved = true)),
      if (nextStepSaved)
        const Text(
            'Saved on this device for this session. Account synchronization requires a backend journal endpoint.',
            style: TextStyle(color: lumaMuted, fontSize: 12, height: 1.4)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sermon study'), actions: [
          IconButton(
              tooltip: 'Share sermon',
              onPressed: () => copyText(context, widget.sermon.title, 'Title'),
              icon: const Icon(Icons.share_outlined))
        ]),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const LumaTag('Example study'),
              const SizedBox(height: 10),
              Text(widget.sermon.title,
                  style: const TextStyle(
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7)),
              const SizedBox(height: 6),
              Text(
                  '${prettyStatus(widget.sermon.sourceType)} · ${prettyStatus(widget.sermon.status)}',
                  style: const TextStyle(color: lumaMuted)),
              const SizedBox(height: 18),
              LumaStudySegmented(
                  selected: tab,
                  onChanged: (value) => setState(() => tab = value)),
              const SizedBox(height: 22),
              if (tab == 0) notesTab(),
              if (tab == 1) scriptureTab(),
              if (tab == 2) reflectTab()
            ]),
      );
}

String sermonProcessingLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'submitted':
    case 'queued':
      return 'Submitted';
    case 'awaiting_captions':
    case 'awaiting_transcript':
      return 'Awaiting transcript';
    case 'retrieving_transcript':
    case 'retrieving_content':
      return 'Retrieving content';
    case 'transcribing':
      return 'Transcribing';
    case 'processing':
    case 'analyzing':
      return 'Processing';
    case 'completed':
    case 'complete':
      return 'Completed';
    case 'failed':
    case 'error':
      return 'Failed';
    default:
      return status.trim().isEmpty ? 'Submitted' : prettyStatus(status);
  }
}

class SermonProcessingScreen extends StatefulWidget {
  const SermonProcessingScreen(
      {required this.api,
      required this.sermonId,
      required this.title,
      super.key});
  final ApiClient api;
  final int sermonId;
  final String title;
  @override
  State<SermonProcessingScreen> createState() => _SermonProcessingScreenState();
}

class _SermonProcessingScreenState extends State<SermonProcessingScreen> {
  Sermon? sermon;
  Timer? poller;
  String? error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final response =
          await widget.api.request('/sermons/${widget.sermonId}', auth: true);
      final data = dataOf(response);
      if (data is! Map) {
        throw const ApiException('The sermon status response was invalid.');
      }
      final loaded = Sermon.fromJson(data.cast<String, dynamic>());
      if (!mounted) return;
      setState(() {
        sermon = loaded;
        error = null;
        busy = false;
      });
      final label = sermonProcessingLabel(loaded.status);
      if (label == 'Completed' || label == 'Failed') {
        poller?.cancel();
      } else {
        poller ??= Timer.periodic(const Duration(seconds: 5), (_) => load());
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.message;
          busy = false;
        });
      }
    }
  }

  Future<void> retry() async {
    setState(() => busy = true);
    try {
      await widget.api.request('/sermons/${widget.sermonId}/process',
          method: 'POST', auth: true);
      await load();
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.message;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = sermonProcessingLabel(sermon?.status ?? 'submitted');
    const stages = [
      'Submitted',
      'Awaiting transcript',
      'Retrieving content',
      'Transcribing',
      'Processing',
      'Completed'
    ];
    final rank = stages.indexOf(label);
    return Scaffold(
        appBar: AppBar(title: const Text('New study')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const LumaEyebrow('Study processing'),
              const SizedBox(height: 10),
              Text(widget.title.isEmpty ? 'Your message' : widget.title,
                  style: const TextStyle(
                      fontSize: 30, height: 1.15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                  'LUMA will update this screen from the server-reported processing state.',
                  style:
                      TextStyle(color: lumaMuted, fontSize: 16, height: 1.45)),
              const SizedBox(height: 24),
              LumaDarkCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const LumaEyebrow('Current status', dark: true),
                          LumaTag(label, dark: true)
                        ]),
                    const SizedBox(height: 22),
                    ...stages.asMap().entries.map((entry) {
                      final reached = rank >= entry.key && label != 'Failed';
                      final active = entry.value == label;
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(children: [
                            Icon(
                                reached
                                    ? Icons.check_circle
                                    : active
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                color: reached || active ? lime : lumaMuted2,
                                size: 20),
                            const SizedBox(width: 12),
                            Text(entry.value,
                                style: TextStyle(
                                    color:
                                        reached || active ? cream : lumaMuted2,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w400))
                          ]));
                    }),
                    if (label == 'Failed')
                      Text(
                          sermon?.error ??
                              error ??
                              'The server could not process this message.',
                          style: const TextStyle(color: cream, height: 1.4))
                  ])),
              if (busy)
                const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator(color: lumaLime)),
              if (error != null && label != 'Failed')
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 18),
              if (label == 'Completed')
                LumaFooterCta(
                    label: 'Open study',
                    accent: true,
                    onPressed: sermon == null
                        ? null
                        : () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SermonDetail(
                                    api: widget.api, sermon: sermon!)))),
              if (label == 'Failed')
                LumaFooterCta(
                    label: 'Retry processing', onPressed: busy ? null : retry),
              if (label != 'Completed' && label != 'Failed')
                OutlinedButton(
                    onPressed: load, child: const Text('Refresh status'))
            ]));
  }
}

class SermonDetail extends StatefulWidget {
  const SermonDetail({required this.api, required this.sermon, super.key});
  final ApiClient api;
  final Sermon sermon;
  @override
  State<SermonDetail> createState() => _SermonDetailState();
}

class _SermonDetailState extends State<SermonDetail> {
  late Sermon sermon = widget.sermon;
  final question = TextEditingController();
  late final title = TextEditingController(text: widget.sermon.title);
  final messages = <SermonMessage>[];
  bool busy = false;
  bool messagesBusy = false;
  bool asking = false;
  String? messagesError;
  String? askError;
  String? lastQuestion;

  Future<void> createDevotional() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.request(
          '/sermons/${sermon.id}/devotional',
          method: 'POST',
          auth: true);
      final data = dataOf(response);
      if (data is! Map) {
        throw const ApiException('The devotional response was invalid.');
      }
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DevotionalDetail(
                  devotional:
                      Devotional.fromJson(data.cast<String, dynamic>()))));
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    question.dispose();
    title.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    if (mounted) setState(() => messagesBusy = true);
    try {
      final response = await widget.api
          .request('/sermons/${sermon.id}/conversation/messages', auth: true);
      final loaded = mapsOf(response).map(SermonMessage.fromJson).toList();
      if (mounted) {
        setState(() {
          messages
            ..clear()
            ..addAll(loaded);
          messagesError = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => messagesError = error.message);
    } finally {
      if (mounted) setState(() => messagesBusy = false);
    }
  }

  Future<void> refresh() async {
    setState(() => busy = true);
    try {
      final response =
          await widget.api.request('/sermons/${sermon.id}', auth: true);
      setState(() => sermon =
          Sermon.fromJson((dataOf(response) as Map).cast<String, dynamic>()));
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ask() async {
    final text = question.text.trim();
    if (text.isEmpty || asking) return;
    await submitQuestion(text);
  }

  Future<void> retryAsk() async {
    final text = lastQuestion;
    if (text == null || asking) return;
    await submitQuestion(text, appendUserMessage: false);
  }

  Future<void> submitQuestion(String text,
      {bool appendUserMessage = true}) async {
    question.clear();
    if (mounted) {
      setState(() {
        asking = true;
        askError = null;
        lastQuestion = text;
        if (appendUserMessage) {
          messages.add(SermonMessage(role: 'user', content: text));
        }
      });
    }
    try {
      final response = await widget.api.request(
          '/sermons/${sermon.id}/conversation/messages',
          method: 'POST',
          auth: true,
          body: {'content': text});
      final data = dataOf(response);
      if (data is Map && data['answer'] is Map) {
        final answer = SermonMessage.fromJson(
            (data['answer'] as Map).cast<String, dynamic>());
        if (mounted) setState(() => messages.add(answer));
      } else {
        throw const ApiException('LUMA returned no answer. Please retry.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => askError = error.message);
    } finally {
      if (mounted) setState(() => asking = false);
    }
  }

  Future<void> editTitle() async {
    title.text = sermon.title;
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit sermon title'),
        content: TextField(
            controller: title,
            autofocus: true,
            textInputAction: TextInputAction.done),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (updated != true || title.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.request('/sermons/${sermon.id}',
          method: 'PATCH', auth: true, body: {'title': title.text.trim()});
      final data = dataOf(response);
      if (data is Map && mounted) {
        setState(() => sermon = Sermon.fromJson(data.cast<String, dynamic>()));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retryProcessing() async {
    setState(() => busy = true);
    try {
      final response = await widget.api
          .request('/sermons/${sermon.id}/process', method: 'POST', auth: true);
      final data = dataOf(response);
      if (data is Map && mounted) {
        setState(() => sermon = Sermon.fromJson(data.cast<String, dynamic>()));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteSermon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this sermon?'),
        content:
            const Text('This permanently removes the sermon and its notes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await widget.api
          .request('/sermons/${sermon.id}', method: 'DELETE', auth: true);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sermon.id >= 0) {
      return SermonStudyShell(api: widget.api, sermon: sermon);
    }
    final note = sermon.notes;
    final chat = messages.map((message) {
      final isUser = message.role == 'user';
      return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: isUser ? ink : Colors.white,
                          borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16)),
                          border: isUser
                              ? null
                              : Border.all(color: Colors.black12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isUser ? 'You' : 'LUMA',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isUser ? lime : Colors.black54)),
                            const SizedBox(height: 4),
                            Text(message.content,
                                style: TextStyle(
                                    height: 1.4, color: isUser ? cream : ink)),
                            Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                    tooltip: 'Copy message',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => copyText(
                                        context, message.content, 'Message'),
                                    icon: Icon(Icons.copy_outlined,
                                        size: 17,
                                        color: isUser
                                            ? Colors.white70
                                            : Colors.black45)))
                          ])))));
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(sermon.title), actions: [
        IconButton(
            onPressed: busy ? null : editTitle,
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'retry') retryProcessing();
              if (value == 'delete') deleteSermon();
            },
            itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'retry', child: Text('Retry processing')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete sermon')),
                ])
      ]),
      body: busy
          ? const Loading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const LumaTag('Example study'),
                      IconButton(
                          tooltip: 'Share sermon',
                          onPressed: () =>
                              copyText(context, sermon.title, 'Title'),
                          icon: const Icon(Icons.share_outlined))
                    ]),
                Text(sermon.title,
                    style: const TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7)),
                const SizedBox(height: 6),
                Text(
                    '${prettyStatus(sermon.sourceType)} · ${prettyStatus(sermon.status)}',
                    style: const TextStyle(color: lumaMuted)),
                if (sermon.status.toLowerCase() == 'completed') ...[
                  const SizedBox(height: 16),
                  LumaDarkCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const LumaEyebrow('The big idea', dark: true),
                        const SizedBox(height: 14),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: 4,
                                  height: 58,
                                  decoration: BoxDecoration(
                                      color: lime,
                                      borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 14),
                              const Expanded(
                                  child: Text(
                                      'Faith grows past the moment of listening when we put what we hear into practice.',
                                      style: TextStyle(
                                          color: cream,
                                          fontSize: 19,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600)))
                            ])
                      ])),
                  const SizedBox(height: 12),
                  LumaAccentButton(
                      label:
                          busy ? 'Creating devotional...' : 'Create devotional',
                      onPressed: busy ? null : createDevotional),
                ],
                if (sermon.error != null)
                  Text(sermon.error!,
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 18),
                const LumaEyebrow('Notes'),
                const SizedBox(height: 8),
                if (note == null ||
                    (note.summary.isEmpty && note.mainIdea.isEmpty))
                  const Text('No generated notes are available yet.')
                else ...[
                  if (note.summary.isNotEmpty)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(note.summary,
                                style: const TextStyle(
                                    fontSize: 16, height: 1.5)))),
                  if (note.mainIdea.isNotEmpty)
                    Text('Main idea: ${note.mainIdea}'),
                ],
                if (note != null && note.keyPoints.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Key points',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ...note.keyPoints.map((point) => Text('• $point')),
                ],
                const SizedBox(height: 24),
                const LumaEyebrow('Transcript'),
                const SizedBox(height: 8),
                if (sermon.transcript?.isNotEmpty != true)
                  const Text('No transcript is available for this sermon.')
                else
                  SelectableText(sermon.transcript!),
                const SizedBox(height: 24),
                const Text('Ask LUMA',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                if (messagesBusy) const LinearProgressIndicator(),
                if (messagesError != null)
                  Text(messagesError!,
                      style: const TextStyle(color: Colors.red)),
                if (!messagesBusy && messages.isEmpty && messagesError == null)
                  const Text('Ask a question about this sermon.'),
                if (asking) const LinearProgressIndicator(),
                if (askError != null) ...[
                  Text(askError!, style: const TextStyle(color: Colors.red)),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: retryAsk,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'))),
                ],
                ...chat,
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: question,
                          enabled: !asking,
                          onSubmitted: (_) => ask(),
                          decoration: const InputDecoration(
                              hintText: 'Ask about this sermon'))),
                  IconButton(
                      onPressed: asking ? null : ask,
                      tooltip: 'Ask LUMA',
                      icon: const Icon(Icons.send))
                ]),
              ],
            ),
    );
  }
}

class BibleReader extends StatefulWidget {
  const BibleReader(
      {required this.api, this.initialBook, this.initialChapter, super.key});
  final ApiClient api;
  final String? initialBook;
  final int? initialChapter;
  @override
  State<BibleReader> createState() => _BibleReaderState();
}

class _BibleReaderState extends State<BibleReader> {
  bool busy = true;
  String translation = 'WEB';
  List<BibleBook> books = [];
  BibleBook? book;
  int chapter = 1;
  BiblePassage? passage;
  String? loadError;
  bool searching = false;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final response = await widget.api.request('/bible/books',
          auth: true, query: {'translation': translation});
      if (mounted) {
        final requested = widget.initialBook?.toLowerCase().trim();
        final loadedBooks = mapsOf(response).map(BibleBook.fromJson).toList();
        BibleBook? requestedBook;
        if (requested != null && requested.isNotEmpty) {
          for (final candidate in loadedBooks) {
            if (candidate.slug.toLowerCase() == requested ||
                candidate.name.toLowerCase() == requested) {
              requestedBook = candidate;
              break;
            }
          }
        }
        setState(() {
          books = loadedBooks;
          book = requestedBook;
          chapter = widget.initialChapter ?? 1;
          busy = false;
          loadError = null;
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() {
          busy = false;
          loadError = value.toString();
        });
        showError(context, value);
      }
    }
  }

  Future<void> read() async {
    if (book == null) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.request(
          '/bible/${book!.slug}/chapters/$chapter',
          auth: true,
          query: {'translation': translation});
      if (mounted) {
        final data = dataOf(response);
        if (data is! Map) {
          throw const ApiException('The Bible passage response was invalid.');
        }
        final parsed = BiblePassage.fromJson(data.cast<String, dynamic>());
        if (parsed.verses.isEmpty || parsed.text.isEmpty) {
          throw const ApiException('No verses were returned for this chapter.');
        }
        setState(() {
          passage = parsed;
          busy = false;
          loadError = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          loadError = error.message;
        });
        showError(context, error);
      }
    }
  }

  Future<void> searchBible() async {
    if (search.text.trim().isEmpty) return;
    setState(() => searching = true);
    try {
      final response = await widget.api.request('/bible/search',
          auth: true,
          query: {'translation': translation, 'q': search.text.trim()});
      if (!mounted) return;
      final results = mapsOf(response);
      if (results.isEmpty) {
        showModalBottomSheet(
            context: context,
            builder: (_) => const Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                    title: 'No results',
                    message: 'Try another Scripture search.')));
        return;
      }
      showModalBottomSheet(
          context: context,
          builder: (_) => ListView(
              padding: const EdgeInsets.all(20),
              children: results
                  .map((item) => ListTile(
                      title: Text('${item['reference'] ?? ''}'),
                      subtitle: Text('${item['text'] ?? ''}'),
                      trailing: Wrap(children: [
                        IconButton(
                            tooltip: 'Copy verse',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(
                                  text:
                                      '${item['reference'] ?? ''}\n${item['text'] ?? ''}'));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Verse copied')));
                            },
                            icon: const Icon(Icons.copy_outlined)),
                        IconButton(
                            tooltip: 'Study this passage',
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => StudyHub(
                                          api: widget.api,
                                          initialPassage:
                                              '${item['reference'] ?? ''}')));
                            },
                            icon: const Icon(Icons.auto_awesome_outlined))
                      ])))
                  .toList()));
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Bible reader',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          if (passage != null)
            IconButton(
                tooltip: 'Copy passage',
                onPressed: () => copyText(context,
                    '${passage!.reference}\n\n${passage!.text}', 'Passage'),
                icon: const Icon(Icons.copy_outlined)),
          IconButton(
              tooltip: 'Refresh books',
              onPressed: load,
              icon: const Icon(Icons.refresh))
        ]),
        onRefresh: load,
        child: busy && books.isEmpty
            ? const Loading()
            : loadError != null && books.isEmpty
                ? RetryState(
                    title: 'Bible unavailable',
                    message: loadError!,
                    onRetry: load)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        if (loadError != null && books.isNotEmpty)
                          Text(loadError!,
                              style: const TextStyle(color: Colors.red)),
                        DropdownButtonFormField<String>(
                            value: translation,
                            decoration:
                                const InputDecoration(labelText: 'Translation'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'WEB', child: Text('WEB')),
                              DropdownMenuItem(
                                  value: 'KJV', child: Text('KJV')),
                              DropdownMenuItem(
                                  value: 'ASV', child: Text('ASV')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                translation = value;
                                book = null;
                                passage = null;
                                busy = true;
                              });
                              load();
                            }),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<BibleBook>(
                            value: book,
                            decoration:
                                const InputDecoration(labelText: 'Book'),
                            items: books
                                .map((item) => DropdownMenuItem(
                                    value: item, child: Text(item.name)))
                                .toList(),
                            onChanged: (value) => setState(() {
                                  book = value;
                                  chapter = 1;
                                })),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                                  value: chapter,
                                  decoration: const InputDecoration(
                                      labelText: 'Chapter'),
                                  items: List.generate(
                                      math.max(1, book?.chapters ?? 1),
                                      (index) => DropdownMenuItem(
                                          value: index + 1,
                                          child: Text('${index + 1}'))),
                                  onChanged: (value) =>
                                      setState(() => chapter = value ?? 1))),
                          const SizedBox(width: 12),
                          FilledButton(
                              onPressed: book == null || busy ? null : read,
                              child: const Text('Read'))
                        ]),
                        if (book != null) ...[
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                    onPressed: chapter > 1 && !busy
                                        ? () {
                                            setState(() => chapter--);
                                            read();
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('Previous')),
                                Text('Chapter $chapter',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                TextButton.icon(
                                    onPressed:
                                        chapter < (book?.chapters ?? 1) && !busy
                                            ? () {
                                                setState(() => chapter++);
                                                read();
                                              }
                                            : null,
                                    icon: const Icon(Icons.chevron_right),
                                    label: const Text('Next'))
                              ])
                        ],
                        const SizedBox(height: 12),
                        TextField(
                            controller: search,
                            decoration: InputDecoration(
                                labelText: 'Search Scripture',
                                suffixIcon: IconButton(
                                    onPressed: searching ? null : searchBible,
                                    icon: const Icon(Icons.search)))),
                        if (passage != null) ...[
                          const SizedBox(height: 24),
                          Text(passage!.reference,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (passage!.verses.isNotEmpty)
                            ...passage!.verses.whereType<Map>().map((verse) =>
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SelectableText(
                                        '${verse['number'] ?? ''} ${verse['text'] ?? ''}',
                                        style: const TextStyle(
                                            fontSize: 18, height: 1.5))))
                          else
                            SelectableText(passage!.text,
                                style:
                                    const TextStyle(fontSize: 18, height: 1.5))
                        ],
                      ]),
      );
}

class StudyHub extends StatefulWidget {
  const StudyHub({required this.api, this.initialPassage, super.key});
  final ApiClient api;
  final String? initialPassage;
  @override
  State<StudyHub> createState() => _StudyHubState();
}

class _StudyHubState extends State<StudyHub> {
  bool busy = true;
  bool generating = false;
  String? generationError;
  late final passage = TextEditingController(
      text: widget.initialPassage?.isNotEmpty == true
          ? widget.initialPassage
          : 'John 3:16');
  String depth = 'quick_read';
  List<BibleStudy> studies = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    passage.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final response = await widget.api.request('/bible-studies', auth: true);
      if (mounted) {
        setState(() {
          studies = mapsOf(response).map(BibleStudy.fromJson).toList();
          busy = false;
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() => busy = false);
        showError(context, value);
      }
    }
  }

  Future<void> generate() async {
    if (parseBibleReaderReference(passage.text.trim()) == null) {
      setState(() => generationError =
          'Enter a valid reference such as Nehemiah 1, Nehemiah 1:1, or Nehemiah 1:1-3.');
      return;
    }
    setState(() {
      generating = true;
      generationError = null;
    });
    try {
      final response = await widget.api.request('/bible-studies',
          method: 'POST',
          auth: true,
          body: {'reader_reference': passage.text.trim(), 'depth': depth},
          idempotencyKey: 'mobile-${DateTime.now().microsecondsSinceEpoch}');
      final data = dataOf(response);
      if (data is! Map) {
        throw const ApiException('The study response was invalid.');
      }
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StudyDetail(
                    study: BibleStudy.fromJson(data.cast<String, dynamic>()))));
      }
      await load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => generationError = error.message);
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Bible Study',
      onRefresh: load,
      child: busy
          ? const Loading()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Go from a passage to a practice.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                  controller: passage,
                  decoration: const InputDecoration(labelText: 'Passage')),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'quick_read', label: Text('Quick Read')),
                    ButtonSegment(value: 'go_deeper', label: Text('Go Deeper'))
                  ],
                  selected: {
                    depth
                  },
                  onSelectionChanged: (value) =>
                      setState(() => depth = value.first)),
              const SizedBox(height: 16),
              if (generationError != null)
                Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(generationError!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer))),
                              IconButton(
                                  tooltip: 'Retry',
                                  onPressed: generating ? null : generate,
                                  icon: const Icon(Icons.refresh))
                            ]))),
              FilledButton.icon(
                  onPressed: generating ? null : generate,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(generating ? 'Generating...' : 'Generate study')),
              const SizedBox(height: 28),
              const Text('Saved studies',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ...studies.map((study) => ListTile(
                  title: Text(study.title),
                  subtitle: Text(study.reference),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StudyDetail(study: study)))))
            ]));
}

class StudyDetail extends StatelessWidget {
  const StudyDetail({required this.study, super.key});
  final BibleStudy study;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(study.title), actions: [
        IconButton(
            tooltip: 'Copy study',
            onPressed: () => copyText(context, study.content, 'Study'),
            icon: const Icon(Icons.copy_outlined))
      ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const LumaTag('Saved study'),
        const SizedBox(height: 12),
        Text(study.reference,
            style: const TextStyle(
                color: lumaMuted, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        LumaDarkCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const LumaEyebrow('Study notes', dark: true),
          const SizedBox(height: 14),
          SelectableText(study.content,
              style: const TextStyle(color: cream, fontSize: 17, height: 1.55))
        ])),
        if (study.notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          const LumaEyebrow('Personal notes'),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18), child: Text(study.notes)))
        ]
      ]));
}

class MoreHub extends StatelessWidget {
  const MoreHub({required this.auth, required this.api, super.key});
  final AuthController auth;
  final ApiClient api;
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'More',
      child: Column(children: [
        ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Bible reader'),
            subtitle: const Text('Read and search Scripture'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BibleReader(api: api)))),
        ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Bible Study'),
            subtitle: const Text('Explore a passage in depth'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => StudyHub(api: api)))),
        ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Daily devotionals'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => Devotionals(api: api)))),
        ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Reading plans'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ReadingPlans(api: api)))),
        ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account and settings'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AccountSettings(auth: auth, api: api)))),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: auth.signOut)
      ]));
}

class Devotionals extends StatefulWidget {
  const Devotionals({required this.api, super.key});
  final ApiClient api;
  @override
  State<Devotionals> createState() => _DevotionalsState();
}

class _DevotionalsState extends State<Devotionals> {
  bool busy = true;
  String? error;
  Devotional? today;
  List<Devotional> history = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        widget.api.request('/devotionals/today', auth: true),
        widget.api.request('/devotionals', auth: true)
      ]);
      final todayData = dataOf(results[0]);
      if (mounted) {
        setState(() {
          if (todayData is Map) {
            today = Devotional.fromJson(todayData.cast<String, dynamic>());
          }
          history = mapsOf(results[1]).map(Devotional.fromJson).toList();
          busy = false;
          error = null;
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() {
          busy = false;
          error = value.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Daily devotionals',
      onRefresh: load,
      child: busy
          ? const Loading()
          : error != null
              ? RetryState(
                  title: 'Devotionals unavailable',
                  message: error!,
                  onRetry: load)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (today != null)
                    ListTile(
                        title: Text(today!.title),
                        subtitle: Text(today!.reference),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    DevotionalDetail(devotional: today!)))),
                  const SizedBox(height: 16),
                  const Text('Saved history',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ...history.map((item) => ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.reference),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DevotionalDetail(devotional: item)))))
                ]));
}

class DevotionalDetail extends StatelessWidget {
  const DevotionalDetail({required this.devotional, super.key});
  final Devotional devotional;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(devotional.title), actions: [
        IconButton(
            tooltip: 'Copy devotional',
            onPressed: () => copyText(
                context,
                '${devotional.reference}\n\n${devotional.text}\n\n${devotional.reflection}\n\n${devotional.application}\n\n${devotional.prayer}',
                'Devotional'),
            icon: const Icon(Icons.copy_outlined))
      ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const LumaEyebrow('Today\'s devotional'),
        const SizedBox(height: 10),
        Text(devotional.reference,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(devotional.text,
                    style: const TextStyle(fontSize: 18, height: 1.5)))),
        const SizedBox(height: 24),
        const LumaEyebrow('Reflection'),
        const SizedBox(height: 8),
        Text(devotional.reflection,
            style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 24),
        const LumaEyebrow('Practical application'),
        const SizedBox(height: 8),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(devotional.application,
                    style: const TextStyle(fontSize: 16, height: 1.5)))),
        const SizedBox(height: 24),
        const LumaEyebrow('Prayer'),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: lumaLimeSoft, borderRadius: BorderRadius.circular(20)),
            child: Text(devotional.prayer,
                style: const TextStyle(fontSize: 16, height: 1.5)))
      ]));
}

class ReadingPlans extends StatefulWidget {
  const ReadingPlans({required this.api, super.key});
  final ApiClient api;
  @override
  State<ReadingPlans> createState() => _ReadingPlansState();
}

class _ReadingPlansState extends State<ReadingPlans> {
  bool busy = true;
  String? error;
  List<ReadingPlan> plans = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await widget.api.request('/reading-plans', auth: true);
      if (mounted) {
        setState(() {
          plans = mapsOf(response).map(ReadingPlan.fromJson).toList();
          busy = false;
          error = null;
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() {
          busy = false;
          error = value.toString();
        });
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final items = plans.map((plan) {
      final progress = plan.days.isEmpty
          ? 0.0
          : plan.completedDayIds.length / plan.days.length;
      return Card(
          child: ListTile(
              title: Text(plan.title),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${plan.days.length} days · ${plan.description}'),
                    if (plan.completeCanon)
                      const Text('Complete canon • 66 books • 1,189 chapters',
                          style: TextStyle(
                              color: lumaMuted, fontWeight: FontWeight.w600)),
                    if (plan.enrollmentId != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 3),
                      Text(
                          '${plan.completedDayIds.length}/${plan.days.length} days complete')
                    ]
                  ]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReadingPlanDetail(api: widget.api, plan: plan)))));
    }).toList();
    final heroPlan = plans.isEmpty ? null : plans.first;
    final heroProgress = heroPlan == null || heroPlan.days.isEmpty
        ? 0.0
        : heroPlan.completedDayIds.length / heroPlan.days.length;
    return PageFrame(
        title: 'Plans',
        onRefresh: load,
        child: busy
            ? const Loading()
            : error != null
                ? RetryState(
                    title: 'Reading plans unavailable',
                    message: error!,
                    onRetry: load)
                : plans.isEmpty
                    ? const EmptyState(
                        title: 'No plans available',
                        message: 'Reading plans will appear when published.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text(
                                'Reading plans and devotionals built from the messages you study.',
                                style: TextStyle(
                                    color: lumaMuted,
                                    fontSize: 16,
                                    height: 1.45)),
                            const SizedBox(height: 20),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: ink,
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: const LinearGradient(
                                        colors: [ink, lumaCard],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const LumaTag('Example plan', dark: true),
                                      const SizedBox(height: 16),
                                      Text(heroPlan?.title ?? 'Reading plan',
                                          style: const TextStyle(
                                              color: cream,
                                              fontSize: 24,
                                              height: 1.15,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Text(
                                          heroPlan?.description ??
                                              'A daily rhythm for Scripture, reflection and practice.',
                                          style: const TextStyle(
                                              color: lumaMuted2)),
                                      const SizedBox(height: 16),
                                      LumaProgressBar(value: heroProgress),
                                      if (heroPlan != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                            '${heroPlan.completedDayIds.length} of ${heroPlan.days.length} days complete',
                                            style: const TextStyle(
                                                color: lumaMuted2))
                                      ],
                                      const SizedBox(height: 14),
                                      LumaAccentButton(
                                          label: heroPlan?.enrollmentId == null
                                              ? 'Start plan'
                                              : 'Continue plan',
                                          onPressed: heroPlan == null
                                              ? null
                                              : () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          ReadingPlanDetail(
                                                              api: widget.api,
                                                              plan: heroPlan))))
                                    ])),
                            const SizedBox(height: 24),
                            const LumaEyebrow('Your plans'),
                            const SizedBox(height: 8),
                            ...items,
                            const SizedBox(height: 14),
                            const LumaEyebrow('Coming next'),
                            const SizedBox(height: 8),
                            ...[
                              'Deeper study',
                              'Equip',
                              'Church spaces'
                            ].map((title) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                    child: ListTile(
                                        enabled: false,
                                        leading: const Icon(
                                            Icons.auto_awesome_outlined),
                                        title: Text(title),
                                        subtitle: const Text('Coming next'),
                                        trailing: const LumaEyebrow('Soon')))))
                          ]));
  }
}

class ReadingPlanDetail extends StatefulWidget {
  const ReadingPlanDetail({required this.api, required this.plan, super.key});
  final ApiClient api;
  final ReadingPlan plan;
  @override
  State<ReadingPlanDetail> createState() => _ReadingPlanDetailState();
}

class _ReadingPlanDetailState extends State<ReadingPlanDetail> {
  late int? enrollmentId = widget.plan.enrollmentId;
  late final completed = <int>{...widget.plan.completedDayIds};
  bool busy = false;
  Future<void> enroll() async {
    setState(() => busy = true);
    try {
      final response = await widget.api.request(
          '/reading-plans/${widget.plan.id}/enrollments',
          method: 'POST',
          auth: true);
      final data = dataOf(response);
      if (data is Map) {
        enrollmentId = data['id'] as int?;
        completed.addAll(
            (data['completed_day_ids'] as List? ?? const []).whereType<int>());
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle(Map<String, dynamic> day, bool value) async {
    if (enrollmentId == null) await enroll();
    final dayId = day['id'] as int?;
    if (enrollmentId == null || dayId == null) return;
    try {
      await widget.api.request(
          '/reading-plan-enrollments/$enrollmentId/days/$dayId',
          method: 'PUT',
          auth: true,
          body: {'completed': value});
      if (mounted) {
        setState(() {
          if (value) {
            completed.add(dayId);
          } else {
            completed.remove(dayId);
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: widget.plan.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.plan.description),
        if (widget.plan.completeCanon) ...[
          const SizedBox(height: 8),
          const LumaTag('Complete canon'),
          const SizedBox(height: 6),
          const Text('Bible in 30 Days covers all 66 books and 1,189 chapters.',
              style: TextStyle(color: lumaMuted)),
        ],
        const SizedBox(height: 16),
        if (widget.plan.days.isNotEmpty)
          LinearProgressIndicator(
              value: completed.length / widget.plan.days.length),
        if (widget.plan.days.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '${completed.length} of ${widget.plan.days.length} days complete')),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: busy ? null : enroll,
            child: Text(
                enrollmentId == null ? 'Start this plan' : 'Plan started')),
        ...widget.plan.days.whereType<Map>().map((raw) {
          final day = raw.cast<String, dynamic>();
          final id = day['id'] as int?;
          final assignments = listValue(day['readings'])
              .map(ReadingAssignment.fromJson)
              .where((assignment) => assignment.reference.isNotEmpty)
              .toList();
          return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: id != null && completed.contains(id),
                            onChanged: id == null
                                ? null
                                : (value) => toggle(day, value ?? false),
                            title: Text(
                                'Day ${day['day_number'] ?? ''}: ${day['title'] ?? ''}')),
                        if (assignments.isNotEmpty)
                          ...assignments.map((assignment) => Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                  onPressed: assignment.book == null ||
                                          assignment.chapter == null
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => BibleReader(
                                                  api: widget.api,
                                                  initialBook: assignment.book,
                                                  initialChapter:
                                                      assignment.chapter))),
                                  icon: const Icon(Icons.menu_book_outlined),
                                  label: Text(
                                      '${assignment.reference} • ${assignment.translation}'))))
                        else if (day['scripture_reference'] != null)
                          Text('${day['scripture_reference']}')
                      ])));
        })
      ]));
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  late final SubscriptionManager subscriptions = SubscriptionManager(
      api: widget.api,
      onStatus: (status) {
        if (mounted) {
          setState(() => purchaseStatus = status);
          if (status.state == SubscriptionState.purchased ||
              status.state == SubscriptionState.restored) {
            load();
          }
        }
      });
  Entitlements? entitlements;
  SubscriptionStatus purchaseStatus =
      const SubscriptionStatus(SubscriptionState.disabled);
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
    subscriptions.loadProducts();
  }

  @override
  void dispose() {
    subscriptions.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      Map<String, dynamic> response;
      try {
        response =
            await widget.api.request('/mobile/purchases/status', auth: true);
      } on ApiException {
        response = await widget.api.request('/entitlements', auth: true);
      }
      if (mounted) {
        setState(() {
          entitlements = Entitlements.fromJson(
              (dataOf(response) as Map).cast<String, dynamic>());
          busy = false;
          error = null;
        });
      }
    } on ApiException catch (value) {
      if (mounted) {
        setState(() {
          busy = false;
          error = value.message;
        });
      }
    }
  }

  Future<void> manageSubscription() async {
    final nativeUrl = Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    if (entitlements?.membership.billingEnabled == true) {
      try {
        final response = await widget.api
            .request('/billing/portal', method: 'POST', auth: true);
        final data = dataOf(response);
        final url = data is Map ? data['url']?.toString() : null;
        if (url != null &&
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication)) {
          return;
        }
      } on ApiException {
        // Native subscriptions are managed in their respective stores.
      }
    }
    await launchUrl(Uri.parse(nativeUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Membership')),
        body: busy
            ? const Loading()
            : error != null
                ? EmptyState(title: 'Membership unavailable', message: error!)
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                          'Current plan: ${membershipLabel(entitlements?.membership.plan ?? 'free')} · ${membershipLabel(entitlements?.membership.status ?? 'unknown')}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      if (entitlements?.membership.endsAt != null)
                        Text(
                            'Renews or ends: ${entitlements!.membership.endsAt}'),
                      if (entitlements?.membership.canceled == true)
                        const Text(
                            'Cancellation scheduled; paid access remains active until the date above.',
                            style: TextStyle(color: lumaMuted)),
                      if (entitlements?.membership.source == 'manual')
                        const Text('Premium access granted manually',
                            style: TextStyle(color: lumaMuted)),
                      if (entitlements?.membership.source == 'mobile_purchase')
                        const Text('Premium access from a store purchase',
                            style: TextStyle(color: lumaMuted)),
                      OutlinedButton.icon(
                          onPressed: manageSubscription,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Manage subscription')),
                      const SizedBox(height: 24),
                      const Text('Free',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const Text(
                          'Core Bible reading and limited advanced features.'),
                      const SizedBox(height: 18),
                      const Text('Premium',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const Text(
                          'Higher limits, sermon processing, Ask LUMA, and deeper study tools.'),
                      const SizedBox(height: 18),
                      if (subscriptions.products.isEmpty)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(purchaseStatus.state ==
                                        SubscriptionState.disabled
                                    ? 'Subscriptions are not available in this build. Store products and server verification must be configured first.'
                                    : 'No store products are currently available.'))),
                      ...subscriptions.products.map((product) => FilledButton(
                          onPressed: () => subscriptions.buy(product),
                          child: Text(
                              'Subscribe · ${product.title} ${product.price}'))),
                      OutlinedButton(
                          onPressed:
                              purchaseStatus.state == SubscriptionState.pending
                                  ? null
                                  : () async {
                                      await subscriptions.restore();
                                      await load();
                                    },
                          child: const Text('Restore purchases')),
                      if (purchaseStatus.message != null)
                        Text(purchaseStatus.message!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      Text('Purchase status: ${purchaseStatus.state.name}'),
                      const SizedBox(height: 24),
                      const Text('Usage',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(usageSummary(entitlements?.usage ?? const {})),
                      OutlinedButton(
                          onPressed: busy ? null : load,
                          child: const Text('Refresh membership')),
                    ],
                  ),
      );
}

class AccountSettings extends StatefulWidget {
  const AccountSettings({required this.auth, required this.api, super.key});
  final AuthController auth;
  final ApiClient api;
  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  late final name = TextEditingController(text: widget.auth.user?.name);
  late final email = TextEditingController(text: widget.auth.user?.email);
  final feedback = TextEditingController();
  late final subscriptions = SubscriptionManager(
      api: widget.api,
      onStatus: (status) {
        if (mounted) setState(() => purchaseStatus = status);
      });
  Entitlements? entitlements;
  NotificationPreferences notifications = const NotificationPreferences();
  SubscriptionStatus purchaseStatus =
      const SubscriptionStatus(SubscriptionState.disabled);
  bool busy = false;
  bool notificationsSaved = false;

  @override
  void initState() {
    super.initState();
    loadAccountData();
    subscriptions.loadProducts();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    feedback.dispose();
    subscriptions.dispose();
    super.dispose();
  }

  Future<void> loadAccountData() async {
    try {
      final results = await Future.wait([
        widget.api.request('/entitlements', auth: true),
        widget.api.request('/mobile/purchases/status', auth: true),
        widget.api.request('/mobile/notification-preferences', auth: true),
      ]);
      if (!mounted) return;
      final entitlementData = dataOf(results[0]);
      final statusData = dataOf(results[1]);
      final preferenceData = dataOf(results[2]);
      setState(() {
        if (entitlementData is Map) {
          entitlements =
              Entitlements.fromJson(entitlementData.cast<String, dynamic>());
        }
        if (statusData is Map) {
          entitlements =
              Entitlements.fromJson(statusData.cast<String, dynamic>());
        }
        if (preferenceData is Map) {
          final loaded = NotificationPreferences.fromJson(
              preferenceData.cast<String, dynamic>());
          notifications =
              loaded.copyWith(timezone: loaded.timezone ?? detectedTimezone());
          notificationsSaved = true;
        }
      });
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> saveNotifications() async {
    try {
      await widget.api.request('/mobile/notification-preferences',
          method: 'PUT', auth: true, body: notifications.toJson());
      if (mounted) {
        setState(() => notificationsSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Preferences saved. Delivery still depends on notification providers.')));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> selectReminderTime() async {
    final picked = await showTimePicker(
        context: context,
        initialTime: parseReminderTime(notifications.reminderTime));
    if (picked == null || !mounted) return;
    setState(() => notifications =
        notifications.copyWith(reminderTime: formatReminderTime(picked)));
  }

  Future<void> deleteAccount() async {
    final confirmation = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'This removes your account, tokens, subscriptions, sermons, and preferences.'),
          const SizedBox(height: 12),
          TextField(
              controller: confirmation,
              decoration:
                  const InputDecoration(labelText: 'Type DELETE to confirm')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, confirmation.text.trim() == 'DELETE'),
              child: const Text('Delete account')),
        ],
      ),
    );
    confirmation.dispose();
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await widget.auth.deleteAccount();
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.auth.updateProfile(name.text.trim(), email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendFeedback() async {
    if (feedback.text.trim().isEmpty) return;
    try {
      await widget.api.request('/beta-feedback',
          method: 'POST', auth: true, body: {'message': feedback.text.trim()});
      feedback.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for the feedback.')));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Account and settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: busy ? null : save, child: const Text('Save profile')),
        const SizedBox(height: 20),
        const Text('Security',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PasswordChangeScreen(auth: widget.auth)))),
        ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl),
                mode: LaunchMode.externalApplication)),
        ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(AppConfig.termsUrl),
                mode: LaunchMode.externalApplication)),
        const SizedBox(height: 20),
        const Text('Membership',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ListTile(
            leading: Icon(Icons.stars_outlined),
            title: Text('Membership and usage'),
            subtitle: Text(
                '${membershipLabel(entitlements?.membership.plan ?? 'free')} · ${membershipLabel(entitlements?.membership.status ?? 'unknown')}'),
            trailing: IconButton(
                tooltip: 'Refresh membership',
                onPressed: loadAccountData,
                icon: const Icon(Icons.refresh)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MembershipScreen(api: widget.api)))),
        if (entitlements?.usage.isNotEmpty == true)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: UsageOverview(usage: entitlements!.usage))),
        OutlinedButton(
            onPressed: () => subscriptions.restore(),
            child: const Text('Restore purchases')),
        if (subscriptions.products.isNotEmpty)
          ...subscriptions.products.map((product) => FilledButton(
              onPressed: () => subscriptions.buy(product),
              child: Text('Subscribe · ${product.price}'))),
        Text('Purchase status: ${prettyStatus(purchaseStatus.state.name)}'),
        const SizedBox(height: 20),
        const Text('Feedback',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        TextField(
            controller: feedback,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Share feedback')),
        OutlinedButton(
            onPressed: sendFeedback, child: const Text('Send feedback')),
        const SizedBox(height: 20),
        const Text('Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Text(
            'Saved preferences control what LUMA requests. Actual push delivery requires configured FCM/APNs providers.',
            style: TextStyle(color: lumaMuted)),
        SwitchListTile(
            title: const Text('Enable notifications'),
            value: notifications.enabled,
            onChanged: (value) => setState(
                () => notifications = notifications.copyWith(enabled: value))),
        SwitchListTile(
            title: const Text('Sermon processing updates'),
            value: notifications.sermonProcessing,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    notifications.copyWith(sermonProcessing: value))
                : null),
        SwitchListTile(
            title: const Text('Devotional reminders'),
            value: notifications.devotionalReminders,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    notifications.copyWith(devotionalReminders: value))
                : null),
        SwitchListTile(
            title: const Text('Reading plan reminders'),
            value: notifications.readingPlanReminders,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    notifications.copyWith(readingPlanReminders: value))
                : null),
        SwitchListTile(
            title: const Text('Subscription updates'),
            value: notifications.subscriptionUpdates,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    notifications.copyWith(subscriptionUpdates: value))
                : null),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Reminder time'),
            subtitle: Text(notifications.reminderTime),
            enabled: notifications.enabled,
            onTap: notifications.enabled ? selectReminderTime : null),
        DropdownButtonFormField<String>(
            value: reminderTimezones.contains(notifications.timezone)
                ? notifications.timezone
                : detectedTimezone(),
            decoration: const InputDecoration(labelText: 'Reminder timezone'),
            items: reminderTimezones
                .map((zone) => DropdownMenuItem(value: zone, child: Text(zone)))
                .toList(),
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications = notifications
                    .copyWith(timezone: value ?? detectedTimezone()))
                : null),
        OutlinedButton(
            onPressed: saveNotifications,
            child: const Text('Save notification preferences')),
        if (notificationsSaved)
          const Text('Saved to your LUMA account.',
              style: TextStyle(color: lumaMuted)),
        const SizedBox(height: 20),
        TextButton(
            onPressed: busy ? null : deleteAccount,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete account permanently'))
      ]));
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({required this.auth, super.key});
  final AuthController auth;
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeState();
}

class _PasswordChangeState extends State<PasswordChangeScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await widget.auth
          .changePassword(current.text, next.text, confirmation.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated')));
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget passwordField(TextEditingController controller, String label,
          {bool confirmationField = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your ${label.toLowerCase()}';
                }
                if (!confirmationField &&
                    label == 'New password' &&
                    value.length < 8) {
                  return 'Use at least 8 characters';
                }
                if (confirmationField && value != next.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              decoration: InputDecoration(labelText: label)));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Keep your LUMA account secure.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            passwordField(current, 'Current password'),
            passwordField(next, 'New password'),
            passwordField(confirmation, 'Confirm new password',
                confirmationField: true),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Updating...' : 'Update password'))
          ])));
}
