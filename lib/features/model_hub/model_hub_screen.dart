import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/model_profile.dart';
import '../../services/ai/model_catalog.dart';
import '../../services/ai/download_manager.dart';
import '../../services/storage/storage_service.dart';
import '../../services/storage/app_database.dart';
import '../../services/local/local_llm_service.dart';
import '../../services/local/hardware_info_service.dart';
import 'model_test_lab.dart';

class _HFUrlParts {
  final String repo;
  final String filename;
  _HFUrlParts(this.repo, this.filename);
}

_HFUrlParts? _parseHFUrl(String url) {
  final cleanUrl = url.trim();
  final uri = Uri.tryParse(cleanUrl);
  if (uri == null || !uri.host.contains('huggingface.co')) return null;

  final segments = uri.pathSegments;
  if (segments.length >= 2) {
    final repo = '${segments[0]}/${segments[1]}';
    String filename = '';
    if (segments.length >= 5 && (segments[2] == 'resolve' || segments[2] == 'blob')) {
      filename = segments.sublist(4).join('/');
    }
    return _HFUrlParts(repo, filename);
  }
  return null;
}

class HubCategoryFilter {
  final String label;
  final String emoji;
  final bool Function(ModelProfile) matches;

  const HubCategoryFilter({
    required this.label,
    required this.emoji,
    required this.matches,
  });
}


// ── Providers ─────────────────────────────────────────────────────────────────

final downloadProgressProvider =
    StateProvider.family<double?, String>((ref, modelId) => null);

final downloadedModelsProvider = StateProvider<Set<String>>((ref) {
  final rows = AppDatabase.instance.getDownloadedModels();
  return rows.map((r) => r['model_id'] as String).toSet();
});

/// ID of the model currently loaded into on-device inference engine.
final activeLocalModelProvider = StateProvider<String?>((ref) => null);

/// Loading state for on-device model load operation.
final localLoadingProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────

class ModelHubScreen extends ConsumerStatefulWidget {
  const ModelHubScreen({super.key});

  @override
  ConsumerState<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends ConsumerState<ModelHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCloudProvider = 'all';
  int _selectedLocalCategoryIndex = 0;
  SystemHardwareInfo? _hardwareInfo;
  String _searchQuery = '';
  int _totalStorageUsedMb = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHardwareInfo();
    _computeStorageUsed();
  }

  Future<void> _loadHardwareInfo() async {
    final info = await HardwareInfoService.instance.getHardwareInfo();
    if (mounted) {
      setState(() => _hardwareInfo = info);
    }
  }

  Future<void> _computeStorageUsed() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(p.join(dir.path, 'models'));
      if (!modelsDir.existsSync()) return;
      int total = 0;
      await for (final f in modelsDir.list()) {
        if (f is File) total += await f.length();
      }
      if (mounted) {
        setState(() => _totalStorageUsedMb = total ~/ (1024 * 1024));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _download(ModelProfile model) async {
    if (model.downloadUrl == null || model.ggufFilename == null) return;

    await for (final progress in DownloadManager.instance.downloadModel(
      modelId: model.id,
      url: model.downloadUrl!,
      filename: model.ggufFilename!,
      estimatedSizeMb: model.fileSizeMb ?? 0,
    )) {
      if (mounted) {
        ref.read(downloadProgressProvider(model.id).notifier).state =
            progress.isComplete ? null : progress.progress;
      }
      if (progress.isComplete) break;
    }

    ref.read(downloadedModelsProvider.notifier).state = {
      ...ref.read(downloadedModelsProvider),
      model.id,
    };
    _computeStorageUsed();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${model.name} downloaded!')));
    }
  }

  void _selectModel(ModelProfile model) async {
    await StorageService.instance.setSelectedModel(model.apiModelId ?? model.id);
    await StorageService.instance.setSelectedProvider(model.provider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Active model: ${model.name}')));
    }
  }

  Future<void> _loadOnDevice(ModelProfile model) async {
    if (model.ggufFilename == null) return;
    ref.read(localLoadingProvider.notifier).state = model.id;
    try {
      await LocalLlmService.instance.loadModel(
        modelId: model.id,
        filename: model.ggufFilename!,
      );
      ref.read(activeLocalModelProvider.notifier).state = model.id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${model.name} loaded on device!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red));
      }
    } finally {
      ref.read(localLoadingProvider.notifier).state = null;
    }
  }

  Future<void> _unloadFromDevice() async {
    await LocalLlmService.instance.unloadModel();
    ref.read(activeLocalModelProvider.notifier).state = null;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Model unloaded.')));
    }
  }

  Future<void> _deleteModel(ModelProfile model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text(
            'This will permanently delete "${model.name}" (${model.fileSizeMb ?? 0} MB) from storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DownloadManager.instance.deleteModel(model.id, model.ggufFilename ?? '');

    final current = {...ref.read(downloadedModelsProvider)};
    current.remove(model.id);
    ref.read(downloadedModelsProvider.notifier).state = current;

    // If the deleted model was the active on-device model, unload it
    if (ref.read(activeLocalModelProvider) == model.id) {
      ref.read(activeLocalModelProvider.notifier).state = null;
    }

    _computeStorageUsed();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${model.name} deleted.')));
    }
  }

  void _showCustomModelDialog() {
    final nameCtrl = TextEditingController();
    final repoCtrl = TextEditingController();
    final fileCtrl = TextEditingController();
    final ramCtrl = TextEditingController();
    ModelCapability selectedCap = ModelCapability.chat;

    repoCtrl.addListener(() {
      final text = repoCtrl.text.trim();
      if (text.startsWith('http') && text.contains('huggingface.co')) {
        final parts = _parseHFUrl(text);
        if (parts != null) {
          final newRepo = parts.repo;
          final newFile = parts.filename;

          repoCtrl.value = repoCtrl.value.copyWith(
            text: newRepo,
            selection: TextSelection.collapsed(offset: newRepo.length),
          );

          if (newFile.isNotEmpty) {
            fileCtrl.text = newFile;
          }
          if (nameCtrl.text.isEmpty) {
            final filePart = newFile.split('/').lastOrNull ?? '';
            final nameWithoutExt = filePart.replaceAll('.gguf', '');
            nameCtrl.text = nameWithoutExt.isNotEmpty ? nameWithoutExt : newRepo.split('/').last;
          }
        }
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Model'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model Name',
                        hintText: 'e.g. My Qwen 1.5B',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: repoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hugging Face Repo or Direct URL',
                        hintText: 'e.g. Qwen/Qwen2.5-1.5B-Instruct-GGUF or full URL',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fileCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model GGUF Filename (Optional for direct URL)',
                        hintText: 'e.g. qwen2.5-1.5b-instruct-q4_k_m.gguf',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ramCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min RAM requirement (MB)',
                        hintText: 'e.g. 2048',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ModelCapability>(
                      initialValue: selectedCap,
                      decoration: const InputDecoration(labelText: 'Model Type / Capability'),
                      items: const [
                        DropdownMenuItem(value: ModelCapability.chat, child: Text('💬 LLM Chat (Text)')),
                        DropdownMenuItem(value: ModelCapability.code, child: Text('💻 Code Generation')),
                        DropdownMenuItem(value: ModelCapability.vision, child: Text('👁️ Vision (Multimodal)')),
                        DropdownMenuItem(value: ModelCapability.voice, child: Text('🎤 Voice (Speech-to-Text)')),
                        DropdownMenuItem(value: ModelCapability.imageGeneration, child: Text('🎨 Image Generation')),
                        DropdownMenuItem(value: ModelCapability.embedding, child: Text('📊 Embeddings')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCap = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    var repo = repoCtrl.text.trim();
                    var file = fileCtrl.text.trim();

                    // Re-parse Hugging Face URL if submitted directly
                    if (repo.contains('huggingface.co')) {
                      final parts = _parseHFUrl(repo);
                      if (parts != null) {
                        repo = parts.repo;
                        if (parts.filename.isNotEmpty) {
                          file = parts.filename;
                        }
                      }
                    }

                    if (name.isEmpty || repo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }

                    String url;
                    String filename;

                    if (repo.startsWith('http://') || repo.startsWith('https://')) {
                      url = repo;
                      final uri = Uri.tryParse(repo);
                      filename = file.isNotEmpty ? file : (uri?.pathSegments.lastOrNull ?? 'model.gguf');
                      repo = 'direct_url';
                    } else {
                      if (file.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hugging Face model requires a GGUF filename')),
                        );
                        return;
                      }
                      url = 'https://huggingface.co/$repo/resolve/main/$file';
                      filename = file;
                    }

                    Navigator.pop(context);

                    final customId = 'custom-${repo.replaceAll("/", "-").toLowerCase()}-${filename.replaceAll(".", "-").toLowerCase()}';

                    final customModel = ModelProfile(
                      id: customId,
                      name: name,
                      description: repo == 'direct_url'
                          ? 'Custom model downloaded from: $url'
                          : 'Custom model downloaded from Hugging Face: $repo',
                      backend: ModelBackend.local,
                      provider: 'local',
                      capabilities: [selectedCap],
                      ggufFilename: filename,
                      downloadUrl: url,
                      fileSizeMb: 1000,
                      minRamMb: int.tryParse(ramCtrl.text) ?? 2048,
                    );

                    _downloadCustom(customModel);
                  },
                  child: const Text('Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadCustom(ModelProfile model) async {
    if (model.downloadUrl == null || model.ggufFilename == null) return;

    await for (final progress in DownloadManager.instance.downloadModel(
      modelId: model.id,
      url: model.downloadUrl!,
      filename: model.ggufFilename!,
      estimatedSizeMb: model.fileSizeMb ?? 1000,
      customProfile: model,
    )) {
      if (mounted) {
        ref.read(downloadProgressProvider(model.id).notifier).state =
            progress.isComplete ? null : progress.progress;
      }
      if (progress.isComplete) break;
    }

    ref.read(downloadedModelsProvider.notifier).state = {
      ...ref.read(downloadedModelsProvider),
      model.id,
    };
    _computeStorageUsed();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${model.name} downloaded!')));
    }
  }

  Widget _buildHardwareDiagnosticsHeader() {
    if (_hardwareInfo == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final info = _hardwareInfo!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.developer_board, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'System Diagnostics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tier: ${info.tier}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDiagItem(Icons.laptop, 'OS', info.platformName),
                _buildDiagItem(Icons.analytics, 'CPU Cores', '${info.cpuCores} Cores'),
                _buildDiagItem(Icons.memory, 'Est. RAM', '${info.estimatedRamGb.toStringAsFixed(1)} GB'),
                _buildDiagItem(Icons.storage, 'Models Used', '$_totalStorageUsedMb MB'),
              ],
            ),
            const Divider(height: 20, color: Colors.white10),
            Row(
              children: [
                Icon(
                  info.isGpuAccelerated ? Icons.bolt : Icons.slow_motion_video,
                  size: 14,
                  color: info.isGpuAccelerated ? Colors.amber : Colors.white30,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'GPU: ${info.gpuName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: info.isGpuAccelerated ? Colors.white70 : Colors.white30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadedIds = ref.watch(downloadedModelsProvider);
    final activeLocalId = ref.watch(activeLocalModelProvider);
    final loadingId = ref.watch(localLoadingProvider);

    final cloudProviders = ['all', 'openai', 'anthropic', 'gemini', 'mistral', 'deepseek', 'groq'];

    final cloudModels = _selectedCloudProvider == 'all'
        ? ModelCatalog.cloudModels
        : ModelCatalog.cloudModels
            .where((m) => m.provider == _selectedCloudProvider)
            .toList();

    // All local + custom models, filtered by category and search
    final allLocalModels = ModelCatalog.allModels
        .where((m) => m.backend == ModelBackend.local)
        .toList();

    final localCategories = [
      HubCategoryFilter(
        label: 'All',
        emoji: '🔮',
        matches: (m) => true,
      ),
      HubCategoryFilter(
        label: 'Chat',
        emoji: '💬',
        matches: (m) => m.capabilities.contains(ModelCapability.chat),
      ),
      HubCategoryFilter(
        label: 'Code',
        emoji: '💻',
        matches: (m) => m.capabilities.contains(ModelCapability.code),
      ),
      HubCategoryFilter(
        label: 'Vision',
        emoji: '👁️',
        matches: (m) => m.capabilities.contains(ModelCapability.vision),
      ),
      HubCategoryFilter(
        label: 'Voice',
        emoji: '🎤',
        matches: (m) => m.capabilities.contains(ModelCapability.voice),
      ),
      HubCategoryFilter(
        label: 'Image',
        emoji: '🎨',
        matches: (m) => m.capabilities.contains(ModelCapability.imageGeneration),
      ),
      HubCategoryFilter(
        label: 'Embed',
        emoji: '📊',
        matches: (m) => m.capabilities.contains(ModelCapability.embedding),
      ),
      HubCategoryFilter(
        label: 'Reasoning',
        emoji: '🧠',
        matches: (m) => m.tags.contains(ModelTag.reasoning),
      ),
      HubCategoryFilter(
        label: 'Uncensored',
        emoji: '🔓',
        matches: (m) => m.tags.contains(ModelTag.uncensored),
      ),
    ];

    final filteredLocalModels = allLocalModels.where((m) {
      final categoryMatch = localCategories[_selectedLocalCategoryIndex].matches(m);
      final searchMatch = _searchQuery.isEmpty ||
          m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Custom HF Model',
            onPressed: _showCustomModelDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cloud Models'),
            Tab(text: 'Local Models'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHardwareDiagnosticsHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Cloud models tab
                Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: cloudProviders.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final prov = cloudProviders[i];
                          return ChoiceChip(
                            label: Text(prov),
                            selected: _selectedCloudProvider == prov,
                            onSelected: (_) =>
                                setState(() => _selectedCloudProvider = prov),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: cloudModels.length,
                        itemBuilder: (_, i) => _ModelCard(
                          model: cloudModels[i],
                          isDownloaded: false,
                          onSelect: () => _selectModel(cloudModels[i]),
                        ),
                      ),
                    ),
                  ],
                ),

                // Local models tab
                Column(
                  children: [
                    if (activeLocalId != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.memory, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'On-device: ${allLocalModels.firstWhere((m) => m.id == activeLocalId, orElse: () => allLocalModels.first).name}',
                                style: const TextStyle(color: Colors.green, fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: _unloadFromDevice,
                              child: const Text('Unload', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    // Category filter pills
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: localCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final cat = localCategories[i];
                          final isSelected = _selectedLocalCategoryIndex == i;
                          return ChoiceChip(
                            label: Text('${cat.emoji} ${cat.label}'),
                            selected: isSelected,
                            onSelected: (_) => setState(
                                () => _selectedLocalCategoryIndex = i),
                          );
                        },
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search models...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Count info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '${filteredLocalModels.length} model${filteredLocalModels.length == 1 ? '' : 's'} available',
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                          const Spacer(),
                          Text(
                            '${downloadedIds.length} downloaded',
                            style: const TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredLocalModels.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off, size: 40, color: Colors.white24),
                                  SizedBox(height: 8),
                                  Text('No models match your search',
                                      style: TextStyle(color: Colors.white38)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredLocalModels.length,
                              itemBuilder: (_, i) {
                                final m = filteredLocalModels[i];
                                final progress = ref.watch(downloadProgressProvider(m.id));
                                final downloaded = downloadedIds.contains(m.id);
                                final isActive = activeLocalId == m.id;
                                final isLoading = loadingId == m.id;

                                String compatibility = 'Compatible';
                                if (_hardwareInfo != null) {
                                  compatibility = HardwareInfoService.instance
                                      .getCompatibilityMessage(_hardwareInfo!, m.minRamMb);
                                }

                                return _ModelCard(
                                  model: m,
                                  isDownloaded: downloaded,
                                  downloadProgress: progress,
                                  isActiveLocal: isActive,
                                  isLoadingLocal: isLoading,
                                  compatibility: compatibility,
                                  onDownload: downloaded ? null : () => _download(m),
                                  onSelect: downloaded ? () => _selectModel(m) : null,
                                  onLoadLocal: (downloaded && !isActive && !isLoading)
                                      ? () => _loadOnDevice(m)
                                      : null,
                                  onDelete: downloaded ? () => _deleteModel(m) : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final ModelProfile model;
  final bool isDownloaded;
  final double? downloadProgress;
  final bool isActiveLocal;
  final bool isLoadingLocal;
  final String? compatibility;
  final VoidCallback? onDownload;
  final VoidCallback? onSelect;
  final VoidCallback? onLoadLocal;
  final VoidCallback? onDelete;

  const _ModelCard({
    required this.model,
    required this.isDownloaded,
    this.downloadProgress,
    this.isActiveLocal = false,
    this.isLoadingLocal = false,
    this.compatibility,
    this.onDownload,
    this.onSelect,
    this.onLoadLocal,
    this.onDelete,
  });

  Color _getCompatibilityColor(String label) {
    if (label == 'Optimized') return Colors.green;
    if (label == 'Compatible') return Colors.blue;
    if (label.contains('slowly')) return Colors.orange;
    return Colors.red;
  }

  IconData _getCapabilityIcon(ModelCapability cap) {
    switch (cap) {
      case ModelCapability.chat:
        return Icons.chat_bubble_outline;
      case ModelCapability.code:
        return Icons.code;
      case ModelCapability.vision:
        return Icons.remove_red_eye_outlined;
      case ModelCapability.voice:
        return Icons.mic_none;
      case ModelCapability.imageGeneration:
        return Icons.image_outlined;
      case ModelCapability.embedding:
        return Icons.analytics_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(model.provider,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (model.fileSizeMb != null)
                      Text('${model.fileSizeMb} MB',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    if (compatibility != null && model.backend == ModelBackend.local) ...[
                      const SizedBox(height: 4),
                      Text(
                        compatibility!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getCompatibilityColor(compatibility!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(model.description,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            // Capability chips
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...model.capabilities
                    .map((c) => Chip(
                          label: Text(c.name,
                              style: const TextStyle(fontSize: 10)),
                          avatar: Icon(_getCapabilityIcon(c), size: 12),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        )),
                if (model.minRamMb != null)
                  Chip(
                    label: Text('Min RAM: ${model.minRamMb}MB',
                        style: const TextStyle(fontSize: 10, color: Colors.amber)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            if (downloadProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: downloadProgress),
              Text('${(downloadProgress! * 100).toInt()}%',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onDownload != null)
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                if (isDownloaded && onSelect != null)
                  FilledButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Use'),
                  )
                else if (onSelect != null && !isDownloaded)
                  OutlinedButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Select'),
                  ),
                if (onLoadLocal != null || isActiveLocal || isLoadingLocal) ...[
                  if (isLoadingLocal)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isActiveLocal)
                    const Chip(
                      label: Text('On Device',
                          style: TextStyle(color: Colors.green, fontSize: 11)),
                      avatar: Icon(Icons.memory, color: Colors.green, size: 14),
                      visualDensity: VisualDensity.compact,
                    )
                  else if (onLoadLocal != null)
                    OutlinedButton.icon(
                      onPressed: onLoadLocal,
                      icon: const Icon(Icons.memory, size: 16),
                      label: const Text('Load on Device'),
                    ),
                ],
                if (isDownloaded && model.backend == ModelBackend.local)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModelTestLab(model: model),
                        ),
                      );
                    },
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Test Lab'),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    tooltip: 'Delete from storage',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
