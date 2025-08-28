import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/service_locator.dart';
import 'core/routes/app_router.dart';
import 'features/authentication/cubit/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await ServiceLocator.init();
  
  runApp(const FarmyApp());
}

class FarmyApp extends StatelessWidget {
  const FarmyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => serviceLocator<AuthCubit>()..initialize(),
      child: Builder(
        builder: (context) {
          final authCubit = context.read<AuthCubit>();
          final router = AppRouter.createRouter(authCubit);
          
          return MaterialApp.router(
            title: 'Farmy Mobile',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                 elevation: 2,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12),
                 ),
               ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
