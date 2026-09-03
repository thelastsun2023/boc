import 'dart:io';

import 'package:postgres/postgres.dart';

void main() async {
  String requiredEnv(String key) {
    final value = Platform.environment[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }

  final conn = await Connection.open(
    Endpoint(
      host: requiredEnv('DB_HOST'),
      port: int.parse(requiredEnv('DB_PORT')),
      database: requiredEnv('DB_NAME'),
      username: requiredEnv('DB_USERNAME'),
      password: requiredEnv('DB_PASSWORD'),
    ),
    settings: ConnectionSettings(
      sslMode: requiredEnv('DB_SSL_MODE') == 'disable'
          ? SslMode.disable
          : SslMode.require,
    ),
  );

  final result = await conn.execute('SELECT username, role FROM users');
  print('Users in database:');
  for (final row in result) {
    print('  ${row[0]} - ${row[1]}');
  }

  await conn.close();
}
