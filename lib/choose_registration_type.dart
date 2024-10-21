import 'package:flutter/material.dart';
import 'register_page.dart';

class ChooseRegistrationType extends StatelessWidget {
  const ChooseRegistrationType({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Registration Type')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage(isRider: false)),
                );
              },
              child: const Text('Register as User'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage(isRider: true)),
                );
              },
              child: const Text('Register as Rider'),
            ),
          ],
        ),
      ),
    );
  }
}
