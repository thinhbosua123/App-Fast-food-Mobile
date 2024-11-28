import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CaloricNeedsScreen extends StatefulWidget {
  final String userId;

  CaloricNeedsScreen({required this.userId});

  @override
  _CaloricNeedsScreenState createState() => _CaloricNeedsScreenState();
}

class _CaloricNeedsScreenState extends State<CaloricNeedsScreen> {
  double? _caloricNeeds;
  Map<String, dynamic> userData = {};  // Dữ liệu người dùng
  bool isLoading = true;  // Trạng thái loading

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Lấy dữ liệu người dùng từ Firestore
  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>;
          isLoading = false;
        });
        _calculateCaloricNeeds();
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorMessage('Không tìm thấy thông tin người dùng.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Lỗi khi tải dữ liệu người dùng: $e");
      _showErrorMessage('Có lỗi khi tải dữ liệu. Vui lòng thử lại sau.');
    }
  }

  void _calculateCaloricNeeds() {
    // Chuyển đổi giá trị từ String thành double
    double weight = double.tryParse(userData['weight']?.toString() ?? '0.0') ?? 0.0;
    double height = double.tryParse(userData['height']?.toString() ?? '0.0') ?? 0.0;
    String activityLevel = userData['activityLevel'] ?? 'Thấp';

    // Kiểm tra nếu trọng lượng và chiều cao hợp lệ
    if (weight > 0 && height > 0) {
      double bmr = 88.362 + (13.397 * weight) + (4.799 * height);

      switch (activityLevel) {
        case 'Thấp':
          _caloricNeeds = bmr * 1.2;
          break;
        case 'Vừa phải':
          _caloricNeeds = bmr * 1.55;
          break;
        case 'Cao':
          _caloricNeeds = bmr * 1.9;
          break;
        default:
          _caloricNeeds = bmr;
      }

      setState(() {});
      _saveCaloricNeeds(); // Save the calculated caloric needs to Firestore
    } else {
      _caloricNeeds = null;  // Dữ liệu không hợp lệ
    }
  }

  // Lưu nhu cầu calo vào Firestore
  Future<void> _saveCaloricNeeds() async {
    try {
      // Cập nhật dữ liệu nhu cầu calo vào Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'caloricNeeds': _caloricNeeds,
      });

      _showSuccessMessage('Nhu cầu calo đã được lưu thành công!');
    } catch (e) {
      print("Lỗi khi lưu nhu cầu calo: $e");
      _showErrorMessage('Có lỗi khi lưu dữ liệu. Vui lòng thử lại sau.');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhu Cầu Calo Hằng Ngày'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_caloricNeeds == null)
              const Text(
                'Dữ liệu không hợp lệ hoặc thiếu thông tin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            if (_caloricNeeds != null)
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nhu cầu calo của bạn:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_caloricNeeds!.toStringAsFixed(0)} kcal/ngày',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Dựa trên trọng lượng, chiều cao và mức độ hoạt động của bạn.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
