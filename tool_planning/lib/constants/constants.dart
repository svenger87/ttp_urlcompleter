import 'dart:ui';

const String primaryApiUrl = 'http://wim-solution.sip.local:3004/projects';
const String secondaryApiUrl = 'http://wim-solution:3000/all-projects';
const Color primaryColor = Color(0xFF104382); // Company CI Color
const Duration refreshInterval =
    Duration(minutes: 5); // Regular refresh interval
const String updatePriorityUrl =
    'http://wim-solution.sip.local:3004/update-priority';
