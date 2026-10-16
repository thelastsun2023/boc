import 'dart:convert';
import 'package:boc/pages/procurement_page.dart';
import 'package:boc/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('supplier filtering, quantity saving and daily completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionService().token = 'test-session';
    addTearDown(SessionService().clear);
    final lines = [
      for (var i = 0; i < 2; i++)
        <String, dynamic>{
          'storeCode': 'S001',
          'storeName': 'Store One',
          'date': '2026-10-16',
          'code': 'RAW$i',
          'nameCN': '商品$i',
          'nameEN': 'Product $i',
          'unit': 'bag',
          'supplierCode': 'SUP$i',
          'supplierName': i == 0 ? 'Supplier Alpha' : 'Supplier Beta',
          'demandQuantity': i + 2,
          'purchaseQuantity': i + 2,
          'purchased': false,
          'sources': ['商城 #1', '点货 #2'],
          'submitters': ['first', 'second'],
        },
    ];
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-session');
      if (request.method == 'PUT') {
        final data = jsonDecode(request.body);
        final item = lines.firstWhere((i) => i['code'] == data['code']);
        item['purchaseQuantity'] = data['purchaseQuantity'];
        item['purchased'] = data['purchased'];
        return http.Response('{"success":true}', 200);
      }
      return http.Response(
        jsonEncode({
          'orders': [
            {
              'storeCode': 'S001',
              'storeName': 'Store One',
              'date': '2026-10-16',
              'items': lines,
              'purchased': lines.every((i) => i['purchased'] == true),
              'purchasedCount': lines
                  .where((i) => i['purchased'] == true)
                  .length,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProcurementPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Product 0'), findsOneWidget);
      expect(find.text('Product 1'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '采购数量').first,
        '4.5',
      );
      await tester.tap(find.byTooltip('保存采购数量').first);
      await tester.pumpAndSettle();
      expect(lines[0]['purchaseQuantity'], 4.5);
      expect(lines[0]['demandQuantity'], 2);
      await tester.tap(find.widgetWithText(ActionChip, '未采购').first);
      await tester.pumpAndSettle();
      expect(lines[0]['purchased'], true);
      expect(find.textContaining('未采购  ·  1 / 2'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, '未采购'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已采购  ·  2 / 2'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('采购单位 ↓').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Product 1')).dy,
        lessThan(tester.getTopLeft(find.text('Product 0')).dy),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supplier Beta').last);
      await tester.pumpAndSettle();
      expect(find.text('Product 0'), findsNothing);
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.textContaining('已采购  ·  2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
