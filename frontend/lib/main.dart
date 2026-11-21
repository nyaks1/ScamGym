import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  runApp(const ScamGymApp());
}

class ScamGymApp extends StatefulWidget {
  const ScamGymApp({super.key});

  @override
  State<ScamGymApp> createState() => _ScamGymAppState();
}

class _ScamGymAppState extends State<ScamGymApp> {
  late String _baseUrl;
  late ApiClient _api;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _baseUrl = defaultApiBase();
    _api = ApiClient(baseUrl: _baseUrl);
  }

  void _changeServer(String value) {
    setState(() {
      _baseUrl = value;
      _api.baseUrl = value;
      _epoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamGym',
      debugShowCheckedModeBanner: false,
      theme: buildScamGymTheme(),
      home: HomeShell(
        api: _api,
        baseUrl: _baseUrl,
        epoch: _epoch,
        onServerChanged: _changeServer,
      ),
    );
  }
}
