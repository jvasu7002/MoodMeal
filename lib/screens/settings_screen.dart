import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'package:moodmeal/auth/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      darkMode = prefs.getBool("darkMode") ?? false;
    });
  }

  Future<void> changeTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("darkMode", value);

    themeNotifier.value =
        value ? ThemeMode.dark : ThemeMode.light;

    setState(() {
      darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),

      body: ListView(
        children: [

          const SizedBox(height: 15),

          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            subtitle: const Text("Enable or disable dark theme"),
            trailing: Switch(
              value: darkMode,
              onChanged: changeTheme,
            ),
          ),
          const Divider(),
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text("About MoodMeal"),
  subtitle: const Text("Version 1.0.0"),
  onTap: () {
    showAboutDialog(
      context: context,
      applicationName: "MoodMeal ❤️",
      applicationVersion: "Version 1.0.0",
      applicationIcon: const Icon(
        Icons.restaurant,
        size: 50,
        color: Colors.orange,
      ),
      children: const [
        SizedBox(height: 10),
        Text(
          "MoodMeal is an AI-powered restaurant recommendation app that suggests nearby restaurants based on your mood and location.",
        ),
        SizedBox(height: 15),
        Text(
          "✨ Features",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text("• AI Mood-based Food Suggestions"),
        Text("• Nearby Restaurants"),
        Text("• Google Maps Navigation"),
        Text("• Favorites"),
        Text("• Dark Mode"),
        SizedBox(height: 15),
        Text(
          "Developed by",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text("Vasu Jain ❤️"),
      ],
    );
  },
),
          const Divider(),

         ListTile(
  leading: const Icon(Icons.share),
  title: const Text("Share App"),
  subtitle: const Text("Share MoodMeal with your friends"),
  onTap: () {
    SharePlus.instance.share(
      ShareParams(
        text: '''
🍽️ Check out MoodMeal!

An AI-powered restaurant recommendation app that suggests food based on your mood.

Developed by Vasu Jain ❤️

Download it here:
Coming Soon on Google Play Store!
''',
      ),
    );
  },
),

          const Divider(),

          ListTile(
  leading: const Icon(Icons.star),
  title: const Text("Rate App"),
  subtitle: const Text("Support MoodMeal"),
  onTap: () {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⭐ Rate MoodMeal"),
        content: const Text(
          "Thank you for using MoodMeal!\n\n"
          "Once the app is available on the Google Play Store, "
          "you'll be able to rate it and help us improve.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  },
),

          const Divider(),



         ListTile(
  leading: const Icon(Icons.feedback_outlined),
  title: const Text("Send Feedback"),
  subtitle: const Text("Help us improve MoodMeal"),
  onTap: () async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'vasuj0814@gmail.com',
      queryParameters: {
        'subject': 'MoodMeal Feedback',
        'body':
            'Hello Vasu,\n\nI would like to share the following feedback:\n\n',
      },
    );

    try {
      await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No email application found.",
          ),
        ),
      );
    }
  },
),
const Divider(),

ListTile(
  leading: const Icon(
    Icons.logout,
    color: Colors.red,
  ),
  title: const Text(
    "Logout",
    style: TextStyle(color: Colors.red),
  ),
  onTap: () async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text(
          "Are you sure you want to logout?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService().logout();
    }
  },
),
          const SizedBox(height: 30),

          const Center(
            child: Text(
              "MoodMeal ❤️",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(height: 5),

          const Center(
            child: Text(
              "Made by Vasu Jain",
              style: TextStyle(color: Colors.grey),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}