import 'dart:math' as math;
import '../../../models/agent_models.dart';

/// Calculator tool for mathematical operations
class CalculatorTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'calculator',
        description:
            'Evaluate mathematical expressions. Supports basic arithmetic, trigonometry, logarithms, and more.',
        type: ToolType.calculator,
        parameters: {
          'expression': ParameterDefinition(
            type: 'string',
            description:
                'The mathematical expression to evaluate (e.g., "2 + 2", "sqrt(16)", "sin(pi/2)")',
            required: true,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final expression = args['expression'] as String;

    try {
      final result = _evaluate(expression);
      return 'Result: $expression = $result';
    } catch (e) {
      return 'Error evaluating "$expression": $e';
    }
  }

  static dynamic _evaluate(String expr) {
    // Clean up expression
    var clean = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('^', '**')
        .replaceAll('π', 'pi')
        .trim();

    // Handle common functions
    clean = clean
        .replaceAll('sqrt(', '_sqrt(')
        .replaceAll('sin(', '_sin(')
        .replaceAll('cos(', '_cos(')
        .replaceAll('tan(', '_tan(')
        .replaceAll('log(', '_log(')
        .replaceAll('ln(', '_ln(')
        .replaceAll('abs(', '_abs(')
        .replaceAll('pow(', '_pow(');

    // Parse and evaluate
    return _parseExpression(clean);
  }

  static double _parseExpression(String expr) {
    final tokens = _tokenize(expr);
    final parser = _Parser(tokens);
    return parser.parseExpression();
  }

  static List<_Token> _tokenize(String expr) {
    final tokens = <_Token>[];
    var i = 0;

    while (i < expr.length) {
      final c = expr[i];

      // Skip whitespace
      if (c == ' ') {
        i++;
        continue;
      }

      // Numbers
      if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57 || c == '.') {
        var numStr = '';
        while (i < expr.length &&
            (expr[i].codeUnitAt(0) >= 48 && expr[i].codeUnitAt(0) <= 57 ||
                expr[i] == '.')) {
          numStr += expr[i];
          i++;
        }
        tokens.add(_Token(_TokenType.number, double.parse(numStr)));
        continue;
      }

      // Constants
      if (expr.substring(i).startsWith('pi')) {
        tokens.add(_Token(_TokenType.number, math.pi));
        i += 2;
        continue;
      }
      if (expr.substring(i).startsWith('e') &&
          (i + 1 >= expr.length || expr[i + 1] != 'x')) {
        tokens.add(_Token(_TokenType.number, math.e));
        i++;
        continue;
      }

      // Functions
      if (expr.substring(i).startsWith('_sqrt(')) {
        tokens.add(_Token(_TokenType.function, 'sqrt'));
        i += 6;
        continue;
      }
      if (expr.substring(i).startsWith('_sin(')) {
        tokens.add(_Token(_TokenType.function, 'sin'));
        i += 5;
        continue;
      }
      if (expr.substring(i).startsWith('_cos(')) {
        tokens.add(_Token(_TokenType.function, 'cos'));
        i += 5;
        continue;
      }
      if (expr.substring(i).startsWith('_tan(')) {
        tokens.add(_Token(_TokenType.function, 'tan'));
        i += 5;
        continue;
      }
      if (expr.substring(i).startsWith('_log(')) {
        tokens.add(_Token(_TokenType.function, 'log'));
        i += 5;
        continue;
      }
      if (expr.substring(i).startsWith('_ln(')) {
        tokens.add(_Token(_TokenType.function, 'ln'));
        i += 4;
        continue;
      }
      if (expr.substring(i).startsWith('_abs(')) {
        tokens.add(_Token(_TokenType.function, 'abs'));
        i += 5;
        continue;
      }
      if (expr.substring(i).startsWith('_pow(')) {
        tokens.add(_Token(_TokenType.function, 'pow'));
        i += 5;
        continue;
      }

      // Operators
      if ('+-*/%'.contains(c)) {
        tokens.add(_Token(_TokenType.operator, c));
        i++;
        continue;
      }

      // Power operator
      if (expr.substring(i).startsWith('**')) {
        tokens.add(_Token(_TokenType.operator, '**'));
        i += 2;
        continue;
      }

      // Parentheses
      if (c == '(') {
        tokens.add(_Token(_TokenType.lparen, '('));
        i++;
        continue;
      }
      if (c == ')') {
        tokens.add(_Token(_TokenType.rparen, ')'));
        i++;
        continue;
      }

      throw Exception('Unexpected character: $c');
    }

    return tokens;
  }
}

enum _TokenType { number, operator, function, lparen, rparen }

class _Token {
  final _TokenType type;
  final dynamic value;
  _Token(this.type, this.value);
}

class _Parser {
  final List<_Token> tokens;
  int pos = 0;

  _Parser(this.tokens);

  double parseExpression() {
    var result = parseTerm();
    while (pos < tokens.length &&
        tokens[pos].type == _TokenType.operator &&
        (tokens[pos].value == '+' || tokens[pos].value == '-')) {
      final op = tokens[pos].value;
      pos++;
      final right = parseTerm();
      if (op == '+') {
        result += right;
      } else {
        result -= right;
      }
    }
    return result;
  }

  double parseTerm() {
    var result = parsePower();
    while (pos < tokens.length &&
        tokens[pos].type == _TokenType.operator &&
        (tokens[pos].value == '*' ||
            tokens[pos].value == '/' ||
            tokens[pos].value == '%')) {
      final op = tokens[pos].value;
      pos++;
      final right = parsePower();
      if (op == '*') {
        result *= right;
      } else if (op == '/') {
        if (right == 0) throw Exception('Division by zero');
        result /= right;
      } else {
        result %= right;
      }
    }
    return result;
  }

  double parsePower() {
    var result = parseUnary();
    while (pos < tokens.length &&
        tokens[pos].type == _TokenType.operator &&
        tokens[pos].value == '**') {
      pos++;
      final right = parseUnary();
      result = math.pow(result, right).toDouble();
    }
    return result;
  }

  double parseUnary() {
    if (pos < tokens.length &&
        tokens[pos].type == _TokenType.operator &&
        (tokens[pos].value == '+' || tokens[pos].value == '-')) {
      final op = tokens[pos].value;
      pos++;
      final value = parseUnary();
      return op == '-' ? -value : value;
    }
    return parsePrimary();
  }

  double parsePrimary() {
    if (pos >= tokens.length) {
      throw Exception('Unexpected end of expression');
    }

    final token = tokens[pos];

    // Function call
    if (token.type == _TokenType.function) {
      final func = token.value as String;
      pos++; // Skip function name
      if (pos < tokens.length && tokens[pos].type == _TokenType.lparen) {
        pos++; // Skip (
        final arg = parseExpression();
        if (pos < tokens.length && tokens[pos].type == _TokenType.rparen) {
          pos++; // Skip )
        }
        return _applyFunction(func, arg);
      }
    }

    // Number
    if (token.type == _TokenType.number) {
      pos++;
      return token.value as double;
    }

    // Parenthesized expression
    if (token.type == _TokenType.lparen) {
      pos++;
      final result = parseExpression();
      if (pos < tokens.length && tokens[pos].type == _TokenType.rparen) {
        pos++;
      }
      return result;
    }

    throw Exception('Unexpected token: ${token.value}');
  }

  double _applyFunction(String func, double arg) {
    switch (func) {
      case 'sqrt':
        return math.sqrt(arg);
      case 'sin':
        return math.sin(arg);
      case 'cos':
        return math.cos(arg);
      case 'tan':
        return math.tan(arg);
      case 'log':
        return math.log(arg) / math.ln10;
      case 'ln':
        return math.log(arg);
      case 'abs':
        return arg.abs();
      case 'pow':
        // For pow, we need a second argument
        if (pos < tokens.length && tokens[pos].value == ',') {
          pos++;
          final exp = parseExpression();
          if (pos < tokens.length && tokens[pos].type == _TokenType.rparen) {
            pos++;
          }
          return math.pow(arg, exp).toDouble();
        }
        return math.pow(arg, 2).toDouble();
      default:
        throw Exception('Unknown function: $func');
    }
  }
}

/// Unit converter tool
class UnitConverterTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'unit_converter',
        description:
            'Convert between different units of measurement (length, weight, temperature, etc.)',
        type: ToolType.unitConverter,
        parameters: {
          'value': ParameterDefinition(
            type: 'number',
            description: 'The value to convert',
            required: true,
          ),
          'from_unit': ParameterDefinition(
            type: 'string',
            description: 'The unit to convert from',
            required: true,
          ),
          'to_unit': ParameterDefinition(
            type: 'string',
            description: 'The unit to convert to',
            required: true,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final value = (args['value'] as num).toDouble();
    final fromUnit = (args['from_unit'] as String).toLowerCase();
    final toUnit = (args['to_unit'] as String).toLowerCase();

    try {
      final result = _convert(value, fromUnit, toUnit);
      return '$value $fromUnit = $result $toUnit';
    } catch (e) {
      return 'Conversion error: $e';
    }
  }

  static double _convert(double value, String from, String to) {
    // Temperature conversions
    if (from == 'celsius' || from == 'c') {
      if (to == 'fahrenheit' || to == 'f') return value * 9 / 5 + 32;
      if (to == 'kelvin' || to == 'k') return value + 273.15;
    }
    if (from == 'fahrenheit' || from == 'f') {
      if (to == 'celsius' || to == 'c') return (value - 32) * 5 / 9;
      if (to == 'kelvin' || to == 'k') return (value - 32) * 5 / 9 + 273.15;
    }
    if (from == 'kelvin' || from == 'k') {
      if (to == 'celsius' || to == 'c') return value - 273.15;
      if (to == 'fahrenheit' || to == 'f') return (value - 273.15) * 9 / 5 + 32;
    }

    // Length conversions (to meters, then to target)
    final lengthToMeter = {
      'meter': 1.0, 'm': 1.0, 'meters': 1.0,
      'kilometer': 1000.0, 'km': 1000.0,
      'centimeter': 0.01, 'cm': 0.01,
      'millimeter': 0.001, 'mm': 0.001,
      'mile': 1609.344, 'miles': 1609.344,
      'yard': 0.9144, 'yd': 0.9144,
      'foot': 0.3048, 'ft': 0.3048, 'feet': 0.3048,
      'inch': 0.0254, 'in': 0.0254, 'inches': 0.0254,
    };

    final lengthFactors = {...lengthToMeter};
    if (lengthFactors.containsKey(from) && lengthFactors.containsKey(to)) {
      final meters = value * lengthFactors[from]!;
      return meters / lengthFactors[to]!;
    }

    // Weight conversions (to grams, then to target)
    final weightToGram = {
      'gram': 1.0, 'g': 1.0, 'grams': 1.0,
      'kilogram': 1000.0, 'kg': 1000.0,
      'milligram': 0.001, 'mg': 0.001,
      'pound': 453.592, 'lb': 453.592, 'lbs': 453.592,
      'ounce': 28.3495, 'oz': 28.3495,
      'ton': 1000000.0, 'tonne': 1000000.0,
    };

    if (weightToGram.containsKey(from) && weightToGram.containsKey(to)) {
      final grams = value * weightToGram[from]!;
      return grams / weightToGram[to]!;
    }

    // Time conversions (to seconds)
    final timeToSecond = {
      'second': 1.0, 's': 1.0, 'seconds': 1.0,
      'minute': 60.0, 'min': 60.0, 'minutes': 60.0,
      'hour': 3600.0, 'h': 3600.0, 'hours': 3600.0,
      'day': 86400.0, 'days': 86400.0,
      'week': 604800.0, 'weeks': 604800.0,
      'year': 31536000.0, 'years': 31536000.0,
    };

    if (timeToSecond.containsKey(from) && timeToSecond.containsKey(to)) {
      final seconds = value * timeToSecond[from]!;
      return seconds / timeToSecond[to]!;
    }

    throw Exception('Cannot convert from $from to $to');
  }
}