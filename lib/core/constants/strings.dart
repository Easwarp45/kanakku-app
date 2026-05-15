/// App-wide string constants
abstract class AppStrings {
  // App
  static const String appName = 'Kanakku Expense Tracker';
  static const String appTitle = 'Kanakku';

  // Auth
  static const String terminalAccess = 'Terminal Access';
  static const String authorizedPersonnelOnly =
      'Authorized personnel only. Please verify credentials.';
  static const String emailAddress = 'Email Address';
  static const String enterEmail = 'Enter your email';
  static const String password = 'Password';
  static const String enterPassword = 'Enter your password';
  static const String confirmPassword = 'Confirm Password';
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String forgotPassword = 'Forgot Password?';
  static const String rememberMe = 'Remember me';

  // Dashboard
  static const String welcomeBack = 'Welcome back,';
  static const String balance = 'Balance';
  static const String totalIncome = 'Total Income';
  static const String totalExpenses = 'Total Expenses';
  static const String recentTransactions = 'Recent Transactions';
  static const String addExpense = 'Add Expense';
  static const String addIncome = 'Add Income';
  static const String viewAll = 'View All';
  static const String noTransactions = 'No transactions yet';

  // Expenses
  static const String expenseName = 'Expense Name';
  static const String amount = 'Amount';
  static const String category = 'Category';
  static const String date = 'Date';
  static const String description = 'Description';
  static const String selectCategory = 'Select a category';
  static const String addExpenseTitle = 'Add New Expense';
  static const String editExpenseTitle = 'Edit Expense';
  static const String deleteExpense = 'Delete Expense';
  static const String confirmDelete =
      'Are you sure you want to delete this expense?';

  // Categories
  static const String food = 'Food';
  static const String transport = 'Transport';
  static const String entertainment = 'Entertainment';
  static const String utilities = 'Utilities';
  static const String shopping = 'Shopping';
  static const String healthcare = 'Healthcare';
  static const String other = 'Other';

  // Validation
  static const String emailRequired = 'Email is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String passwordRequired = 'Password is required';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String amountRequired = 'Amount is required';
  static const String invalidAmount = 'Please enter a valid amount';
  static const String categoryRequired = 'Please select a category';
  static const String nameRequired = 'Name is required';
  static const String descriptionRequired = 'Description is required';

  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String logout = 'Logout';
  static const String settings = 'Settings';
  static const String profile = 'Profile';
  static const String tryAgain = 'Try Again';
  static const String noInternetConnection =
      'No internet connection. Please check your network.';
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';
  static const String unauthorized =
      'Unauthorized. Please login again.';
}
