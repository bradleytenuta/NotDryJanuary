// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print(
      'Error: coverage/lcov.info not found. Run tests with coverage first.',
    );
    exit(1);
  }

  int totalLF = 0;
  int totalLH = 0;

  final lines = file.readAsLinesSync();
  for (final line in lines) {
    if (line.startsWith('LF:')) {
      final value = int.tryParse(line.substring(3).trim());
      if (value != null) {
        totalLF += value;
      }
    } else if (line.startsWith('LH:')) {
      final value = int.tryParse(line.substring(3).trim());
      if (value != null) {
        totalLH += value;
      }
    }
  }

  if (totalLF == 0) {
    print('Error: No lines found in coverage report.');
    exit(1);
  }

  final coverage = (totalLH / totalLF) * 100;
  print('Total lines found (LF): $totalLF');
  print('Total lines hit (LH): $totalLH');
  print('Line Coverage: ${coverage.toStringAsFixed(2)}%');

  const targetCoverage = 80.0;
  if (coverage < targetCoverage) {
    print(
      'Error: Coverage ${coverage.toStringAsFixed(2)}% is below the required $targetCoverage%',
    );
    exit(1);
  }

  print('Success: Coverage check passed!');
}
