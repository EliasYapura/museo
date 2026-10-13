import 'package:flutter/material.dart';

import '../estilo.dart';
import '../sesion/sesion.dart';
import 'administracion.dart';
import 'login.dart';

/// Pestaña Perfil.
///
/// Sin sesión iniciada se explica que para recorrer no hace falta cuenta y se
/// ofrece el ingreso del equipo del museo. Con sesión se muestra quién entró y,
/// si es administrador, la puerta a la parte de administración.
class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Text(
            'Museo de La Plata',
            style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text('Perfil', style: AppText.serif(size: 26)),
          const SizedBox(height: 14),
          SizedBox(
            height: 18,
            width: double.infinity,
            child: CustomPaint(painter: GrecaPainter()),
          ),
          const SizedBox(height: 22),

          if (sesion.cargando)
            const Center(child: CircularProgressIndicator(color: AppColors.acento))
          else if (!sesion.haySesion)
            _SinSesion()
          else
            _ConSesion(usuario: sesion.usuario!),
        ],
      ),
    );
  }
}

class _SinSesion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estás recorriendo como visitante.', style: AppText.sans(size: 15)),
        const SizedBox(height: 8),
        Text(
          'Para jugar las misiones no hace falta ninguna cuenta: elegí una y empezá.',
          style: AppText.sans(size: 14),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Trabajás en el museo?', style: AppText.serif(size: 17)),
              const SizedBox(height: 8),
              Text(
                'Ingresá con tu cuenta para cargar misiones, objetos y desafíos.',
                style: AppText.sans(size: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PantallaLogin()),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.acento,
                    side: const BorderSide(color: AppColors.acento),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ingresar',
                    style: AppText.sans(
                      size: 15,
                      color: AppColors.acento,
                      peso: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConSesion extends StatelessWidget {
  final Usuario usuario;
  const _ConSesion({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usuario.nombre, style: AppText.serif(size: 20)),
              const SizedBox(height: 4),
              Text(usuario.email, style: AppText.sans(size: 13.5)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  usuario.esAdministrador ? 'Administrador' : 'Visitante',
                  style: AppText.sans(
                    size: 12.5,
                    color: usuario.esAdministrador ? AppColors.acento : AppColors.textoSecundario,
                    peso: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (usuario.esAdministrador) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaAdministracion()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Administrar el museo',
                style: AppText.sans(size: 15, color: AppColors.fondo, peso: FontWeight.w700),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: sesion.cerrarSesion,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textoSecundario,
              side: const BorderSide(color: AppColors.borde),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cerrar sesión', style: AppText.sans(size: 14.5)),
          ),
        ),
      ],
    );
  }
}
