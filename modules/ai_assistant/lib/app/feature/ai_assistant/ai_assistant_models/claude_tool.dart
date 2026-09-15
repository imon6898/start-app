/// A tool definition sent in `tools[]`. Claude picks tools from the
/// description, so be prescriptive about WHEN to call it, not just what it does.
class ClaudeTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const ClaudeTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  /// Shorthand for the usual `{"type": "object", …}` schema.
  factory ClaudeTool.object({
    required String name,
    required String description,
    Map<String, dynamic> properties = const {},
    List<String> required = const [],
  }) => ClaudeTool(
    name: name,
    description: description,
    inputSchema: {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    },
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'input_schema': inputSchema,
  };
}

/// Executes one tool call. Return a String, or anything `jsonEncode` accepts.
/// Throwing is fine — the runner converts it to an `is_error` tool_result.
typedef ClaudeToolHandler = Future<Object?> Function(Map<String, dynamic> input);
