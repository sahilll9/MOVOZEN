import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/streaming/streaming_bloc.dart';
import 'presentation/screens/home_screen.dart';

/// Root widget for MoboSafe Pocket Dashcam.
class MoboSafeApp extends StatelessWidget {
  const MoboSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<StreamingBloc>(
          create: (_) => sl<StreamingBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'MoboSafe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
