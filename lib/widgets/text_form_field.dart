import 'package:flutter/material.dart';
import 'package:talabna/app_theme.dart';

class TextFromField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final bool obscureText;
  final Function validator;
  final Widget prefixIcon;
  final IconButton? suffixIcon;
  final String hintText;
  final EdgeInsets padding;

  const TextFromField(
      {super.key,
      required this.controller,
      required this.obscureText,
      required this.validator,
      required this.prefixIcon,
      required this.hintText,
      this.suffixIcon,
      required TextInputType keyboardType,
      required this.padding,
      required this.maxLength});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: SizedBox(
        child: TextFormField(
          maxLength: maxLength,
          controller: controller,
          obscureText: obscureText,
          keyboardType: TextInputType.text,
          validator: (value) => validator(value),
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            prefixIconColor: theme.iconTheme.color,
            suffixIconColor: theme.iconTheme.color,
            suffixIcon: suffixIcon,
            hintText: hintText,
            filled: true,
            fillColor: theme.inputDecorationTheme.fillColor,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.error,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
