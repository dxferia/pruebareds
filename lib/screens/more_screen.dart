import 'package:flutter/material.dart';
import '../utils/route_names.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import 'contacto_screen.dart';
import 'encuestas_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/ui_helpers.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Más',
      role: 'Habitante',
      bottomIndex: 3,
      onBottomTap: (i) => residentNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          Text('Servicios comunitarios', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Publicaciones, contacto, encuestas y gestión comunitaria.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          _MenuTile(
            icon: Icons.publish_outlined,
            title: 'Enviar para publicación',
            subtitle: 'Crear una nueva solicitud para revisión',
            onTap: () => Navigator.pushNamed(context, Routes.publish),
          ),
          _MenuTile(icon:Icons.contact_phone_outlined,title:'Mi contacto',subtitle:'Registrar o editar datos de contacto',
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ContactoScreen(api:state.api)))),
          _MenuTile(icon:Icons.quiz_outlined,title:'Encuestas',subtitle:'Responder las preguntas de usabilidad',
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>EncuestasScreen(api:state.api)))),
          _MenuTile(
            icon: Icons.groups_outlined,
            title: 'Gestión comunitaria',
            subtitle: 'Entrar al modo Junta de Acción Comunal',
            onTap: () => _entrarJunta(context),
          ),
          _MenuTile(
            icon: Icons.wifi_off_outlined,
            title: 'Simular pantalla sin conexión',
            subtitle: 'Ver el estado de conectividad variable',
            onTap: () {
              state.toggleOffline(true);
              Navigator.pushNamed(context, Routes.offline);
            },
          ),
          _MenuTile(
            icon: Icons.event_busy_outlined,
            title: 'Ver publicación vencida',
            subtitle: 'Estado histórico sin nuevas solicitudes',
            onTap: () => Navigator.pushNamed(context, Routes.expired),
          ),
          const SizedBox(height: 18),
          const InfoCard(
            background: AppColors.background,
            child: Text('Los datos de publicaciones, solicitudes y encuestas se consultan desde MySQL a través de la API. Configura primero el servidor.'),
          ),
        ],
      ),
    );
  }

  Future<void> _entrarJunta(BuildContext context) async {
    final clave=TextEditingController();
    final key=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Acceso administrativo de la Junta'),
      content:TextField(controller:clave,obscureText:true,decoration:const InputDecoration(labelText:'Clave administrativa del servidor')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,clave.text),child:const Text('Entrar'))]));
    // Never hardcode or persist the secret in the application.
    if(key==null||key.isEmpty)return;
    try {await state.activarJunta(key);
      if(context.mounted)Navigator.of(context).pushNamedAndRemoveUntil(Routes.community,(r)=>false);
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
