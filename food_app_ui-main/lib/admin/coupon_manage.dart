import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponManageScreen extends StatefulWidget {
  const CouponManageScreen({super.key});

  @override
  State<CouponManageScreen> createState() => _CouponManageScreenState();
}

class _CouponManageScreenState extends State<CouponManageScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _expirationController = TextEditingController();

  /// Thêm hoặc cập nhật mã giảm giá
  Future<void> _addOrUpdateCoupon() async {
    final code = _codeController.text.trim();
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final expirationText = _expirationController.text.trim();

    if (code.isEmpty || discount <= 0 || expirationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')),
      );
      return;
    }

    try {
      // Chuyển đổi ngày hết hạn từ chuỗi sang `DateTime`
      final expirationDate = DateTime.parse(expirationText);

      await FirebaseFirestore.instance.collection('coupons').doc(code).set({
        'code': code,
        'discount': discount,
        'isActive': true,
        'expirationDate': Timestamp.fromDate(expirationDate), // Lưu dưới dạng Timestamp
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thêm/cập nhật mã giảm giá thành công')),
      );

      // Xóa nội dung sau khi thành công
      _codeController.clear();
      _discountController.clear();
      _expirationController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    }
  }

  /// Xóa mã giảm giá
  Future<void> _deleteCoupon(String code) async {
    try {
      await FirebaseFirestore.instance.collection('coupons').doc(code).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa mã giảm giá thành công')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    }
  }

  /// Widget hiển thị danh sách mã giảm giá
  Widget _buildCouponList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final coupons = snapshot.data!.docs;

        if (coupons.isEmpty) {
          return const Center(child: Text('Không có mã giảm giá nào.'));
        }

        return ListView.builder(
          itemCount: coupons.length,
          itemBuilder: (context, index) {
            final data = coupons[index].data() as Map<String, dynamic>;
            final expirationTimestamp = data['expirationDate'] as Timestamp;
            final expirationDate = expirationTimestamp.toDate();
            final formattedDate =
                '${expirationDate.year}-${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.day.toString().padLeft(2, '0')}';

            return ListTile(
              title: Text(data['code']),
              subtitle: Text(
                'Giảm ${(data['discount'] * 100).toInt()}%, Hết hạn: $formattedDate',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteCoupon(data['code']),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý mã giảm giá'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Mã giảm giá'),
            ),
            TextField(
              controller: _discountController,
              decoration: const InputDecoration(labelText: 'Phần trăm giảm giá (0.1 = 10%)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _expirationController,
              decoration: const InputDecoration(labelText: 'Ngày hết hạn'),
              readOnly: true,
              onTap: () async {
                // Sử dụng DatePicker để chọn ngày
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );

                if (pickedDate != null) {
                  setState(() {
                    _expirationController.text =
                    '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addOrUpdateCoupon,
              child: const Text('Thêm / Cập nhật mã giảm giá'),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildCouponList()), // Hiển thị danh sách mã giảm giá
          ],
        ),
      ),
    );
  }
}
