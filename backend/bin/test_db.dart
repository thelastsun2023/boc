import 'package:postgres/postgres.dart';

void main() async {
  try {
    var conn = await Connection.open(
      Endpoint(
        host: 'localhost',
        port: 5432,
        database: 'postgres',
        username: 'postgres',
        password: 'postgres',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    print('Connected successfully');

    // Test query
    final result = await conn.execute('SELECT version()');
    print('Database version: ${result.first.first}');

    await conn.close();
  } catch (e) {
    print('Connection failed: $e');
  }
}