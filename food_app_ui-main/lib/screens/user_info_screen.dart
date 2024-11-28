import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Import màn hình đăng nhập

class UserInfoScreen extends StatefulWidget {
  final String userUid;
  const UserInfoScreen({Key? key, required this.userUid}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  final List<String> _activityLevels = ['Thấp', 'Vừa phải', 'Cao'];
  final List<String> _goals = ['Tăng cân', 'Giảm cân'];

  String? _selectedActivityLevel;
  String? _selectedGoal;

  Future<void> _saveUserInfo() async {
    final address = _addressController.text.trim();
    final height = _heightController.text.trim();
    final weight = _weightController.text.trim();

    // Kiểm tra các trường nhập liệu
    if (address.isEmpty || height.isEmpty || weight.isEmpty || _selectedActivityLevel == null || _selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền tất cả các trường')),
      );
      return;
    }

    // Kiểm tra chiều cao và cân nặng có hợp lệ
    if (double.tryParse(height) == null || double.tryParse(weight) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chiều cao và cân nặng phải là số hợp lệ')),
      );
      return;
    }

    try {
      // Lưu thông tin người dùng vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(widget.userUid).update({
        'address': address,
        'height': height,
        'weight': weight,
        'activityLevel': _selectedActivityLevel,
        'goal': _selectedGoal,
      });

      // Thông báo khi lưu thành công
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thông tin đã được cập nhật')),
      );

      // Chuyển đến màn hình đăng nhập sau khi lưu thông tin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LogIn()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông Tin Người Dùng'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.orange], // Gradient tím cam
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTextField(_addressController, 'Địa chỉ'),
            _buildTextField(_heightController, 'Chiều cao (cm)'),
            _buildTextField(_weightController, 'Cân nặng (kg)'),
            // Dropdown chọn mức độ hoạt động
            _buildDropdown(
              label: 'Mức độ hoạt động',
              value: _selectedActivityLevel,
              items: _activityLevels,
              onChanged: (value) {
                setState(() {
                  _selectedActivityLevel = value;
                });
              },
            ),
            // Dropdown chọn mục tiêu
            _buildDropdown(
              label: 'Mục tiêu',
              value: _selectedGoal,
              items: _goals,
              onChanged: (value) {
                setState(() {
                  _selectedGoal = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, // Để màu nền trong suốt
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.orange), // Viền nút màu cam
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.orange], // Gradient tím cam
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: const Text(
                  'Lưu Thông Tin',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.purple), // Màu label tím
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.purple), // Màu viền tím
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.purple), // Màu label tím
          border: OutlineInputBorder(),
        ),
        value: value,
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
