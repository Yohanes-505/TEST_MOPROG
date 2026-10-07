import 'package:Meetcha/services/supabase_service.dart'; 
import 'package:Meetcha/constants/app_colors.dart';
import 'package:flutter/material.dart'; 
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> handleForgotPassword() async {
    if (emailController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your email', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(emailController.text.trim());
      Get.snackbar('Success', 'Password reset email sent. Please check your inbox.', snackPosition: SnackPosition.BOTTOM);
      Get.back(); // Navigate back to the login screen
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'An unexpected error occurred', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 35),
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              const Text("Forgot Password?",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                "Enter your email and we'll send you a link to reset your password.",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              const Text("Email", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleForgotPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: AppColors.onPrimary))
                      : const Text("Send Reset Link",
                          style: TextStyle(fontSize: 16, color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}