import 'package:flutter/material.dart';
import 'register_page.dart';

class ChooseRegistrationType extends StatelessWidget {
  const ChooseRegistrationType({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade200, Colors.purple.shade400],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Good2Go',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage(isRider: true)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.motorcycle, color: Colors.purple.shade400),
                          const SizedBox(width: 8),
                          const Text('โรเดอร์', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage(isRider: false)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, color: Colors.purple.shade400),
                          const SizedBox(width: 8),
                          const Text('ผู้ใช้งาน', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'เข้าสู่ระบบ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
