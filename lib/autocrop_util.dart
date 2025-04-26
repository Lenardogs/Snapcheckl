import 'package:image/image.dart' as img;

/// Automatically crops the edges of an image by detecting the bounding box of non-white (or non-background) pixels.
/// Returns the cropped [img.Image].
img.Image autoCropEdges(img.Image image, {int threshold = 245}) {
  int top = 0;
  int bottom = image.height - 1;
  int left = 0;
  int right = image.width - 1;

  // Helper to check if a pixel is 'background' (almost white)
  bool isBackground(img.Pixel pixel) {
    final r = pixel.r;
    final g = pixel.g;
    final b = pixel.b;
    return r > threshold && g > threshold && b > threshold;
  }

  // Find top
  for (int y = 0; y < image.height; y++) {
    bool found = false;
    for (int x = 0; x < image.width; x++) {
      if (!isBackground(image.getPixel(x, y))) {
        top = y;
        found = true;
        break;
      }
    }
    if (found) break;
  }
  // Find bottom
  for (int y = image.height - 1; y >= 0; y--) {
    bool found = false;
    for (int x = 0; x < image.width; x++) {
      if (!isBackground(image.getPixel(x, y))) {
        bottom = y;
        found = true;
        break;
      }
    }
    if (found) break;
  }
  // Find left
  for (int x = 0; x < image.width; x++) {
    bool found = false;
    for (int y = top; y <= bottom; y++) {
      if (!isBackground(image.getPixel(x, y))) {
        left = x;
        found = true;
        break;
      }
    }
    if (found) break;
  }
  // Find right
  for (int x = image.width - 1; x >= 0; x--) {
    bool found = false;
    for (int y = top; y <= bottom; y++) {
      if (!isBackground(image.getPixel(x, y))) {
        right = x;
        found = true;
        break;
      }
    }
    if (found) break;
  }

  // Edge case: if no content found, return original
  if (left >= right || top >= bottom) return image;

  // Crop
  return img.copyCrop(image, x: left, y: top, width: right - left + 1, height: bottom - top + 1);
}
