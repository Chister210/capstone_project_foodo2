import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;

class ImageCompressionService {
  static final ImageCompressionService _instance = ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  // Compress image and convert to base64
  Future<String> compressAndEncodeImage(File imageFile, {
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 80,
  }) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image if needed
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxWidth : null,
          height: image.width > image.height ? null : maxHeight,
          maintainAspect: true,
        );
      }

      // Encode as JPEG with compression
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      // Convert to base64
      final base64String = base64Encode(compressedBytes);
      
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      // Fallback to original image if compression fails
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    }
  }

  // Get image size from base64 string
  Map<String, int> getImageSize(String base64String) {
    try {
      // Remove data URL prefix
      final base64Data = base64String.split(',').last;
      final bytes = base64Decode(base64Data);
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        return {
          'width': image.width,
          'height': image.height,
        };
      }
    } catch (e) {
      print('Error getting image size: $e');
    }
    
    return {'width': 0, 'height': 0};
  }

  // Check if image needs compression
  bool needsCompression(String base64String, {int maxSizeKB = 500}) {
    try {
      final base64Data = base64String.split(',').last;
      final bytes = base64Decode(base64Data);
      final sizeKB = bytes.length / 1024;
      return sizeKB > maxSizeKB;
    } catch (e) {
      return false;
    }
  }

  // Compress existing base64 image
  Future<String> compressBase64Image(String base64String, {
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 80,
  }) async {
    try {
      // Remove data URL prefix
      final base64Data = base64String.split(',').last;
      final bytes = base64Decode(base64Data);
      
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        return base64String; // Return original if decode fails
      }

      // Resize image if needed
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxWidth : null,
          height: image.width > image.height ? null : maxHeight,
          maintainAspect: true,
        );
      }

      // Encode as JPEG with compression
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      // Convert to base64
      final compressedBase64 = base64Encode(compressedBytes);
      
      return 'data:image/jpeg;base64,$compressedBase64';
    } catch (e) {
      print('Error compressing base64 image: $e');
      return base64String; // Return original if compression fails
    }
  }
}
