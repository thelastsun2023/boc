import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(String url, String name, String features);

extension type JSWindow._(JSObject _) implements JSObject {
  external JSDocument? get document;
  external void focus();
  external void print();
  external void close();
}

extension type JSDocument._(JSObject _) implements JSObject {
  external void open();
  external void write(String text);
  external void close();
}

Future<bool> printHtmlDocument({
  required String title,
  required String htmlContent,
}) async {
  final window = _windowOpen(
    '',
    '_blank',
    '',
  ) as JSWindow?;
  if (window == null) {
    return false;
  }

  final document = window.document;
  if (document == null) {
    return false;
  }

  document.open();
  document.write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$title</title>
    <style>
      .print-toolbar {
        position: sticky;
        top: 0;
        z-index: 10;
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 12px 24px;
        background: #ffffff;
        border-bottom: 1px solid #e5e7eb;
      }
      .print-toolbar button {
        border: 0;
        border-radius: 8px;
        background: #2563eb;
        color: #ffffff;
        padding: 8px 14px;
        font-size: 14px;
        cursor: pointer;
      }
      .print-container {
        padding: 8px 0 24px;
      }
      @media print {
        .print-toolbar {
          display: none;
        }
      }
    </style>
    <script>
      function startPrint() {
        setTimeout(function () {
          window.focus();
          window.print();
        }, 350);
      }
    </script>
  </head>
  <body onload="startPrint()">
    <div class="print-toolbar">
      <div>原材料打印预览</div>
      <button onclick="startPrint()">打印</button>
    </div>
    <div class="print-container">
      $htmlContent
    </div>
  </body>
</html>
''');
  document.close();
  window.focus();
  return true;
}