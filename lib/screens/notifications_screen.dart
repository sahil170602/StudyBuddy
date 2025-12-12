// File: lib/screens/notifications_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

const double kNavVisualHeight = 86.0;

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime time;
  bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    DateTime? time,
    this.read = false,
  }) : time = time ?? DateTime.now();
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedCategory = "All";
  String _query = '';

  late final AnimationController _headerPulse;

  List<NotificationItem> _notifications = [];

  final List<String> _categories = [
    "All",
    "Important",
    "Tech",
    "University",
    "Student Picks",
    "System"
  ];

  @override
  void initState() {
    super.initState();
    _headerPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });

    _seedNotifications();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    _headerPulse.dispose();
    super.dispose();
  }

  void _seedNotifications() {
    _notifications = [
      NotificationItem(
        id: 'n1',
        title: "Student startup wins grant",
        body:
            "Congrats to the student team for securing seed funding. See full story inside.",
        category: "Student Picks",
        time: DateTime.now().subtract(const Duration(minutes: 56)),
      ),
      NotificationItem(
        id: 'n2',
        title: "System: password expiring soon",
        body:
            "Your account password will expire in 7 days. Update it to avoid temporary lockout.",
        category: "System",
        time: DateTime.now().subtract(const Duration(hours: 6)),
        read: true,
      ),
      NotificationItem(
        id: 'n3',
        title: "Exam schedule released — check dates",
        body: "Your exam timetable is now available in the student portal.",
        category: "Important",
        time: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<NotificationItem> get _filtered {
    var list = _notifications;

    if (_selectedCategory != "All") {
      list = list.where((n) => n.category == _selectedCategory).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              n.body.toLowerCase().contains(q))
          .toList();
    }

    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _notifications.insert(
        0,
        NotificationItem(
          id: 'n${DateTime.now().millisecondsSinceEpoch}',
          title: "Recommended for you",
          body: "A new AI-suggested article based on your subjects.",
          category: "Student Picks",
          time: DateTime.now(),
        ),
      );
    });
  }

  void _toggleRead(NotificationItem n) =>
      setState(() => n.read = !n.read);

  void _dismiss(NotificationItem n) =>
      setState(() => _notifications.removeWhere((i) => i.id == n.id));

  void _markAllRead() =>
      setState(() => _notifications.forEach((n) => n.read = true));

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return "${d.inMinutes}m ago";
    if (d.inHours < 24) return "${d.inHours}h ago";
    return "${d.inDays}d ago";
  }

  Widget _animatedSearchBar() {
    final active = _query.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? Colors.white12 : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.18),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search notifications...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          if (active)
            GestureDetector(
              onTap: () => _searchCtrl.clear(),
              child: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _filterChip() {
    return GestureDetector(
      onTap: () {
        final currentIndex = _categories.indexOf(_selectedCategory);
        final nextIndex = (currentIndex + 1) % _categories.length;
        setState(() => _selectedCategory = _categories[nextIndex]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.filter_list, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Text(_selectedCategory, style: const TextStyle(color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _notificationCard(NotificationItem n) {
    final tagColor = {
          "Important": Colors.orangeAccent,
          "Tech": Colors.cyanAccent,
          "University": Colors.limeAccent,
          "Student Picks": Colors.purpleAccent,
          "System": Colors.redAccent
        }[n.category] ??
        Colors.white70;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tagColor.withOpacity(0.16),
                  child: Text(
                    n.category[0],
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                if (!n.read)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      _timeAgo(n.time),
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(n.body, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: tagColor.withOpacity(0.12)),
                    child: Text(n.category, style: TextStyle(fontSize: 12, color: tagColor)),
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => _toggleRead(n), icon: Icon(n.read ? Icons.mark_email_read : Icons.mark_email_unread)),
                  PopupMenuButton(
                    onSelected: (value) {
                      if (value == "dismiss") _dismiss(n);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: "dismiss", child: Text("Dismiss")),
                    ],
                  ),
                ]),
              ]),
            )
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _NotifHeaderDelegate(
        minExtent: 110,
        maxExtent: 130,
        childBuilder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Notifications", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _animatedSearchBar()),
                const SizedBox(width: 10),
                _filterChip(),
              ]),
              const SizedBox(height: 4),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // single source of truth for reserved bottom space:
    final bottomReserve = kNavVisualHeight + MediaQuery.of(context).viewPadding.bottom;
    final list = _filtered;

    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                _header(),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i >= list.length) return null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: _notificationCard(list[i]),
                      );
                    },
                    childCount: list.length,
                  ),
                ),

                // final footer spacer to reserve nav overlay area (single reservation)
                SliverToBoxAdapter(child: SizedBox(height: bottomReserve + 12)),
              ],
            ),
          ),

          // Floating action button (glassy styling can be added if you want)
          Positioned(
            bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
            right: 18,
            child: FloatingActionButton.extended(
              onPressed: list.isEmpty ? null : _markAllRead,
              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.92),
              label: const Text("Mark all read"),
              icon: const Icon(Icons.done_all),
            ),
          ),
        ],
      ),
    );
  }
}

// Correct delegate
class _NotifHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double _minExtent;
  final double _maxExtent;
  final Widget Function(BuildContext) childBuilder;

  _NotifHeaderDelegate({
    required double minExtent,
    required double maxExtent,
    required this.childBuilder,
  })  : _minExtent = minExtent,
        _maxExtent = maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return childBuilder(context);
  }

  @override
  bool shouldRebuild(covariant _NotifHeaderDelegate oldDelegate) => true;
}
