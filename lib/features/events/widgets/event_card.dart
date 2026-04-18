import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/date_helpers.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
  static final DateFormat _dateFormat = DateFormat.yMMMd();

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

    return RepaintBoundary(
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: Color(event.color),
            child: Text(event.emoji),
          ),
          title: Text(event.title),
          subtitle: Text('${_dateFormat.format(event.date)} • ${event.category}'),
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
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'add_widget',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.add_to_home_screen_rounded, size: 16),
                        SizedBox(width: 12),
                        Text('Add to Home'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
