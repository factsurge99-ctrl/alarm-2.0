import 'package:flutter/material.dart';
import '../main.dart' show crimson, panel, muted;
import '../models/alarm.dart';

class AlarmEditor extends StatefulWidget {
  const AlarmEditor({super.key, this.existing});
  final Alarm? existing;
  @override State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late TimeOfDay time;
  late final TextEditingController label, message;
  late bool repeat, enabled;
  @override void initState() { super.initState(); final a=widget.existing; time=a==null?TimeOfDay.now():TimeOfDay(hour:a.hour,minute:a.minute); label=TextEditingController(text:a?.label??'Wake up'); message=TextEditingController(text:a?.message??''); repeat=a?.repeatDaily??true; enabled=a?.enabled??true; }
  @override void dispose(){label.dispose();message.dispose();super.dispose();}
  Future<void> save() async {
    final name=label.text.trim(); if(name.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Give your alarm a label first.')));return;}
    final a=widget.existing;
    Navigator.pop(context,Alarm(id:a?.id??DateTime.now().millisecondsSinceEpoch.remainder(2000000000),hour:time.hour,minute:time.minute,label:name,message:message.text.trim(),enabled:enabled,repeatDaily:repeat));
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.existing==null?'Set an alarm':'Edit alarm'),backgroundColor:Colors.transparent),body:SafeArea(child(ListView(padding:const EdgeInsets.fromLTRB(22,10,22,28),children:[
    Center(child(Column(children:[Text(time.format(context),style:const TextStyle(fontSize:64,fontWeight:FontWeight.w300,letterSpacing:-2)),const SizedBox(height:7),TextButton.icon(onPressed:()async{final picked=await showTimePicker(context:context,initialTime:time,builder:(context,child)=>Theme(data:Theme.of(context).copyWith(colorScheme:const ColorScheme.dark(primary:crimson,surface:panel)),child:child!));if(picked!=null)setState(()=>time=picked);},icon:const Icon(Icons.schedule,color:crimson),label:const Text('CHANGE TIME'))]))),
    const SizedBox(height:22),TextField(controller:label,maxLength:32,decoration:const InputDecoration(labelText:'Alarm label',hintText:'Early meeting, gym, ...')),const SizedBox(height:14),TextField(controller:message,maxLength:100,maxLines:2,decoration:const InputDecoration(labelText:'Wake-up message',hintText:'A little motivation for the morning')),
    const SizedBox(height:12),Container(decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(16)),child:Column(children:[SwitchListTile(value:repeat,onChanged:(v)=>setState(()=>repeat=v),activeColor:crimson,title:const Text('Repeat daily'),subtitle:const Text('Ring again each day at this time')),const Divider(height:1,color:Colors.white12),SwitchListTile(value:enabled,onChanged:(v)=>setState(()=>enabled=v),activeColor:crimson,title:const Text('Alarm enabled'),subtitle:const Text('Keep this alarm in your schedule'))])),
    const SizedBox(height:28),SizedBox(height:56,child:ElevatedButton.icon(onPressed:save,icon:const Icon(Icons.check),label:const Text('SAVE ALARM',style:TextStyle(letterSpacing:1.5,fontWeight:FontWeight.w800)),style:ElevatedButton.styleFrom(backgroundColor:crimson,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))))),
    const SizedBox(height:12),const Text('Exact alarm permission is required for reliable on-time wake-ups. The app will guide you to Android settings if needed.',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11,height:1.4)),
  ]))));
}
