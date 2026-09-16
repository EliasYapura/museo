import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

// Permite recibir cuerpos JSON en las peticiones.
app.use(express.json());

// Endpoint de diagnostico: sirve para confirmar que la API esta viva.
// No consulta la base; responde aunque la base este caida.
app.get('/health', (req, res) => {
  res.json({
    estado: 'ok',
    servicio: 'exploradores-museo-backend',
    hora: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`API escuchando en http://localhost:${PORT}`);
});
