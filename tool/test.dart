import 'dart:io';

void main() async {
  print('Running tests via tool/test.dart...');
  final result = await Process.run('flutter', ['test']);
  print(result.stdout);
  print(result.stderr);
  exit(result.exitCode);
}
