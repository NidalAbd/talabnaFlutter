import 'package:equatable/equatable.dart';

abstract class FontSizeState extends Equatable {
  const FontSizeState();

  @override
  List<Object> get props => [];
}

class FontSizeInitial extends FontSizeState {}

class FontSizeLoaded extends FontSizeState {
  final double descriptionFontSize;

  const FontSizeLoaded(this.descriptionFontSize);

  @override
  List<Object> get props => [descriptionFontSize];
}