import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/navigation.dart';
import '../widgets/status_chip.dart';
import '../widgets/ui_helpers.dart';

class ManagePublicationScreen extends StatefulWidget {
  const ManagePublicationScreen({super.key, required this.state, required this.job});
  final AppState state;
  final JobPost job;

  @override
  State<ManagePublicationScreen> createState() => _ManagePublicationScreenState();
}

class _ManagePublicationScreenState extends State<ManagePublicationScreen> {
  late final TextEditingController people;
  late DateTime from;
  late DateTime to;

  @override
  void initState() {
    super.initState();
    people = TextEditingController(text: '${widget.job.people}');
    from = widget.job.startDate;
    to = widget.job.endDate;
  }

  @override
  void dispose() {
    people.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Gestionar publicación',
      role: 'Junta',
      junta: true,
      showBack: true,
      bottomIndex: 2,
      onBottomTap: (i) => juntaNav(context, i),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          const Align(alignment: Alignment.centerLeft, child: StatusChip(status: RequestStatus.active)),
          const SizedBox(height: 8),
          Text(widget.job.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('Cantidad disponible'),
          const SizedBox(height: 7),
          TextField(controller: people, keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          const Text('Disponible desde'),
          const SizedBox(height: 7),
          _DateInput(date: from, onTap: () => _pick(true)),
          const SizedBox(height: 14),
          const Text('Disponible hasta'),
          const SizedBox(height: 7),
          _DateInput(date: to, onTap: () => _pick(false)),
          const SizedBox(height: 14),
          const Text('Ubicación de referencia'),
          const SizedBox(height: 7),
          InputDecorator(decoration: const InputDecoration(), child: Text(widget.job.location.replaceAll(', Vereda Travesías', ''))),
          const SizedBox(height: 70),
          PrimaryButton(
            label: 'Guardar cambios',
            onPressed: () async {
              try {final count=int.tryParse(people.text)??widget.job.people;
                await widget.state.updateJob(widget.job,people:count,start:from,end:to);
                if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cambios guardados en MySQL.')));
              }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Cerrar publicación',
            danger: true,
            onPressed: () async {
              try {await widget.state.closeJob(widget.job);if(context.mounted)Navigator.of(context).pop();}
              catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pick(bool start) async {
    final current = start ? from : to;
    final value = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2026), lastDate: DateTime(2100));
    if (value != null) setState(() => start ? from = value : to = value);
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
          child: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
        ),
      );
}
