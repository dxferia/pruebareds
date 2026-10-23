import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';

class ContactoScreen extends StatefulWidget {
  const ContactoScreen({super.key,required this.api});
  final ApiService api;
  @override State<ContactoScreen> createState()=>_ContactoScreenState();
}
class _ContactoScreenState extends State<ContactoScreen> {
  final formulario=GlobalKey<FormState>();
  final nombre=TextEditingController(),correo=TextEditingController(),telefono=TextEditingController();
  String medio='WHATSAPP';bool cargando=true,guardando=false;String? error;String? idActual;
  @override void initState(){super.initState();_cargar();}
  Future<void> _cargar() async {
    try {final p=await widget.api.miContacto();if(!mounted)return;
      if(p!=null){nombre.text=p.nombre;correo.text=p.correo;telefono.text=p.telefono;medio=p.medioPreferido;idActual=p.id;}
    }catch(e){if(mounted)error=e.toString();}
    if(mounted)setState(()=>cargando=false);
  }
  @override void dispose(){nombre.dispose();correo.dispose();telefono.dispose();super.dispose();}
  Future<void> _guardar() async {
    if(!formulario.currentState!.validate())return;
    setState((){guardando=true;error=null;});
    try {final p=await widget.api.guardarContacto({'nombre':nombre.text.trim(),
      'correo':correo.text.trim(),'telefono':telefono.text.trim(),'medio_preferido':medio});
      if(!mounted)return;
      setState(()=>idActual=p.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Datos guardados en MySQL.')));
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>guardando=false);}
  }
  @override Widget build(BuildContext context)=>AppShell(title:'Mi contacto',role:'Habitante',bottomIndex:3,
    onBottomTap:(i)=>residentNav(context,i),body:cargando?const Center(child:CircularProgressIndicator()):
    Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:ListView(
      padding:const EdgeInsets.all(20),children:[
      Text('Mi contacto',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:8),const Text('Tus datos se guardan en MySQL y sirven para enviar solicitudes. No se requiere contraseña.'),
      const SizedBox(height:8),if(idActual!=null)Text('Perfil local: $idActual',style:Theme.of(context).textTheme.bodySmall),
      const SizedBox(height:18),Card(child:Padding(padding:const EdgeInsets.all(20),child:Form(key:formulario,child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextFormField(controller:nombre,decoration:const InputDecoration(labelText:'Nombre completo',prefixIcon:Icon(Icons.person_outline)),
            maxLength:150,validator:(v)=>(v??'').trim().length<2?'Ingresa el nombre completo.':null),
          const SizedBox(height:10),TextFormField(controller:correo,keyboardType:TextInputType.emailAddress,
            maxLength:254,decoration:const InputDecoration(labelText:'Correo electrónico',prefixIcon:Icon(Icons.email_outlined)),
            validator:(v)=>RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v??'').trim())?null:'Correo electrónico no válido.'),
          const SizedBox(height:10),TextFormField(controller:telefono,keyboardType:TextInputType.phone,maxLength:30,
            decoration:const InputDecoration(labelText:'Teléfono',prefixIcon:Icon(Icons.phone_outlined)),
            validator:(v)=>RegExp(r'^\+?[0-9()\s-]{7,30}$').hasMatch((v??'').trim())?null:'Teléfono no válido.'),
          const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:medio,
            decoration:const InputDecoration(labelText:'Medio de contacto preferido'),items:const [
              DropdownMenuItem(value:'WHATSAPP',child:Text('WhatsApp')),
              DropdownMenuItem(value:'LLAMADA',child:Text('Llamada')),
              DropdownMenuItem(value:'CORREO',child:Text('Correo electrónico'))],
            onChanged:(v){if(v!=null)setState(()=>medio=v);}),
          if(error!=null)...[const SizedBox(height:10),Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
          const SizedBox(height:16),ElevatedButton.icon(onPressed:guardando?null:_guardar,
            icon:guardando?const SizedBox(width:16,height:16,child:CircularProgressIndicator()):const Icon(Icons.save_outlined),
            label:Text(guardando?'Guardando...':idActual==null?'Registrar contacto':'Actualizar contacto')),
        ])))),
      const SizedBox(height:14),const Text('El identificador de edición se conserva en este dispositivo. Si borras los datos locales o cambias de dispositivo, no se recupera automáticamente. No compartas ese identificador.'),
    ]))));
}
