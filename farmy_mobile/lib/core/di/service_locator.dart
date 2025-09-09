import 'package:get_it/get_it.dart';
import '../../features/authentication/services/auth_service.dart';
import '../../features/authentication/services/token_service.dart';
import '../../features/authentication/cubit/auth_cubit.dart';
import '../services/employee_api_service.dart';
import '../services/customer_api_service.dart';
import '../services/inventory_api_service.dart';
import '../services/order_api_service.dart';
import '../services/payment_api_service.dart';
import '../services/expense_api_service.dart';
import '../services/loading_api_service.dart';
import '../services/employee_expense_api_service.dart';

final GetIt serviceLocator = GetIt.instance;

class ServiceLocator {
  static Future<void> init() async {
    // Register core services first
    serviceLocator.registerLazySingleton<TokenService>(() => TokenService());
    serviceLocator.registerLazySingleton<AuthService>(() => AuthService());

    // Register API services that depend on core services
    serviceLocator.registerSingleton<EmployeeApiService>(
      EmployeeApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<CustomerApiService>(
      CustomerApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<InventoryApiService>(
      InventoryApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<OrderApiService>(
      OrderApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<PaymentApiService>(
      PaymentApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<EmployeeExpenseApiService>(
      EmployeeExpenseApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<ExpenseApiService>(
      ExpenseApiService(tokenService: serviceLocator<TokenService>()),
    );
    serviceLocator.registerSingleton<LoadingApiService>(
      LoadingApiService(tokenService: serviceLocator<TokenService>()),
    );

    // Register cubits that depend on services
    serviceLocator.registerLazySingleton<AuthCubit>(
      () => AuthCubit(
        authService: serviceLocator<AuthService>(),
        tokenService: serviceLocator<TokenService>(),
      ),
    );
  }

  static void reset() {
    serviceLocator.reset();
  }
}
