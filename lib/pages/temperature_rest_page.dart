import 'package:flutter/material.dart';
import '../services/system_service.dart';

class TemperatureRestPage extends StatefulWidget {
  const TemperatureRestPage({super.key});
  @override
  State<TemperatureRestPage> createState() => _RestState();
}
class _RestState extends State<TemperatureRestPage> {
  final service = SystemService();
  List<dynamic> days = [];
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final data = await service.getTemperatureSchedule(); if(mounted) setState(() {days=data['days'];error=null;}); }
    catch(e) {if(mounted) setState(() => error='$e');}
  }
  Future<void> change(String day, bool remove) async {
    try {await service.saveTemperatureSchedule({'day':day,'remove':remove}); await load();}
    catch(e) {if(mounted) setState(() => error='$e');}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('休息日 / Rest Days')),
    body: Column(children:[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            icon: const Icon(Icons.add, size: 28),
            label: const Text('增加休息日 / Add Rest Day'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
      final date=await showDatePicker(context:context, initialDate:DateTime.now(), firstDate:DateTime(2026,5), lastDate:DateTime(2100));
      if(date!=null) await change(date.toIso8601String().substring(0,10),false);
            },
          ),
        ),
      ),
      if(error!=null) Text(error!), const Padding(padding:EdgeInsets.all(16),child:Text('休息日跳过自动生成；已有记录保留。')),Expanded(child:ListView(children:[for(final day in days) ListTile(title:Text('$day'), trailing:IconButton(icon:const Icon(Icons.delete_outline), onPressed:() async {
      final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text('删除休息日 $day？'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('删除'))]));
      if(yes==true) await change('$day',true);
    }))]))]),
  );
}
