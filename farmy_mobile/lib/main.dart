import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/service_locator.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/cubit/auth_cubit.dart';
import 'features/authentication/cubit/auth_state.dart';

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
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final authCubit = context.read<AuthCubit>();
          final router = AppRouter.createRouter(authCubit);

          return MaterialApp.router(
            title: 'Farmy Mobile',
            theme: AppTheme.lightTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
