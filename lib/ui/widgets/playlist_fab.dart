import 'package:flutter/material.dart';

class PlaylistFab extends StatefulWidget {
  final VoidCallback onCreate;
  // final VoidCallback onImport;

  const PlaylistFab({
    super.key,
    required this.onCreate,
    // required this.onImport,
  });

  @override
  State<PlaylistFab> createState() => _PlaylistFabState();
}

class _PlaylistFabState extends State<PlaylistFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Kurve für sanftes Aufploppen
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      parent: _controller,
    );

    // Rotation für das Haupt-Icon (+ wird zu x)
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end, // Rechtsbündig
      children: [
        // OPTION 1: IMPORTIEREN
        // _buildFabOption(
        //   icon: Icons.input_rounded,
        //   label: "M3U Importieren",
        //   onTap: () {
        //     _toggle();
        //     widget.onImport();
        //   },
        // ),
        const SizedBox(height: 16),

        // OPTION 2: ERSTELLEN
        _buildFabOption(
          icon: Icons.playlist_add,
          label: "Neue Playlist",
          onTap: () {
            _toggle();
            widget.onCreate();
          },
        ),

        const SizedBox(height: 16),

        // HAUPT FAB
        FloatingActionButton(
          heroTag: "playlist_main_fab",
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          // backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          onPressed: _toggle,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: const Icon(Icons.arrow_circle_up_sharp, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Label (Text links vom Button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Kleiner FAB
          FloatingActionButton.small(
            heroTag:
                null, // Wichtig: null setzen, um Tag-Konflikte zu vermeiden
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: onTap,
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }
}
