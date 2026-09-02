import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart'; //Fix bug text editor - flutter_quill
import 'package:hive_flutter/hive_flutter.dart';

import '../services/hive_service.dart';
import 'pages/login_page.dart';
import 'flavors.dart';


void main() async {
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
    orElse: () => Flavor.dev,
  );

  await Hive.initFlutter();
  await HiveService.init();

  runApp(const MyApp());
}

const appFlavor = String.fromEnvironment(
  'FLAVOR',
  defaultValue: 'dev',
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: F.title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: LoginPage(title: F.title),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
    );
  }
}