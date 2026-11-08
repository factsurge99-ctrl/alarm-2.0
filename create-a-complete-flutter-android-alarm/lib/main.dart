import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/alarm.dart';
import 'screens/alarm_editor.dart';
import 'services/alarm_bridge.dart';

const ink = Color(0xFF090809);
const panel = Color(0xFF171315);
const crimson = Color(0xFFE32645);
const muted = Color(0xFFB8AEB2);

void main() => runApp(const MistressAlarmApp());

class MistressAlarmApp extends StatelessWidget {
  const MistressAlarmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Mistress Alarm',
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: ink, colorScheme: const ColorScheme.dark(primary: crimson, surface: panel),
      appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), labelStyle: const TextStyle(color: muted)),
      switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? crimson : Colors.grey), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? crimson.withValues(alpha: .45) : Colors.white12)),
    ), home: const HomeScreen());
}

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  List<Alarm> alarms = [];
  bool exact = false, notifications = false, fullScreen = false;
  Map<String, dynamic>? ringingAlarm;
  @override void initState() { super.initState(); AlarmBridge.alarmEvents.listen((raw){try{ringingAlarm=Map<String,dynamic>.from(jsonDecode(raw));_showChallenge();}catch(_){}}); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('alarms') ?? '[]';
    try { alarms = (jsonDecode(raw) as List).map((e) => Alarm.fromJson(Map<String, dynamic>.from(e))).toList(); } catch (_) { alarms = []; }
    alarms.sort((a,b) => (a.hour*60+a.minute).compareTo(b.hour*60+b.minute));
    exact = await AlarmBridge.exactPermission(); notifications = await AlarmBridge.notificationPermission(); fullScreen = await AlarmBridge.fullScreenPermission();
    if (exact) await AlarmBridge.save(Alarm.encodeAll(alarms));
    final initial = await AlarmBridge.initialAlarm();
    if (initial != null && initial.isNotEmpty) { try { ringingAlarm = Map<String,dynamic>.from(jsonDecode(initial)); } catch (_) {} }
    if (mounted) {
      setState(() {});
      if (ringingAlarm != null) _showChallenge();
    }
  }
  Future<void> _showChallenge() async {
    final alarm = ringingAlarm;
    if (alarm == null || !mounted) return;
    ringingAlarm = null;
    await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog:true,builder:(_)=>ChallengeScreen(alarm:alarm,onClose:()=>Navigator.of(context).pop())));
  }
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = Alarm.encodeAll(alarms);
    await prefs.setString('alarms', encoded);
    exact = await AlarmBridge.exactPermission();
    if (exact) await AlarmBridge.save(encoded);
    if (mounted) setState(() {});
  }
  Future<void> _permissions() async {
    if (!notifications) await AlarmBridge.requestNotificationPermission();
    if (!exact) await AlarmBridge.requestExactPermission();
    if (!fullScreen) await AlarmBridge.requestFullScreenPermission();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    exact = await AlarmBridge.exactPermission(); notifications = await AlarmBridge.notificationPermission(); fullScreen = await AlarmBridge.fullScreenPermission();
    if (mounted) setState(() {});
  }
  Future<void> _edit([Alarm? old]) async {
    final result = await Navigator.push<Alarm>(context, MaterialPageRoute(builder: (_) => AlarmEditor(existing: old)));
    if (result == null) return;
    if (old == null) { alarms.add(result); } else { alarms[alarms.indexWhere((a) => a.id == old.id)] = result; }
    await _persist();
  }
  String _nextLabel() {
    final now = DateTime.now();
    final upcoming = alarms.where((a) => a.enabled).map((a) { var d = DateTime(now.year,now.month,now.day,a.hour,a.minute); if (!d.isAfter(now)) d=d.add(const Duration(days:1)); return d; }).toList()..sort();
    if (upcoming.isEmpty) return 'No alarms set';
    final d = upcoming.first; final diff = d.difference(now);
    return '${DateFormat('EEE, MMM d • h:mm a').format(d)}  ·  ${diff.inHours}h ${diff.inMinutes.remainder(60)}m from now';
  }
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(body: SafeArea(child: CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(22,22,22,8), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 44,height:44,decoration: BoxDecoration(color: crimson.withValues(alpha:.15),borderRadius: BorderRadius.circular(14)),child: const Icon(Icons.notifications_active_outlined,color:crimson)),const SizedBox(width:12),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('MISTRESS ALARM',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,letterSpacing:2.1,color:crimson)),Text('Your morning, on your terms.',style:TextStyle(color:muted,fontSize:12))]),const Spacer(),IconButton(onPressed:_permissions,icon:Icon(exact&&notifications?Icons.verified_user:Icons.warning_amber_rounded,color:exact&&notifications?Colors.greenAccent:crimson),tooltip:'Alarm permissions')]),
        const SizedBox(height:30), Text(DateFormat('EEEE, MMMM d').format(now).toUpperCase(),style:const TextStyle(color:muted,letterSpacing:2,fontSize:11,fontWeight:FontWeight.w700)),
        const SizedBox(height:6), Text(DateFormat('h:mm').format(now),style:const TextStyle(fontSize:66,fontWeight:FontWeight.w300,height:1.05,letterSpacing:-3)),
        const SizedBox(height:18), Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF35121B),Color(0xFF1A1216)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(20),border:Border.all(color:crimson.withValues(alpha:.35))),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:crimson.withValues(alpha:.18),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.bedtime_outlined,color:crimson)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NEXT WAKE-UP',style:TextStyle(color:muted,fontSize:10,letterSpacing:1.7,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(_nextLabel(),style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14))]))])),
        if (!exact || !notifications || !fullScreen) ...[const SizedBox(height:14), InkWell(onTap:_permissions,borderRadius:BorderRadius.circular(14),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF29151B),borderRadius:BorderRadius.circular(14),border:Border.all(color:crimson.withValues(alpha:.35))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,color:crimson,size:20),const SizedBox(width:10),Expanded(child:Text('Allow notifications, exact alarms, and full-screen alarm access so your wake-up happens on time and can open the challenge.',style:TextStyle(color:Colors.white.withValues(alpha:.85),height:1.35,fontSize:12))),const Icon(Icons.chevron_right,color:muted)])))],
        const SizedBox(height:28),Row(children:[const Text('YOUR ALARMS',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.8,fontSize:12)),const Spacer(),Text('${alarms.length} SET',style:const TextStyle(color:muted,fontSize:10,letterSpacing:1.4))]),
      ]))),
      if (alarms.isEmpty) SliverPadding(padding:const EdgeInsets.fromLTRB(22,14,22,8),sliver:SliverToBoxAdapter(child:Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18)),child:const Column(children:[Icon(Icons.alarm_add,color:crimson,size:32),SizedBox(height:10),Text('Your mornings are yours to set.',style:TextStyle(fontWeight:FontWeight.w600)),SizedBox(height:5),Text('Create an alarm and choose your wake-up message.',style:TextStyle(color:muted,fontSize:12),textAlign:TextAlign.center)]))))
      else SliverPadding(padding:const EdgeInsets.symmetric(horizontal:22),sliver:SliverList(delegate:SliverChildBuilderDelegate((context,index){final a=alarms[index];final tm=DateTime(2000,1,1,a.hour,a.minute);return Dismissible(key:ValueKey(a.id),direction:DismissDirection.endToStart,background:Container(alignment:Alignment.centerRight,padding:const EdgeInsets.only(right:24),margin:const EdgeInsets.only(bottom:12),decoration:BoxDecoration(color:crimson,borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.delete_outline,color:Colors.white)),onDismissed:(_){alarms.removeWhere((x)=>x.id==a.id);_persist();},child:GestureDetector(onTap:()=>_edit(a),child:Container(margin:const EdgeInsets.only(top:12),padding:const EdgeInsets.fromLTRB(17,16,10,15),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:a.enabled?Colors.white.withValues(alpha:.06):Colors.transparent)),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(DateFormat('h:mm').format(tm),style:TextStyle(fontSize:39,fontWeight:FontWeight.w300,color:a.enabled?Colors.white:muted,height:1.1)),const SizedBox(height:7),Text(a.label,style:TextStyle(fontWeight:FontWeight.w700,color:a.enabled?Colors.white:muted)),const SizedBox(height:3),Text('${DateFormat('a').format(tm)}  ·  ${a.repeatDaily?'Every day':'Once'}${a.message.isNotEmpty?'  ·  ${a.message}':''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:muted))])),Switch(value:a.enabled,onChanged:(v){alarms[alarms.indexWhere((x)=>x.id==a.id)]=a.copyWith(enabled:v);_persist();}),PopupMenuButton<String>(icon:const Icon(Icons.more_vert,color:muted),onSelected:(v){if(v=='edit')_edit(a);if(v=='delete'){alarms.removeWhere((x)=>x.id==a.id);_persist();}},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit alarm')),PopupMenuItem(value:'delete',child:Text('Delete'))])]))));},childCount:alarms.length))),
    ]))),
      floatingActionButton: FloatingActionButton.extended(onPressed:()=>_edit(), backgroundColor:crimson, foregroundColor:Colors.white, icon:const Icon(Icons.add_alarm), label:const Text('SET ALARM',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.2))),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class ChallengeScreen extends StatefulWidget { const ChallengeScreen({super.key,required this.alarm,required this.onClose}); final Map<String,dynamic> alarm; final VoidCallback onClose; @override State<ChallengeScreen> createState()=>_ChallengeScreenState(); }
class _ChallengeScreenState extends State<ChallengeScreen>{late int x,y,answer;final input=TextEditingController();String? error;@override void initState(){super.initState();final r=Random();x=r.nextInt(8)+3;y=r.nextInt(8)+2;answer=x+y;}Future<void> dismiss()async{await AlarmBridge.dismiss();widget.onClose();} @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF10080B),body:SafeArea(child(Padding(padding:const EdgeInsets.all(26),child(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Spacer(),const Icon(Icons.notifications_active,color:crimson,size:54),const SizedBox(height:22),const Text('RISE AND CLAIM THE DAY',textAlign:TextAlign.center,style:TextStyle(color:crimson,fontSize:12,letterSpacing:2,fontWeight:FontWeight.w800)),const SizedBox(height:20),Text('${widget.alarm['label']??'Wake up'}',textAlign:TextAlign.center,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700)),if((widget.alarm['message']??'').toString().isNotEmpty)...[const SizedBox(height:10),Text(widget.alarm['message'].toString(),textAlign:TextAlign.center,style:const TextStyle(color:muted))],const SizedBox(height:50),Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:crimson.withValues(alpha:.3))),child:Column(children:[const Text('SOLVE TO DISMISS',style:TextStyle(color:muted,fontSize:11,letterSpacing:1.7,fontWeight:FontWeight.bold)),const SizedBox(height:18),Text('$x + $y = ?',style:const TextStyle(fontSize:42,fontWeight:FontWeight.w300)),const SizedBox(height:20),TextField(controller:input,keyboardType:TextInputType.number,textAlign:TextAlign.center,style:const TextStyle(fontSize:24),decoration:const InputDecoration(hintText:'Your answer',labelText:'Answer'),onSubmitted:(_)=>submit())])),if(error!=null)...[const SizedBox(height:10),Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:crimson))],const SizedBox(height:22),ElevatedButton(onPressed:submit,style:ElevatedButton.styleFrom(backgroundColor:crimson,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:17),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:const Text('DISMISS ALARM',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.4))),TextButton(onPressed:()async{await AlarmBridge.snooze();widget.onClose();},child:const Text('SNOOZE FOR 5 MINUTES',style:TextStyle(color:muted,letterSpacing:1))),const Spacer(),const Text('A clear mind is a powerful start.',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:12))])))));
void submit(){if(int.tryParse(input.text.trim())==answer){dismiss();}else{setState(()=>error='Not quite. Try once more.');input.clear();}}}
