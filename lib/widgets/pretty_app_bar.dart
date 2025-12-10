import 'package:flutter/material.dart';

class PrettyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const PrettyAppBar({Key? key, this.title = 'Projet IOT', this.actions}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 12);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_ethernet, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Dashboard',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (actions != null) ...actions! else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {},
                      tooltip: 'Search',
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle, color: Colors.white),
                      onPressed: () {},
                      tooltip: 'Profile',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
Usage:

import 'package:your_app/widgets/pretty_app_bar.dart';

Scaffold(
  appBar: const PrettyAppBar(),
  body: ...,
)

You can also pass actions: PrettyAppBar(actions: [IconButton(...)]).
*/
