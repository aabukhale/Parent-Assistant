import 'package:flutter/material.dart';

class ChannelManagementScreen extends StatefulWidget {
  const ChannelManagementScreen({super.key});

  @override
  State<ChannelManagementScreen> createState() =>
      _ChannelManagementScreenState();
}

class _ChannelManagementScreenState
    extends State<ChannelManagementScreen> {
  final List<Map<String, dynamic>> channels = [
    {
      'name': 'YouTube Kids',
      'icon': Icons.smart_display_rounded,
      'allowed': true,
    },
    {
      'name': 'National Geographic Kids',
      'icon': Icons.public_rounded,
      'allowed': true,
    },
    {
      'name': 'TikTok',
      'icon': Icons.music_video_rounded,
      'allowed': false,
    },
    {
      'name': 'Netflix',
      'icon': Icons.movie_rounded,
      'allowed': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'إدارة القنوات',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4DF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      channel['icon'],
                      color: const Color(0xFFFF624E),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      channel['name'],
                      style: const TextStyle(
                        color: Color(0xFF2E3B63),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Switch(
                    value: channel['allowed'],
                    activeColor: const Color(0xFF62D9D4),
                    onChanged: (value) {
                      setState(() {
                        channel['allowed'] = value;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}