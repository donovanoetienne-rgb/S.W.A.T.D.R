const express = require('express');
const cors = require('cors');
const pool = require('./config/db');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const app = express();
const PORT = 3000;

// ==========================================
// CONFIGURACIÓN DE SWAGGER
// ==========================================
const swaggerOptions = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'SWATDR - API Tienda Departamental',
            version: '1.0.0',
            description: 'API para tienda departamental con autenticación, productos y pedidos'
        },
        servers: [{ url: 'http://localhost:3000' }]
    },
    apis: ['./server.js']
};

const swaggerDocs = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs));

app.use(express.static('public'));
app.use(cors());
app.use(express.json());

// ==========================================
// RUTA PRINCIPAL
// ==========================================
app.get('/', (req, res) => {
    res.sendFile(__dirname + '/public/index.html');
});

// ==========================================
// AUTENTICACIÓN
// ==========================================

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Iniciar sesión
 *     tags: [Autenticación]
 */
app.post('/api/auth/login', async (req, res) => {
    const { email, contrasenia, ip, user_agent } = req.body;
    try {
        const result = await pool.query(
            `SELECT * FROM autenticar_usuario($1, $2, $3, $4)`,
            [email, contrasenia, ip || null, user_agent || null]
        );
        const usuario = result.rows[0];
        if (usuario.exito) {
            res.json({
                success: true,
                usuario: {
                    id: usuario.id_usuario,
                    nombre: usuario.nombre_usuario,
                    rol: usuario.rol
                },
                mensaje: usuario.mensaje
            });
        } else {
            res.status(401).json({
                success: false,
                mensaje: usuario.mensaje
            });
        }
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Registrar nuevo usuario
 *     tags: [Autenticación]
 */
app.post('/api/auth/register', async (req, res) => {
    const { nombre, email, contrasenia, rol } = req.body;
    try {
        const result = await pool.query(
            `SELECT * FROM registrar_usuario($1, $2, $3, $4)`,
            [nombre, email, contrasenia, rol || 'Comprador']
        );
        const usuario = result.rows[0];
        if (usuario.exito) {
            res.status(201).json({
                success: true,
                usuario_id: usuario.id_usuario,
                mensaje: usuario.mensaje
            });
        } else {
            res.status(400).json({
                success: false,
                mensaje: usuario.mensaje
            });
        }
    } catch (error) {
        console.error('Error en registro:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * @swagger
 * /api/auth/auditoria:
 *   get:
 *     summary: Auditoría de inicios de sesión
 *     tags: [Autenticación]
 */
app.get('/api/auth/auditoria', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM vista_auditoria_logins`);
        res.json(result.rows);
    } catch (error) {
        console.error('Error en auditoría:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * @swagger
 * /api/auth/historial/{usuario_id}:
 *   get:
 *     summary: Historial de logins de un usuario
 *     tags: [Autenticación]
 */
app.get('/api/auth/historial/:usuario_id', async (req, res) => {
    const { usuario_id } = req.params;
    const { limite } = req.query;
    try {
        const result = await pool.query(
            `SELECT * FROM obtener_historial_logins($1, $2)`,
            [usuario_id, limite || 10]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener historial:', error);
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// PRODUCTOS
// ==========================================

/**
 * @swagger
 * /api/productos:
 *   get:
 *     summary: Lista de productos
 *     tags: [Productos]
 */
app.get('/api/productos', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM buscar_ropa_web()`);
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * @swagger
 * /api/buscar:
 *   get:
 *     summary: Buscar productos
 *     tags: [Productos]
 */
app.get('/api/buscar', async (req, res) => {
    const { nombre, categoria, precio } = req.query;
    try {
        const result = await pool.query(
            `SELECT * FROM buscar_ropa_web($1, $2, $3)`,
            [nombre || null, categoria || null, precio || null]
        );
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// CATEGORÍAS
// ==========================================

/**
 * @swagger
 * /api/categorias:
 *   get:
 *     summary: Lista de categorías
 *     tags: [Categorías]
 */
app.get('/api/categorias', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM categorias ORDER BY nombre_categoria`);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// USUARIOS
// ==========================================

/**
 * @swagger
 * /api/usuarios:
 *   get:
 *     summary: Lista de usuarios
 *     tags: [Usuarios]
 */
app.get('/api/usuarios', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                u.usuario_id, u.nombre, u.email, u.rol_id, r.nombre_rol,
                u.fecha_registro, u.intentos_fallidos, u.bloqueado_hasta,
                CASE WHEN u.bloqueado_hasta > NOW() THEN 'BLOQUEADO' ELSE 'ACTIVO' END AS estado
            FROM usuarios u
            INNER JOIN roles r ON u.rol_id = r.rol_id
            ORDER BY u.usuario_id
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// PANEL ADMINISTRADOR
// ==========================================

/**
 * @swagger
 * /api/admin:
 *   get:
 *     summary: Panel de administración
 *     tags: [Administración]
 */
app.get('/api/admin', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM vista_panel_administrador`);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// HISTORIAL DE COMPRAS
// ==========================================

/**
 * @swagger
 * /api/historial:
 *   get:
 *     summary: Historial de compras
 *     tags: [Administración]
 */
app.get('/api/historial', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM vista_historial_comprador`);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// DASHBOARD
// ==========================================

/**
 * @swagger
 * /api/dashboard:
 *   get:
 *     summary: Dashboard de estadísticas
 *     tags: [Dashboard]
 */
app.get('/api/dashboard', async (req, res) => {
    try {
        const productos = await pool.query(`SELECT COUNT(*) AS total FROM productos`);
        const usuarios = await pool.query(`SELECT COUNT(*) AS total FROM usuarios`);
        const pedidos = await pool.query(`SELECT COUNT(*) AS total FROM pedidos`);
        const ingresos = await pool.query(`SELECT COALESCE(SUM(total), 0) AS total FROM pedidos`);
        res.json([{
            total_productos: parseInt(productos.rows[0].total),
            total_usuarios: parseInt(usuarios.rows[0].total),
            total_pedidos: parseInt(pedidos.rows[0].total),
            ingresos_totales: parseFloat(ingresos.rows[0].total)
        }]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// PEDIDOS
// ==========================================

/**
 * @swagger
 * /api/pedidos:
 *   post:
 *     summary: Crear un nuevo pedido
 *     tags: [Pedidos]
 */
app.post('/api/pedidos', async (req, res) => {
    const { comprador_id, total, productos } = req.body;
    
    try {
        const pedidoResult = await pool.query(
            `INSERT INTO pedidos (comprador_id, total) 
             VALUES ($1, $2) 
             RETURNING pedido_id`,
            [comprador_id, total]
        );
        
        const pedido_id = pedidoResult.rows[0].pedido_id;
        
        // Aquí puedes agregar los detalles del pedido si los tienes
        if (productos && productos.length > 0) {
            for (const item of productos) {
                await pool.query(
                    `INSERT INTO detalles_pedido (pedido_id, variante_id, cantidad, precio_unitario)
                     VALUES ($1, $2, $3, $4)`,
                    [pedido_id, item.variante_id, item.cantidad, item.precio_unitario]
                );
            }
        }
        
        res.status(201).json({
            success: true,
            pedido_id: pedido_id,
            mensaje: 'Pedido creado exitosamente'
        });
        
    } catch (error) {
        console.error('Error al crear pedido:', error);
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// SERVIDOR
// ==========================================

app.listen(PORT, () => {
    console.log(`✅ Servidor corriendo en http://localhost:${PORT}`);
    console.log(`📚 Documentación Swagger: http://localhost:${PORT}/api-docs`);
    console.log(`🛍️  Panel de Control: http://localhost:${PORT}`);
    console.log('\n📌 ENDPOINTS DISPONIBLES:');
    console.log('   🔐 AUTENTICACIÓN:');
    console.log('   POST /api/auth/login       - Iniciar sesión');
    console.log('   POST /api/auth/register    - Registrar usuario');
    console.log('   GET  /api/auth/auditoria   - Auditoría de logins');
    console.log('   📦 PRODUCTOS:');
    console.log('   GET  /api/productos        - Lista de productos');
    console.log('   GET  /api/buscar           - Buscar productos');
    console.log('   GET  /api/categorias       - Lista de categorías');
    console.log('   📊 ADMINISTRACIÓN:');
    console.log('   GET  /api/admin            - Panel de administración');
    console.log('   GET  /api/historial        - Historial de compras');
    console.log('   👤 USUARIOS:');
    console.log('   GET  /api/usuarios         - Lista de usuarios');
    console.log('   📈 DASHBOARD:');
    console.log('   GET  /api/dashboard        - Estadísticas generales');
    console.log('   🛒 PEDIDOS:');
    console.log('   POST /api/pedidos          - Crear pedido');
});