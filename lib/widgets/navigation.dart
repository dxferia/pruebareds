import 'package:flutter/material.dart';
import '../utils/route_names.dart';

void residentNav(BuildContext context, int index) {
  final route = switch (index) {
    0 => Routes.home,
    1 => Routes.jobs,
    2 => Routes.myRequests,
    _ => Routes.more,
  };
  if (ModalRoute.of(context)?.settings.name == route) return;
  Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
}

void juntaNav(BuildContext context, int index) {
  final route = switch (index) {
    0 => Routes.community,
    1 => Routes.community,
    2 => Routes.juntaPublications,
    _ => Routes.access,
  };
  if (ModalRoute.of(context)?.settings.name == route) return;
  Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
}
