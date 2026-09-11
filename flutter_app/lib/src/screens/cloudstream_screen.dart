import 'package:flutter/material.dart';
import '../services/cloudstream_service.dart';

class CloudstreamScreen extends StatefulWidget {
  CloudstreamScreen({super.key, CloudstreamService? service})
      : service = service ?? CloudstreamService();
  final CloudstreamService service;
  @override
  State<CloudstreamScreen> createState() => _CloudstreamScreenState();
}

class _CloudstreamScreenState extends State<CloudstreamScreen> {
  final _url = TextEditingController();
  final _filter = TextEditingController();
  Map<String, dynamic> _data = {'repos': [], 'installed': {}};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _run(() async {});
  }

  @override
  void dispose() {
    _url.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final data = await widget.service.state();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install(Map<String, dynamic> plugin) async {
    final trusted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Trust ${plugin['name']}?'),
              content: const Text(
                  'Cloudstream plugins execute third-party Android code with Omnio\'s permissions. '
                  'Install only from authors you trust. They are not sandboxed. Updates also replace executable code. '
                  'A repo-provided hash checks the download, not whether its author is trustworthy.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Trust and install'))
              ],
            ));
    if (trusted == true && mounted) {
      await _run(() => widget.service.install(plugin));
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = _data['installed'] as Map;
    final plugins = <String, Map<String, dynamic>>{
      for (final entry in installed.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
      for (final repo in _data['repos'] as List)
        for (final plugin in repo['plugins'] as List)
          plugin['id']: Map<String, dynamic>.from(plugin),
    }
        .values
        .where((p) =>
            '${p['name']} ${p['language']} ${(p['tvTypes'] as List?)?.join(' ')}'
                .toLowerCase()
                .contains(_filter.text.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Cloudstream sources')),
      body: CustomScrollView(slivers: [
        SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(children: [
              const Text('Sources only',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Enabled plugins add playable links beside Stremio sources. Home, search, and TMDB stay unchanged.'),
              if (!widget.service.supported)
                const Text('Plugin execution requires Android 6 or newer.'),
              const SizedBox(height: 20),
              TextField(
                  controller: _url,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: 'Repository URL',
                      hintText: 'https://.../repo.json',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await widget.service.addRepository(_url.text);
                            _url.clear();
                          }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Cloudstream repo')),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.orangeAccent))),
              for (final repo in _data['repos'] as List) ...[
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(repo['name']),
                    subtitle: Text(
                        '${(repo['plugins'] as List).length} plugins',
                        maxLines: 2),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: 'Refresh repository',
                          onPressed: _busy
                              ? null
                              : () => _run(() =>
                                  widget.service.addRepository(repo['url'])),
                          icon: const Icon(Icons.refresh)),
                      IconButton(
                          tooltip: 'Remove repo and its plugins',
                          onPressed: _busy
                              ? null
                              : () async {
                                  final remove = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                              title: const Text(
                                                  'Remove repository?'),
                                              content: const Text(
                                                  'Its installed plugins will also be removed.'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child:
                                                        const Text('Cancel')),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    child: const Text('Remove'))
                                              ]));
                                  if (remove == true && mounted) {
                                    await _run(() => widget.service
                                        .removeRepository(repo['url']));
                                  }
                                },
                          icon: const Icon(Icons.delete_outline)),
                    ])),
                for (final warning in repo['warnings'] as List? ?? [])
                  Text(warning,
                      style: const TextStyle(color: Colors.orangeAccent)),
              ],
              const SizedBox(height: 12),
              TextField(
                  controller: _filter,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Filter plugins by name, language, or type')),
            ])),
        SliverList.builder(
            itemCount: plugins.length,
            itemBuilder: (context, index) {
              final plugin = plugins[index];
              final saved = installed[plugin['id']] as Map?;
              final update = saved != null &&
                  (saved['version'] != plugin['version'] ||
                      saved['fileHash'] != plugin['fileHash']);
              return Card(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plugin['name'],
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                                '${plugin['language'] ?? ''} - version ${plugin['version'] ?? '?'}'),
                            if (plugin['description'] != null)
                              Text('${plugin['description']}',
                                  maxLines: 3, overflow: TextOverflow.ellipsis),
                            if (plugin['status'] == 0)
                              const Text('Marked broken by repository'),
                            Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (saved == null || update)
                                    FilledButton(
                                        onPressed: _busy ||
                                                !widget.service.supported ||
                                                plugin['status'] == 0
                                            ? null
                                            : () => _install(plugin),
                                        child: Text(update
                                            ? 'Update plugin'
                                            : 'Install plugin')),
                                  if (saved != null) ...[
                                    const Text('Enabled'),
                                    Switch(
                                        value: saved['enabled'] == true,
                                        onChanged: _busy
                                            ? null
                                            : (value) => _run(() =>
                                                widget.service.setEnabled(
                                                    plugin['id'], value))),
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _run(() => widget.service
                                                .removePlugin(plugin['id'])),
                                        child: const Text('Uninstall')),
                                  ],
                                ]),
                          ])));
            }),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}
