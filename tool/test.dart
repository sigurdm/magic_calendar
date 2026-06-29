import 'dart:io';

void main() async {
  final result = await Process.run('flutter', ['test']);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
