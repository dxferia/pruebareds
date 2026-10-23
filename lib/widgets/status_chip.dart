import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      RequestStatus.pending => ('Pendiente', AppColors.pendingBg, AppColors.pendingFg),
      RequestStatus.approved => ('Aprobada', AppColors.approvedBg, AppColors.approvedFg),
      RequestStatus.rejected => ('Rechazada', AppColors.rejectedBg, AppColors.rejectedFg),
      RequestStatus.suspended => ('Suspendida', AppColors.suspendedBg, AppColors.suspendedFg),
      RequestStatus.active => ('Activa', AppColors.approvedBg, AppColors.approvedFg),
      RequestStatus.expired => ('Vencida', AppColors.suspendedBg, AppColors.suspendedFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: data.$2, borderRadius: BorderRadius.circular(999)),
      child: Text(data.$1, style: TextStyle(fontSize: 12.5, color: data.$3, fontWeight: FontWeight.w600)),
    );
  }
}
