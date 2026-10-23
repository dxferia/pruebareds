import 'package:flutter/material.dart';

class EstadoMensaje extends StatelessWidget {
  const EstadoMensaje({super.key,required this.mensaje,this.icono=Icons.info_outline,this.onReintentar});
  final String mensaje;
  final IconData icono;
  final VoidCallback? onReintentar;
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
    mainAxisSize:MainAxisSize.min,children:[Icon(icono,size:42,color:Theme.of(context).colorScheme.primary),
    const SizedBox(height:14),Text(mensaje,textAlign:TextAlign.center),if(onReintentar!=null)...[
    const SizedBox(height:16),OutlinedButton.icon(onPressed:onReintentar,icon:const Icon(Icons.refresh),label:const Text('Reintentar'))]])));
}
void mostrarMensaje(BuildContext context,String texto){
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(texto)));
}
