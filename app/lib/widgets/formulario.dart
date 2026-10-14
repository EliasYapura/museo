import 'package:flutter/material.dart';

import '../estilo.dart';

/// Piezas comunes de los formularios de la app, para que el ingreso y las
/// pantallas de administración se vean y se comporten igual.

/// Etiqueta de un campo, con la marca de obligatorio u opcional.
class EtiquetaCampo extends StatelessWidget {
  final String texto;
  final bool obligatorio;
  final bool opcional;

  const EtiquetaCampo(this.texto, {super.key, this.obligatorio = false, this.opcional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(texto, style: AppText.sans(size: 13.5, peso: FontWeight.w700)),
          if (obligatorio)
            Text(' *', style: AppText.sans(size: 13.5, color: AppColors.dificil, peso: FontWeight.w700)),
          if (opcional) Text('  (opcional)', style: AppText.sans(size: 12.5)),
        ],
      ),
    );
  }
}

/// Decoración de los campos de texto. El borde cambia de color al enfocarse y
/// al tener un error, que es la señal que se ve sin leer.
InputDecoration decoracionCampo({Widget? suffixIcon, String? pista}) {
  OutlineInputBorder borde(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  return InputDecoration(
    filled: true,
    fillColor: AppColors.superficie,
    suffixIcon: suffixIcon,
    hintText: pista,
    hintStyle: AppText.sans(size: 14, color: AppColors.textoInactivo),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: borde(AppColors.borde),
    focusedBorder: borde(AppColors.acento),
    errorBorder: borde(AppColors.dificil),
    focusedErrorBorder: borde(AppColors.dificil),
    errorStyle: AppText.sans(size: 12.5, color: AppColors.dificil),
  );
}

/// Estilo de los campos de texto.
TextStyle get estiloCampo => AppText.sans(size: 15, color: AppColors.textoPrimario);

/// Aviso en bloque: el error general de una pantalla o la confirmación de que
/// algo se guardó.
class Aviso extends StatelessWidget {
  final String texto;
  final bool esError;

  const Aviso(this.texto, {super.key, this.esError = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: esError ? AppColors.dificil : AppColors.facil),
      ),
      child: Text(
        texto,
        style: AppText.sans(size: 13.5, color: AppColors.textoPrimario),
      ),
    );
  }
}

/// Botón principal, con su estado de "guardando".
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final String textoOcupado;
  final bool ocupado;
  final VoidCallback? alTocar;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.textoOcupado,
    required this.ocupado,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: ocupado ? null : alTocar,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.acento,
          disabledBackgroundColor: AppColors.superficie,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          ocupado ? textoOcupado : texto,
          style: AppText.sans(
            size: 15,
            color: ocupado ? AppColors.textoInactivo : AppColors.fondo,
            peso: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
