import 'package:flutter/material.dart';
import '../models/encuesta.dart';
import '../services/api_service.dart';
import '../widgets/estados.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/brand_strip.dart';

class EncuestasScreen extends StatefulWidget {
  const EncuestasScreen({super.key,required this.api});
  final ApiService api;
  @override State<EncuestasScreen> createState()=>_EncuestasScreenState();
}
class _EncuestasScreenState extends State<EncuestasScreen> {
  late Future<List<Encuesta>> _futuro;
  @override
  void initState() {
    super.initState();
    _futuro = widget.api.encuestas();
  }
  void _cargar() {
    setState(() { _futuro = widget.api.encuestas(); });
  }
  @override Widget build(BuildContext context)=>AppShell(title:'Encuestas',role:'Habitante',bottomIndex:3,
    onBottomTap:(i)=>residentNav(context,i),body:ListView(padding:const EdgeInsets.all(20),children:[
    const BrandStrip(),const SizedBox(height:20),
    Text('Encuestas',style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:8),const Text('Ayúdanos a mejorar la aplicación. Puedes responder sin iniciar sesión.'),
    const SizedBox(height:18),FutureBuilder<List<Encuesta>>(future:_futuro,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError)return EstadoMensaje(mensaje:snapshot.error.toString(),icono:Icons.wifi_off,onReintentar:_cargar);
      if(snapshot.data!.isEmpty)return const EstadoMensaje(mensaje:'Por el momento no hay encuestas disponibles.',icono:Icons.inbox_outlined);
      return Column(children:snapshot.data!.map((e)=>Card(child:ListTile(
        title:Text(e.titulo),subtitle:Text('${e.descripcion}\nVersión ${e.version}'),isThreeLine:true,
        trailing:const Icon(Icons.arrow_forward_ios),onTap:()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>EncuestaDetalleScreen(api:widget.api,id:e.id)))))).toList());
    }),
  ]));
}

class EncuestaDetalleScreen extends StatefulWidget {
  const EncuestaDetalleScreen({super.key,required this.api,required this.id});
  final ApiService api;
  final String id;
  @override State<EncuestaDetalleScreen> createState()=>_EncuestaDetalleScreenState();
}
class _EncuestaDetalleScreenState extends State<EncuestaDetalleScreen> {
  late Future<Encuesta> _futuro;
  final Map<int,dynamic> _respuestas={};
  final Map<int,TextEditingController> _textos={};
  bool enviando=false,enviada=false;
  String? error;
  @override void initState(){super.initState();_futuro=widget.api.encuesta(widget.id);}
  @override void dispose(){for(final c in _textos.values){c.dispose();}super.dispose();}
  void _marcar(int id,dynamic respuesta)=>setState(()=>_respuestas[id]=respuesta);
  Widget _contenidoPregunta(Pregunta p){
    final valor=_respuestas[p.id];
    if(p.tipo=='ESCALA') { return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:8,runSpacing:8,children:[for(var n=1;n<=5;n++)
        ChoiceChip(label:Text('$n'),tooltip:['Totalmente en desacuerdo','En desacuerdo',
          'Ni de acuerdo ni en desacuerdo','De acuerdo','Totalmente de acuerdo'][n-1],
          selected:valor==n,onSelected:enviando?null:(_)=>_marcar(p.id,n))]),
      const SizedBox(height:7),Text('1 = Totalmente en desacuerdo · 5 = Totalmente de acuerdo',
        style:Theme.of(context).textTheme.bodySmall)
    ]); }
    if(p.tipo=='TEXTO'){
      final controller=_textos.putIfAbsent(p.id,()=>TextEditingController());
      return TextField(controller:controller,maxLines:3,maxLength:2000,enabled:!enviando,
        decoration:const InputDecoration(labelText:'Tu respuesta',border:OutlineInputBorder()),
        onChanged:(v)=>_marcar(p.id,v));
    }
    if (p.tipo == 'UNICA') {
      return RadioGroup<String>(
        groupValue: valor as String?,
        onChanged: (String? v) {
          if (!enviando && v != null) _marcar(p.id, v);
        },
        child: Column(children: [for (final opcion in p.opciones)
          RadioListTile<String>(title: Text(opcion), value: opcion, enabled: !enviando),
        ]),
      );
    }
    if(p.tipo=='MULTIPLE'){
      final seleccion=valor is List<String>?valor:<String>[];
      return Column(children:[for(final opcion in p.opciones)
        CheckboxListTile(title:Text(opcion),value:seleccion.contains(opcion),
          onChanged:enviando?null:(v){final nueva=[...seleccion];if(v==true){nueva.add(opcion);}else{nueva.remove(opcion);} _marcar(p.id,nueva);})]);
    }
    return const Text('Tipo de pregunta no soportado.');
  }
  bool _valida(Encuesta e){
    for(final p in e.preguntas){
      if(!p.obligatoria)continue;
      final v=_respuestas[p.id];
      if(v==null || (v is String&&v.trim().isEmpty) || (v is List&&v.isEmpty))return false;
    }
    return true;
  }
  Future<void> _enviar(Encuesta e) async {
    if(!_valida(e)){setState(()=>error='Responde todas las preguntas obligatorias.');return;}
    setState((){enviando=true;error=null;});
    try {final datos=<int,dynamic>{};
      for(final p in e.preguntas){final v=_respuestas[p.id];
        if(v!=null && !(v is String&&v.trim().isEmpty) && !(v is List&&v.isEmpty))datos[p.id]=v;}
      await widget.api.enviarEncuesta(e.id,datos);
      if(mounted)setState(()=>enviada=true);
    }catch(ex){if(mounted)setState(()=>error=ex.toString());}
    finally{if(mounted)setState(()=>enviando=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Encuesta de Travesías Conecta')),
    body:FutureBuilder<Encuesta>(future:_futuro,builder:(context,snapshot){
      if(!snapshot.hasData){if(snapshot.hasError)return EstadoMensaje(mensaje:snapshot.error.toString(),icono:Icons.wifi_off);
        return const Center(child:CircularProgressIndicator());}
      final e=snapshot.data!;
      if(enviada)return const EstadoMensaje(mensaje:'¡Gracias por tu opinión! Tu encuesta se guardó correctamente.',icono:Icons.check_circle_outline);
      final contestadas=e.preguntas.where((p){final v=_respuestas[p.id];return v!=null&&!(v is String&&v.trim().isEmpty)&&!(v is List&&v.isEmpty);}).length;
      return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:820),child:ListView(
        padding:const EdgeInsets.all(16),children:[const BrandStrip(),const SizedBox(height:20),
        Text(e.titulo,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:8),Text(e.descripcion),
        const SizedBox(height:16),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('Tu progreso',style:Theme.of(context).textTheme.titleMedium),Text('$contestadas de ${e.preguntas.length}')]),
          const SizedBox(height:12),LinearProgressIndicator(value:e.preguntas.isEmpty?0:contestadas/e.preguntas.length),
        ]))),const SizedBox(height:12),
        for(final p in e.preguntas) Padding(padding:const EdgeInsets.only(bottom:12),child:Card(child:Padding(
          padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${p.numero}. ${p.texto}${p.obligatoria?' *':''}',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:14),_contenidoPregunta(p),
          ])))),
        if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        Text('Las respuestas se guardan en la base de datos. Si tienes un contacto registrado en este dispositivo, se vincularán a ese perfil; si no, serán anónimas.',
          style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:12),
        ElevatedButton.icon(onPressed:enviando||e.preguntas.isEmpty?null:()=>_enviar(e),
          icon:enviando?const SizedBox(width:16,height:16,child:CircularProgressIndicator()):const Icon(Icons.send),
          label:Text(enviando?'Enviando...':'Enviar respuestas')),
        const SizedBox(height:22),
      ])));
    }));
}
