import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage/storage_service.dart';
import '../services/ai/download_manager.dart';
import '../services/agent/agent_orchestrator.dart';
import '../services/workflow/workflow_executor.dart';

final storageProvider = Provider<StorageService>((ref) => StorageService.instance);
final downloadManagerProvider = Provider<DownloadManager>((ref) => DownloadManager.instance);
final agentOrchestratorProvider = Provider<AgentOrchestrator>((ref) => AgentOrchestrator.instance);
final workflowExecutorProvider = Provider<WorkflowExecutor>((ref) => WorkflowExecutor.instance);
