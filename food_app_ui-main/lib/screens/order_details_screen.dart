import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_app_ui/screens/order_success_screen.dart';
import 'package:food_app_ui/firestore_helper.dart';
import 'cart_provider.dart';

class OrderDetailsScreen extends StatefulWidget {
  final List<CartItem> orderItems;
  final double? totalPrice;

  const OrderDetailsScreen({
    Key? key,
    required this.orderItems,
    this.totalPrice,
  }) : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _couponController = TextEditingController(); // Controller cho mã giảm giá
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final String _clientId = "AaAVVFksDIhN2uzEZq7t7x3HDxvApsBGH17NT3WnEVTLxoIpx8ci5JjRoYXhBTkNSF7g2IQvBTE0Dwre"; // Thay bằng client ID của bạn
  final String _secretKey = "EFcmdZ21pOId8N0KMVg2FG8dP_3edTUeZQz_TgSL5aPsGK-Ez8lKZQ7OqYaZifzT56v5s_2B3P3X4FI7"; // Thay bằng secret key của bạn
  final String _paypalUrl = "https://api.sandbox.paypal.com"; // Use sandbox for testing
  bool _isLoading = false;
  double _discountAmount = 0.0;
  bool _isCouponValid = false;
  String? _couponMessage;

  double get totalPrice {
    return widget.totalPrice ?? widget.orderItems.fold(0, (sum, item) => sum + item.price * item.quantity);
  }

  double get finalPrice => totalPrice - _discountAmount;

  @override
  void dispose() {
    _noteController.dispose();
    _couponController.dispose();
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  // Hàm áp dụng mã giảm giá
  Future<void> _applyCoupon() async {
    final couponCode = _couponController.text.trim();

    if (couponCode.isEmpty) {
      setState(() {
        _couponMessage = "Vui lòng nhập mã giảm giá.";
        _isCouponValid = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(couponCode)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final isActive = data['isActive'] as bool;
        final discount = data['discount'] as double;
        final expirationDate = (data['expirationDate'] as Timestamp).toDate();

        if (!isActive) {
          setState(() {
            _couponMessage = "Mã giảm giá đã hết hiệu lực.";
            _isCouponValid = false;
          });
        } else if (DateTime.now().isAfter(expirationDate)) {
          setState(() {
            _couponMessage = "Mã giảm giá đã hết hạn.";
            _isCouponValid = false;
          });
        } else {
          setState(() {
            _discountAmount = totalPrice * discount;
            _couponMessage = "Áp dụng mã giảm giá thành công!";
            _isCouponValid = true;
          });
        }
      } else {
        setState(() {
          _couponMessage = "Mã giảm giá không hợp lệ.";
          _isCouponValid = false;
        });
      }
    } catch (e) {
      setState(() {
        _couponMessage = "Có lỗi xảy ra khi kiểm tra mã giảm giá.";
        _isCouponValid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết đơn hàng'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Món hàng của bạn:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              SizedBox(height: 10),
              Divider(),
              ListView.builder(
                itemCount: widget.orderItems.length,
                itemBuilder: (context, index) {
                  final cartItem = widget.orderItems[index];
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(cartItem.name),
                      subtitle: Text('Số lượng: ${cartItem.quantity}'),
                      trailing: Text('đ${(cartItem.price * cartItem.quantity).toStringAsFixed(2)}'),
                    ),
                  );
                },
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
              ),
              SizedBox(height: 20),
              Divider(),
              Text('Tổng cộng: đ${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (_discountAmount > 0)
                Text('Giảm giá: đ${_discountAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, color: Colors.green)),
              Text('Thành tiền: đ${finalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              SizedBox(height: 20),

              // Mã giảm giá
              TextFormField(
                controller: _couponController,
                decoration: InputDecoration(labelText: 'Nhập mã giảm giá'),
              ),
              ElevatedButton(
                onPressed: _applyCoupon,
                child: Text('Áp dụng mã giảm giá'),
              ),
              if (_couponMessage != null)
                Text(
                  _couponMessage!,
                  style: TextStyle(
                    color: _isCouponValid ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              SizedBox(height: 20),

              // Thêm các trường thanh toán (thẻ Visa, PayPal)
              ElevatedButton(
                onPressed: _isLoading ? null : _handleCardPayment,
                child: Text('THANH TOÁN QUA THẺ VISA'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _payWithPayPal,
                child: Text('THANH TOÁN QUA PAYPAL'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCardPayment() async {
    if (!_formKey.currentState!.validate()) {
      return; // Dừng nếu có lỗi
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _processOrder(); // Xử lý đơn hàng nếu thanh toán thành công
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _payWithPayPal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getAccessToken();
      final paymentResponse = await _createPayPalPayment(token);

      if (paymentResponse != null && paymentResponse['state'] == 'created') {
        await _processOrder();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Thanh toán qua PayPal thất bại")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Có lỗi xảy ra khi thanh toán qua PayPal: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processOrder() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final note = _noteController.text.isNotEmpty ? _noteController.text : null;

    await FirestoreHelper().saveOrderAndReduceStock(userId, widget.orderItems, finalPrice, note);

    context.read<CartProvider>().clearCart();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OrderSuccessScreen(orderedProductIds: [], orderedQuantities: [],)),
    );
  }

  Future<String> _getAccessToken() async {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('$_clientId:$_secretKey'))}';

    final response = await http.post(
      Uri.parse('$_paypalUrl/v1/oauth2/token'),
      headers: {
        'Authorization': basicAuth,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['access_token'];
    } else {
      throw Exception('Không thể lấy token truy cập');
    }
  }

  Future<Map<String, dynamic>?> _createPayPalPayment(String accessToken) async {
    final response = await http.post(
      Uri.parse('$_paypalUrl/v1/payments/payment'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'intent': 'sale',
        'payer': {
          'payment_method': 'paypal',
        },
        'transactions': [
          {
            'amount': {
              'total': finalPrice.toStringAsFixed(2),
              'currency': 'USD',
            },
            'description': 'Mua hàng trên FoodApp',
          },
        ],
        'redirect_urls': {
          'return_url': 'https://www.your-site.com/return',
          'cancel_url': 'https://www.your-site.com/cancel',
        },
      }),
    );

    if (response.statusCode == 201) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse;
    } else {
      throw Exception('Không thể tạo thanh toán PayPal');
    }
  }

}
