import 'package:flutter/material.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String cuisine;
  final String time;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.cuisine,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.restaurant),
        ),
        title: Text(name),
        subtitle: Text(cuisine),
        trailing: Text(time),
      ),
    );
  }
}