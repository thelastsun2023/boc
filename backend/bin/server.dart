import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';

// PostgreSQL connection
late Connection _conn;
final Directory _uploadImagesDir = Directory.fromUri(
  File.fromUri(Platform.script)
      .parent
      .parent
      .parent
      .uri
      .resolve('UPLOAD/IMAGES/'),
);

final Directory _webBuildDir = Directory.fromUri(
  File.fromUri(Platform.script).parent.parent.parent.uri.resolve('build/web/'),
);

Handler _createWebHandler() {
  late final Directory webDir;

  if (_webBuildDir.existsSync()) {
    webDir = _webBuildDir;
    print('Serving web assets from ${webDir.path}');
  } else {
    return (Request request) => Response.notFound(
          jsonEncode({
            'error': 'Web assets not found',
            'hint': 'Run "flutter build web" and ensure build/web exists.',
          }),
          headers: {'Content-Type': 'application/json'},
        );
  }

  final staticHandler = createStaticHandler(
    webDir.path,
    defaultDocument: 'index.html',
    serveFilesOutsidePath: true,
  );

  return (Request request) async {
    final path = request.url.path;
    if (path.startsWith('api/') || path.startsWith('uploads/')) {
      return Response.notFound('Not Found');
    }

    final response = await staticHandler(request);

    // SPA fallback: unknown path without file extension returns index.html.
    if (response.statusCode == 404 && !path.contains('.')) {
      return staticHandler(request.change(path: 'index.html'));
    }

    return response;
  };
}

Map<String, String> _loadFileConfig() {
  final backendDir = File.fromUri(Platform.script).parent.parent;
  final rootDir = backendDir.parent;
  final candidates = <File>[
    File.fromUri(backendDir.uri.resolve('.env')),
    File.fromUri(rootDir.uri.resolve('.env')),
  ];

  for (final file in candidates) {
    if (!file.existsSync()) {
      continue;
    }

    final map = <String, String>{};
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final sep = line.indexOf('=');
      if (sep <= 0) {
        continue;
      }

      final key = line.substring(0, sep).trim();
      var value = line.substring(sep + 1).trim();

      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      map[key] = value;
    }

    print('Loaded config from ${file.path}');
    return map;
  }

  return <String, String>{};
}

final Map<String, String> _fileConfig = _loadFileConfig();

String? _getConfig(String key) {
  final envValue = Platform.environment[key];
  if (envValue != null && envValue.isNotEmpty) {
    return envValue;
  }

  final fileValue = _fileConfig[key];
  if (fileValue != null && fileValue.isNotEmpty) {
    return fileValue;
  }

  return null;
}

// Database initialization
Future<void> initDb() async {
  await _uploadImagesDir.create(recursive: true);

  // Read config from env vars first, then .env file, then defaults
  final dbHost = _getConfig('DB_HOST') ?? 'localhost';
  final dbPort = int.tryParse(_getConfig('DB_PORT') ?? '5432') ?? 5432;
  final dbName = _getConfig('DB_NAME') ?? 'postgres';
  final dbUsername = _getConfig('DB_USERNAME') ?? 'postgres';
  final dbPassword = _getConfig('DB_PASSWORD') ?? 'postgres';
  final sslModeStr = _getConfig('DB_SSL_MODE') ?? 'disable';
  final sslCaPath = _getConfig('DB_SSL_CA_PATH');

  // Parse SSL mode
  SslMode sslMode;
  switch (sslModeStr.toLowerCase()) {
    case 'require':
    case 'prefer':
      sslMode = SslMode.require;
      break;
    case 'verify-full':
    case 'verifyfull':
      sslMode = SslMode.verifyFull;
      break;
    default:
      sslMode = SslMode.disable;
  }

  SecurityContext? securityContext;
  if (sslCaPath != null && sslCaPath.trim().isNotEmpty) {
    final caFile = File(sslCaPath.trim());
    if (!caFile.existsSync()) {
      throw Exception('DB_SSL_CA_PATH file not found: ${caFile.path}');
    }
    securityContext = SecurityContext(withTrustedRoots: true);
    securityContext.setTrustedCertificates(caFile.path);
  }

  _conn = await Connection.open(
    Endpoint(
      host: dbHost,
      port: dbPort,
      database: dbName,
      username: dbUsername,
      password: dbPassword,
    ),
    settings: ConnectionSettings(
      sslMode: sslMode,
      securityContext: securityContext,
    ),
  );

  // Create users table if not exists
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(255) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      role VARCHAR(50) NOT NULL DEFAULT 'USER',
      store_code VARCHAR(50),
      ui_language VARCHAR(10) NOT NULL DEFAULT 'ZH'
    )
  ''');
  await _conn.execute(
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS store_code VARCHAR(50)',
  );
  await _conn.execute(
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS ui_language VARCHAR(10) NOT NULL DEFAULT 'ZH'",
  );
  // Create raw_materials table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS raw_materials (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      specification VARCHAR(255),
      image_path VARCHAR(255),
      primary_supplier_code VARCHAR(50),
      secondary_supplier_code VARCHAR(50),
      category_code VARCHAR(50),
      location_code VARCHAR(50),
      min_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS specification VARCHAR(255)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS image_path VARCHAR(255)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS primary_supplier_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS secondary_supplier_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS category_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS location_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS min_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0',
  );

  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS raw_material_categories (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name VARCHAR(255) UNIQUE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS raw_material_locations (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name VARCHAR(255) UNIQUE NOT NULL,
      note TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS user_raw_material_category_permissions (
      user_id INTEGER NOT NULL,
      category_code VARCHAR(50) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, category_code),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (category_code) REFERENCES raw_material_categories(code) ON DELETE CASCADE
    )
  ''');

  // Create suppliers table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS suppliers (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name VARCHAR(255) NOT NULL,
      alias VARCHAR(255),
      address VARCHAR(255),
      contact VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Create units table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS units (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS regions (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      note TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    'ALTER TABLE regions ADD COLUMN IF NOT EXISTS name_en VARCHAR(255)',
  );
  await _conn.execute(
    'ALTER TABLE regions ADD COLUMN IF NOT EXISTS note TEXT',
  );
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS stores (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name VARCHAR(255) NOT NULL,
      note TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    'ALTER TABLE stores ADD COLUMN IF NOT EXISTS note TEXT',
  );
  final storeCountRes = await _conn.execute('SELECT COUNT(*) FROM stores');
  final storeCount = storeCountRes.first[0] as int;
  if (storeCount == 0) {
    await _conn.execute(
      'INSERT INTO stores (code, name, note) VALUES (\$1, \$2, \$3)',
      parameters: ['S001', '默认门店', '系统初始化门店'],
    );
  }

  // Create semi_products table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS semi_products (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      category_code VARCHAR(50),
      description TEXT,
      raw_material_codes TEXT[] DEFAULT ARRAY[]::TEXT[],
      tool_codes TEXT[] DEFAULT ARRAY[]::TEXT[],
      steps TEXT[] DEFAULT ARRAY[]::TEXT[],
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS category_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS description TEXT',
  );
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS raw_material_codes TEXT[] DEFAULT ARRAY[]::TEXT[]',
  );
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS tool_codes TEXT[] DEFAULT ARRAY[]::TEXT[]',
  );
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS steps TEXT[] DEFAULT ARRAY[]::TEXT[]',
  );
  await _conn.execute(
    'ALTER TABLE semi_products ADD COLUMN IF NOT EXISTS image_path VARCHAR(255)',
  );
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS semi_product_stock_checks (
      id SERIAL PRIMARY KEY,
      semi_product_code VARCHAR(50) NOT NULL,
      region_code VARCHAR(50) NOT NULL,
      store_code VARCHAR(50),
      weekday_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
      weekend_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
      holiday_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (semi_product_code, region_code)
    )
  ''');
  await _conn.execute(
    'ALTER TABLE semi_product_stock_checks ADD COLUMN IF NOT EXISTS weekday_stock NUMERIC(12, 2) NOT NULL DEFAULT 0',
  );
  await _conn.execute(
    'ALTER TABLE semi_product_stock_checks ADD COLUMN IF NOT EXISTS weekend_stock NUMERIC(12, 2) NOT NULL DEFAULT 0',
  );
  await _conn.execute(
    'ALTER TABLE semi_product_stock_checks ADD COLUMN IF NOT EXISTS holiday_stock NUMERIC(12, 2) NOT NULL DEFAULT 0',
  );
  await _conn.execute(
    'ALTER TABLE semi_product_stock_checks ADD COLUMN IF NOT EXISTS store_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE semi_product_stock_checks DROP CONSTRAINT IF EXISTS semi_product_stock_checks_semi_product_code_region_code_key',
  );
  await _conn.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS semi_product_stock_checks_store_unique_idx ON semi_product_stock_checks (semi_product_code, region_code, COALESCE(store_code, \'\'))',
  );
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS semi_product_categories (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) UNIQUE NOT NULL,
      name_en VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    'ALTER TABLE semi_product_categories ADD COLUMN IF NOT EXISTS name_en VARCHAR(255)',
  );

  // Create finance_records table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS finance_records (
      id SERIAL PRIMARY KEY,
      type VARCHAR(20) NOT NULL,
      record_date DATE NOT NULL,
      amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
      note TEXT,
      image_path VARCHAR(255),
      store_code VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    "ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS type VARCHAR(20) NOT NULL DEFAULT '收入'",
  );
  await _conn.execute(
    'ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS record_date DATE NOT NULL DEFAULT CURRENT_DATE',
  );
  await _conn.execute(
    'ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS amount NUMERIC(12, 2) NOT NULL DEFAULT 0',
  );
  await _conn.execute(
    'ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS note TEXT',
  );
  await _conn.execute(
    'ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS image_path VARCHAR(255)',
  );
  await _conn.execute(
    'ALTER TABLE finance_records ADD COLUMN IF NOT EXISTS store_code VARCHAR(50)',
  );

  // Create todo_tasks table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS todo_tasks (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      content TEXT,
      note TEXT,
      due_date_time TIMESTAMP NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT '未做完',
      stock_order_id INTEGER,
      supplier_code VARCHAR(50),
      task_type VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    "ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS title VARCHAR(255) NOT NULL DEFAULT ''",
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS content TEXT',
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS note TEXT',
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS due_date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
  );
  await _conn.execute(
    "ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT '未做完'",
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS owner_username VARCHAR(255)',
  );
  await _conn.execute(
    "UPDATE todo_tasks SET owner_username = 'admin' WHERE owner_username IS NULL OR TRIM(owner_username) = ''",
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS stock_order_id INTEGER',
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS supplier_code VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS task_type VARCHAR(50)',
  );
  await _conn.execute(
    'ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS store_code VARCHAR(50)',
  );

  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS stock_orders (
      id SERIAL PRIMARY KEY,
      order_date DATE NOT NULL,
      details TEXT NOT NULL,
      owner_username VARCHAR(255),
      store_code VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _conn.execute(
    "ALTER TABLE stock_orders ADD COLUMN IF NOT EXISTS order_date DATE NOT NULL DEFAULT CURRENT_DATE",
  );
  await _conn.execute(
    "ALTER TABLE stock_orders ADD COLUMN IF NOT EXISTS details TEXT NOT NULL DEFAULT '[]'",
  );
  await _conn.execute(
    'ALTER TABLE stock_orders ADD COLUMN IF NOT EXISTS is_confirmed BOOLEAN NOT NULL DEFAULT FALSE',
  );
  await _conn.execute(
    'ALTER TABLE stock_orders ADD COLUMN IF NOT EXISTS owner_username VARCHAR(255)',
  );
  await _conn.execute(
    'ALTER TABLE stock_orders ADD COLUMN IF NOT EXISTS store_code VARCHAR(50)',
  );

  // Create kitchen_tools table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS kitchen_tools (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      image_data BYTEA,
      image_path VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _conn.execute(
    'ALTER TABLE kitchen_tools ADD COLUMN IF NOT EXISTS image_path VARCHAR(255)',
  );

  // Create processes table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS processes (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      tool_codes TEXT[],
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Create tools table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS tools (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      image_path VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Create menu_categories table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS menu_categories (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Create menus table
  await _conn.execute('''
    CREATE TABLE IF NOT EXISTS menus (
      id SERIAL PRIMARY KEY,
      code VARCHAR(50) UNIQUE NOT NULL,
      name_cn VARCHAR(255) NOT NULL,
      name_en VARCHAR(255),
      category_code VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (category_code) REFERENCES menu_categories(code) ON DELETE SET NULL
    )
  ''');

  // Seed or synchronize admin user to lowercase credentials
  final hashedPw = sha256.convert(utf8.encode('admin')).toString();
  final res = await _conn.execute(
    'SELECT id, username FROM users WHERE LOWER(username) = LOWER(\$1)',
    parameters: ['admin'],
  );
  if (res.isEmpty) {
    await _conn.execute(
      'INSERT INTO users (username, password, role, store_code, ui_language) VALUES (\$1, \$2, \$3, \$4, \$5)',
      parameters: ['admin', hashedPw, 'ADMIN', null, 'ZH'],
    );
    print('Admin user created: admin/admin');
  } else {
    final userId = res.first[0] as int;
    await _conn.execute(
      'UPDATE users SET username = \$1, password = \$2, role = \$3, store_code = \$4, ui_language = \$5 WHERE id = \$6',
      parameters: ['admin', hashedPw, 'ADMIN', null, 'ZH', userId],
    );
    print('Existing admin user synchronized to admin/admin');
  }
}

class _UserScope {
  const _UserScope({
    required this.username,
    required this.role,
    required this.storeCode,
  });

  final String username;
  final String role;
  final String? storeCode;

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
}

String? _normalizedStoreCode(dynamic value) {
  final normalized = _normalizedOptionalString(value);
  if (normalized == null) {
    return null;
  }
  return normalized.toUpperCase();
}

String _normalizedUiLanguage(dynamic value) {
  final text = _normalizedOptionalString(value)?.toUpperCase();
  if (text == 'EN') {
    return 'EN';
  }
  return 'ZH';
}

Future<_UserScope?> _getUserScopeByUsername(String? username) async {
  final normalizedUsername = _normalizedOptionalString(username);
  if (normalizedUsername == null) {
    return null;
  }

  final result = await _conn.execute(
    '''
    SELECT username, role, store_code
    FROM users
    WHERE LOWER(username) = LOWER(\$1)
    LIMIT 1
    ''',
    parameters: [normalizedUsername],
  );
  if (result.isEmpty) {
    return null;
  }

  return _UserScope(
    username: result.first[0] as String? ?? normalizedUsername,
    role: result.first[1] as String? ?? 'USER',
    storeCode: _normalizedStoreCode(result.first[2]),
  );
}

bool _canAccessStoreScopedRecord(
  _UserScope scope,
  String? recordStoreCode,
  String? recordOwnerUsername,
) {
  if (scope.isAdmin) {
    return true;
  }

  final normalizedRecordStore = _normalizedStoreCode(recordStoreCode);
  if (scope.storeCode != null && scope.storeCode!.isNotEmpty) {
    return normalizedRecordStore == scope.storeCode;
  }

  return (recordOwnerUsername ?? '').toLowerCase() ==
      scope.username.toLowerCase();
}

// CORS middleware with proper OPTIONS handling
Middleware corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-File-Name',
  };

  return (innerHandler) {
    return (request) async {
      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {...corsHeaders, 'Access-Control-Max-Age': '3600'},
        );
      }

      // Handle actual requests and ensure CORS headers are always present,
      // even if the inner handler throws an exception.
      try {
        final response = await innerHandler(request);
        return response.change(headers: corsHeaders);
      } catch (e, st) {
        // Log error and return 500 with CORS headers so browser receives them
        print('Handler error: $e\n$st');
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json', ...corsHeaders},
        );
      }
    };
  };
}

// Routes
final _router = Router()
  ..post('/api/login', _login)
  ..post('/api/register', _register)
  ..get('/api/users', _getUsers)
  ..put('/api/users/<username>', _updateUser)
  ..delete('/api/users/<username>', _deleteUser)
  ..get('/api/test', _test)
  ..post('/api/uploads/images', _uploadImage)
  ..get('/uploads/images/<fileName>', _serveUploadedImage)
  // Raw Material Categories
  ..post('/api/raw-material-categories', _addRawMaterialCategory)
  ..get('/api/raw-material-categories', _getRawMaterialCategories)
  ..put('/api/raw-material-categories/<code>', _updateRawMaterialCategory)
  ..delete('/api/raw-material-categories/<code>', _deleteRawMaterialCategory)
  // Raw Material Locations
  ..post('/api/raw-material-locations', _addRawMaterialLocation)
  ..get('/api/raw-material-locations', _getRawMaterialLocations)
  ..put('/api/raw-material-locations/<code>', _updateRawMaterialLocation)
  ..delete('/api/raw-material-locations/<code>', _deleteRawMaterialLocation)
  // Raw Materials
  ..post('/api/raw-materials', _addRawMaterial)
  ..get('/api/raw-materials', _getRawMaterials)
  ..put('/api/raw-materials/<code>', _updateRawMaterial)
  ..delete('/api/raw-materials/<code>', _deleteRawMaterial)
  // Suppliers
  ..post('/api/suppliers', _addSupplier)
  ..get('/api/suppliers', _getSuppliers)
  ..put('/api/suppliers/<code>', _updateSupplier)
  ..delete('/api/suppliers/<code>', _deleteSupplier)
  // Units
  ..post('/api/units', _addUnit)
  ..get('/api/units', _getUnits)
  ..put('/api/units/<code>', _updateUnit)
  ..delete('/api/units/<code>', _deleteUnit)
  // Regions
  ..post('/api/regions', _addRegion)
  ..get('/api/regions', _getRegions)
  ..put('/api/regions/<code>', _updateRegion)
  ..delete('/api/regions/<code>', _deleteRegion)
  // Stores
  ..post('/api/stores', _addStore)
  ..get('/api/stores', _getStores)
  ..put('/api/stores/<code>', _updateStore)
  ..delete('/api/stores/<code>', _deleteStore)
  // Semi Products
  ..post('/api/semi-products', _addSemiProduct)
  ..get('/api/semi-products', _getSemiProducts)
  ..put('/api/semi-products/<code>', _updateSemiProduct)
  ..delete('/api/semi-products/<code>', _deleteSemiProduct)
  ..post('/api/semi-product-stock-checks', _addSemiProductStockCheck)
  ..get('/api/semi-product-stock-checks', _getSemiProductStockChecks)
  ..put('/api/semi-product-stock-checks/<id>', _updateSemiProductStockCheck)
  ..delete('/api/semi-product-stock-checks/<id>', _deleteSemiProductStockCheck)
  ..post('/api/semi-product-categories', _addSemiProductCategory)
  ..get('/api/semi-product-categories', _getSemiProductCategories)
  ..put('/api/semi-product-categories/<code>', _updateSemiProductCategory)
  ..delete('/api/semi-product-categories/<code>', _deleteSemiProductCategory)
  // Finance Records
  ..post('/api/finance-records', _addFinanceRecord)
  ..get('/api/finance-records', _getFinanceRecords)
  ..put('/api/finance-records/<id>', _updateFinanceRecord)
  ..delete('/api/finance-records/<id>', _deleteFinanceRecord)
  // Todo Tasks
  ..post('/api/todo-tasks', _addTodoTask)
  ..get('/api/todo-tasks', _getTodoTasks)
  ..put('/api/todo-tasks/<id>', _updateTodoTask)
  ..delete('/api/todo-tasks/<id>', _deleteTodoTask)
  // Stock Orders
  ..post('/api/stock-orders', _addStockOrder)
  ..get('/api/stock-orders', _getStockOrders)
  ..put('/api/stock-orders/<id>', _updateStockOrder)
  ..delete('/api/stock-orders/<id>', _deleteStockOrder)
  // Kitchen Tools
  ..post('/api/kitchen-tools', _addKitchenTool)
  ..get('/api/kitchen-tools', _getKitchenTools)
  ..put('/api/kitchen-tools/<code>', _updateKitchenTool)
  ..delete('/api/kitchen-tools/<code>', _deleteKitchenTool)
  // Processes
  ..post('/api/processes', _addProcess)
  ..get('/api/processes', _getProcesses)
  ..put('/api/processes/<code>', _updateProcess)
  ..delete('/api/processes/<code>', _deleteProcess)
  // Tools
  ..post('/api/tools', _addTool)
  ..get('/api/tools', _getTools)
  ..put('/api/tools/<code>', _updateTool)
  ..delete('/api/tools/<code>', _deleteTool)
  // Menu Categories
  ..post('/api/menu-categories', _addMenuCategory)
  ..get('/api/menu-categories', _getMenuCategories)
  ..put('/api/menu-categories/<code>', _updateMenuCategory)
  ..delete('/api/menu-categories/<code>', _deleteMenuCategory)
  // Menus
  ..post('/api/menus', _addMenu)
  ..get('/api/menus', _getMenus)
  ..put('/api/menus/<code>', _updateMenu)
  ..delete('/api/menus/<code>', _deleteMenu);

Future<Response> _test(Request request) async {
  final result = await _conn.execute('SELECT username, role FROM users');
  final users =
      result.map((row) => {'username': row[0], 'role': row[1]}).toList();
  return Response.ok(
    jsonEncode({'users': users}),
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  );
}

Future<bool> _storeExists(String storeCode) async {
  final result = await _conn.execute(
    'SELECT 1 FROM stores WHERE LOWER(code) = LOWER(\$1) LIMIT 1',
    parameters: [storeCode],
  );
  return result.isNotEmpty;
}

Future<Response> _login(Request request) async {
  try {
    final body = await request.readAsString();
    print('Login body: $body');

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid JSON body'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }

    final username = (json['username'] as String?)?.trim();
    final password = (json['password'] as String?)?.trim();

    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing username or password'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }

    final hashedPw = sha256.convert(utf8.encode(password)).toString();
    print('Login attempt: username=$username, hashedPw=$hashedPw');

    final result = await _conn.execute(
      'SELECT id, username, role, store_code, ui_language FROM users WHERE LOWER(username) = LOWER(\$1) AND password = \$2',
      parameters: [username, hashedPw],
    );
    print('Query result: ${result.length} rows found');

    if (result.isEmpty) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid credentials'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }

    final userId = result.first[0] as int;
    final dbUsername = result.first[1] as String? ?? username;
    final role = result.first[2] as String? ?? 'USER';
    final storeCode = _normalizedStoreCode(result.first[3]);
    final uiLanguage = _normalizedUiLanguage(result.first[4]);
    final allowedCategoryCodes = await _getUserAllowedCategoryCodes(userId);
    return Response.ok(
      jsonEncode({
        'success': true,
        'username': dbUsername,
        'role': role,
        'storeCode': storeCode,
        'uiLanguage': uiLanguage,
        'allowedCategoryCodes': allowedCategoryCodes,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    );
  } on FormatException catch (e, st) {
    print('login parse error: $e\n$st');
    return Response.badRequest(
      body: jsonEncode({'error': 'Bad JSON: ${e.message}'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    );
  } catch (e, st) {
    print('login error: $e\n$st');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    );
  }
}

Future<Response> _register(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final username = _normalizedOptionalString(json['username']);
    final password = _normalizedOptionalString(json['password']);
    final role =
        (_normalizedOptionalString(json['role']) ?? 'USER').toUpperCase();
    final storeCode = _normalizedStoreCode(json['storeCode']);
    final uiLanguage = _normalizedUiLanguage(json['uiLanguage']);
    final allowedCategoryCodes = _normalizedStringList(
      json['allowedCategoryCodes'],
    );

    if (username == null || password == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing username or password'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }
    if (role != 'ADMIN' && (storeCode == null || storeCode.isEmpty)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing storeCode for non-admin user'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }
    if (role != 'ADMIN' && !(await _storeExists(storeCode!))) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid storeCode'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }

    final hashedPw = sha256.convert(utf8.encode(password)).toString();
    try {
      final result = await _conn.execute(
        'INSERT INTO users (username, password, role, store_code, ui_language) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id',
        parameters: [
          username,
          hashedPw,
          role,
          role == 'ADMIN' ? null : storeCode,
          uiLanguage,
        ],
      );
      final userId = result.first[0] as int;
      await _replaceUserCategoryPermissions(
        userId,
        role == 'ADMIN' ? const [] : allowedCategoryCodes,
      );
      return Response.ok(
        jsonEncode({'success': true, 'message': 'User registered'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    } catch (e) {
      if (e.toString().contains('unique')) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Username already exists'}),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        );
      }
      rethrow;
    }
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    );
  }
}

Future<List<String>> _getUserAllowedCategoryCodes(int userId) async {
  final result = await _conn.execute(
    '''
    SELECT category_code
    FROM user_raw_material_category_permissions
    WHERE user_id = \$1
    ORDER BY category_code ASC
    ''',
    parameters: [userId],
  );
  return result.map((row) => row[0] as String).toList();
}

Future<void> _replaceUserCategoryPermissions(
  int userId,
  List<String> categoryCodes,
) async {
  await _conn.execute(
    'DELETE FROM user_raw_material_category_permissions WHERE user_id = \$1',
    parameters: [userId],
  );

  for (final code in categoryCodes.toSet()) {
    await _conn.execute(
      '''
      INSERT INTO user_raw_material_category_permissions (user_id, category_code)
      VALUES (\$1, \$2)
      ''',
      parameters: [userId, code],
    );
  }
}

List<String> _normalizedStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map(_normalizedOptionalString)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
}

Future<Response> _getUsers(Request request) async {
  try {
    final result = await _conn.execute('''
      SELECT
        u.id,
        u.username,
        u.role,
        u.store_code,
        u.ui_language,
        COALESCE(
          ARRAY_AGG(DISTINCT p.category_code) FILTER (WHERE p.category_code IS NOT NULL),
          ARRAY[]::VARCHAR[]
        ) AS allowed_category_codes,
        COALESCE(
          ARRAY_AGG(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL),
          ARRAY[]::VARCHAR[]
        ) AS allowed_category_names
      FROM users u
      LEFT JOIN user_raw_material_category_permissions p ON p.user_id = u.id
      LEFT JOIN raw_material_categories c ON c.code = p.category_code
      GROUP BY u.id, u.username, u.role, u.store_code, u.ui_language
      ORDER BY u.username ASC
    ''');

    final users = result.map((row) {
      return {
        'id': row[0],
        'username': row[1],
        'role': row[2],
        'storeCode': _normalizedStoreCode(row[3]),
        'uiLanguage': _normalizedUiLanguage(row[4]),
        'allowedCategoryCodes': List<String>.from(row[5] as List? ?? const []),
        'allowedCategoryNames': List<String>.from(row[6] as List? ?? const []),
      };
    }).toList();

    return Response.ok(
      jsonEncode({'users': users}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _updateUser(Request request, String username) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final password = _normalizedOptionalString(json['password']);
    final role =
        (_normalizedOptionalString(json['role']) ?? 'USER').toUpperCase();
    final storeCode = _normalizedStoreCode(json['storeCode']);
    final uiLanguage = _normalizedUiLanguage(json['uiLanguage']);
    final allowedCategoryCodes = _normalizedStringList(
      json['allowedCategoryCodes'],
    );

    if (role != 'ADMIN' && (storeCode == null || storeCode.isEmpty)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing storeCode for non-admin user'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }
    if (role != 'ADMIN' && !(await _storeExists(storeCode!))) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid storeCode'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final existing = await _conn.execute(
      'SELECT id FROM users WHERE LOWER(username) = LOWER(\$1)',
      parameters: [username],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'User not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final userId = existing.first[0] as int;
    if (password != null) {
      final hashedPw = sha256.convert(utf8.encode(password)).toString();
      await _conn.execute(
        'UPDATE users SET password = \$1, role = \$2, store_code = \$3, ui_language = \$4 WHERE id = \$5',
        parameters: [
          hashedPw,
          role,
          role == 'ADMIN' ? null : storeCode,
          uiLanguage,
          userId,
        ],
      );
    } else {
      await _conn.execute(
        'UPDATE users SET role = \$1, store_code = \$2, ui_language = \$3 WHERE id = \$4',
        parameters: [
          role,
          role == 'ADMIN' ? null : storeCode,
          uiLanguage,
          userId
        ],
      );
    }

    await _replaceUserCategoryPermissions(
      userId,
      role == 'ADMIN' ? const [] : allowedCategoryCodes,
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'User updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _addStore(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedStoreCode(json['code']);
    final name = _normalizedOptionalString(json['name']);
    final note = _normalizedOptionalString(json['note']);

    if (code == null || name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    await _conn.execute(
      'INSERT INTO stores (code, name, note) VALUES (\$1, \$2, \$3)',
      parameters: [code, name, note],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Store added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _getStores(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name, note FROM stores ORDER BY code ASC',
    );
    final stores = result
        .map((row) => {
              'code': row[0],
              'name': row[1],
              'note': row[2],
            })
        .toList();

    return Response.ok(
      jsonEncode({'stores': stores}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _updateStore(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final name = _normalizedOptionalString(json['name']);
    final note = _normalizedOptionalString(json['note']);

    if (name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final normalizedCode = _normalizedStoreCode(code) ?? code;
    final result = await _conn.execute(
      'UPDATE stores SET name = \$1, note = \$2 WHERE LOWER(code) = LOWER(\$3)',
      parameters: [name, note, normalizedCode],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Store not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Store updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _deleteStore(Request request, String code) async {
  try {
    final normalizedCode = _normalizedStoreCode(code) ?? code;
    final usersUsingStore = await _conn.execute(
      'SELECT COUNT(*) FROM users WHERE LOWER(COALESCE(store_code, \'\')) = LOWER(\$1)',
      parameters: [normalizedCode],
    );
    if ((usersUsingStore.first[0] as int) > 0) {
      return Response(
        409,
        body: jsonEncode({
          'error': 'Store is used by users and cannot be deleted',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final result = await _conn.execute(
      'DELETE FROM stores WHERE LOWER(code) = LOWER(\$1)',
      parameters: [normalizedCode],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Store not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Store deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

Future<Response> _deleteUser(Request request, String username) async {
  try {
    if (username.toLowerCase() == 'admin') {
      return Response(
        400,
        body: jsonEncode({'error': 'Default admin cannot be deleted'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final result = await _conn.execute(
      'DELETE FROM users WHERE LOWER(username) = LOWER(\$1)',
      parameters: [username],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'User not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'User deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

String? _normalizedOptionalString(dynamic value) {
  final text = (value as String?)?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

Future<String> _generateSequentialCode(
  String tableName,
  String prefix,
) async {
  final result = await _conn.execute(
    '''
    SELECT code
    FROM $tableName
    WHERE code LIKE \$1
    ORDER BY id DESC
    LIMIT 1
    ''',
    parameters: ['$prefix%'],
  );

  if (result.isEmpty) {
    return '${prefix}000001';
  }

  final lastCode = result.first[0] as String? ?? '';
  final numericPart = lastCode.replaceFirst(prefix, '');
  final nextNumber = (int.tryParse(numericPart) ?? 0) + 1;
  return '$prefix${nextNumber.toString().padLeft(6, '0')}';
}

double _normalizedMinQuantity(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().trim()) ?? 0;
}

// Raw Materials APIs
Future<Response> _addRawMaterial(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final nameCN = json['nameCN'] as String?;
    final nameEN = _normalizedOptionalString(json['nameEN']);
    final specification = _normalizedOptionalString(json['specification']);
    final imagePath = _normalizedOptionalString(json['imagePath']);
    final primarySupplierCode = _normalizedOptionalString(
      json['primarySupplierCode'],
    );
    final secondarySupplierCode = _normalizedOptionalString(
      json['secondarySupplierCode'],
    );
    final categoryCode = _normalizedOptionalString(json['categoryCode']);
    final locationCode = _normalizedOptionalString(json['locationCode']);
    final minQuantity = _normalizedMinQuantity(json['minQuantity']);

    if (nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    final finalCode =
        code ?? await _generateSequentialCode('raw_materials', 'RAW');

    await _conn.execute(
      '''
      INSERT INTO raw_materials (
        code,
        name_cn,
        name_en,
        specification,
        image_path,
        primary_supplier_code,
        secondary_supplier_code,
        category_code,
        location_code,
        min_quantity
      ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10)
      ''',
      parameters: [
        finalCode,
        nameCN,
        nameEN,
        specification,
        imagePath,
        primarySupplierCode,
        secondarySupplierCode,
        categoryCode,
        locationCode,
        minQuantity,
      ],
    );

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Raw material added',
        'code': finalCode,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getRawMaterials(Request request) async {
  try {
    final result = await _conn.execute(
      '''
      SELECT
        rm.code,
        rm.name_cn,
        rm.name_en,
        rm.specification,
        rm.image_path,
        rm.primary_supplier_code,
        rm.secondary_supplier_code,
        rm.category_code,
        rm.location_code,
        rm.min_quantity,
        ps.name,
        ss.name,
        rc.name,
        rl.name
      FROM raw_materials rm
      LEFT JOIN suppliers ps ON ps.code = rm.primary_supplier_code
      LEFT JOIN suppliers ss ON ss.code = rm.secondary_supplier_code
      LEFT JOIN raw_material_categories rc ON rc.code = rm.category_code
      LEFT JOIN raw_material_locations rl ON rl.code = rm.location_code
      ORDER BY rm.created_at DESC
      ''',
    );
    final materials = result
        .map((row) => {
              'code': row[0],
              'nameCN': row[1],
              'nameEN': row[2],
              'specification': row[3],
              'imagePath': row[4],
              'imageUrl': _imageUrlFromPath(row[4] as String?),
              'primarySupplierCode': row[5],
              'secondarySupplierCode': row[6],
              'categoryCode': row[7],
              'locationCode': row[8],
              'minQuantity': row[9],
              'primarySupplierName': row[10],
              'secondarySupplierName': row[11],
              'categoryName': row[12],
              'locationName': row[13],
            })
        .toList();

    return Response.ok(
      jsonEncode({'materials': materials}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

String _normalizeUploadFileName(String rawName) {
  final sanitized = rawName
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return sanitized.isEmpty ? 'upload.bin' : sanitized;
}

String _extensionFromName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return '.bin';
  }
  return fileName.substring(dotIndex).toLowerCase();
}

Future<String> _allocateUploadFileName(String originalName) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final extension = _extensionFromName(_normalizeUploadFileName(originalName));
  var sequence = 1;

  while (true) {
    final fileName =
        '${timestamp}_${sequence.toString().padLeft(3, '0')}$extension';
    final file = File('${_uploadImagesDir.path}/$fileName');
    if (!await file.exists()) {
      return fileName;
    }
    sequence++;
  }
}

String? _imageUrlFromPath(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) {
    return null;
  }
  final fileName = imagePath.replaceAll('\\', '/').split('/').last;
  // Return a root-relative path so both local dev and production work
  // without hardcoding a hostname/port.
  return '/uploads/images/$fileName';
}

Future<void> _deleteUploadedImage(String? imagePath) async {
  if (imagePath == null || imagePath.trim().isEmpty) {
    return;
  }

  final fileName = imagePath.replaceAll('\\', '/').split('/').last;
  final file = File('${_uploadImagesDir.path}/$fileName');
  if (await file.exists()) {
    await file.delete();
  }
}

Future<Response> _uploadImage(Request request) async {
  try {
    final originalName = request.headers['x-file-name'];
    if (originalName == null || originalName.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing x-file-name header'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Empty upload'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final fileName = await _allocateUploadFileName(originalName);
    final relativePath = 'UPLOAD/IMAGES/$fileName';
    final file = File('${_uploadImagesDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return Response.ok(
      jsonEncode({
        'success': true,
        'fileName': fileName,
        'imagePath': relativePath,
        'imageUrl': _imageUrlFromPath(relativePath),
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _serveUploadedImage(Request request, String fileName) async {
  try {
    final normalizedFileName = _normalizeUploadFileName(fileName);
    final file = File('${_uploadImagesDir.path}/$normalizedFileName');
    if (!await file.exists()) {
      return Response.notFound(
        jsonEncode({'error': 'Image not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final extension = _extensionFromName(normalizedFileName);
    final contentType = switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

    return Response.ok(
      await file.readAsBytes(),
      headers: {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateRawMaterial(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = json['nameCN'] as String?;
    final nameEN = _normalizedOptionalString(json['nameEN']);
    final specification = _normalizedOptionalString(json['specification']);
    final hasImagePath = json.containsKey('imagePath');
    final imagePath = _normalizedOptionalString(json['imagePath']);
    final primarySupplierCode = _normalizedOptionalString(
      json['primarySupplierCode'],
    );
    final secondarySupplierCode = _normalizedOptionalString(
      json['secondarySupplierCode'],
    );
    final categoryCode = _normalizedOptionalString(json['categoryCode']);
    final locationCode = _normalizedOptionalString(json['locationCode']);
    final minQuantity = _normalizedMinQuantity(json['minQuantity']);

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    String? finalImagePath;
    if (hasImagePath) {
      final existing = await _conn.execute(
        'SELECT image_path FROM raw_materials WHERE code = \$1',
        parameters: [code],
      );
      if (existing.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Raw material not found'}),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
        );
      }

      final oldImagePath = existing.first[0] as String?;
      finalImagePath = imagePath;
      if (oldImagePath != null && oldImagePath != finalImagePath) {
        await _deleteUploadedImage(oldImagePath);
      }
    }

    final result = await _conn.execute(
      hasImagePath
          ? '''
            UPDATE raw_materials
            SET
              name_cn = \$1,
              name_en = \$2,
              specification = \$3,
              image_path = \$4,
              primary_supplier_code = \$5,
              secondary_supplier_code = \$6,
              category_code = \$7,
              location_code = \$8,
              min_quantity = \$9
            WHERE code = \$10
            '''
          : '''
            UPDATE raw_materials
            SET
              name_cn = \$1,
              name_en = \$2,
              specification = \$3,
              primary_supplier_code = \$4,
              secondary_supplier_code = \$5,
              category_code = \$6,
              location_code = \$7,
              min_quantity = \$8
            WHERE code = \$9
            ''',
      parameters: hasImagePath
          ? [
              nameCN.trim(),
              nameEN,
              specification,
              finalImagePath,
              primarySupplierCode,
              secondarySupplierCode,
              categoryCode,
              locationCode,
              minQuantity,
              code,
            ]
          : [
              nameCN.trim(),
              nameEN,
              specification,
              primarySupplierCode,
              secondarySupplierCode,
              categoryCode,
              locationCode,
              minQuantity,
              code,
            ],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Raw material not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Raw material updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteRawMaterial(Request request, String code) async {
  try {
    final existing = await _conn.execute(
      'SELECT image_path FROM raw_materials WHERE code = \$1',
      parameters: [code],
    );
    final oldImagePath =
        existing.isNotEmpty ? existing.first[0] as String? : null;

    final result = await _conn.execute(
      'DELETE FROM raw_materials WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Raw material not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _deleteUploadedImage(oldImagePath);

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Raw material deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addRawMaterialCategory(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final name = _normalizedOptionalString(json['name']);

    if (code == null || name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO raw_material_categories (code, name) VALUES (\$1, \$2)',
      parameters: [code, name],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Category added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getRawMaterialCategories(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name FROM raw_material_categories ORDER BY name ASC',
    );
    final categories =
        result.map((row) => {'code': row[0], 'name': row[1]}).toList();

    return Response.ok(
      jsonEncode({'categories': categories}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateRawMaterialCategory(
  Request request,
  String code,
) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final name = _normalizedOptionalString(json['name']);

    if (name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE raw_material_categories SET name = \$1 WHERE code = \$2',
      parameters: [name, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Category updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteRawMaterialCategory(
  Request request,
  String code,
) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM raw_material_categories WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Category deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addRawMaterialLocation(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final name = _normalizedOptionalString(json['name']);
    final note = _normalizedOptionalString(json['note']);

    if (code == null || name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO raw_material_locations (code, name, note) VALUES (\$1, \$2, \$3)',
      parameters: [code, name, note],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Location added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getRawMaterialLocations(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name, note FROM raw_material_locations ORDER BY name ASC',
    );
    final locations = result
        .map((row) => {'code': row[0], 'name': row[1], 'note': row[2]})
        .toList();

    return Response.ok(
      jsonEncode({'locations': locations}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateRawMaterialLocation(
    Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final name = _normalizedOptionalString(json['name']);
    final note = _normalizedOptionalString(json['note']);

    if (name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE raw_material_locations SET name = \$1, note = \$2 WHERE code = \$3',
      parameters: [name, note, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Location not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Location updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteRawMaterialLocation(
    Request request, String code) async {
  try {
    await _conn.execute(
      'UPDATE raw_materials SET location_code = NULL WHERE location_code = \$1',
      parameters: [code],
    );
    final result = await _conn.execute(
      'DELETE FROM raw_material_locations WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Location not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Location deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Suppliers APIs
Future<Response> _addSupplier(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final code = json['code'] as String?;
    final name = json['name'] as String?;
    final alias = json['alias'] as String?;
    final address = json['address'] as String?;
    final contact = json['contact'] as String?;

    if (code == null || name == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO suppliers (code, name, alias, address, contact) VALUES (\$1, \$2, \$3, \$4, \$5)',
      parameters: [code, name, alias ?? '', address ?? '', contact ?? ''],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Supplier added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getSuppliers(Request request) async {
  try {
    final result = await _conn.execute(
        'SELECT code, name, alias, address, contact FROM suppliers ORDER BY created_at DESC');
    final suppliers = result
        .map((row) => {
              'code': row[0],
              'name': row[1],
              'alias': row[2],
              'address': row[3],
              'contact': row[4],
            })
        .toList();

    return Response.ok(
      jsonEncode({'suppliers': suppliers}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateSupplier(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final name = json['name'] as String?;
    final alias = json['alias'] as String?;
    final address = json['address'] as String?;
    final contact = json['contact'] as String?;

    if (name == null || name.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE suppliers SET name = \$1, alias = \$2, address = \$3, contact = \$4 WHERE code = \$5',
      parameters: [
        name.trim(),
        (alias ?? '').trim(),
        (address ?? '').trim(),
        (contact ?? '').trim(),
        code,
      ],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Supplier not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Supplier updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteSupplier(Request request, String code) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM suppliers WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Supplier not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Supplier deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Units APIs
Future<Response> _addUnit(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final code = json['code'] as String?;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;

    if (code == null || nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO units (code, name_cn, name_en) VALUES (\$1, \$2, \$3)',
      parameters: [code, nameCN, (nameEN ?? '').trim()],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Unit added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getUnits(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name_cn, name_en FROM units ORDER BY created_at DESC',
    );
    final units = result
        .map((row) => {
              'code': row[0],
              'nameCN': row[1],
              'nameEN': row[2],
            })
        .toList();

    return Response.ok(
      jsonEncode({'units': units}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateUnit(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE units SET name_cn = \$1, name_en = \$2 WHERE code = \$3',
      parameters: [nameCN.trim(), (nameEN ?? '').trim(), code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Unit not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Unit updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteUnit(Request request, String code) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM units WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Unit not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Unit deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addRegion(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final nameCN = _normalizedOptionalString(json['nameCN']);
    final nameEN = _normalizedOptionalString(json['nameEN']);
    final note = _normalizedOptionalString(json['note']);

    if (code == null || nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO regions (code, name_cn, name_en, note) VALUES (\$1, \$2, \$3, \$4)',
      parameters: [code, nameCN, nameEN, note],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Region added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getRegions(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name_cn, name_en, note FROM regions ORDER BY created_at DESC',
    );
    final regions = result
        .map((row) => {
              'code': row[0],
              'nameCN': row[1],
              'nameEN': row[2],
              'note': row[3],
            })
        .toList();

    return Response.ok(
      jsonEncode({'regions': regions}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateRegion(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = _normalizedOptionalString(json['nameCN']);
    final nameEN = _normalizedOptionalString(json['nameEN']);
    final note = _normalizedOptionalString(json['note']);

    if (nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE regions SET name_cn = \$1, name_en = \$2, note = \$3 WHERE code = \$4',
      parameters: [nameCN, nameEN, note, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Region not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Region updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteRegion(Request request, String code) async {
  try {
    await _conn.execute(
      'DELETE FROM semi_product_stock_checks WHERE region_code = \$1',
      parameters: [code],
    );
    final result = await _conn.execute(
      'DELETE FROM regions WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Region not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Region deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Semi Products APIs
Future<Response> _addSemiProduct(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final code = json['code'] as String?;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final categoryCode = _normalizedOptionalString(json['categoryCode']);
    final description = json['description'] as String?;
    final imagePath = _normalizedOptionalString(json['imagePath']);
    final rawMaterialCodes =
        (json['rawMaterialCodes'] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final toolCodes =
        (json['toolCodes'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final steps =
        (json['steps'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    if (code == null || nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO semi_products (code, name_cn, name_en, category_code, description, image_path, raw_material_codes, tool_codes, steps) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)',
      parameters: [
        code,
        nameCN,
        nameEN ?? '',
        categoryCode,
        description ?? '',
        imagePath,
        rawMaterialCodes,
        toolCodes,
        steps,
      ],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getSemiProducts(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT sp.code, sp.name_cn, sp.name_en, sp.category_code, sp.description, sp.image_path, sp.raw_material_codes, sp.tool_codes, sp.steps, spc.name_cn, spc.name_en FROM semi_products sp LEFT JOIN semi_product_categories spc ON spc.code = sp.category_code ORDER BY sp.created_at DESC',
    );
    final products = result
        .map((row) => {
              'code': row[0],
              'nameCN': row[1],
              'nameEN': row[2],
              'categoryCode': row[3],
              'description': row[4],
              'imagePath': row[5],
              'imageUrl': _imageUrlFromPath(row[5] as String?),
              'rawMaterialCodes': row[6] ?? <String>[],
              'toolCodes': row[7] ?? <String>[],
              'steps': row[8] ?? <String>[],
              'categoryNameCN': row[9],
              'categoryNameEN': row[10],
            })
        .toList();

    return Response.ok(
      jsonEncode({'products': products}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateSemiProduct(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final categoryCode = _normalizedOptionalString(json['categoryCode']);
    final description = json['description'] as String?;
    final hasImagePath = json.containsKey('imagePath');
    final imagePath = _normalizedOptionalString(json['imagePath']);
    final rawMaterialCodes =
        (json['rawMaterialCodes'] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final toolCodes =
        (json['toolCodes'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final steps =
        (json['steps'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    String? finalImagePath;
    if (hasImagePath) {
      final existing = await _conn.execute(
        'SELECT image_path FROM semi_products WHERE code = \$1',
        parameters: [code],
      );
      if (existing.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Semi product not found'}),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
        );
      }

      final oldImagePath = existing.first[0] as String?;
      finalImagePath = imagePath;
      if (oldImagePath != null && oldImagePath != finalImagePath) {
        await _deleteUploadedImage(oldImagePath);
      }
    }

    final result = await _conn.execute(
      hasImagePath
          ? 'UPDATE semi_products SET name_cn = \$1, name_en = \$2, category_code = \$3, description = \$4, image_path = \$5, raw_material_codes = \$6, tool_codes = \$7, steps = \$8 WHERE code = \$9'
          : 'UPDATE semi_products SET name_cn = \$1, name_en = \$2, category_code = \$3, description = \$4, raw_material_codes = \$5, tool_codes = \$6, steps = \$7 WHERE code = \$8',
      parameters: hasImagePath
          ? [
              nameCN.trim(),
              (nameEN ?? '').trim(),
              categoryCode,
              description ?? '',
              finalImagePath,
              rawMaterialCodes,
              toolCodes,
              steps,
              code,
            ]
          : [
              nameCN.trim(),
              (nameEN ?? '').trim(),
              categoryCode,
              description ?? '',
              rawMaterialCodes,
              toolCodes,
              steps,
              code,
            ],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteSemiProduct(Request request, String code) async {
  try {
    final existing = await _conn.execute(
      'SELECT image_path FROM semi_products WHERE code = \$1',
      parameters: [code],
    );
    final oldImagePath =
        existing.isNotEmpty ? existing.first[0] as String? : null;

    final result = await _conn.execute(
      'DELETE FROM semi_products WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    if (oldImagePath != null) {
      await _deleteUploadedImage(oldImagePath);
    }
    await _conn.execute(
      'DELETE FROM semi_product_stock_checks WHERE semi_product_code = \$1',
      parameters: [code],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addSemiProductStockCheck(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final semiProductCode = _normalizedOptionalString(json['semiProductCode']);
    final regionCode = _normalizedOptionalString(json['regionCode']);
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;
    final weekdayStock = (json['weekdayStock'] as num?)?.toDouble() ??
        double.tryParse(json['weekdayStock']?.toString() ?? '') ??
        0;
    final weekendStock = (json['weekendStock'] as num?)?.toDouble() ??
        double.tryParse(json['weekendStock']?.toString() ?? '') ??
        0;
    final holidayStock = (json['holidayStock'] as num?)?.toDouble() ??
        double.tryParse(json['holidayStock']?.toString() ?? '') ??
        0;

    if (semiProductCode == null || regionCode == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO semi_product_stock_checks (semi_product_code, region_code, weekday_stock, weekend_stock, holiday_stock, store_code) VALUES (\$1, \$2, \$3, \$4, \$5, \$6)',
      parameters: [
        semiProductCode,
        regionCode,
        weekdayStock,
        weekendStock,
        holidayStock,
        storeCode,
      ],
    );

    return Response.ok(
      jsonEncode(
          {'success': true, 'message': 'Semi product stock check added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getSemiProductStockChecks(Request request) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final result = await _conn.execute(
      scope.isAdmin
          ? 'SELECT s.id, s.semi_product_code, sp.name_cn, sp.name_en, s.region_code, r.name_cn, r.name_en, s.weekday_stock, s.weekend_stock, s.holiday_stock, s.store_code FROM semi_product_stock_checks s LEFT JOIN semi_products sp ON sp.code = s.semi_product_code LEFT JOIN regions r ON r.code = s.region_code ORDER BY COALESCE(r.name_cn, s.region_code) ASC, COALESCE(sp.name_cn, s.semi_product_code) ASC'
          : '''
            SELECT s.id, s.semi_product_code, sp.name_cn, sp.name_en, s.region_code, r.name_cn, r.name_en, s.weekday_stock, s.weekend_stock, s.holiday_stock, s.store_code
            FROM semi_product_stock_checks s
            LEFT JOIN semi_products sp ON sp.code = s.semi_product_code
            LEFT JOIN regions r ON r.code = s.region_code
            WHERE LOWER(COALESCE(s.store_code, '')) = LOWER(\$1)
            ORDER BY COALESCE(r.name_cn, s.region_code) ASC, COALESCE(sp.name_cn, s.semi_product_code) ASC
            ''',
      parameters: scope.isAdmin ? const [] : [scope.storeCode ?? ''],
    );
    final checks = result
        .map((row) => {
              'id': row[0],
              'semiProductCode': row[1],
              'semiProductNameCN': row[2],
              'semiProductNameEN': row[3],
              'regionCode': row[4],
              'regionNameCN': row[5],
              'regionNameEN': row[6],
              'weekdayStock': row[7],
              'weekendStock': row[8],
              'holidayStock': row[9],
              'storeCode': row[10],
            })
        .toList();

    return Response.ok(
      jsonEncode({'checks': checks}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateSemiProductStockCheck(
    Request request, String id) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final semiProductCode = _normalizedOptionalString(json['semiProductCode']);
    final regionCode = _normalizedOptionalString(json['regionCode']);
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;
    final weekdayStock = (json['weekdayStock'] as num?)?.toDouble() ??
        double.tryParse(json['weekdayStock']?.toString() ?? '') ??
        0;
    final weekendStock = (json['weekendStock'] as num?)?.toDouble() ??
        double.tryParse(json['weekendStock']?.toString() ?? '') ??
        0;
    final holidayStock = (json['holidayStock'] as num?)?.toDouble() ??
        double.tryParse(json['holidayStock']?.toString() ?? '') ??
        0;

    if (semiProductCode == null || regionCode == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final existing = await _conn.execute(
      'SELECT store_code FROM semi_product_stock_checks WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product stock check not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existingStoreCode = existing.first[0] as String?;
    if (!scope.isAdmin &&
        _normalizedStoreCode(existingStoreCode) != (scope.storeCode ?? '')) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to update this record'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE semi_product_stock_checks SET semi_product_code = \$1, region_code = \$2, weekday_stock = \$3, weekend_stock = \$4, holiday_stock = \$5, store_code = \$6 WHERE id = \$7',
      parameters: [
        semiProductCode,
        regionCode,
        weekdayStock,
        weekendStock,
        holidayStock,
        storeCode,
        int.parse(id),
      ],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product stock check not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode(
          {'success': true, 'message': 'Semi product stock check updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteSemiProductStockCheck(
    Request request, String id) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existing = await _conn.execute(
      'SELECT store_code FROM semi_product_stock_checks WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product stock check not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existingStoreCode = existing.first[0] as String?;
    if (!scope.isAdmin &&
        _normalizedStoreCode(existingStoreCode) != (scope.storeCode ?? '')) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to delete this record'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'DELETE FROM semi_product_stock_checks WHERE id = \$1',
      parameters: [int.parse(id)],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Semi product stock check not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode(
          {'success': true, 'message': 'Semi product stock check deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addSemiProductCategory(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final nameCN = _normalizedOptionalString(json['nameCN']);
    final nameEN = _normalizedOptionalString(json['nameEN']);

    if (code == null || nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO semi_product_categories (code, name_cn, name_en) VALUES (\$1, \$2, \$3)',
      parameters: [code, nameCN, nameEN],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product category added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getSemiProductCategories(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name_cn, name_en FROM semi_product_categories ORDER BY name_cn ASC',
    );
    final categories = result
        .map((row) => {
              'code': row[0],
              'nameCN': row[1],
              'nameEN': row[2],
            })
        .toList();

    return Response.ok(
      jsonEncode({'categories': categories}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateSemiProductCategory(
    Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = _normalizedOptionalString(json['nameCN']);
    final nameEN = _normalizedOptionalString(json['nameEN']);

    if (nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE semi_product_categories SET name_cn = \$1, name_en = \$2 WHERE code = \$3',
      parameters: [nameCN, nameEN, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product category updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteSemiProductCategory(
    Request request, String code) async {
  try {
    await _conn.execute(
      'UPDATE semi_products SET category_code = NULL WHERE category_code = \$1',
      parameters: [code],
    );

    final result = await _conn.execute(
      'DELETE FROM semi_product_categories WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Semi product category deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Finance Records APIs
Future<Response> _addFinanceRecord(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final type = json['type'] as String?;
    final recordDate = json['recordDate'] as String?;
    final amount = json['amount'] as num?;
    final note = json['note'] as String?;
    final imagePath = json['imagePath'] as String?;
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;

    if (type == null || recordDate == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO finance_records (type, record_date, amount, note, image_path, store_code) VALUES (\$1, \$2, \$3, \$4, \$5, \$6)',
      parameters: [
        type,
        DateTime.parse(recordDate),
        amount ?? 0,
        note ?? '',
        imagePath ?? '',
        storeCode,
      ],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Finance record added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getFinanceRecords(Request request) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final result = await _conn.execute(
      scope.isAdmin
          ? 'SELECT id, type, TO_CHAR(record_date, \'YYYY-MM-DD\'), amount, note, image_path, store_code FROM finance_records ORDER BY record_date DESC, id DESC'
          : 'SELECT id, type, TO_CHAR(record_date, \'YYYY-MM-DD\'), amount, note, image_path, store_code FROM finance_records WHERE LOWER(COALESCE(store_code, \'\')) = LOWER(\$1) ORDER BY record_date DESC, id DESC',
      parameters: scope.isAdmin ? const [] : [scope.storeCode ?? ''],
    );
    final records = result
        .map((row) => {
              'id': row[0],
              'type': row[1],
              'recordDate': row[2],
              'amount': row[3],
              'note': row[4],
              'imagePath': row[5],
              'storeCode': row[6],
            })
        .toList();

    return Response.ok(
      jsonEncode({'records': records}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateFinanceRecord(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body);
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final type = json['type'] as String?;
    final recordDate = json['recordDate'] as String?;
    final amount = json['amount'] as num?;
    final note = json['note'] as String?;
    final imagePath = json['imagePath'] as String?;
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;

    if (type == null || recordDate == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final existing = await _conn.execute(
      'SELECT store_code FROM finance_records WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Finance record not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existingStoreCode = existing.first[0] as String?;
    if (!scope.isAdmin &&
        _normalizedStoreCode(existingStoreCode) != (scope.storeCode ?? '')) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to update this record'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final payload = <dynamic>[
      type,
      DateTime.parse(recordDate),
      amount ?? 0,
      note ?? '',
      storeCode,
    ];
    var sql =
        'UPDATE finance_records SET type = \$1, record_date = \$2, amount = \$3, note = \$4, store_code = \$5';
    if (imagePath != null && imagePath.isNotEmpty) {
      sql += ', image_path = \$6 WHERE id = \$7';
      payload.add(imagePath);
      payload.add(int.parse(id));
    } else {
      sql += ' WHERE id = \$6';
      payload.add(int.parse(id));
    }

    final result = await _conn.execute(sql, parameters: payload);
    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Finance record not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Finance record updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteFinanceRecord(Request request, String id) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existing = await _conn.execute(
      'SELECT store_code FROM finance_records WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Finance record not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existingStoreCode = existing.first[0] as String?;
    if (!scope.isAdmin &&
        _normalizedStoreCode(existingStoreCode) != (scope.storeCode ?? '')) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to delete this record'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'DELETE FROM finance_records WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Finance record not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Finance record deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Todo Tasks APIs
Future<Response> _addTodoTask(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final title = json['title'] as String?;
    final content = json['content'] as String?;
    final note = json['note'] as String?;
    final dueDateTime = json['dueDateTime'] as String?;
    final status = json['status'] as String? ?? '未做完';
    final ownerUsername = _normalizedOptionalString(json['ownerUsername']);
    final effectiveOwnerUsername =
        scope.isAdmin ? ownerUsername : scope.username;
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;
    final stockOrderId = json['stockOrderId'] as int?;
    final supplierCode = _normalizedOptionalString(json['supplierCode']);
    final taskType = _normalizedOptionalString(json['taskType']);

    if (title == null ||
        title.isEmpty ||
        dueDateTime == null ||
        dueDateTime.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'INSERT INTO todo_tasks (title, content, note, due_date_time, status, owner_username, stock_order_id, supplier_code, task_type, store_code) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10) RETURNING id',
      parameters: [
        title,
        content ?? '',
        note ?? '',
        DateTime.parse(dueDateTime),
        status,
        effectiveOwnerUsername,
        stockOrderId,
        supplierCode,
        taskType,
        storeCode,
      ],
    );

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Todo task added',
        'id': result.first[0],
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getTodoTasks(Request request) async {
  try {
    final username = _normalizedOptionalString(
      request.requestedUri.queryParameters['username'],
    );
    final scope = await _getUserScopeByUsername(username);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final result = await _conn.execute(
      scope.isAdmin
          ? 'SELECT id, title, content, note, TO_CHAR(due_date_time, \'YYYY-MM-DD HH24:MI:SS\'), status, owner_username, stock_order_id, supplier_code, task_type, store_code FROM todo_tasks ORDER BY due_date_time ASC, id DESC'
          : '''
            SELECT id, title, content, note, TO_CHAR(due_date_time, 'YYYY-MM-DD HH24:MI:SS'), status, owner_username, stock_order_id, supplier_code, task_type, store_code
            FROM todo_tasks
            WHERE
              (
                COALESCE(store_code, '') <> ''
                AND LOWER(store_code) = LOWER(\$1)
              )
              OR (
                COALESCE(store_code, '') = ''
                AND LOWER(COALESCE(owner_username, '')) = LOWER(\$2)
              )
            ORDER BY due_date_time ASC, id DESC
            ''',
      parameters:
          scope.isAdmin ? const [] : [scope.storeCode ?? '', scope.username],
    );
    final tasks = result
        .map((row) => {
              'id': row[0],
              'title': row[1],
              'content': row[2],
              'note': row[3],
              'dueDateTime': row[4],
              'status': row[5],
              'ownerUsername': row[6],
              'stockOrderId': row[7],
              'supplierCode': row[8],
              'taskType': row[9],
              'storeCode': row[10],
            })
        .toList();

    return Response.ok(
      jsonEncode({'tasks': tasks}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateTodoTask(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final title = json['title'] as String?;
    final content = json['content'] as String?;
    final note = json['note'] as String?;
    final dueDateTime = json['dueDateTime'] as String?;
    final status = json['status'] as String?;
    final hasOwnerUsername = json.containsKey('ownerUsername');
    final ownerUsername = _normalizedOptionalString(json['ownerUsername']);
    final hasStoreCode = json.containsKey('storeCode');
    final requestedStoreCode = _normalizedStoreCode(json['storeCode']);
    final hasStockOrderId = json.containsKey('stockOrderId');
    final stockOrderId = json['stockOrderId'] as int?;
    final hasSupplierCode = json.containsKey('supplierCode');
    final supplierCode = _normalizedOptionalString(json['supplierCode']);
    final hasTaskType = json.containsKey('taskType');
    final taskType = _normalizedOptionalString(json['taskType']);

    if (title == null ||
        title.isEmpty ||
        dueDateTime == null ||
        dueDateTime.isEmpty ||
        status == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final existing = await _conn.execute(
      'SELECT owner_username, store_code FROM todo_tasks WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Todo task not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existingOwner = existing.first[0] as String?;
    final existingStoreCode = existing.first[1] as String?;
    if (!_canAccessStoreScopedRecord(scope, existingStoreCode, existingOwner)) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to update this task'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final sql = StringBuffer(
      'UPDATE todo_tasks SET title = \$1, content = \$2, note = \$3, due_date_time = \$4, status = \$5',
    );
    final parameters = <dynamic>[
      title,
      content ?? '',
      note ?? '',
      DateTime.parse(dueDateTime),
      status,
    ];
    if (hasStockOrderId) {
      sql.write(', stock_order_id = \$${parameters.length + 1}');
      parameters.add(stockOrderId);
    }
    if (hasOwnerUsername) {
      sql.write(', owner_username = \$${parameters.length + 1}');
      parameters.add(scope.isAdmin ? ownerUsername : scope.username);
    }
    if (hasStoreCode) {
      sql.write(', store_code = \$${parameters.length + 1}');
      parameters.add(scope.isAdmin ? requestedStoreCode : scope.storeCode);
    }
    if (hasSupplierCode) {
      sql.write(', supplier_code = \$${parameters.length + 1}');
      parameters.add(supplierCode);
    }
    if (hasTaskType) {
      sql.write(', task_type = \$${parameters.length + 1}');
      parameters.add(taskType);
    }
    sql.write(' WHERE id = \$${parameters.length + 1}');
    parameters.add(int.parse(id));

    final result = await _conn.execute(sql.toString(), parameters: parameters);

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Todo task not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Todo task updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteTodoTask(Request request, String id) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existing = await _conn.execute(
      'SELECT owner_username, store_code FROM todo_tasks WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Todo task not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    if (!_canAccessStoreScopedRecord(
      scope,
      existing.first[1] as String?,
      existing.first[0] as String?,
    )) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to delete this task'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'DELETE FROM todo_tasks WHERE id = \$1',
      parameters: [int.parse(id)],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Todo task not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Todo task deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _addStockOrder(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final orderDate = json['orderDate'] as String?;
    final details = json['details'];
    final isConfirmed = json['isConfirmed'] == true;
    final storeCode = scope.isAdmin
        ? _normalizedStoreCode(json['storeCode'])
        : scope.storeCode;

    if (orderDate == null || orderDate.isEmpty || details == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'INSERT INTO stock_orders (order_date, details, is_confirmed, owner_username, store_code) VALUES (\$1, \$2, \$3, \$4, \$5) RETURNING id',
      parameters: [
        DateTime.parse(orderDate),
        jsonEncode(details),
        isConfirmed,
        scope.username,
        storeCode,
      ],
    );

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Stock order added',
        'id': result.first[0],
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getStockOrders(Request request) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final result = await _conn.execute(
      scope.isAdmin
          ? 'SELECT id, TO_CHAR(order_date, \'YYYY-MM-DD\'), details, is_confirmed, TO_CHAR(created_at, \'YYYY-MM-DD HH24:MI:SS\'), owner_username, store_code FROM stock_orders ORDER BY order_date DESC, id DESC'
          : '''
            SELECT id, TO_CHAR(order_date, 'YYYY-MM-DD'), details, is_confirmed, TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS'), owner_username, store_code
            FROM stock_orders
            WHERE
              (
                COALESCE(store_code, '') <> ''
                AND LOWER(store_code) = LOWER(\$1)
              )
              OR (
                COALESCE(store_code, '') = ''
                AND LOWER(COALESCE(owner_username, '')) = LOWER(\$2)
              )
            ORDER BY order_date DESC, id DESC
            ''',
      parameters:
          scope.isAdmin ? const [] : [scope.storeCode ?? '', scope.username],
    );
    final orders = result.map((row) {
      final detailsText = row[2] as String? ?? '[]';
      dynamic details;
      try {
        details = jsonDecode(detailsText);
      } catch (_) {
        details = [];
      }
      return {
        'id': row[0],
        'orderDate': row[1],
        'details': details,
        'isConfirmed': row[3] == true,
        'createdAt': row[4],
        'ownerUsername': row[5],
        'storeCode': row[6],
      };
    }).toList();

    return Response.ok(
      jsonEncode({'orders': orders}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateStockOrder(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final scope =
        await _getUserScopeByUsername(json['actorUsername'] as String?);
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid actorUsername'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final details = json['details'];
    final hasIsConfirmed = json.containsKey('isConfirmed');
    final isConfirmed = json['isConfirmed'] == true;

    if (details == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final existing = await _conn.execute(
      'SELECT owner_username, store_code FROM stock_orders WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Stock order not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    if (!_canAccessStoreScopedRecord(
      scope,
      existing.first[1] as String?,
      existing.first[0] as String?,
    )) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to update this stock order'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = hasIsConfirmed
        ? await _conn.execute(
            'UPDATE stock_orders SET details = \$1, is_confirmed = \$2 WHERE id = \$3',
            parameters: [jsonEncode(details), isConfirmed, int.parse(id)],
          )
        : await _conn.execute(
            'UPDATE stock_orders SET details = \$1 WHERE id = \$2',
            parameters: [jsonEncode(details), int.parse(id)],
          );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Stock order not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Stock order updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteStockOrder(Request request, String id) async {
  try {
    final scope = await _getUserScopeByUsername(
      request.requestedUri.queryParameters['username'],
    );
    if (scope == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing or invalid username'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    final existing = await _conn.execute(
      'SELECT owner_username, store_code FROM stock_orders WHERE id = \$1',
      parameters: [int.parse(id)],
    );
    if (existing.isEmpty) {
      return Response.notFound(
        jsonEncode({'error': 'Stock order not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }
    if (!_canAccessStoreScopedRecord(
      scope,
      existing.first[1] as String?,
      existing.first[0] as String?,
    )) {
      return Response.forbidden(
        jsonEncode({'error': 'No permission to delete this stock order'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'DELETE FROM todo_tasks WHERE stock_order_id = \$1 AND task_type = \$2',
      parameters: [int.parse(id), 'stock_order'],
    );
    final result = await _conn.execute(
      'DELETE FROM stock_orders WHERE id = \$1',
      parameters: [int.parse(id)],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Stock order not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Stock order deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Kitchen Tools APIs
Future<Response> _addKitchenTool(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = json['code'] as String?;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final imagePath = (json['imagePath'] as String?)?.trim();

    if (code == null || nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO kitchen_tools (code, name_cn, name_en, image_path) VALUES (\$1, \$2, \$3, \$4)',
      parameters: [code, nameCN, nameEN ?? '', imagePath],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Kitchen tool added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getKitchenTools(Request request) async {
  try {
    final result = await _conn.execute(
        'SELECT code, name_cn, name_en, image_path, image_data FROM kitchen_tools ORDER BY created_at DESC');
    final tools = result.map((row) {
      final imagePath = row[3] as String?;
      final imageData = row[4];
      String? base64Image;
      if ((imagePath == null || imagePath.isEmpty) && imageData != null) {
        base64Image = base64Encode(imageData as List<int>);
      }
      return {
        'code': row[0],
        'nameCN': row[1],
        'nameEN': row[2],
        'imagePath': imagePath,
        'imageUrl': _imageUrlFromPath(imagePath),
        'imageData': base64Image,
      };
    }).toList();

    return Response.ok(
      jsonEncode({'tools': tools}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateKitchenTool(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final hasImagePath = json.containsKey('imagePath');
    final imagePath = (json['imagePath'] as String?)?.trim();

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    String? finalImagePath;
    if (hasImagePath) {
      final existing = await _conn.execute(
        'SELECT image_path FROM kitchen_tools WHERE code = \$1',
        parameters: [code],
      );
      if (existing.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Kitchen tool not found'}),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
        );
      }

      final oldImagePath = existing.first[0] as String?;
      finalImagePath = imagePath;
      if (oldImagePath != null && oldImagePath != finalImagePath) {
        await _deleteUploadedImage(oldImagePath);
      }
    }

    final result = await _conn.execute(
      hasImagePath
          ? 'UPDATE kitchen_tools SET name_cn = \$1, name_en = \$2, image_path = \$3, image_data = NULL WHERE code = \$4'
          : 'UPDATE kitchen_tools SET name_cn = \$1, name_en = \$2 WHERE code = \$3',
      parameters: hasImagePath
          ? [nameCN.trim(), (nameEN ?? '').trim(), finalImagePath, code]
          : [nameCN.trim(), (nameEN ?? '').trim(), code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Kitchen tool not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Kitchen tool updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteKitchenTool(Request request, String code) async {
  try {
    final existing = await _conn.execute(
      'SELECT image_path FROM kitchen_tools WHERE code = \$1',
      parameters: [code],
    );
    final oldImagePath =
        existing.isNotEmpty ? existing.first[0] as String? : null;

    final result = await _conn.execute(
      'DELETE FROM kitchen_tools WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Kitchen tool not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _deleteUploadedImage(oldImagePath);

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Kitchen tool deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Processes APIs
Future<Response> _addProcess(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = await _generateSequentialCode('processes', 'PROC');
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final toolCodes = json['toolCodes'] as List<dynamic>?;

    if (nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO processes (code, name_cn, name_en, tool_codes) VALUES (\$1, \$2, \$3, \$4)',
      parameters: [code, nameCN, nameEN ?? '', toolCodes ?? []],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Process added', 'code': code}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getProcesses(Request request) async {
  try {
    final result = await _conn.execute(
        'SELECT code, name_cn, name_en, tool_codes FROM processes ORDER BY created_at DESC');
    final processes = result.map((row) {
      return {
        'code': row[0],
        'nameCN': row[1],
        'nameEN': row[2],
        'toolCodes': row[3] ?? [],
      };
    }).toList();

    return Response.ok(
      jsonEncode({'processes': processes}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateProcess(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final toolCodes = json['toolCodes'] as List<dynamic>?;

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE processes SET name_cn = \$1, name_en = \$2, tool_codes = \$3 WHERE code = \$4',
      parameters: [nameCN.trim(), (nameEN ?? '').trim(), toolCodes ?? [], code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Process not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Process updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteProcess(Request request, String code) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM processes WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Process not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Process deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Tools APIs
Future<Response> _addTool(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = await _generateSequentialCode('tools', 'TOOL');
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final imagePath = (json['imagePath'] as String?)?.trim();

    if (nameCN == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO tools (code, name_cn, name_en, image_path) VALUES (\$1, \$2, \$3, \$4)',
      parameters: [code, nameCN, nameEN ?? '', imagePath],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Tool added', 'code': code}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getTools(Request request) async {
  try {
    final result = await _conn.execute(
        'SELECT code, name_cn, name_en, image_path FROM tools ORDER BY created_at DESC');
    final tools = result.map((row) {
      return {
        'code': row[0],
        'nameCN': row[1],
        'nameEN': row[2],
        'imagePath': row[3],
        'imageUrl': _imageUrlFromPath(row[3] as String?),
      };
    }).toList();

    return Response.ok(
      jsonEncode({'tools': tools}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateTool(Request request, String code) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCN = json['nameCN'] as String?;
    final nameEN = json['nameEN'] as String?;
    final hasImagePath = json.containsKey('imagePath');
    final imagePath = (json['imagePath'] as String?)?.trim();

    if (nameCN == null || nameCN.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    String? finalImagePath;
    if (hasImagePath) {
      final existing = await _conn.execute(
        'SELECT image_path FROM tools WHERE code = \$1',
        parameters: [code],
      );
      if (existing.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Tool not found'}),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
        );
      }

      final oldImagePath = existing.first[0] as String?;
      finalImagePath = imagePath;
      if (oldImagePath != null && oldImagePath != finalImagePath) {
        await _deleteUploadedImage(oldImagePath);
      }
    }

    final result = await _conn.execute(
      hasImagePath
          ? 'UPDATE tools SET name_cn = \$1, name_en = \$2, image_path = \$3 WHERE code = \$4'
          : 'UPDATE tools SET name_cn = \$1, name_en = \$2 WHERE code = \$3',
      parameters: hasImagePath
          ? [nameCN.trim(), (nameEN ?? '').trim(), finalImagePath, code]
          : [nameCN.trim(), (nameEN ?? '').trim(), code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Tool not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Tool updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteTool(Request request, String code) async {
  try {
    final existing = await _conn.execute(
      'SELECT image_path FROM tools WHERE code = \$1',
      parameters: [code],
    );
    final oldImagePath =
        existing.isNotEmpty ? existing.first[0] as String? : null;

    final result = await _conn.execute(
      'DELETE FROM tools WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Tool not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _deleteUploadedImage(oldImagePath);

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Tool deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Menu Categories
Future<Response> _addMenuCategory(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final nameCn = _normalizedOptionalString(json['name_cn']);
    final nameEn = _normalizedOptionalString(json['name_en']);

    if (code == null || nameCn == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO menu_categories (code, name_cn, name_en) VALUES (\$1, \$2, \$3)',
      parameters: [code, nameCn, nameEn],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu category added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getMenuCategories(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT code, name_cn, name_en FROM menu_categories ORDER BY name_cn ASC',
    );
    final categories = result
        .map((row) => {'code': row[0], 'name_cn': row[1], 'name_en': row[2]})
        .toList();

    return Response.ok(
      jsonEncode({'categories': categories}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateMenuCategory(
  Request request,
  String code,
) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCn = _normalizedOptionalString(json['name_cn']);
    final nameEn = _normalizedOptionalString(json['name_en']);

    if (nameCn == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE menu_categories SET name_cn = \$1, name_en = \$2 WHERE code = \$3',
      parameters: [nameCn, nameEn, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Menu category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu category updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteMenuCategory(
  Request request,
  String code,
) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM menu_categories WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Menu category not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu category deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

// Menus
Future<Response> _addMenu(Request request) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final code = _normalizedOptionalString(json['code']);
    final nameCn = _normalizedOptionalString(json['name_cn']);
    final nameEn = _normalizedOptionalString(json['name_en']);
    final categoryCode = _normalizedOptionalString(json['category_code']);

    if (code == null || nameCn == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    await _conn.execute(
      'INSERT INTO menus (code, name_cn, name_en, category_code) VALUES (\$1, \$2, \$3, \$4)',
      parameters: [code, nameCn, nameEn, categoryCode],
    );

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu added'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _getMenus(Request request) async {
  try {
    final result = await _conn.execute(
      'SELECT m.code, m.name_cn, m.name_en, m.category_code, mc.name_cn as category_name_cn FROM menus m LEFT JOIN menu_categories mc ON m.category_code = mc.code ORDER BY m.name_cn ASC',
    );
    final menus = result
        .map((row) => {
              'code': row[0],
              'name_cn': row[1],
              'name_en': row[2],
              'category_code': row[3],
              'category_name_cn': row[4]
            })
        .toList();

    return Response.ok(
      jsonEncode({'menus': menus}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _updateMenu(
  Request request,
  String code,
) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nameCn = _normalizedOptionalString(json['name_cn']);
    final nameEn = _normalizedOptionalString(json['name_en']);
    final categoryCode = _normalizedOptionalString(json['category_code']);

    if (nameCn == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    final result = await _conn.execute(
      'UPDATE menus SET name_cn = \$1, name_en = \$2, category_code = \$3 WHERE code = \$4',
      parameters: [nameCn, nameEn, categoryCode, code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Menu not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu updated'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

Future<Response> _deleteMenu(
  Request request,
  String code,
) async {
  try {
    final result = await _conn.execute(
      'DELETE FROM menus WHERE code = \$1',
      parameters: [code],
    );

    if (result.affectedRows == 0) {
      return Response.notFound(
        jsonEncode({'error': 'Menu not found'}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
      );
    }

    return Response.ok(
      jsonEncode({'success': true, 'message': 'Menu deleted'}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    );
  }
}

void main() async {
  try {
    await initDb();
    print('Database initialized');

    final apiHandler = Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(_router.call);

    final webHandler = _createWebHandler();
    FutureOr<Response> handler(Request request) {
      final path = request.url.path;
      if (path.startsWith('api/') || path.startsWith('uploads/')) {
        return apiHandler(request);
      }
      return webHandler(request);
    }

    // Read server port from config, default to 8081
    final port = int.tryParse(_getConfig('PORT') ?? '8081') ?? 8081;
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('Server listening on http://${server.address.host}:${server.port}');
  } catch (e, st) {
    stderr.writeln('Startup failed: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}
