import 'package:flutter/material.dart';

class WalkerAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const WalkerAvatar({super.key, this.imageUrl, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[300],
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null
          ? Icon(Icons.person, color: Colors.grey[600], size: size * 0.6)
          : null,
    );
  }
}
