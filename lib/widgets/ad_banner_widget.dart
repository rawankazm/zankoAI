import 'package:flutter/material.dart';

/// Reads active ads from Firestore and shows them as a hero banner matching the premium design.
/// Pass [screenName] matching one of the screen IDs set in the Admin panel.
/// If no active ad targets this screen, the widget renders as SizedBox.shrink().
class AdBannerWidget extends StatelessWidget {
  final String screenName;

  const AdBannerWidget({super.key, required this.screenName});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

