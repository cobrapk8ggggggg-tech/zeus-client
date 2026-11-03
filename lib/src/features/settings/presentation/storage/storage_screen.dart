// Zeus Manhwa — full app storage control.
// Lets the user inspect and delete cached chapter images, temporary files
// and the GraphQL (Hive) cache — individually selected or all at once.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/misc/toast/toast.dart';

enum _StorageItem { images, temp, graphql }

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final Map<_StorageItem, int> _sizes = {};
  final Set<_StorageItem> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<int> _sizeOf(String path, {String? excludePrefix}) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (excludePrefix != null && entity.path.startsWith(excludePrefix)) {
          continue;
        }
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _refresh() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final tmp = (await getTemporaryDirectory()).path;
      final docs = (await getApplicationDocumentsDirectory()).path;
      final images = '$tmp/libCachedImageData';
      final sizes = <_StorageItem, int>{};
      sizes[_StorageItem.images] = await _sizeOf(images);
      sizes[_StorageItem.temp] =
          await _sizeOf(tmp, excludePrefix: '$images/');

      int hiveSize = 0;
      final docsDir = Directory(docs);
      if (docsDir.existsSync()) {
        await for (final entity in docsDir.list(followLinks: false)) {
          if (entity is File &&
              (entity.path.endsWith('.hive') ||
                  entity.path.endsWith('.lock'))) {
            try {
              hiveSize += entity.lengthSync();
            } catch (_) {}
          }
        }
      }
      sizes[_StorageItem.graphql] = hiveSize;
      if (!mounted) return;
      setState(() {
        _sizes
          ..clear()
          ..addAll(sizes);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearDir(String path, {String? excludePrefix}) async {
    final dir = Directory(path);
    if (!dir.existsSync()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (excludePrefix != null && entity.path.startsWith(excludePrefix)) {
        continue;
      }
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _delete(Set<_StorageItem> items) async {
    final l10n = context.l10n;
    final toast = ref.read(toastProvider);
    try {
      final tmp = (await getTemporaryDirectory()).path;
      final docs = (await getApplicationDocumentsDirectory()).path;
      final images = '$tmp/libCachedImageData';
      for (final item in items) {
        try {
          switch (item) {
            case _StorageItem.images:
              await DefaultCacheManager().emptyCache();
              await _clearDir(images);
            case _StorageItem.temp:
              await _clearDir(tmp, excludePrefix: '$images/');
            case _StorageItem.graphql:
              final docsDir = Directory(docs);
              if (docsDir.existsSync()) {
                await for (final entity in docsDir.list(followLinks: false)) {
                  if (entity is File &&
                      (entity.path.endsWith('.hive') ||
                          entity.path.endsWith('.lock'))) {
                    try {
                      await entity.delete();
                    } catch (_) {}
                  }
                }
              }
          }
        } catch (_) {}
      }
    } catch (_) {}
    toast?.show(l10n.storageDeleted);
    await _refresh();
  }

  Future<bool> _confirm(Set<_StorageItem> items) async {
    final names = items.map(_title).join(', ');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.storageConfirmTitle),
        content: Text(context.l10n.storageConfirmBody(names)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _title(_StorageItem item) {
    switch (item) {
      case _StorageItem.images:
        return context.l10n.storageImages;
      case _StorageItem.temp:
        return context.l10n.storageTemp;
      case _StorageItem.graphql:
        return context.l10n.storageGraphql;
    }
  }

  IconData _icon(_StorageItem item) {
    switch (item) {
      case _StorageItem.images:
        return Icons.image_rounded;
      case _StorageItem.temp:
        return Icons.folder_open_rounded;
      case _StorageItem.graphql:
        return Icons.storage_rounded;
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _subtitle(_StorageItem item) {
    final label =
        _loading ? context.l10n.storageScanning : _fmt(_sizes[item] ?? 0);
    return item == _StorageItem.graphql
        ? '$label · ${context.l10n.storageRequiresRestart}'
        : label;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.storageManagement)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.storageUnsupported,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final total = _sizes.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.storageManagement),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: ListTile(
              leading: const Icon(Icons.data_usage_rounded),
              title: Text(context.l10n.storageTotal),
              subtitle: Text(
                _loading ? context.l10n.storageScanning : _fmt(total),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: _StorageItem.values
                  .map(
                    (item) => CheckboxListTile(
                      value: _selected.contains(item),
                      onChanged: _loading
                          ? null
                          : (value) => setState(
                                () => value == true
                                    ? _selected.add(item)
                                    : _selected.remove(item),
                              ),
                      secondary: Icon(_icon(item)),
                      title: Text(_title(item)),
                      subtitle: Text(_subtitle(item)),
                    ),
                  )
                  .toList(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selected.isEmpty || _loading
                          ? null
                          : () async {
                              final selected =
                                  Set<_StorageItem>.from(_selected);
                              if (await _confirm(selected)) {
                                if (!mounted) return;
                                await _delete(selected);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(context.l10n.storageDeleteSelected),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final all =
                                  Set<_StorageItem>.from(_StorageItem.values);
                              if (await _confirm(all)) {
                                if (!mounted) return;
                                setState(_selected.clear);
                                await _delete(all);
                              }
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(context.l10n.storageDeleteAll),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
