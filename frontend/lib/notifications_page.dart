import 'env.dart'; 
import 'package:flutter/material.dart';

class NotificationsResult {
  final List<int> readIndexes;
  NotificationsResult(this.readIndexes);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.items});

  /// 어떤 모델이든 OK. 하지만 내부에서는 Map으로만 접근한다.
  /// 기대 키: title / body / read (bool)
  final List<dynamic> items;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Set<int> _read = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, NotificationsResult(_read.toList()));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알림'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  _read.addAll(List.generate(widget.items.length, (i) => i));
                  Navigator.pop(context, NotificationsResult(_read.toList()));
                },
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('모두 읽음'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body:
            widget.items.isEmpty
                ? const Center(child: Text('알림이 없어요.'))
                : ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    // ✅ item은 Map으로만 다룬다 (메서드 접근 금지)
                    final Map<String, dynamic> item =
                        (widget.items[i] as Map).cast<String, dynamic>();

                    final String title = (item['title'] ?? '').toString();
                    final String body = (item['body'] ?? '').toString();
                    final bool readFlag = (item['read'] as bool?) ?? false;

                    final alreadyRead = readFlag || _read.contains(i);

                    return ListTile(
                      leading: Icon(
                        alreadyRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color:
                            alreadyRead
                                ? const Color(0xFF004377)
                                : const Color(0xFF004377),
                      ),

                      title: Text(title),
                      subtitle: Text(body),
                      trailing:
                          alreadyRead
                              ? null
                              : const Icon(
                                Icons.brightness_1,
                                size: 8,
                                color: Colors.redAccent,
                              ),
                      onTap: () => setState(() => _read.add(i)),
                    );
                  },
                ),
      ),
    );
  }
}