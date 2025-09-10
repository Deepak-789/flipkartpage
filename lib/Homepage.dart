import 'package:flipkartpage/Newpage.dart';
import 'package:flipkartpage/ProductDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:molten_navigationbar_flutter/molten_navigationbar_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class NavigationController extends GetxController {

  String formatCategoryName(String category) {
    return category
        .split('-')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : "")
        .join(" ");
  }


  var selectedIndex = 0.obs;
  var products = <dynamic>[].obs;
  var fullCategories = [].obs;
  var isLoading = true.obs;
  var posts = <dynamic>[].obs;
  var categories = <String>[].obs;
  var slugs = <String>[].obs;
  var selectedCategory = 'all'.obs;
  var isInitialLoad = true.obs;
  var userInitiatedSearch = false.obs;
  var showShimmer = false.obs;
  var shimmerType = "grid".obs;
  var cart = {}.obs;
  var localCart = <Map<String, dynamic>>[].obs;




  @override
  void onInit() {
    super.onInit();
    fetchCategories();
    fetchProduct();
  }

  void changePage(int index, dynamic products, dynamic categories) {
    selectedIndex.value = index;

    if (index == 0 && posts.isEmpty) {
      fetchProduct();
    }

    if (index == 2) {   // 👈 My Cart page
      fetchCart();
    }
  }





  Future<void> fetchProduct() async {
    shimmerType.value = "grid";  // 👈 choose shimmer type
    showShimmer.value = true;
    isLoading.value = true;

    final url = Uri.parse('https://dummyjson.com/products?limit=1000');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        posts.assignAll(data["products"]);
      }
    } finally {
      isLoading.value = false;
      showShimmer.value = false;
    }
  }



  Future<void> fetchCategories() async {
    isLoading.value = true;
    final url = Uri.parse('https://dummyjson.com/products/categories');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List && data.isNotEmpty && data.first is Map) {
          final List<String> names = data.map<String>((e) => e['name'].toString()).toList();
          final List<String> slug = data.map<String>((e) => e['slug'].toString()).toList();
          categories.assignAll(names);
          slugs.assignAll(slug);
          fullCategories.assignAll(names);
        } else {
          categories.assignAll(List<String>.from(data));
          fullCategories.assignAll(List<String>.from(data));
        }

        categories.insert(0, 'all');
        slugs.insert(0, 'all');
      }
    } catch (e) {
      log("❌ Exception: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchProductsByCategory(String category) async {
    shimmerType.value = "list"; // 👈 use different shimmer
    showShimmer.value = true;
    isLoading.value = true;

    try {
      Uri url;
      if (category.toLowerCase() == 'all') {
        url = Uri.parse('https://dummyjson.com/products?limit=1000');
      } else {
        url = Uri.parse('https://dummyjson.com/products/category/${Uri.encodeComponent(category)}?limit=1000');
      }

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        posts.assignAll(data["products"]);
      }
    } finally {
      isLoading.value = false;
      showShimmer.value = false;
    }
  }



  Future<void> searchProducts(String query) async {
    isLoading.value = true;
    userInitiatedSearch.value = true;
    isInitialLoad.value = false;  // no shimmer during search

    try {
      if (query.trim().isEmpty) {
        await fetchProductsByCategory('all');
        return;
      }

      final url = Uri.parse('https://dummyjson.com/products/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        posts.assignAll(data["products"]);
        log("🔍 Search results for \"$query\": ${posts.length}");
      } else {
        log("❌ Search error: ${response.statusCode}");
      }
    } catch (e) {
      log("❌ Search exception: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCart() async {
    isLoading.value = true;
    try {
      final url = Uri.parse('https://dummyjson.com/carts/1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        cart.assignAll(data);   // ✅ बस data assign करो
      }
    } catch (e) {
      log("❌ Exception fetching cart: $e");
      Get.snackbar("Error", "Something went wrong",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }



  Future<void> addToCart(int productId, {int quantity = 1}) async {
    isLoading.value = true;

    try {
      // 🔹 Check if already exists in local cart
      final existingIndex =
      localCart.indexWhere((item) => item["id"] == productId);

      if (existingIndex >= 0) {
        // increase quantity locally
        localCart[existingIndex]["quantity"] += quantity;
      } else {
        // new product locally
        localCart.add({"id": productId, "quantity": quantity});
      }

      // 🔹 API request
      final url = Uri.parse('https://dummyjson.com/carts/add');
      final body = json.encode({
        "userId": 1, // TODO: replace with dynamic user later
        "products": [
          {"id": productId, "quantity": quantity}
        ]
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        log("✅ Added to cart: $data");

        // Refresh API cart
        await fetchCart();

        // 🔹 Snackbar only for new item, not for quantity update
        if (existingIndex == -1) {
          Get.snackbar(
            "Success",
            "Product added to cart",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            mainButton: TextButton(
              onPressed: () {
                Get.find<NavigationController>().selectedIndex.value = 2;
              },
              child: const Text("View Cart",
                  style: TextStyle(color: Colors.white)),
            ),
          );
        }
      } else {
        log("❌ Failed to add to cart: ${response.statusCode}");
        Get.snackbar(
          "Error",
          "Failed to add product to cart",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      log("❌ Exception adding to cart: $e");
      Get.snackbar(
        "Error",
        "Something went wrong while adding to cart",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }





}

class Homepage extends StatefulWidget {

  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final TextEditingController searchController = TextEditingController();

  final NavigationController controller = Get.put(NavigationController());

  @override
  Widget build(BuildContext context) {
    return Obx(()=>
        SafeArea(
          child: Scaffold(
            body: getWidget(controller.selectedIndex.value),
              bottomNavigationBar: MoltenBottomNavigationBar(
                barColor: Colors.white,
                domeCircleColor: Colors.pink, // dome color for selected tab
                selectedIndex: controller.selectedIndex.value,
                onTabChange: (index) => controller.changePage(index, controller.products, controller.categories),
                tabs: [
                  MoltenTab(
                    icon: Icon(
                      Icons.home,
                      color: controller.selectedIndex.value == 0 ? Colors.white : Colors.pinkAccent,
                      size: 30,
                    ),
                    title: Text(
                      'Home',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: controller.selectedIndex.value == 0 ? Colors.pink : Colors.black54,
                      ),
                    ),
                  ),
                  MoltenTab(
                    icon: Icon(
                      Icons.favorite,
                      color: controller.selectedIndex.value == 1 ? Colors.white : Colors.redAccent,
                      size: 30,
                    ),
                    title: Text(
                      'Wishlist',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: controller.selectedIndex.value == 1 ? Colors.red : Colors.black54,
                      ),
                    ),
                  ),
                  MoltenTab(
                    icon: Icon(
                      Icons.card_travel_rounded,
                      color: controller.selectedIndex.value == 2 ? Colors.white : Colors.orangeAccent,
                      size: 30,
                    ),
                    title: Text(
                      'Cart',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: controller.selectedIndex.value == 2 ? Colors.orange : Colors.black54,
                      ),
                    ),
                  ),
                  MoltenTab(
                    icon: Icon(
                      Icons.person,
                      color: controller.selectedIndex.value == 3 ? Colors.white : Colors.blueAccent,
                      size: 30,
                    ),
                    title: Text(
                      'Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: controller.selectedIndex.value == 3 ? Colors.blue : Colors.black54,
                      ),
                    ),
                  ),
                ],
              )

          ),
        ),
    );
  }

  Widget getWidget(int index) {
    switch (index) {
      case 0:
        return page1();
      case 1:
        return page2();
      case 2:
        return page3();
      case 3:
        return page4();
      default:
        return page1();
    }
  }

  Widget page1() {
    return SafeArea(
      child: Obx(() {
        if (controller.posts.isEmpty && controller.userInitiatedSearch.value) {
          return Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.search_off, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No products match your search.",
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }
        else {
          return
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child:
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.pink.shade200,
                            Colors.pink.shade800,
                            Colors.orange.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(40),
                          bottomLeft: Radius.circular(40),
                        ),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Flipkart",style: TextStyle(fontSize: 20,color: Colors.white,fontWeight: FontWeight.bold),),
                              Icon(Icons.notifications,color: Colors.white,size: 24,)
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.location_on_sharp),
                              SizedBox(width: 12,),
                              Text("Select Delivery location",style: TextStyle(color: Colors.white),)
                            ],
                          ),
                          SizedBox(height: 50),
                          TextField(
                            controller: searchController,
                            onSubmitted: (value) {
                              controller.searchProducts(value);
                            },
                            decoration: InputDecoration(
                              hintText: "Enter product name...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                              filled: true,
                              fillColor: Colors.white24,
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white),
                                onPressed: () {
                                  searchController.clear();
                                  controller.fetchProductsByCategory('all'); // Reset
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Text(
                            "Popular Categories",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Obx(() =>
                          SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.categories.length,
                          itemBuilder: (_, index) {
                            String category = controller.categories[index];
                            String slug = controller.slugs[index];
                            bool isSelected = controller.selectedCategory.value == category;

                            return GestureDetector(
                              onTap: () {
                                controller.showShimmer.value=true;
                                controller.selectedCategory.value = category;
                                controller.fetchProductsByCategory(slug);
                              },
                              child: Card(
                                color: isSelected ? Colors.pink : Colors.white,
                                elevation: 4,
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.category,
                                          color: isSelected ? Colors.white : Colors.blue),
                                      SizedBox(width: 8),
                                      Text(
                                        controller.formatCategoryName(category),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // SliverList for posts
                  Obx(() {
                    if (controller.showShimmer.value) {
                      // Show shimmer only
                      return SliverToBoxAdapter(
                        child: SizedBox(
                          height: 400,
                          child: controller.shimmerType.value == "grid"
                              ? _buildShimmerGrid()
                              : _buildShimmerList(),
                        ),
                      );
                    } else {
                      // Show actual list
                      return SliverList.separated(
                        itemCount: controller.posts.length,
                        separatorBuilder: (_, __) => Divider(height: 5, color: Colors.grey),
                        itemBuilder: (context, index) {
                          var post = controller.posts[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailPage(product: post),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    height: 200,
                                    width: 170,
                                    child: Card(
                                      elevation: 8,
                                      child: Image.network(post["images"][0], fit: BoxFit.cover),
                                    ),
                                  ),
                                  SizedBox(width: 20),

                                  // Product Details + Add to Cart
                                  Container(
                                    height: 200,
                                    width: 150,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Product Title & ID
                                        Row(
                                          children: [
                                            Text("Product", style: TextStyle(fontWeight: FontWeight.bold)),
                                            SizedBox(width: 10),
                                            Text(post['id'].toString(),
                                                style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Flexible(
                                          child: Text(
                                            post['title'].toString(),
                                            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(height: 5),

                                        // Rating (Optional)
                                        Row(
                                          children: [
                                            Icon(Icons.star, size: 15),
                                            Icon(Icons.star, size: 15),
                                            Icon(Icons.star, size: 15),
                                            Icon(Icons.star_border_outlined, size: 15),
                                            Icon(Icons.star_border_outlined, size: 15),
                                            Text("(2979)"),
                                          ],
                                        ),
                                        SizedBox(height: 5),

                                        // Price
                                        Row(
                                          children: [
                                            Icon(Icons.arrow_downward, size: 15, color: Colors.green),
                                            Text("28%", style: TextStyle(color: Colors.green, fontSize: 15)),
                                            SizedBox(width: 4),
                                            Text("\$ 9999",
                                                style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                            SizedBox(width: 4),
                                            Text(post['price'].toString(),
                                                style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        SizedBox(height: 8),

                                        // Description
                                        Text(
                                          post['description'].toString(),
                                          style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                    }
                  })

                ],
              ),
            );
        }
      }),
    );
  }

  Widget page2() {
    return SafeArea(
      child: Scaffold(
        body: Text("hello"),
      ),
    );
    //   Obx(() => controller.isLoading.value
    //     ? const Center(child: CircularProgressIndicator())
    //     : ListView.builder(
    //   itemCount: controller.categories.length,
    //   itemBuilder: (_, index) {
    //     return Card(
    //       child: ListTile(
    //         leading: const Icon(Icons.category),
    //         title: Text(controller.categories[index]['name']),
    //       ),
    //     );
    //   },
    // ));
  }

  Widget page3() {
    return SafeArea(
      child: Obx(() {
        if (controller.localCart.isNotEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("My Cart"),
              centerTitle: true,
              backgroundColor: Colors.pink,
              elevation: 2,
            ),
            body: ListView.builder(
              itemCount: controller.localCart.length,
              itemBuilder: (_, index) {
                var item = controller.localCart[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink.shade100,
                      child: Text(
                        item["id"].toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    title: Text(
                      "Product ID: ${item["id"]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Quantity: ${item["quantity"]}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        controller.localCart.removeAt(index);
                        Get.snackbar("Removed", "Item removed from cart",
                            backgroundColor: Colors.red.shade400,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      Get.snackbar("Checkout", "Proceeding to checkout...",
                          backgroundColor: Colors.pink.shade400,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM);
                    },
                    icon: const Icon(Icons.payment, color: Colors.white),
                    label: const Text("Checkout",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.cart.isEmpty) {
          return const Center(
            child: Text(
              "🛒 Cart is empty",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          );
        }

        var cartData = controller.cart;
        var products = cartData["products"] as List<dynamic>;

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Cart"),
            centerTitle: true,
            backgroundColor: Colors.pink,
            elevation: 2,
          ),
          body: ListView.builder(
            itemCount: products.length,
            itemBuilder: (_, index) {
              var item = products[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item["thumbnail"] ?? "",
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    item["title"],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Qty: ${item["quantity"]} | Price: \$${item["price"]}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Text(
                    "\$${item["total"]}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total: \$${cartData["total"]}",
                    style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Get.snackbar("Checkout", "Proceeding to checkout...",
                        backgroundColor: Colors.pink.shade400,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM);
                  },
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: const Text("Checkout",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }),

    );
  }


  Widget page4() {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade100, // हल्का बैकग्राउंड
        appBar: AppBar(
          title: const Text("My Account"),
          centerTitle: true,
          backgroundColor: Colors.pink,
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Get.snackbar("Notifications", "No new notifications");
              },
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔹 Profile Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade400, Colors.orange.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundImage:
                    NetworkImage("assets/images/IMG-20231202-WA0053.jpg"),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Deepak Rastogi",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text("deepak@example.com",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Section Title
            const Text("Account Options",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 10),

            // 🔹 Account Options Card
            Card(
              elevation: 5,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildAccountTile(
                      icon: Icons.shopping_bag,
                      color: Colors.pink,
                      title: "My Orders",
                      onTap: () => Get.snackbar("Orders", "Opening your orders...")),
                  _divider(),
                  _buildAccountTile(
                      icon: Icons.favorite,
                      color: Colors.redAccent,
                      title: "My Wishlist",
                      onTap: () => Get.find<NavigationController>().selectedIndex.value = 1),
                  _divider(),
                  _buildAccountTile(
                      icon: Icons.location_on,
                      color: Colors.orangeAccent,
                      title: "Saved Addresses",
                      onTap: () =>
                          Get.snackbar("Address", "Manage your addresses")),
                  _divider(),
                  _buildAccountTile(
                      icon: Icons.settings,
                      color: Colors.blue,
                      title: "Settings",
                      onTap: () =>
                          Get.snackbar("Settings", "Opening settings...")),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 🔹 Logout Button
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: Colors.pinkAccent,
                ),
                onPressed: () {
                  Get.snackbar("Logout", "You have been logged out",
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);

                  Future.delayed(const Duration(seconds: 1), () {
                    Get.offAll(() => const Newpage());
                  });
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// helper for list tiles
  Widget _buildAccountTile(
      {required IconData icon,
        required Color color,
        required String title,
        required Function() onTap}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  /// divider for list tiles
  Widget _divider() {
    return const Divider(height: 1, indent: 15, endIndent: 15);
  }



  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[600]!,
          highlightColor: Colors.grey[300]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[600]!,
          highlightColor: Colors.grey[300]!,
          child: ListTile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Container(
              height: 16,
              width: double.infinity,
              color: Colors.white,
            ),
            subtitle: Container(
              margin: EdgeInsets.only(top: 8),
              height: 14,
              width: 150,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

}
