// Flutter 3.50 currently reports the Material library import as deprecated
// while the app remains on the stable Material 3 API surface.
// ignore_for_file: deprecated_member_use

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

const ink = Color(0xFF171717);
const cream = Color(0xFFF5F1E8);
const lime = Color(0xFFC8F500);

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
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: lime),
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
        ),
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
  Widget build(BuildContext context) => Image.asset(
        'assets/logo-mark.png',
        width: size,
        height: size,
        color: dark ? cream : null,
      );
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
        backgroundColor: ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const BrandMark(dark: true),
                const SizedBox(height: 28),
                const Text('Make space for a deeper faith.',
                    style: TextStyle(
                        color: cream,
                        fontSize: 38,
                        height: 1.03,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                const Text(
                    'Study Scripture, reflect on sermons, and build a rhythm that lasts.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 17, height: 1.45)),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AuthScreen(auth: auth))),
                  style: FilledButton.styleFrom(
                      backgroundColor: lime,
                      foregroundColor: ink,
                      minimumSize: const Size.fromHeight(54)),
                  child: const Text('Get started',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AuthScreen(auth: auth, login: true))),
                    child: const Text('I already have an account',
                        style: TextStyle(color: cream)),
                  ),
                ),
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(auth: widget.auth, api: widget.api),
      SermonLibrary(api: widget.api),
      BibleReader(api: widget.api),
      StudyHub(api: widget.api),
      MoreHub(auth: widget.auth, api: widget.api),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: 'Sermons'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Bible'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Study'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
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
                style: const TextStyle(fontWeight: FontWeight.w700)),
            actions: action == null ? null : [action!]),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: onRefresh ?? () async {},
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
    final recent = sermons.map((sermon) => Card(
          child: ListTile(
            title: Text(sermon.title),
            subtitle: Text(prettyStatus(sermon.status)),
            leading: const CircleAvatar(
                backgroundColor: lime,
                child: Icon(Icons.graphic_eq, color: ink)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SermonDetail(api: widget.api, sermon: sermon))),
          ),
        ));
    return PageFrame(
      title: 'Good day, $firstName',
      action: IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      onRefresh: load,
      child: busy
          ? const Loading()
          : error != null
              ? EmptyState(title: 'Could not load your day', message: error!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                          color: ink, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TODAY',
                                style: TextStyle(
                                    color: lime,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            const SizedBox(height: 10),
                            Text(
                                devotional?.title ??
                                    'Start with a moment of reflection.',
                                style: const TextStyle(
                                    color: cream,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(
                                devotional?.reference ??
                                    'Daily Scripture and thoughtful tools are ready for you.',
                                style: const TextStyle(color: Colors.white70)),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: StatCard(
                              label: 'Membership',
                              value: entitlements?.membership.plan ?? 'Free')),
                      Expanded(
                          child: StatCard(
                              label: 'AI usage',
                              value: entitlements?.usage.isEmpty ?? true
                                  ? '—'
                                  : usageSummary(entitlements!.usage)))
                    ]),
                    const SizedBox(height: 24),
                    const Text('Recent sermons',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (sermons.isEmpty)
                      const EmptyState(
                          title: 'Your library is ready',
                          message:
                              'Submit a sermon to begin your study library.')
                    else
                      ...recent,
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
  List<Sermon> sermons = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await widget.api.request('/sermons',
          auth: true, query: {'page': '$page', 'per_page': '12'});
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
              ? EmptyState(title: 'Library unavailable', message: error!)
              : sermons.isEmpty
                  ? const EmptyState(
                      title: 'No sermons yet',
                      message:
                          'Submit a video link, transcript, or file to begin.')
                  : Column(children: [
                      ...items,
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
    if (mode == 2 && path == null) {
      showError(
          context, const ApiException('Choose an audio or video file first.'));
      return;
    }
    setState(() => busy = true);
    try {
      if (mode == 2) {
        await widget.api.uploadSermon(path!, title: title.text);
      } else {
        await widget.api.request('/sermons', method: 'POST', auth: true, body: {
          'source_type': mode == 0 ? 'url' : 'transcript',
          'title': title.text.trim(),
          if (mode == 0) 'source_url': url.text.trim(),
          if (mode == 1) 'transcript': transcript.text.trim(),
          'auto_process': true
        });
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sermon submitted for processing.')));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Submit a sermon')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Bring a message into your study library.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        SegmentedButton<int>(segments: const [
          ButtonSegment(value: 0, label: Text('Link')),
          ButtonSegment(value: 1, label: Text('Transcript')),
          ButtonSegment(value: 2, label: Text('File'))
        ], selected: {
          mode
        }, onSelectionChanged: (value) => setState(() => mode = value.first)),
        const SizedBox(height: 16),
        TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title (optional)')),
        const SizedBox(height: 12),
        if (mode == 0)
          TextField(
              controller: url,
              decoration:
                  const InputDecoration(labelText: 'Video or sermon URL'))
        else if (mode == 1)
          TextField(
              controller: transcript,
              minLines: 10,
              maxLines: 18,
              decoration: const InputDecoration(labelText: 'Paste transcript'))
        else
          OutlinedButton.icon(
              onPressed: busy ? null : pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(fileName ?? 'Choose audio or video')),
        if (mode == 2)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Accepted: FLAC, MP3, MP4, MPEG, MPGA, M4A, OGG, WAV, WEBM. Maximum 25 MB.')),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Submitting...' : 'Submit sermon'))
      ]));
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

  @override
  void initState() {
    super.initState();
    refresh();
    loadMessages();
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
    final note = sermon.notes;
    final chat = messages.map((message) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: message.role == 'user'
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
                padding: const EdgeInsets.all(12),
                color: message.role == 'user' ? ink : Colors.white,
                child: Text(message.content,
                    style: TextStyle(
                        color: message.role == 'user' ? cream : ink))),
          ),
        ));
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
              padding: const EdgeInsets.all(20),
              children: [
                Chip(label: Text(prettyStatus(sermon.status))),
                if (sermon.error != null)
                  Text(sermon.error!,
                      style: const TextStyle(color: Colors.red)),
                const Text('Summary and main idea',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (note == null ||
                    (note.summary.isEmpty && note.mainIdea.isEmpty))
                  const Text('No generated notes are available yet.')
                else ...[
                  if (note.summary.isNotEmpty) Text(note.summary),
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
                const Text('Transcript',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
  const BibleReader({required this.api, super.key});
  final ApiClient api;
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
        setState(() {
          books = mapsOf(response).map(BibleBook.fromJson).toList();
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
    try {
      final response = await widget.api.request('/bible/search',
          auth: true,
          query: {'translation': translation, 'q': search.text.trim()});
      if (!mounted) return;
      showModalBottomSheet(
          context: context,
          builder: (_) => ListView(
              padding: const EdgeInsets.all(20),
              children: mapsOf(response)
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
    }
  }

  @override
  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Bible reader',
        action: IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        onRefresh: load,
        child: busy && books.isEmpty
            ? const Loading()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (loadError != null && books.isNotEmpty)
                  Text(loadError!, style: const TextStyle(color: Colors.red)),
                DropdownButtonFormField<String>(
                    value: translation,
                    decoration: const InputDecoration(labelText: 'Translation'),
                    items: const [
                      DropdownMenuItem(value: 'WEB', child: Text('WEB')),
                      DropdownMenuItem(value: 'KJV', child: Text('KJV')),
                      DropdownMenuItem(value: 'ASV', child: Text('ASV')),
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
                    decoration: const InputDecoration(labelText: 'Book'),
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
                          decoration:
                              const InputDecoration(labelText: 'Chapter'),
                          items: List.generate(
                              math.max(1, book?.chapters ?? 1),
                              (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1}'))),
                          onChanged: (value) =>
                              setState(() => chapter = value ?? 1))),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: read, child: const Text('Read'))
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: search,
                    decoration: InputDecoration(
                        labelText: 'Search Scripture',
                        suffixIcon: IconButton(
                            onPressed: searchBible,
                            icon: const Icon(Icons.search)))),
                if (passage != null) ...[
                  const SizedBox(height: 24),
                  Text(passage!.reference,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (passage!.verses.isNotEmpty)
                    ...passage!.verses.whereType<Map>().map((verse) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SelectableText(
                            '${verse['number'] ?? ''} ${verse['text'] ?? ''}',
                            style: const TextStyle(fontSize: 18, height: 1.5))))
                  else
                    SelectableText(passage!.text,
                        style: const TextStyle(fontSize: 18, height: 1.5))
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
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'AI Bible study',
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
                Text(generationError!,
                    style: const TextStyle(color: Colors.red)),
              FilledButton.icon(
                  onPressed: generating ? null : generate,
                  icon: const Icon(Icons.auto_awesome),
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
      appBar: AppBar(title: Text(study.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(study.reference, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        SelectableText(study.content,
            style: const TextStyle(fontSize: 17, height: 1.5))
      ]));
}

class MoreHub extends StatelessWidget {
  const MoreHub({required this.auth, required this.api, super.key});
  final AuthController auth;
  final ApiClient api;
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Your rhythm',
      child: Column(children: [
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
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() => busy = false);
        showError(context, value);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Daily devotionals',
      onRefresh: load,
      child: busy
          ? const Loading()
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ...history.map((item) => ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.reference),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DevotionalDetail(devotional: item)))))
            ]));
}

class DevotionalDetail extends StatelessWidget {
  const DevotionalDetail({required this.devotional, super.key});
  final Devotional devotional;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(devotional.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(devotional.reference,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SelectableText(devotional.text,
            style: const TextStyle(fontSize: 18, height: 1.5)),
        const SizedBox(height: 18),
        Text(devotional.reflection),
        const SizedBox(height: 12),
        Text(devotional.application),
        const SizedBox(height: 12),
        Text(devotional.prayer)
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
        });
      }
    } catch (value) {
      if (mounted) {
        setState(() => busy = false);
        showError(context, value);
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final items = plans
        .map((plan) => ListTile(
            title: Text(plan.title),
            subtitle: Text('${plan.days.length} days · ${plan.description}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ReadingPlanDetail(api: widget.api, plan: plan)))))
        .toList();
    return PageFrame(
        title: 'Reading plans',
        onRefresh: load,
        child: busy
            ? const Loading()
            : plans.isEmpty
                ? const EmptyState(
                    title: 'No plans available',
                    message: 'Reading plans will appear when published.')
                : Column(children: items));
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
  int? enrollmentId;
  final completed = <int>{};
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
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : enroll,
            child: Text(
                enrollmentId == null ? 'Start this plan' : 'Plan started')),
        ...widget.plan.days.whereType<Map>().map((raw) {
          final day = raw.cast<String, dynamic>();
          final id = day['id'] as int?;
          return CheckboxListTile(
              value: id != null && completed.contains(id),
              onChanged:
                  id == null ? null : (value) => toggle(day, value ?? false),
              title:
                  Text('Day ${day['day_number'] ?? ''}: ${day['title'] ?? ''}'),
              subtitle: Text(
                  '${day['scripture_reference'] ?? ''}\n${day['scripture_text'] ?? ''}'));
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
        response = await widget.api
            .request('/mobile/purchases/status', auth: true);
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
        final response =
            await widget.api.request('/billing/portal', method: 'POST', auth: true);
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
                          'Current plan: ${entitlements?.membership.plan ?? 'free'} · ${entitlements?.membership.status ?? 'unknown'}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      if (entitlements?.membership.endsAt != null)
                        Text(
                            'Renews or ends: ${entitlements!.membership.endsAt}'),
                      OutlinedButton.icon(
                          onPressed: manageSubscription,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Manage subscription')),
                      const SizedBox(height: 24),
                      const Text('Free',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const Text('Core Bible reading and limited AI features.'),
                      const SizedBox(height: 18),
                      const Text('Premium',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const Text(
                          'Higher AI limits, sermon processing, Ask LUMA, and deeper study tools.'),
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
                          onPressed: purchaseStatus.state ==
                                  SubscriptionState.pending
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
          notifications = NotificationPreferences.fromJson(
              preferenceData.cast<String, dynamic>());
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification preferences saved')));
      }
    } on ApiException catch (error) {
      if (mounted) showError(context, error);
    }
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
                '${entitlements?.membership.plan ?? 'Free'} · ${entitlements?.membership.status ?? 'unknown'}'),
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
                  child: Text('Usage: ${entitlements!.usage}'))),
        OutlinedButton(
            onPressed: () => subscriptions.restore(),
            child: const Text('Restore purchases')),
        if (subscriptions.products.isNotEmpty)
          ...subscriptions.products.map((product) => FilledButton(
              onPressed: () => subscriptions.buy(product),
              child: Text('Subscribe · ${product.price}'))),
        Text('Purchase status: ${purchaseStatus.state.name}'),
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
        SwitchListTile(
            title: const Text('Enable notifications'),
            value: notifications.enabled,
            onChanged: (value) => setState(() => notifications =
                NotificationPreferences(
                    enabled: value,
                    sermonProcessing: notifications.sermonProcessing,
                    devotionalReminders: notifications.devotionalReminders,
                    subscriptionUpdates: notifications.subscriptionUpdates))),
        SwitchListTile(
            title: const Text('Sermon processing updates'),
            value: notifications.sermonProcessing,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    NotificationPreferences(
                        enabled: notifications.enabled,
                        sermonProcessing: value,
                        devotionalReminders: notifications.devotionalReminders,
                        subscriptionUpdates: notifications.subscriptionUpdates))
                : null),
        SwitchListTile(
            title: const Text('Devotional reminders'),
            value: notifications.devotionalReminders,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    NotificationPreferences(
                        enabled: notifications.enabled,
                        sermonProcessing: notifications.sermonProcessing,
                        devotionalReminders: value,
                        subscriptionUpdates: notifications.subscriptionUpdates))
                : null),
        SwitchListTile(
            title: const Text('Subscription updates'),
            value: notifications.subscriptionUpdates,
            onChanged: notifications.enabled
                ? (value) => setState(() => notifications =
                    NotificationPreferences(
                        enabled: notifications.enabled,
                        sermonProcessing: notifications.sermonProcessing,
                        devotionalReminders: notifications.devotionalReminders,
                        subscriptionUpdates: value))
                : null),
        OutlinedButton(
            onPressed: saveNotifications,
            child: const Text('Save notification preferences')),
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
