import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/date_helpers.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    this.onAddToHomeScreen,
    this.onEdit,
    super.key,
  });

  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback? onAddToHomeScreen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String countText = DateHelpers.eventCountCompactDescription(event);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Color(event.color),
          child: Text(event.emoji),
        ),
        title: Text(event.title),
        subtitle: Text(
            '${DateFormat.yMMMd().format(event.date)} • ${event.category}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              countText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_outlined),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                switch (value) {
                  case 'edit':
                    onEdit?.call();
                  case 'add_widget':
                    onAddToHomeScreen?.call();
                  case 'delete':
                    onDelete.call();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.edit_rounded, size: 16),
                      const SizedBox(width: 12),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'add_widget',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.add_to_home_screen_rounded, size: 16),
                      const SizedBox(width: 12),
                      const Text('Add to Home'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
