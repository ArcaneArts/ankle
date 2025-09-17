import 'dart:convert';
import 'dart:math';

int gf_add(int a, int b) => a ^ b;

const int _primitivePoly = 0x1b; // Low bits for reduction

int gf_mult(int a, int b) {
  int product = 0;
  for (int i = 0; i < 8; i++) {
    if ((b & 1) == 1) {
      product ^= a;
    }
    bool hi_bit_set = (a & 0x80) != 0;
    a = (a << 1) & 0xFF;
    if (hi_bit_set) {
      a ^= _primitivePoly;
    }
    b >>= 1;
  }
  return product;
}

int gf_pow(int a, int e) {
  int res = 1;
  int base = a;
  while (e > 0) {
    if (e & 1 == 1) res = gf_mult(res, base);
    base = gf_mult(base, base);
    e >>= 1;
  }
  return res;
}

int gf_inverse(int a) {
  if (a == 0) throw Exception('Division by zero');
  return gf_pow(a, 254); // a^{255} = 1, so inverse = a^{254}
}

int evaluate(List<int> coef, int x) {
  if (coef.isEmpty) return 0;
  int result = coef[coef.length - 1];
  for (int i = coef.length - 2; i >= 0; i--) {
    result = gf_mult(result, x);
    result = gf_add(result, coef[i]);
  }
  return result;
}

int compute_li0(int i, List<int> xs) {
  int n = xs.length;
  int prod = 1;
  for (int jj = 0; jj < n; jj++) {
    if (jj == i) continue;
    int xj = xs[jj];
    int xi = xs[i];
    int num_term = xj; // 0 - xj = xj (char 2)
    int den = gf_add(xi, xj); // xi - xj = xi + xj
    if (den == 0) throw Exception('Duplicate x values');
    int inv_den = gf_inverse(den);
    prod = gf_mult(prod, gf_mult(num_term, inv_den));
  }
  return prod;
}

int lagrange_interpolate(List<int> xs, List<int> ys, int x_eval) {
  // Specialized for x_eval = 0
  int n = xs.length;
  if (n != ys.length || n == 0) throw Exception('Invalid inputs');
  int result = 0;
  for (int i = 0; i < n; i++) {
    int li = compute_li0(i, xs);
    int contrib = gf_mult(ys[i], li);
    result = gf_add(result, contrib);
  }
  return result;
}

/// This will continue generating more shares so long as the iterator keeps pulling them
Iterable<String> encodeSSS(
  int threshold,
  String rawText,
  String charset,
) sync* {
  if (threshold < 1 || threshold > 255) {
    throw Exception('Threshold must be 1-255');
  }
  String base64 = base64Encode(utf8.encode(rawText));
  Random random = Random("$rawText.$charset.$threshold.ankle".hashCode);

  List<int> secretBytes = utf8.encode(base64);
  int numChunks = secretBytes.length;

  // Generate polynomials: coef[0] = secret byte, coef[1..threshold-1] = random
  List<List<int>> coefficients = List.generate(numChunks, (j) {
    List<int> coef = List.filled(threshold, 0);
    coef[0] = secretBytes[j];
    for (int d = 1; d < threshold; d++) {
      coef[d] = random.nextInt(256);
    }
    return coef;
  });

  int shareIndex = 0;
  while (true) {
    shareIndex++;
    if (shareIndex > 255) {
      throw Exception("FIELD LIMIT MAXED 255"); // Field limit
    }
    int x = shareIndex;

    List<int> shareBytes = [];
    for (int j = 0; j < numChunks; j++) {
      int y = evaluate(coefficients[j], x);
      shareBytes.add(y);
    }

    // Prepend x as byte
    List<int> fullShareBytes = [x, ...shareBytes];
    String shareBase64 = base64Encode(fullShareBytes);
    yield encodeFullCustomBase(charset, shareBase64);
  }
}

String decodeSSS(List<String> parts) {
  if (parts.length < 1) throw Exception('No parts provided');
  // Convert the parts back to base64 shares
  parts = parts.map(decodeFullCustomBase).toList();

  // Decode base64 to bytes
  List<List<int>> shareBytesList = parts.map(base64Decode).toList();
  int numShares = shareBytesList.length;
  if (numShares == 0) throw Exception('No shares');

  int shareLen = shareBytesList[0].length;
  if (shareLen < 2) throw Exception('Invalid share length');

  // Extract xs and ys
  List<int> xs = [];
  List<List<int>> ys = List.generate(numShares, (i) => <int>[]);
  for (int i = 0; i < numShares; i++) {
    List<int> bytes = shareBytesList[i];
    if (bytes.length != shareLen) throw Exception('Inconsistent share lengths');
    int x = bytes[0];
    if (x < 1 || x > 255) throw Exception('Invalid share index');
    xs.add(x);
    ys[i] = bytes.sublist(1);
  }

  int numChunks = shareLen - 1;
  List<int> secretBytes = [];
  for (int j = 0; j < numChunks; j++) {
    List<int> y_chunk = [];
    for (int i = 0; i < numShares; i++) {
      y_chunk.add(ys[i][j]);
    }
    // Reconstruct at x=0
    int secret_byte = lagrange_interpolate(xs, y_chunk, 0);
    secretBytes.add(secret_byte);
  }

  String combinedBase64 = utf8.decode(secretBytes);

  // To get the original text, decode the combined base64
  return utf8.decode(base64Decode(combinedBase64));
}

String encodeFullCustomBase(String charset, String base64) =>
    "$charset${encodeToCustomBase(base64, charset)}";

String encodeToCustomBase(String base64Input, String charset) {
  if (base64Input.isEmpty) return '';

  List<int> bytes = base64.decode(base64Input);
  int n = charset.length;
  if (n < 2) throw Exception('Charset must have at least 2 unique characters');

  BigInt number = BigInt.zero;
  for (int byte in bytes) {
    number = (number << 8) | BigInt.from(byte & 0xFF);
  }

  int bitLength = bytes.length * 8;
  if (bitLength == 0) return '';

  double log2N = log(n) / log(2);
  int outputLength = (bitLength / log2N).ceil().toInt();

  List<int> digits = [];
  BigInt base = BigInt.from(n);

  while (number > BigInt.zero) {
    digits.add((number % base).toInt());
    number = number ~/ base;
  }

  while (digits.length < outputLength) {
    digits.add(0);
  }

  digits = digits.reversed.toList();

  StringBuffer sb = StringBuffer();
  for (int digit in digits) {
    sb.write(charset[digit]);
  }

  return sb.toString();
}

String extractCharset(String encoded) {
  List<String> x = [];
  for (int i = 0; i < encoded.length; i++) {
    if (!x.contains(encoded[i])) {
      x.add(encoded[i]);
    } else {
      break;
    }
  }

  return x.join();
}

String decodeFullCustomBase(String encoded) {
  String charset = extractCharset(encoded);
  return decodeFromCustomBase(encoded.substring(charset.length), charset);
}

String decodeFromCustomBase(String encoded, String charset) {
  if (encoded.isEmpty) return '';

  int outputLength = encoded.length;
  int n = charset.length;
  if (n < 2) throw Exception('Charset must have at least 2 unique characters');

  Map<String, int> charToDigit = {};
  for (int i = 0; i < n; i++) {
    String ch = charset[i];
    if (charToDigit.containsKey(ch)) {
      throw Exception('Charset must have unique characters');
    }
    charToDigit[ch] = i;
  }

  BigInt number = BigInt.zero;
  BigInt base = BigInt.from(n);
  for (int i = 0; i < outputLength; i++) {
    String ch = encoded[i];
    int? digit = charToDigit[ch];
    if (digit == null) throw Exception('Invalid character in encoded string');
    number = number * base + BigInt.from(digit);
  }

  double log2N = log(n) / log(2);
  double maxBits = outputLength * log2N;
  double minBits = (outputLength - 1) * log2N;

  int byteLen = (maxBits / 8).floor();
  int bitLen = byteLen * 8;
  if (!(bitLen > minBits && bitLen <= maxBits)) {
    throw Exception('Invalid encoded length for this charset');
  }

  List<int> bytes = List<int>.filled(byteLen, 0);
  BigInt temp = number;
  for (int i = byteLen - 1; i >= 0; i--) {
    bytes[i] = (temp & BigInt.from(0xFF)).toInt();
    temp = temp >> 8;
  }
  if (temp != BigInt.zero) {
    throw Exception('Number too large for the computed byte length');
  }

  return base64.encode(bytes);
}
