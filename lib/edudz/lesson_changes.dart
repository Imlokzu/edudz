import 'package:edudz/api.dart';
import 'package:flutter/material.dart';
import 'controller.dart';

class LessonChangeBadges extends StatelessWidget {
  const LessonChangeBadges(
      {super.key,
      required this.controller,
      required this.changes,
      this.onDark = false});
  final SchoolController controller;
  final LessonChanges changes;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final dark = onDark || Theme.of(context).brightness == Brightness.dark;
    Widget badge(String label, IconData icon, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? .22 : .1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: dark ? color.shade100 : color.shade800),
          const SizedBox(width: 5),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dark ? color.shade100 : color.shade800)))
        ]));
    return Wrap(spacing: 7, runSpacing: 7, children: [
      if (changes.cancelled)
        badge(c.tr('Ausfall · скасовано', 'Ausfall · cancelled', 'Ausfall'),
            Icons.event_busy, Colors.red),
      if (!changes.cancelled && changes.teacher)
        badge(c.tr('Заміна', 'Substitution', 'Vertretung'),
            Icons.person_outline, Colors.orange),
      if (!changes.cancelled && changes.room)
        badge(c.tr('Інший кабінет', 'Room change', 'Raumänderung'),
            Icons.meeting_room_outlined, Colors.blue),
      if (!changes.cancelled && changes.schoolClass)
        badge(c.tr('Інший клас', 'Class change', 'Klassenänderung'),
            Icons.groups_outlined, Colors.purple),
      if (!changes.cancelled && changes.subject)
        badge(c.tr('Інший предмет', 'Subject change', 'Fachänderung'),
            Icons.swap_horiz, Colors.teal),
      if (!changes.cancelled && changes.changed && !changes.hasSpecificChange)
        badge(c.tr('Зміни у розкладі', 'Schedule change', 'Änderung'),
            Icons.info_outline, Colors.orange),
    ]);
  }
}
