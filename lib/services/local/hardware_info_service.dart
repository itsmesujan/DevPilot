import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_llm_service.dart';

class SystemHardwareInfo {
  final String platformName;
  final int cpuCores;
  final double estimatedRamGb;
  final String gpuName;
  final bool isGpuAccelerated;

  SystemHardwareInfo({
    required this.platformName,
    required this.cpuCores,
    required this.estimatedRamGb,
    required this.gpuName,
    required this.isGpuAccelerated,
  });

  String get tier {
    if (estimatedRamGb >= 12 && cpuCores >= 8) return 'Ultra';
    if (estimatedRamGb >= 8 && cpuCores >= 6) return 'High-End';
    if (estimatedRamGb >= 4 && cpuCores >= 4) return 'Mid-Range';
    return 'Low-End';
  }
}

class HardwareInfoService {
  HardwareInfoService._();
  static final HardwareInfoService instance = HardwareInfoService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<SystemHardwareInfo> getHardwareInfo() async {
    String platform = 'Unknown';
    double ram = 4.0; // fallback
    String gpu = 'Software Renderer';
    bool hasGpu = false;

    final cpuCores = Platform.numberOfProcessors;

    if (kIsWeb) {
      platform = 'Web Browser';
      ram = 4.0;
      gpu = 'WebGL Canvas';
    } else if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        platform = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
        
        // Estimate RAM based on model or hardware config if possible, 
        // otherwise default to a reasonable baseline based on CPU cores
        if (cpuCores >= 8) {
          ram = 6.0;
        } else if (cpuCores >= 6) {
          ram = 4.0;
        } else {
          ram = 3.0;
        }
        
        // Check local llama controller GPU info if available
        final gpuInfo = await LocalLlmService.instance.detectGpu();
        if (gpuInfo != null) {
          gpu = gpuInfo.gpuName ?? 'Adreno/Mali GPU';
          hasGpu = gpuInfo.vulkanSupported ?? false;
        } else {
          gpu = 'Mobile GPU (Vulkan/GLES)';
        }
      } catch (_) {}
    } else if (Platform.isIOS) {
      try {
        final iosInfo = await _deviceInfo.iosInfo;
        platform = 'iOS ${iosInfo.systemVersion} (${iosInfo.name})';
        ram = cpuCores >= 6 ? 6.0 : 4.0;
        gpu = 'Apple GPU (Metal)';
        hasGpu = true;
      } catch (_) {}
    } else if (Platform.isWindows) {
      platform = 'Windows PC';
      ram = 16.0; // standard desktop baseline
      gpu = 'DirectX GPU';
      hasGpu = true;
    } else if (Platform.isMacOS) {
      platform = 'macOS Desktop';
      ram = 8.0;
      gpu = 'Apple Silicon (Metal)';
      hasGpu = true;
    } else if (Platform.isLinux) {
      platform = 'Linux Desktop';
      ram = 8.0;
      gpu = 'OpenGL GPU';
      hasGpu = true;
    }

    return SystemHardwareInfo(
      platformName: platform,
      cpuCores: cpuCores,
      estimatedRamGb: ram,
      gpuName: gpu,
      isGpuAccelerated: hasGpu,
    );
  }

  String getCompatibilityMessage(SystemHardwareInfo info, int? minRamMb) {
    if (minRamMb == null) return 'Compatible';
    final minRamGb = minRamMb / 1024.0;
    if (info.estimatedRamGb >= minRamGb) {
      if (info.estimatedRamGb >= minRamGb + 2) {
        return 'Optimized';
      }
      return 'Compatible';
    } else if (info.estimatedRamGb >= minRamGb - 1) {
      return 'Runs slowly (Low memory)';
    } else {
      return 'Not Recommended';
    }
  }
}
