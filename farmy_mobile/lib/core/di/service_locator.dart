import 'package:get_it/get_it.dart';
import '../../features/authentication/services/auth_service.dart';
import '../../features/authentication/services/token_service.dart';
import '../../features/authentication/cubit/auth_cubit.dart';

final GetIt serviceLocator = GetIt.instance;

class ServiceLocator {
  static Future<void> init() async {
    // Register services
    serviceLocator.registerLazySingleton<TokenService>(() => TokenService());
    serviceLocator.registerLazySingleton<AuthService>(() => AuthService());
    
    // Register cubits
    serviceLocator.registerFactory<AuthCubit>(
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