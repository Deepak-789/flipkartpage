import 'package:flipkartpage/Homepage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:photo_view/photo_view.dart';


class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final NavigationController controller = Get.find();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _openImageViewer(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.grey,
          appBar: AppBar(
            backgroundColor: Colors.grey,
            title: const Text("Preview"),
          ),
          body: PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: PageController(initialPage: index),
            builder: (context, i) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[i]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.grey),
          ),
        ),
      ),
    );
  }



  void openCheckout() {
    var options = {
      'key': 'rzp_test_RAJa2wxfjGRtCQ',
      'amount': (widget.product['price'] * 100).toInt(),
      'name': 'Flipkart Clone',
      'description': 'Order Payment',
      'prefill': {'contact': '9999999999', 'email': 'test@gmail.com'},
      'external': {'wallets': ['paytm']}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Payment Success: ${response.paymentId}")),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Error: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("💳 Wallet: ${response.walletName}")),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  @override
  Widget build(BuildContext context) {
    var reviews = List<Map<String, dynamic>>.from(widget.product['reviews']);
    var tags = List<String>.from(widget.product['tags']);
    var dimensions = widget.product['dimensions'];

    final List<String> images = (widget.product!['images'] != null &&
        widget.product!['images'] is List &&
        widget.product!['images'].isNotEmpty)
        ? List<String>.from(widget.product!['images'] as List)
        : <String>[];



    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product['title'], style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Product Image Carousel
            if (widget.product['images'] != null &&
                widget.product['images'] is List &&
                widget.product['images'].isNotEmpty)
              SizedBox(
                height: 320,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16), // 👈 Rounded edges
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 1),
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () {
                              _openImageViewer(images, index); // 👈 Fullscreen open karega
                            },
                            child: Hero(
                              tag: "image_$index",
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Image.network(
                                  images[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    /// 👇 Dot Indicator
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            images.length,
                                (dotIndex) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(
                                    dotIndex == 0 ? 0.9 : 0.4), // active vs inactive
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            

            const SizedBox(height: 16),

            /// Title & Rating
            Text(widget.product['title'],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < 3 ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 18,
                  );
                }),
                const SizedBox(width: 6),
                Text("${widget.product['rating']} / 5",
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),

            const SizedBox(height: 12),

            /// Price
            Row(
              children: [
                const Text("₹9999",
                    style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey)),
                const SizedBox(width: 6),
                Text("₹${widget.product['price']}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(width: 6),
                const Text("28% Off", style: TextStyle(color: Colors.green)),
              ],
            ),

            const SizedBox(height: 16),

            /// Tags
            Wrap(
              spacing: 6,
              children: tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),

            const SizedBox(height: 16),

            /// Details Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Description",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(widget.product['description']),
                    const Divider(),
                    Text("Brand: ${widget.product['brand']}"),
                    Text("SKU: ${widget.product['sku']}"),
                    Text("Stock: ${widget.product['stock']}"),
                    Text("Dimensions: ${dimensions['width']} x ${dimensions['height']} x ${dimensions['depth']}"),
                    Text("Weight: ${widget.product['weight']} kg"),
                    const SizedBox(height: 6),
                    Text("Warranty: ${widget.product['warrantyInformation']}"),
                    Text("Shipping: ${widget.product['shippingInformation']}"),
                    Text("Return Policy: ${widget.product['returnPolicy']}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Reviews
            const Text("Customer Reviews",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...reviews.map((review) => ListTile(
              leading: const Icon(Icons.person, color: Colors.blueAccent),
              title: Text(review['reviewerName']),
              subtitle: Text(review['comment']),
              trailing: Text("${review['rating']} ⭐"),
            )),

            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text("Scan QR for More Info"),
                  const SizedBox(height: 8),
                  Image.network(widget.product['meta']['qrCode'], height: 100),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      /// Bottom Buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  controller.addToCart(widget.product['id']);
                  controller.changePage(1, controller.products, controller.categories);
                  Get.snackbar("Added", "Product added to cart",
                      snackPosition: SnackPosition.BOTTOM);
                },
                child: const Text("Add to Cart", style: TextStyle(fontSize: 16,color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: openCheckout,
                child: const Text("Buy Now", style: TextStyle(fontSize: 16,color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
