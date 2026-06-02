import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../models/agent_models.dart';
import 'tool_registry.dart';

class FileTools {
  static void registerAll() {
    final registry = ToolRegistry.instance;
    registry.register(_readFileTool);
    registry.register(_writeFileTool);
    registry.register(_listDirTool);
    registry.register(_searchFilesTool);
  }

  static final ToolDefinition _readFileTool = ToolDefinition(
    name: 'read_file',
    description: 'Reads the content of a local file',
    type: ToolType.fileBrowser,
    parameters: {
      'path': ParameterDefinition(
        type: 'string',
        description: 'Absolute or relative path to the file',
      ),
    },
    execute: (args) async {
      final path = args['path'] as String;
      final file = File(path);
      if (!await file.exists()) return 'Error: File not found at $path';
      return await file.readAsString();
    },
  );

  static final ToolDefinition _writeFileTool = ToolDefinition(
    name: 'write_file',
    description: 'Writes text to a local file, creating directories if needed',
    type: ToolType.fileBrowser,
    parameters: {
      'path': ParameterDefinition(
        type: 'string',
        description: 'Path to write to',
      ),
      'content': ParameterDefinition(
        type: 'string',
        description: 'Content to write',
      ),
    },
    execute: (args) async {
      final path = args['path'] as String;
      final content = args['content'] as String;
      final file = File(path);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(content);
      return 'File written successfully to $path';
    },
  );

  static final ToolDefinition _listDirTool = ToolDefinition(
    name: 'list_directory',
    description: 'Lists contents of a directory',
    type: ToolType.fileBrowser,
    parameters: {
      'path': ParameterDefinition(
        type: 'string',
        description: 'Path to the directory',
      ),
    },
    execute: (args) async {
      final path = args['path'] as String;
      final dir = Directory(path);
      if (!await dir.exists()) return 'Error: Directory not found';
      final entities = await dir.list().toList();
      final buffer = StringBuffer();
      for (final e in entities) {
        final name = p.basename(e.path);
        buffer.writeln(e is Directory ? 'DIR  $name' : 'FILE $name');
      }
      return buffer.isEmpty ? 'Directory is empty' : buffer.toString();
    },
  );

  static final ToolDefinition _searchFilesTool = ToolDefinition(
    name: 'search_files',
    description: 'Searches for files containing a query in their filename',
    type: ToolType.fileBrowser,
    parameters: {
      'query': ParameterDefinition(
        type: 'string',
        description: 'Text to search for in filenames',
      ),
      'dir': ParameterDefinition(
        type: 'string',
        description: 'Directory to search in',
      ),
    },
    execute: (args) async {
      final query = args['query'] as String;
      final dirPath = args['dir'] as String;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 'Error: Directory not found';
      
      final results = <String>[];
      await for (final e in dir.list(recursive: true)) {
        if (e is File && p.basename(e.path).contains(query)) {
          results.add(e.path);
        }
      }
      return results.isEmpty ? 'No files found matching "$query"' : results.join('\n');
    },
  );
}
