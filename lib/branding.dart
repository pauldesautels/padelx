import 'package:flutter/material.dart';

const padelXBackground = Color(0xFF021812);
const padelXSurface = Color(0xFF0B211B);
const padelXAccent = Color(0xFF72F58B);
const padelXAuthFieldFill = Color(0xFF071A15);
const padelXAuthBorder = Color(0xFF29463B);
const padelXAuthAccent = Color(0xFF74E8A0);
const padelXAuthPrimary = Color(0xFF237A4F);
const padelXAuthPrimaryDisabled = Color(0xFF29483A);
const padelXMarkAsset = 'assets/branding/padelx-mark.png';

class PadelXBrandMark extends StatelessWidget {
  final double size;
  final bool announce;

  const PadelXBrandMark({super.key, this.size = 112, this.announce = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      padelXMarkAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    if (!announce) return image;
    return Semantics(label: 'PadelX', image: true, child: image);
  }
}

class PadelXWordmark extends StatelessWidget {
  const PadelXWordmark({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Text(
      'PADELX',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 7,
      ),
    ),
  );
}
