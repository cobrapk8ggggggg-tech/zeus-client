// Zeus Manhwa — guided server setup with connection test.
// Opens automatically on first run (see NavigationShellScreen) and is
// reachable any time from Settings → Server → Client → "Server Setup".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../global_providers/global_providers.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/toast/toast.dart';
import '../client/server_url_tile/server_url_tile.dart';

const String _kSetupDoneKey = 'zeus_server_setup_done';

/// Whether the first-run setup wizard has been completed (or skipped).
bool serverSetupCompleted(SharedPreferences prefs) =>
    prefs.getBool(_kSetupDoneKey) ?? false;

String? _normalizeUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return null;
  if (!url.toLowerCase().startsWith('http://') &&
      !url.toLowerCase().startsWith('https://')) {
    url = 'http://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return url;
}

class ServerSetupScreen extends HookConsumerWidget {
  const ServerSetupScreen({super.key, this.firstRun = false});

  /// True when launched automatically because no server has been set up yet.
  final bool firstRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: ref.watch(serverUrlProvider) ?? '',
    );
    final testing = useState(false);
    final reachable = useState<bool?>(null);
    final message = useState<String?>(null);

    Future<void> save() async {
      final l10n = context.l10n;
      final toast = ref.read(toastProvider);
      final url = _normalizeUrl(controller.text);
      if (url == null) {
        reachable.value = false;
        message.value = l10n.serverSetupInvalidUrl;
        return;
      }
      ref.read(serverUrlProvider.notifier).update(url);
      await ref.read(sharedPreferencesProvider).setBool(_kSetupDoneKey, true);
      toast?.show(l10n.serverSetupSaved);
      if (context.mounted) Navigator.of(context).pop(true);
    }

    Future<void> skip() async {
      await ref.read(sharedPreferencesProvider).setBool(_kSetupDoneKey, true);
      if (context.mounted) Navigator.of(context).pop(false);
    }

    Future<void> testConnection() async {
      final l10n = context.l10n;
      final url = _normalizeUrl(controller.text);
      if (url == null) {
        reachable.value = false;
        message.value = l10n.serverSetupInvalidUrl;
        return;
      }
      testing.value = true;
      reachable.value = null;
      message.value = null;
      try {
        final base = Uri.parse(url);
        final testUri = base.replace(pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          'api',
          'v1',
          'settings',
          'about',
        ]);
        final response =
            await http.get(testUri).timeout(const Duration(seconds: 6));
        reachable.value = true;
        message.value =
            (response.statusCode >= 200 && response.statusCode < 300)
                ? l10n.serverSetupConfirmed
                : l10n.serverSetupReachable;
      } on TimeoutException {
        reachable.value = false;
        message.value = l10n.serverSetupUnreachable(l10n.serverSetupTimeout);
      } catch (e) {
        reachable.value = false;
        message.value = l10n.serverSetupUnreachable(e.toString());
      } finally {
        testing.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.serverSetupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const Gap(8),
            Image.asset('assets/branding/zeus-logo.png', height: 96),
            const Gap(16),
            Text(
              context.l10n.serverSetupDescription,
              style: context.textTheme.bodyMedium,
            ),
            const Gap(16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.serverSetupAddressLabel,
                hintText: 'http://192.168.1.10:4567',
                prefixIcon: const Icon(Icons.dns_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            OutlinedButton.icon(
              onPressed: testing.value ? null : testConnection,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: testing.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_rounded),
              label: Text(
                testing.value
                    ? context.l10n.serverSetupTesting
                    : context.l10n.serverSetupTest,
              ),
            ),
            if (message.value != null) ...[
              const Gap(8),
              Text(
                message.value!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: reachable.value == true
                      ? Colors.green
                      : context.colorScheme.error,
                ),
              ),
            ],
            const Gap(20),
            FilledButton.icon(
              onPressed: save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.l10n.serverSetupSave),
            ),
            if (firstRun)
              TextButton(
                onPressed: skip,
                child: Text(context.l10n.serverSetupSkip),
              ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}

/// Settings tile that opens the setup wizard manually.
class ServerSetupTile extends ConsumerWidget {
  const ServerSetupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.settings_input_antenna_rounded),
      title: Text(context.l10n.serverSetupTitle),
      subtitle: Text(context.l10n.serverSetupOpenWizard),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const ServerSetupScreen()),
      ),
    );
  }
}
