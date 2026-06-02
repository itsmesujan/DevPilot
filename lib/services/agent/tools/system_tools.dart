import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../../models/agent_models.dart';
import 'tool_registry.dart';

class SystemTools {
  static void registerAll() {
    final registry = ToolRegistry.instance;
    registry.register(_runShellTool);
    registry.register(_getDeviceInfoTool);
    registry.register(_checkBatteryTool);
  }

  static final ToolDefinition _runShellTool = ToolDefinition(
    name: 'run_shell',
    description: 'Runs a shell command',
    type: ToolType.codeRunner,
    parameters: {
      'command': ParameterDefinition(
        type: 'string',
        description: 'The shell command to run',
      ),
    },
    execute: (args) async {
      final command = args['command'] as String;
      try {
        final parts = command.split(' ');
        final result = await Process.run(parts.first, parts.sublist(1));
        return 'Exit code: ${result.exitCode}\nStdout: ${result.stdout}\nStderr: ${result.stderr}';
      } catch (e) {
        return 'Error running shell command: $e';
      }
    },
  );

  static final ToolDefinition _getDeviceInfoTool = ToolDefinition(
    name: 'get_device_info',
    description: 'Retrieves information about the device running DevPilot',
    type: ToolType.deviceInfo,
    parameters: {},
    execute: (args) async {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return 'Android ${info.version.release} (SDK ${info.version.sdkInt}), Device: ${info.model}, Manufacturer: ${info.manufacturer}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return 'iOS ${info.systemVersion}, Device: ${info.name}, Model: ${info.model}';
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return 'Windows OS, Computer Name: ${info.computerName}';
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        return 'macOS ${info.osRelease}, Computer Name: ${info.computerName}';
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        return 'Linux ${info.prettyName}';
      }
      return 'Unknown Platform';
    },
  );

  static final ToolDefinition _checkBatteryTool = ToolDefinition(
    name: 'check_battery',
    description: 'Checks the current battery level and state of the device',
    type: ToolType.deviceInfo,
    parameters: {},
    execute: (args) async {
      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      return 'Battery Level: $level%\nState: ${state.name}';
    },
  );
}
