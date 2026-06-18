# BOC 登录系统 - PostgreSQL 版本

## 快速启动

### 1. 启动 PostgreSQL 数据库

在项目根目录执行：

```bash
docker-compose up -d
```

验证数据库运行状态：
```bash
docker ps
```

你应该看到 `boc_postgres` 容器运行中。

### 2. 启动后端 API 服务器

打开新的 PowerShell 窗口，进入后端目录：

```powershell
cd d:\APP\BOC\boc\backend
dart pub get
dart run bin/server.dart
```

服务器应该输出：
```
Database initialized
Admin user created (第一次启动)
Server listening on http://localhost:8080
```

### 3. 运行 Flutter 应用

打开另一个 PowerShell 窗口：

```powershell
cd d:\APP\BOC\boc
flutter pub get
flutter run -d chrome
```

## 登录凭证

### 管理员账号
- 用户名: `ADMIN`
- 密码: `admin`

管理员登录后会导航到 `AdminPage`。

### 普通用户
- 用户名: `testuser`
- 密码: `testpass`

普通用户登录后会导航到 `HomePage`。

## 注册新用户

在后端运行中，向以下端点发送 POST 请求：

```bash
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"newuser","password":"newpass","role":"USER"}'
```

## API 端点

### POST /api/login
请求体：
```json
{
  "username": "ADMIN",
  "password": "admin"
}
```

响应（成功）：
```json
{
  "success": true,
  "role": "ADMIN"
}
```

### POST /api/register
请求体：
```json
{
  "username": "newuser",
  "password": "newpass",
  "role": "USER"
}
```

响应（成功）：
```json
{
  "success": true,
  "message": "User registered"
}
```

## 停止服务

### 停止 Flutter 应用
在运行 `flutter run` 的终端按 `q`。

### 停止后端服务器
在运行 `dart run bin/server.dart` 的终端按 `Ctrl+C`。

### 停止 PostgreSQL
```bash
docker-compose down
```

保留数据卷：
```bash
docker-compose down -v
```

## 故障排查

### 后端连接失败
确保 PostgreSQL 容器已启动：
```bash
docker-compose up -d
docker logs boc_postgres
```

### 登录请求失败
确保后端服务器在 `http://localhost:8080` 运行。

### 端口冲突
如果 5432 或 8080 已被占用，编辑 `docker-compose.yaml` 或后端代码修改端口。

## 项目结构

```
boc/
├── backend/                   # Dart 后端 API 服务器
│   ├── bin/
│   │   └── server.dart       # 主服务器程序
│   └── pubspec.yaml          # 后端依赖
├── lib/
│   ├── pages/
│   │   ├── login_page.dart   # 登录 UI
│   │   ├── admin_page.dart   # 管理员页面
│   │   └── home_page.dart    # 用户主页
│   ├── services/
│   │   └── http_auth_service.dart  # HTTP 认证客户端
│   └── main.dart             # Flutter 应用入口
├── docker-compose.yaml       # PostgreSQL 容器配置
└── pubspec.yaml              # Flutter 依赖
```
