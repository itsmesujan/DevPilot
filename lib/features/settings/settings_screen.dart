import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/storage/storage_service.dart';
import '../../services/ai/model_catalog.dart';
import '../../services/mcp/mcp_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final settingsRefreshProvider = StateProvider<int>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storage = StorageService.instance;
  final _controllers = <String, TextEditingController>{};

  final _providers = [
    'openai', 'anthropic', 'gemini', 'mistral',
    'deepseek', 'groq', 'together', 'kimi', 'openrouter', 'ollama',
    'huggingface', 'brave', 'tavily',
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Model Selection ─────────────────────────────────────────────
          const _SectionHeader('Active Model'),
          _ModelSelector(storage: _storage),
          const SizedBox(height: 24),

          // ── API Keys ─────────────────────────────────────────────────────
          const _SectionHeader('API Keys'),
          ..._providers.map((p) => _ApiKeyTile(provider: p)),
          const SizedBox(height: 24),

          // ── Inference Settings ───────────────────────────────────────────
          const _SectionHeader('Inference'),
          _SliderTile(
            label: 'Temperature',
            value: _storage.temperature,
            min: 0,
            max: 1,
            onChanged: (v) async {
              await _storage.setTemperature(v);
              setState(() {});
            },
          ),
          _SliderTile(
            label: 'Max context tokens',
            value: _storage.maxContextTokens.toDouble(),
            min: 1024,
            max: 32768,
            divisions: 31,
            formatValue: (v) => v.round().toString(),
            onChanged: (v) async {
              await _storage.setMaxContextTokens(v.round());
              setState(() {});
            },
          ),
          _SwitchTile(
            label: 'Streaming responses',
            value: _storage.streamingEnabled,
            onChanged: (v) async {
              await _storage.setStreaming(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // ── Voice ────────────────────────────────────────────────────────
          const _SectionHeader('Voice'),
          _SwitchTile(
            label: 'Enable voice assistant',
            value: _storage.voiceEnabled,
            onChanged: (v) async {
              await _storage.setVoiceEnabled(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // ── Appearance ───────────────────────────────────────────────────
          const _SectionHeader('Appearance'),
          _SwitchTile(
            label: 'Dark mode',
            value: _storage.darkMode,
            onChanged: (v) async {
              await _storage.setDarkMode(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // ── System Prompt ────────────────────────────────────────────────
          const _SectionHeader('System Prompt'),
          TextField(
            controller: _ctrl('system_prompt')
              ..text = _storage.systemPrompt,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'System prompt for the AI…',
            ),
            onChanged: (v) => _storage.setSystemPrompt(v),
          ),
          const SizedBox(height: 24),

          // ── Navigate to Model Hub ─────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => context.go('/models'),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Manage Local Models'),
          ),
          const SizedBox(height: 12),

          // ── Navigate to Custom Skills ─────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => context.go('/skills'),
            icon: const Icon(Icons.psychology_outlined),
            label: const Text('Manage Custom Skills'),
          ),
          const SizedBox(height: 12),

          // ── Navigate to Study Mode ─────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => context.go('/study'),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Enter Study Mode'),
          ),
          const SizedBox(height: 24),

          // ── MCP Servers ──────────────────────────────────────────────────
          const _SectionHeader('External MCP Servers'),
          _McpServerSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _McpServerSection extends StatefulWidget {
  @override
  State<_McpServerSection> createState() => _McpServerSectionState();
}

class _McpServerSectionState extends State<_McpServerSection> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isConnecting = false;

  Future<void> _connect() async {
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;

    setState(() => _isConnecting = true);
    try {
      await McpService.instance.connectToServer(name, url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to $name MCP server!')),
        );
        _nameCtrl.clear();
        _urlCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = McpService.instance.connections;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (connections.isNotEmpty) ...[
          for (final conn in connections)
            ListTile(
              leading: const Icon(Icons.hub, color: Colors.green),
              title: Text(conn.name),
              subtitle: Text('${conn.baseUrl}\n${conn.tools.length} tools registered'),
              isThreeLine: true,
            ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Server Name', hintText: 'e.g. Postgres'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'SSE URL', hintText: 'http://localhost:8000/sse'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isConnecting ? null : _connect,
          icon: _isConnecting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_link),
          label: const Text('Connect MCP Server'),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ModelSelector extends StatefulWidget {
  final StorageService storage;
  const _ModelSelector({required this.storage});

  @override
  State<_ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<_ModelSelector> {
  @override
  Widget build(BuildContext context) {
    final allModels = [...ModelCatalog.cloudModels, ...ModelCatalog.localModels];
    final current = widget.storage.selectedModelId;
    final currentModel = allModels.where((m) => m.apiModelId == current || m.id == current).firstOrNull;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(currentModel?.name ?? current),
      subtitle: Text(currentModel?.provider ?? '', style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/models'),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  final String provider;
  const _ApiKeyTile({required this.provider});

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  final _ctrl = TextEditingController();
  bool _loaded = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await StorageService.instance.getApiKey(widget.provider);
    if (mounted) {
      setState(() {
        _ctrl.text = key ?? '';
        _loaded = true;
      });
    }
  }

  Future<void> _saveKey() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) {
      await StorageService.instance.deleteApiKey(widget.provider);
    } else {
      await StorageService.instance.saveApiKey(widget.provider, value);
    }
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _getDisplayName(String provider) {
    switch (provider) {
      case 'openai': return 'OpenAI';
      case 'anthropic': return 'Anthropic';
      case 'gemini': return 'Gemini';
      case 'mistral': return 'Mistral';
      case 'deepseek': return 'DeepSeek';
      case 'groq': return 'Groq';
      case 'together': return 'Together AI';
      case 'kimi': return 'Kimi';
      case 'openrouter': return 'OpenRouter';
      case 'ollama': return 'Ollama URL';
      case 'huggingface': return 'Hugging Face';
      case 'brave': return 'Brave Search';
      case 'tavily': return 'Tavily Search';
      default: return provider.isNotEmpty ? (provider[0].toUpperCase() + provider.substring(1)) : provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _getDisplayName(widget.provider),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'API key…',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              _saved ? Icons.check : Icons.save_outlined,
              size: 18,
              color: _saved ? Colors.green : Colors.white54,
            ),
            onPressed: _saveKey,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? formatValue;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              formatValue != null
                  ? formatValue!(value)
                  : value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
