import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/register_screen.dart';
import 'screens/farmer_screen.dart';
import 'screens/buyer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(FarmiaPrototype());
}

class FarmiaPrototype extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmia Prototype',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthScreen(),
      routes: {
        '/register': (context) => RegisterScreen(),
        '/farmer': (context) => FarmerScreen(),
        '/buyer': (context) => BuyerScreen(),
      },
    );
  }
}
