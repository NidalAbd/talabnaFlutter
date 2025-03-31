import 'package:equatable/equatable.dart';

abstract class FontSizeEvent extends Equatable {
  const FontSizeEvent();

  @override
  List<Object> get props => [];
}

class FontSizeInitialized extends FontSizeEvent {}

class FontSizeIncreased extends FontSizeEvent {}

class FontSizeDecreased extends FontSizeEvent {}

class FontSizeReset extends FontSizeEvent {}

class FontSizeChanged extends FontSizeEvent {
  final double fontSize;

  const FontSizeChanged(this.fontSize);

  @override
  List<Object> get props => [fontSize];
}