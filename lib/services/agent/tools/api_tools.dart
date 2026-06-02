import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/agent_models.dart';
import 'tool_registry.dart';

class ApiTools {
  static void registerAll() {
    final registry = ToolRegistry.instance;
    registry.register(_restGetTool);
    registry.register(_restPostTool);
  }

  static final ToolDefinition _restGetTool = ToolDefinition(
    name: 'rest_get',
    description: 'Performs a GET request to a REST API',
    type: ToolType.urlReader,
    parameters: {
      'url': ParameterDefinition(
        type: 'string',
        description: 'The URL to make the GET request to',
      ),
      'headers': ParameterDefinition(
        type: 'string',
        description: 'Optional JSON string of headers to include',
        required: false,
      ),
    },
    execute: (args) async {
      final url = args['url'] as String;
      final headersStr = args['headers'] as String?;
      
      Map<String, String>? headers;
      if (headersStr != null && headersStr.isNotEmpty) {
        try {
          headers = Map<String, String>.from(jsonDecode(headersStr));
        } catch (_) {}
      }

      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        return 'Status: ${response.statusCode}\nBody:\n${response.body}';
      } catch (e) {
        return 'Error during GET request: $e';
      }
    },
  );

  static final ToolDefinition _restPostTool = ToolDefinition(
    name: 'rest_post',
    description: 'Performs a POST request to a REST API',
    type: ToolType.urlReader,
    parameters: {
      'url': ParameterDefinition(
        type: 'string',
        description: 'The URL to make the POST request to',
      ),
      'body': ParameterDefinition(
        type: 'string',
        description: 'The body of the POST request (usually JSON)',
      ),
      'headers': ParameterDefinition(
        type: 'string',
        description: 'Optional JSON string of headers to include',
        required: false,
      ),
    },
    execute: (args) async {
      final url = args['url'] as String;
      final body = args['body'] as String;
      final headersStr = args['headers'] as String?;
      
      Map<String, String>? headers;
      if (headersStr != null && headersStr.isNotEmpty) {
        try {
          headers = Map<String, String>.from(jsonDecode(headersStr));
        } catch (_) {}
      }

      try {
        final response = await http.post(Uri.parse(url), headers: headers, body: body);
        return 'Status: ${response.statusCode}\nBody:\n${response.body}';
      } catch (e) {
        return 'Error during POST request: $e';
      }
    },
  );
}
