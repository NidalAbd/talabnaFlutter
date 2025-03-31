
// font_size_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/services/font_size_service.dart';
import 'package:talabna/blocs/font_size/font_size_event.dart';
import 'package:talabna/blocs/font_size/font_size_state.dart';

class FontSizeBloc extends Bloc<FontSizeEvent, FontSizeState> {
  FontSizeBloc() : super(FontSizeInitial()) {
    on<FontSizeInitialized>(_onFontSizeInitialized);
    on<FontSizeIncreased>(_onFontSizeIncreased);
    on<FontSizeDecreased>(_onFontSizeDecreased);
    on<FontSizeReset>(_onFontSizeReset);
    on<FontSizeChanged>(_onFontSizeChanged);
  }

  Future<void> _onFontSizeInitialized(
      FontSizeInitialized event,
      Emitter<FontSizeState> emit,
      ) async {
    final fontSize = await FontSizeService.getDescriptionFontSize();
    emit(FontSizeLoaded(fontSize));
  }

  Future<void> _onFontSizeIncreased(
      FontSizeIncreased event,
      Emitter<FontSizeState> emit,
      ) async {
    final newFontSize = await FontSizeService.increaseFontSize();
    emit(FontSizeLoaded(newFontSize));
  }

  Future<void> _onFontSizeDecreased(
      FontSizeDecreased event,
      Emitter<FontSizeState> emit,
      ) async {
    final newFontSize = await FontSizeService.decreaseFontSize();
    emit(FontSizeLoaded(newFontSize));
  }

  Future<void> _onFontSizeReset(
      FontSizeReset event,
      Emitter<FontSizeState> emit,
      ) async {
    final newFontSize = await FontSizeService.resetFontSize();
    emit(FontSizeLoaded(newFontSize));
  }

  Future<void> _onFontSizeChanged(
      FontSizeChanged event,
      Emitter<FontSizeState> emit,
      ) async {
    await FontSizeService.setDescriptionFontSize(event.fontSize);
    emit(FontSizeLoaded(event.fontSize));
  }
}