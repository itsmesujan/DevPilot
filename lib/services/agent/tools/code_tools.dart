import 'dart:io';
import '../../../models/agent_models.dart';
import 'tool_registry.dart';

class CodeTools {
  static void registerAll() {
    final registry = ToolRegistry.instance;
    registry.register(_dartAnalyzeTool);
    registry.register(_flutterTestTool);
    registry.register(_grepCodeTool);
  }

  static final ToolDefinition _dartAnalyzeTool = ToolDefinition(
    name: 'dart_analyze',
    description: 'Runs flutter analyze or dart analyze on a project directory',
    type: ToolType.codeRunner,
    parameters: {
      'dir': ParameterDefinition(
        type: 'string',
        description: 'Directory of the flutter/dart project',
      ),
    },
    execute: (args) async {
      final dir = args['dir'] as String;
      try {
        final result = await Process.run('flutter', ['analyze'], workingDirectory: dir);
        if (result.exitCode == 0) return 'No issues found:\n${result.stdout}';
        return 'Issues found:\n${result.stdout}\n${result.stderr}';
      } catch (e) {
        return 'Error running analyze: $e';
      }
    },
  );

  static final ToolDefinition _flutterTestTool = ToolDefinition(
    name: 'flutter_test',
    description: 'Runs flutter test in a project directory',
    type: ToolType.codeRunner,
    parameters: {
      'dir': ParameterDefinition(
        type: 'string',
        description: 'Directory of the flutter project',
      ),
    },
    execute: (args) async {
      final dir = args['dir'] as String;
      try {
        final result = await Process.run('flutter', ['test'], workingDirectory: dir);
        if (result.exitCode == 0) return 'Tests passed:\n${result.stdout}';
        return 'Tests failed:\n${result.stdout}\n${result.stderr}';
      } catch (e) {
        return 'Error running tests: $e';
      }
    },
  );

  static final ToolDefinition _grepCodeTool = ToolDefinition(
    name: 'grep_code',
    description: 'Searches for a text pattern in files (like grep -r)',
    type: ToolType.codeRunner,
    parameters: {
      'pattern': ParameterDefinition(
        type: 'string',
        description: 'Text pattern to search for',
      ),
      'dir': ParameterDefinition(
        type: 'string',
        description: 'Directory to search in',
      ),
    },
    execute: (args) async {
      final pattern = args['pattern'] as String;
      final dirPath = args['dir'] as String;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 'Error: Directory not found';
      
      final buffer = StringBuffer();
      int count = 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File && (e.path.endsWith('.dart') || e.path.endsWith('.md') || e.path.endsWith('.yaml'))) {
          try {
            final lines = await e.readAsLines();
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].contains(pattern)) {
                buffer.writeln('${e.path}:${i + 1}: ${lines[i].trim()}');
                count++;
                if (count >= 50) {
                  buffer.writeln('... too many results, truncating to 50.');
                  return buffer.toString();
                }
              }
            }
          } catch (_) {
            // ignore binary files or encoding errors
          }
        }
      }
      return buffer.isEmpty ? 'No matches found.' : buffer.toString();
    },
  );
}
