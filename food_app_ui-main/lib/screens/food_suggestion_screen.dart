import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodSuggestionScreen extends StatefulWidget {
  @override
  _FoodSuggestionScreenState createState() => _FoodSuggestionScreenState();
}

class _FoodSuggestionScreenState extends State<FoodSuggestionScreen> {
  String _searchQuery = "";
  List<String> _selectedCategories = [];
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fetch dữ liệu người dùng
  Future<void> _fetchUserData() async {
    final userId = 'USER_ID'; // Thay bằng ID người dùng thực tế
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    setState(() {
      _userData = userSnapshot.data() as Map<String, dynamic>?;
    });
  }

  // Fetch danh sách món ăn từ Firestore
  Future<List<Map<String, dynamic>>> _fetchFoods() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('foods').get();
    List<Map<String, dynamic>> foods = [];

    for (var doc in snapshot.docs) {
      var foodData = doc.data() as Map<String, dynamic>;
      double protein = (foodData['protein'] ?? 0).toDouble();
      double carbs = (foodData['carbs'] ?? 0).toDouble();
      double fat = (foodData['fat'] ?? 0).toDouble();
      double calories = (protein * 4) + (carbs * 4) + (fat * 9);

      foods.add({
        'name': foodData['name'],
        'category': foodData['category'],
        'description': foodData['description'],
        'imageUrl': foodData['imageUrl'],
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      });
    }
    return foods;
  }

  // Lọc món ăn dựa trên nhu cầu calo
  List<Map<String, dynamic>> _filterFoods(List<Map<String, dynamic>> foods) {
    if (_userData == null) return foods;

    double caloricNeeds = _userData!['caloricNeeds'] ?? 2500;

    return foods.where((food) {
      return food['calories'] <= caloricNeeds;
    }).toList();
  }

  // Ưu tiên món ăn theo sở thích
  List<Map<String, dynamic>> _prioritizeFoods(List<Map<String, dynamic>> foods) {
    if (_userData == null || !_userData!.containsKey('preferences')) return foods;

    List<String> preferences = List<String>.from(_userData!['preferences']);
    return foods
      ..sort((a, b) {
        int aIsPreferred = preferences.contains(a['category']) ? 1 : 0;
        int bIsPreferred = preferences.contains(b['category']) ? 1 : 0;
        return bIsPreferred.compareTo(aIsPreferred); // Sort in descending order
      });
  }


  // Lọc món ăn theo danh mục
  List<Map<String, dynamic>> _filterByCategory(List<Map<String, dynamic>> foods) {
    if (_selectedCategories.isEmpty) return foods;

    return foods
        .where((food) => _selectedCategories.contains(food['category']))
        .toList();
  }

  // Tìm kiếm món ăn
  List<Map<String, dynamic>> _searchFoods(List<Map<String, dynamic>> foods) {
    return foods.where((food) {
      return food['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          food['description'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Đề xuất món ăn dựa trên dinh dưỡng
  List<Map<String, dynamic>> _suggestByNutrition(List<Map<String, dynamic>> foods) {
    if (_userData == null) return foods;

    double targetProtein = _userData!['targetProtein'] ?? 0;
    double targetCarbs = _userData!['targetCarbs'] ?? 0;
    double targetFat = _userData!['targetFat'] ?? 0;

    foods.sort((a, b) {
      double scoreA = (a['protein'] - targetProtein).abs() +
          (a['carbs'] - targetCarbs).abs() +
          (a['fat'] - targetFat).abs();
      double scoreB = (b['protein'] - targetProtein).abs() +
          (b['carbs'] - targetCarbs).abs() +
          (b['fat'] - targetFat).abs();
      return scoreA.compareTo(scoreB);
    });

    return foods;
  }

  // Hiển thị phần gợi ý hàng đầu
  Widget _buildTopSuggestions(List<Map<String, dynamic>> foods) {
    var topSuggestions = foods.take(3).toList();

    return Container(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topSuggestions.length,
        itemBuilder: (context, index) {
          var food = topSuggestions[index];
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(food['imageUrl'], width: 100, height: 100, fit: BoxFit.cover),
                Text(food['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${food['calories']} kcal'),
              ],
            ),
          );
        },
      ),
    );
  }

  // Hiển thị giao diện
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi Ý Món Ăn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showCategoryFilterDialog(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchFoods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có món ăn nào'));
          }

          var foods = snapshot.data!;
          var filteredFoods = _suggestByNutrition(
            _filterByCategory(
              _searchFoods(
                _prioritizeFoods(
                  _filterFoods(foods),
                ),
              ),
            ),
          );

          return Column(
            children: [
              _buildTopSuggestions(filteredFoods),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm món ăn...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredFoods.length,
                  itemBuilder: (context, index) {
                    var food = filteredFoods[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: Image.network(
                          food['imageUrl'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                        title: Text(food['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${food['category']} - ${food['calories']} kcal'),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(food['name']),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Loại: ${food['category']}'),
                                      Text('Calo: ${food['calories']} kcal'),
                                      const SizedBox(height: 10),
                                      Text('Mô tả: ${food['description']}'),
                                    ],
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Đóng'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hiển thị dialog lọc danh mục món ăn
  void _showCategoryFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn loại món ăn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Pizza', 'Gà', 'Burger', 'Drinks', 'Other'].map((category) {
              return CheckboxListTile(
                title: Text(category),
                value: _selectedCategories.contains(category),
                onChanged: (bool? selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
