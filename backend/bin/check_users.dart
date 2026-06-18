import 'package:postgres/postgres.dart';

void main() async {
  final conn = await Connection.open(
    Endpoint(
      host: 'bocpostgre-thelastsun2023-2f01.a.aivencloud.com',
      port: 26562,
      database: 'defaultdb',
      username: 'avnadmin',
      password: 'AVNS_xCsi_qv4XVNgtB59qVt',
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.require,
    ),
  );

  final result = await conn.execute('SELECT username, password, role FROM users');
  print('Users in database:');
  for (final row in result) {
    print('  ${row[0]} - ${row[1]} - ${row[2]}');
  }

  await conn.close();
}