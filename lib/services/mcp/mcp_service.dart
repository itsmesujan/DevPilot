import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/agent_models.dart';
import '../agent/tools/tool_registry.dart';

/// Service to manage MCP (Model Context Protocol) external servers.
/// Connects via HTTP/SSE to remote MCP hubs (e.g. running on a developer's laptop)
/// and registers their tools dynamically into the local DevPilot ToolRegistry.
class McpService {
  McpService._();
  static final McpService instance = McpService._();

  final List<McpConnection> _connections = [];
  List<McpConnection> get connections => List.unmodifiable(_connections);

  Future<void> connectToServer(String name, String url) async {
    final connection = McpConnection(name: name, baseUrl: url);
    await connection.connect();
    _connections.add(connection);
    
    // Register tools discovered from this MCP server
    for (final tool in connection.tools) {
      ToolRegistry.instance.register(tool);
    }
  }

  Future<void> disconnectAll() async {
    for (final conn in _connections) {
      for (final tool in conn.tools) {
        ToolRegistry.instance.unregister(tool.name);
      }
    }
    _connections.clear();
  }
}

class McpConnection {
  final String name;
  final String baseUrl;
  bool isConnected = false;
  final List<ToolDefinition> tools = [];

  McpConnection({required this.name, required this.baseUrl});

  Future<void> connect() async {
    try {
      // 1. Fetch tool list from MCP server
      // Following a typical JSON-RPC over HTTP pattern for MCP:
      final uri = Uri.parse('$baseUrl/v1/tools/list');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'method': 'tools/list',
          'params': {}
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('MCP server returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final result = json['result'] as Map<String, dynamic>?;
      if (result == null || result['tools'] == null) {
        throw Exception('Invalid MCP response format');
      }

      final toolList = result['tools'] as List;
      for (final t in toolList) {
        tools.add(_parseMcpTool(t));
      }
      isConnected = true;
    } catch (e) {
      isConnected = false;
      throw Exception('Failed to connect to MCP server $name: $e');
    }
  }

  ToolDefinition _parseMcpTool(Map<String, dynamic> json) {
    final tName = json['name'] as String;
    final tDesc = json['description'] as String? ?? 'No description';
    
    final parameters = <String, ParameterDefinition>{};
    final inputSchema = json['inputSchema'] as Map<String, dynamic>?;
    
    if (inputSchema != null && inputSchema['properties'] != null) {
      final props = inputSchema['properties'] as Map<String, dynamic>;
      final requiredFields = (inputSchema['required'] as List?)?.cast<String>() ?? [];
      
      props.forEach((key, value) {
        parameters[key] = ParameterDefinition(
          type: value['type'] as String? ?? 'string',
          description: value['description'] as String? ?? '',
          required: requiredFields.contains(key),
        );
      });
    }

    return ToolDefinition(
      name: '${name}_$tName', // Prefix with server name to avoid collisions
      description: '[$name] $tDesc',
      type: ToolType.webSearch, // generic external type
      parameters: parameters,
      execute: (args) => _executeMcpTool(tName, args),
    );
  }

  Future<String> _executeMcpTool(String toolName, Map<String, dynamic> args) async {
    final uri = Uri.parse('$baseUrl/v1/tools/call');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'method': 'tools/call',
          'params': {
            'name': toolName,
            'arguments': args,
          }
        }),
      );

      final json = jsonDecode(response.body);
      if (json['error'] != null) {
        return 'MCP Error: ${json['error']}';
      }
      
      final result = json['result'] as Map<String, dynamic>;
      final contentList = result['content'] as List?;
      if (contentList != null && contentList.isNotEmpty) {
        // Typically MCP returns a list of content blocks
        return contentList.map((c) => c['text']).join('\n');
      }
      return 'Success (No output)';
    } catch (e) {
      return 'MCP Execution Error: $e';
    }
  }
}
