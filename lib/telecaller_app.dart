import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

const _storage = FlutterSecureStorage();
const _dialer = MethodChannel('call_monitor/dialer');

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  String? _token;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final token = await _storage.read(key: 'access_token');
    if (mounted) setState(() => _token = token);
  }

  @override
  Widget build(BuildContext context) => _token == null
      ? AuthScreen(onSignedIn: (token) => setState(() => _token = token))
      : HomeShell(
          token: _token!,
          onSignOut: () async {
            await _storage.delete(key: 'access_token');
            if (mounted) setState(() => _token = null);
          });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});
  final ValueChanged<String> onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _loading = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final api = ApiService(token: null);
      final result = _register
          ? await api.register(
              _name.text.trim(), _email.text.trim(), _password.text)
          : await api.login(_email.text.trim(), _password.text);
      final token = result['token'] as String;
      await _storage.write(key: 'access_token', value: token);
      widget.onSignedIn(token);
    } on ApiException catch (e) {
      _notice(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(Icons.phone_in_talk_rounded,
                                    size: 64, color: Color(0xFF4F6BFF)),
                                const SizedBox(height: 20),
                                Text(
                                    _register
                                        ? 'Create telecaller account'
                                        : 'Welcome back',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Securely manage your app-owned call activity.',
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 28),
                                if (_register)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: TextFormField(
                                          controller: _name,
                                          decoration: const InputDecoration(
                                              labelText: 'Full name'),
                                          validator: (v) => v!.trim().isEmpty
                                              ? 'Enter your name'
                                              : null)),
                                TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                        labelText: 'Email address'),
                                    validator: (v) => v!.contains('@')
                                        ? null
                                        : 'Enter a valid email'),
                                const SizedBox(height: 14),
                                TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Password'),
                                    validator: (v) => v!.length >= 8
                                        ? null
                                        : 'Use at least 8 characters'),
                                const SizedBox(height: 22),
                                FilledButton(
                                    onPressed: _loading ? null : _submit,
                                    child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Text(_loading
                                            ? 'Please wait…'
                                            : _register
                                                ? 'Create account'
                                                : 'Sign in'))),
                                TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => setState(
                                            () => _register = !_register),
                                    child: Text(_register
                                        ? 'Already have an account? Sign in'
                                        : 'Need an account? Create one')),
                              ])))))));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.token, required this.onSignOut});
  final String token;
  final Future<void> Function() onSignOut;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final ApiService _api = ApiService(token: widget.token);
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: _api),
      CallsPage(api: _api),
      ContactsPage(api: _api),
      AnalyticsPage(api: _api),
      RecordingsPage(api: _api),
      SettingsPage(onSignOut: widget.onSignOut)
    ];
    return Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Calls'),
              NavigationDestination(
                  icon: Icon(Icons.contacts_outlined), label: 'Contacts'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart), label: 'Reports'),
              NavigationDestination(
                  icon: Icon(Icons.mic_none), label: 'Recordings'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ]));
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame(
      {super.key, required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(title), actions: action == null ? null : [action!]),
      body: child);
}

String _duration(int seconds) => '${seconds ~/ 60}m ${seconds % 60}s';
String _date(String value) => value.replaceFirst('T', ' ').substring(0, 16);
void _error(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is ApiException
            ? error.message
            : 'Unable to complete this request.')));
Widget _failure(Object error, VoidCallback retry) => Center(
    child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              error is ApiException
                  ? error.message
                  : 'Could not reach the server.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Retry'))
        ])));
Widget _metric(String label, String value) => SizedBox(
    width: 150,
    child: Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label)
            ]))));
Widget _callCard(Map<String, dynamic> call) => Card(
    child: ListTile(
        leading: Icon(call['type'] == 'missed'
            ? Icons.call_missed
            : call['type'] == 'outgoing'
                ? Icons.call_made
                : Icons.call_received),
        title: Text(call['name'] as String),
        subtitle: Text('${call['phone']} · ${_date(call['date'] as String)}'),
        trailing: Text(_duration(call['durationSeconds'] as int))));

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api});
  final ApiService api;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.api.dashboard();
  }

  void _reload() => setState(() => _data = widget.api.dashboard());
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Dashboard',
      action: IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
      child: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _failure(snapshot.error!, _reload);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final m =
                Map<String, dynamic>.from(snapshot.data!['metrics'] as Map);
            final recent = List<Map<String, dynamic>>.from(
                snapshot.data!['recent'] as List);
            return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text('${m['total']} calls logged',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _metric('Today', '${m['today']}'),
                    _metric('Incoming', '${m['incoming']}'),
                    _metric('Outgoing', '${m['outgoing']}'),
                    _metric('Missed', '${m['missed']}'),
                    _metric('Talk time', _duration(m['durationSeconds'] as int))
                  ]),
                  const SizedBox(height: 24),
                  Text('Recent activity',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...recent.map(_callCard)
                ]));
          }));
}

class CallsPage extends StatefulWidget {
  const CallsPage({super.key, required this.api});
  final ApiService api;
  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  final _search = TextEditingController();
  String _type = 'all';
  DateTimeRange? _range;
  late Future<List<Map<String, dynamic>>> _calls;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() => setState(() => _calls = widget.api.calls(
      query: _search.text,
      type: _type,
      from: _range?.start.toIso8601String().substring(0, 10),
      to: _range?.end.toIso8601String().substring(0, 10)));
  Future<void> _add() async {
    final didAdd = await showDialog<bool>(
        context: context, builder: (_) => CallDialog(api: widget.api));
    if (didAdd == true) _load();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Call logs',
      action: IconButton(icon: const Icon(Icons.add), onPressed: _add),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _search,
                  onChanged: (_) => _load(),
                  decoration: const InputDecoration(
                      labelText: 'Search name or number',
                      prefixIcon: Icon(Icons.search))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField(
                        initialValue: _type,
                        items: const ['all', 'incoming', 'outgoing', 'missed']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          _type = v!;
                          _load();
                        })),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (result != null) {
                        _range = result;
                        _load();
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: const Text('Date'))
              ])
            ])),
        Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _calls,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _failure(snapshot.error!, _load);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(child: Text('No call logs found.'));
                  }
                  return ListView(
                      children: snapshot.data!
                          .map((call) => Dismissible(
                              key: ValueKey(call['id']),
                              direction: DismissDirection.endToStart,
                              background: const ColoredBox(color: Colors.red),
                              confirmDismiss: (_) async {
                                try {
                                  await widget.api
                                      .deleteCall(call['id'] as String);
                                  return true;
                                } catch (e) {
                                  if (context.mounted) _error(context, e);
                                  return false;
                                }
                              },
                              child: _callCard(call)))
                          .toList());
                }))
      ]));
}

class CallDialog extends StatefulWidget {
  const CallDialog({super.key, required this.api});
  final ApiService api;
  @override
  State<CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<CallDialog> {
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _duration = TextEditingController(text: '0');
  String _type = 'incoming';
  bool _spam = false, _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        int.tryParse(_duration.text) == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.addCall({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'type': _type,
        'durationSeconds': int.parse(_duration.text),
        'isSpam': _spam,
        'date': DateTime.now().toIso8601String(),
        'source': 'manual'
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Add call log'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Duration (seconds)')),
            DropdownButtonFormField(
                initialValue: _type,
                items: const ['incoming', 'outgoing', 'missed']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as spam'),
                value: _spam,
                onChanged: (v) => setState(() => _spam = v))
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'))
          ]);
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.api});
  final ApiService api;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _contacts;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() => setState(() => _contacts = widget.api.contacts(_search.text));
  Future<void> _add() async {
    final controllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(text: 'Contact')
    ];
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Add contact'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: controllers[0],
                      decoration: const InputDecoration(labelText: 'Name')),
                  TextField(
                      controller: controllers[1],
                      decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(
                      controller: controllers[2],
                      decoration: const InputDecoration(labelText: 'Tag'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        try {
                          await widget.api.addContact(
                              controllers[0].text.trim(),
                              controllers[1].text.trim(),
                              controllers[2].text.trim());
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) _error(ctx, e);
                        }
                      },
                      child: const Text('Save'))
                ]));
    for (final c in controllers) {
      c.dispose();
    }
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Contacts',
      action:
          IconButton(icon: const Icon(Icons.person_add_alt), onPressed: _add),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: const InputDecoration(
                    labelText: 'Search contacts',
                    prefixIcon: Icon(Icons.search)))),
        Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _contacts,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _failure(snapshot.error!, _load);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                      children: snapshot.data!
                          .map((contact) => ListTile(
                              leading: CircleAvatar(
                                  child: Text((contact['name'] as String)
                                      .substring(0, 1)
                                      .toUpperCase())),
                              title: Text(contact['name'] as String),
                              subtitle: Text(
                                  '${contact['phone']} · ${contact['tag']}'),
                              trailing: IconButton(
                                  icon: const Icon(Icons.call),
                                  onPressed: () => launchUrl(Uri(
                                      scheme: 'tel',
                                      path: (contact['phone'] as String)
                                          .replaceAll(' ', ''))))))
                          .toList());
                }))
      ]));
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.api});
  final ApiService api;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<Map<String, dynamic>> _data;
  DateTimeRange _range = DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now());
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _data = widget.api.analytics(
      from: _range.start.toIso8601String().substring(0, 10),
      to: _range.end.toIso8601String().substring(0, 10)));
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Analytics & reports',
      action: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final value = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _range);
            if (value != null) {
              _range = value;
              _load();
            }
          }),
      child: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _failure(snapshot.error!, _load);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final totals =
                Map<String, dynamic>.from(snapshot.data!['totals'] as Map);
            final series = List<Map<String, dynamic>>.from(
                snapshot.data!['series'] as List);
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text(
                  '${_range.start.toString().substring(0, 10)} – ${_range.end.toString().substring(0, 10)}'),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _metric('Total calls', '${totals['total']}'),
                _metric('Incoming', '${totals['incoming']}'),
                _metric('Outgoing', '${totals['outgoing']}'),
                _metric('Missed', '${totals['missed']}'),
                _metric(
                    'Talk time', _duration(totals['durationSeconds'] as int))
              ]),
              const SizedBox(height: 24),
              Text('Daily call frequency',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (series.isEmpty)
                const Text('No calls in this period.')
              else
                ...series.map((item) => ListTile(
                    title: Text(item['date'] as String),
                    trailing: Text('${item['count']} calls')))
            ]);
          }));
}

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key, required this.api});
  final ApiService api;
  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  late Future<List<Map<String, dynamic>>> _recordings;
  late Future<List<Map<String, dynamic>>> _calls;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _recordings = widget.api.recordings();
    _calls = widget.api.calls();
    setState(() {});
  }

  Future<void> _upload() async {
    final calls = await _calls;
    if (!mounted) return;
    if (calls.isEmpty) {
      _error(
          context,
          const ApiException(
              'Create a call log before attaching an authorized recording.'));
      return;
    }
    String callId = calls.first['id'] as String;
    bool consent = false;
    final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                    title: const Text('Upload authorized recording'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Only upload recordings from a supported app-owned/authorized capture flow after all required parties have consented.'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: callId,
                          items: calls
                              .map((call) => DropdownMenuItem(
                                  value: call['id'] as String,
                                  child: Text(
                                      '${call['name']} · ${call['phone']}')))
                              .toList(),
                          onChanged: (value) =>
                              setDialog(() => callId = value!)),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: consent,
                          onChanged: (value) =>
                              setDialog(() => consent = value ?? false),
                          title: const Text(
                              'I confirm required consent was obtained'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed:
                              consent ? () => Navigator.pop(ctx, true) : null,
                          child: const Text('Choose file'))
                    ])));
    if (proceed != true) return;
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty || files.single.path == null || !mounted) return;
    final selectedFile = files.single;
    try {
      await widget.api.uploadRecording(
          file: File(selectedFile.path!),
          callId: callId,
          name: selectedFile.name);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording uploaded securely.')));
      }
    } catch (e) {
      if (mounted) _error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Recordings',
      action:
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _upload),
      child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _recordings,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _failure(snapshot.error!, _reload);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No authorized recordings uploaded. Cellular call recording is not enabled by default.')));
            }
            return ListView(
                children: snapshot.data!
                    .map((recording) => ListTile(
                        leading: const Icon(Icons.audio_file),
                        title: Text(recording['name'] as String),
                        subtitle: Text(
                            'Consent captured ${_date(recording['consentedAt'] as String)}'),
                        trailing: Text(
                            '${((recording['size'] as int) / 1024).round()} KB')))
                    .toList());
          }));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onSignOut});
  final Future<void> Function() onSignOut;
  Future<void> _dialerRequest(BuildContext context) async {
    try {
      final message =
          await _dialer.invokeMethod<String>('requestDefaultDialer');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                message ?? 'Complete the selection in Android settings.')));
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        _error(
            context,
            ApiException(
                e.message ?? 'Default-dialer request is unavailable.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Settings & privacy',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Call logs, contacts, and recordings are private data. Recording uploads require explicit confirmation of consent. Default-dialer status does not enable third-party cellular-call recording.'))),
        ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Request default dialer role'),
            subtitle:
                const Text('Android will ask you to choose; you can decline.'),
            onTap: () => _dialerRequest(context)),
        const Divider(),
        const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('Notifications'),
            subtitle:
                Text('Server event delivery can be configured at deployment.')),
        const Divider(),
        const ListTile(
            leading: Icon(Icons.security),
            title: Text('Privacy controls'),
            subtitle: Text(
                'Use a production privacy policy, data retention policy, and legal review before release.')),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: onSignOut)
      ]));
}
