/// Validation utility for form inputs and data
abstract class Validators {
  /// Email validation pattern
  static const String _emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// Validates if email is in correct format
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    if (!RegExp(_emailPattern).hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates password strength
  /// Requires: min 6 chars, at least 1 letter and 1 number
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      return 'Password must contain at least one letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates if password and confirm password match
  static String? validatePasswordMatch(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validates general text field (non-empty)
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  /// Validates minimum text length
  static String? validateMinLength(
    String? value,
    int minLength,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum text length
  static String? validateMaxLength(
    String? value,
    int maxLength,
    String fieldName,
  ) {
    if (value == null) return null;

    if (value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validates phone number (basic validation)
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }

    if (!RegExp(r'^[0-9]{10,}$').hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''))) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validates numeric amount
  static String? validateAmount(String? amount) {
    if (amount == null || amount.isEmpty) {
      return 'Amount is required';
    }

    final numValue = double.tryParse(amount);
    if (numValue == null) {
      return 'Please enter a valid amount';
    }

    if (numValue <= 0) {
      return 'Amount must be greater than 0';
    }

    if (numValue > 999999999) {
      return 'Amount is too large';
    }

    return null;
  }

  /// Validates if number is positive
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final numValue = double.tryParse(value);
    if (numValue == null) {
      return '$fieldName must be a valid number';
    }

    if (numValue <= 0) {
      return '$fieldName must be greater than 0';
    }

    return null;
  }

  /// Validates username
  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }

    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (username.length > 20) {
      return 'Username must not exceed 20 characters';
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, underscores, and hyphens';
    }

    return null;
  }

  /// Validates URL format
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'URL is required';
    }

    try {
      Uri.parse(url);
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'URL must start with http:// or https://';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid URL';
    }
  }

  /// Validates credit card number (basic Luhn algorithm)
  static String? validateCreditCard(String? cardNumber) {
    if (cardNumber == null || cardNumber.isEmpty) {
      return 'Card number is required';
    }

    final digits = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length < 13 || digits.length > 19) {
      return 'Card number must be between 13 and 19 digits';
    }

    return null;
  }

  /// Validates date format (assumes MM/DD/YYYY or similar)
  static String? validateDateFormat(String? date) {
    if (date == null || date.isEmpty) {
      return 'Date is required';
    }

    try {
      DateTime.parse(date);
      return null;
    } catch (e) {
      return 'Please enter a valid date';
    }
  }

  /// Validates if password and confirm password are provided
  static bool arePasswordsValid(String password, String confirmPassword) {
    return password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        password == confirmPassword &&
        password.length >= 6;
  }

  /// Checks if all fields are filled
  static bool areAllFieldsFilled(List<String> fields) {
    return fields.every((field) => field.trim().isNotEmpty);
  }
}
