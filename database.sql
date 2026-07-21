

-- ============================================================================
-- BASE DE DATOS SWATDR - TIENDA DEPARTAMENTAL
-- Script completo con autenticación, auditoría y todo lo necesario
-- ============================================================================

-- EXTENSIÓN DE SEGURIDAD
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- LIMPIEZA DE OBJETOS PREVIOS
DROP VIEW IF EXISTS vista_historial_comprador CASCADE;
DROP VIEW IF EXISTS vista_panel_administrador CASCADE;
DROP VIEW IF EXISTS vista_auditoria_logins CASCADE;

DROP FUNCTION IF EXISTS buscar_ropa_web(TEXT, TEXT, NUMERIC) CASCADE;
DROP FUNCTION IF EXISTS autenticar_usuario(VARCHAR, VARCHAR, VARCHAR, TEXT) CASCADE;
DROP FUNCTION IF EXISTS registrar_usuario(VARCHAR, VARCHAR, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS obtener_historial_logins(INT, INT) CASCADE;

DROP TRIGGER IF EXISTS trg_mensajeria_stock ON variantes_producto CASCADE;
DROP FUNCTION IF EXISTS funcion_mensajeria_stock() CASCADE;

DROP TABLE IF EXISTS logs_sesion CASCADE;
DROP TABLE IF EXISTS detalles_pedido CASCADE;
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS variantes_producto CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS categorias CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- ============================================================================
-- 1. CREACIÓN DE TABLAS
-- ============================================================================

CREATE TABLE roles (
    rol_id SERIAL PRIMARY KEY,
    nombre_rol VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE usuarios (
    usuario_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    contrasenia_hash VARCHAR(255) NOT NULL,
    rol_id INT NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    intentos_fallidos INT DEFAULT 0,
    bloqueado_hasta TIMESTAMP DEFAULT NULL,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES roles(rol_id) ON DELETE RESTRICT
);

CREATE TABLE categorias (
    categoria_id SERIAL PRIMARY KEY,
    nombre_categoria VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT
);

CREATE TABLE productos (
    producto_id SERIAL PRIMARY KEY,
    nombre_producto VARCHAR(150) NOT NULL,
    descripcion TEXT,
    categoria_id INT NOT NULL,
    precio_mercado NUMERIC(10,2) NOT NULL CHECK (precio_mercado > 0),
    marca VARCHAR(100),
    fecha_ingreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id) ON DELETE RESTRICT
);

CREATE TABLE variantes_producto (
    variante_id SERIAL PRIMARY KEY,
    producto_id INT NOT NULL,
    talla VARCHAR(10) NOT NULL,
    color VARCHAR(50) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0),
    CONSTRAINT fk_variante_producto FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
    CONSTRAINT uq_producto_talla_color UNIQUE(producto_id,talla,color)
);

CREATE TABLE pedidos (
    pedido_id SERIAL PRIMARY KEY,
    comprador_id INT NOT NULL,
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total NUMERIC(10,2) DEFAULT 0.00,
    CONSTRAINT fk_pedido_comprador FOREIGN KEY (comprador_id) REFERENCES usuarios(usuario_id) ON DELETE RESTRICT
);

CREATE TABLE detalles_pedido (
    detalle_id SERIAL PRIMARY KEY,
    pedido_id INT NOT NULL,
    variante_id INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL,
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_variante FOREIGN KEY (variante_id) REFERENCES variantes_producto(variante_id) ON DELETE RESTRICT
);

-- ============================================================================
-- 2. TABLA DE AUDITORÍA DE LOGINS
-- ============================================================================

CREATE TABLE logs_sesion (
    log_id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL,
    email VARCHAR(150) NOT NULL,
    fecha_inicio_sesion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    direccion_ip VARCHAR(45),
    user_agent TEXT,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('EXITOSO', 'FALLIDO')),
    mensaje VARCHAR(255),
    CONSTRAINT fk_log_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE CASCADE
);

-- ============================================================================
-- 3. SISTEMA DE MENSAJERÍA AUTOMÁTICA (TRIGGER)
-- ============================================================================

CREATE OR REPLACE FUNCTION funcion_mensajeria_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock = 0 THEN
        RAISE NOTICE '🚨 Alerta Crítica: Variante ID % SIN STOCK', NEW.variante_id;
    ELSIF NEW.stock < 10 THEN
        RAISE NOTICE '⚠️ Advertencia: Variante ID % stock bajo (% unidades)', NEW.variante_id, NEW.stock;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mensajeria_stock
AFTER INSERT OR UPDATE ON variantes_producto
FOR EACH ROW
EXECUTE FUNCTION funcion_mensajeria_stock();

-- ============================================================================
-- 4. ÍNDICES
-- ============================================================================

CREATE INDEX idx_productos_nombre ON productos(nombre_producto);
CREATE INDEX idx_productos_marca ON productos(marca);
CREATE INDEX idx_productos_categoria ON productos(categoria_id);
CREATE INDEX idx_logs_usuario_fecha ON logs_sesion(usuario_id, fecha_inicio_sesion);

-- ============================================================================
-- 5. DATOS DE PRUEBA
-- ============================================================================

INSERT INTO roles(nombre_rol) VALUES ('Administrador'), ('Comprador');

-- Contraseñas: admin123, sofia123, carlos123 (cifradas con bcrypt)
INSERT INTO usuarios(nombre, email, contrasenia_hash, rol_id)
VALUES
('Ing. Alejandro Silva', 'admin.alex@tienda.com', crypt('admin123', gen_salt('bf')), 1),
('Sofía Martínez', 'sofia.mtz@email.com', crypt('sofia123', gen_salt('bf')), 2),
('Carlos Gómez', 'carlos.g@email.com', crypt('carlos123', gen_salt('bf')), 2);

INSERT INTO categorias(nombre_categoria, descripcion)
VALUES
('Caballeros','Ropa informal, formal y deportiva para hombres'),
('Damas','Vestidos, blusas, pantalones y calzado para mujeres'),
('Accesorios','Gorras, cinturones, bufandas y complementos');

INSERT INTO productos(nombre_producto, descripcion, categoria_id, precio_mercado, marca)
VALUES
('Chamarra de Mezclilla Slim Fit', 'Chamarra clásica de mezclilla prelavada', 1, 899.00, 'Levi''s'),
('Playera Tipo Polo Algodón', 'Playera polo transpirable casual', 1, 450.00, 'Lacoste'),
('Vestido de Noche Floral', 'Vestido largo de fiesta con estampado elegante', 2, 1250.00, 'Zara'),
('Jeans High Rise Skinny', 'Pantalón de mezclilla tiro alto para dama', 2, 699.00, 'Pull & Bear'),
('Gorra Deportiva Ajustable', 'Gorra con protección UV para entrenamiento', 3, 349.00, 'Adidas');

INSERT INTO variantes_producto(producto_id, talla, color, stock)
VALUES
(1,'M','Azul Claro',15),
(1,'G','Azul Claro',8),
(1,'M','Negro',0),
(2,'CH','Blanco',25),
(2,'M','Azul Marino',30),
(2,'G','Rojo',4),
(3,'CH','Negro Floral',7),
(3,'M','Rojo Vino',12),
(4,'26','Azul Oscuro',18),
(4,'28','Azul Oscuro',22),
(5,'Única','Negro',50),
(5,'Única','Blanco',35);

INSERT INTO pedidos(comprador_id, total) VALUES (2, 1248.00);

INSERT INTO detalles_pedido(pedido_id, variante_id, cantidad, precio_unitario)
VALUES (1, 1, 1, 899.00), (1, 11, 1, 349.00);

-- ============================================================================
-- 6. FUNCIONES PRINCIPALES
-- ============================================================================

-- BÚSQUEDA DE ROPA
CREATE OR REPLACE FUNCTION buscar_ropa_web(
    p_busqueda TEXT DEFAULT NULL,
    p_categoria TEXT DEFAULT NULL,
    p_precio_max NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    id_producto INT,
    prenda VARCHAR,
    marca VARCHAR,
    categoria VARCHAR,
    precio NUMERIC,
    tallas_disponibles TEXT,
    stock_total BIGINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.producto_id,
        p.nombre_producto::VARCHAR,
        p.marca::VARCHAR,
        c.nombre_categoria::VARCHAR,
        p.precio_mercado,
        array_to_string(array_agg(DISTINCT vp.talla ORDER BY vp.talla),', '),
        SUM(vp.stock)::BIGINT
    FROM productos p
    INNER JOIN categorias c ON p.categoria_id = c.categoria_id
    INNER JOIN variantes_producto vp ON p.producto_id = vp.producto_id
    WHERE (p_busqueda IS NULL OR p.nombre_producto ILIKE '%'||p_busqueda||'%' OR p.marca ILIKE '%'||p_busqueda||'%')
      AND (p_categoria IS NULL OR c.nombre_categoria ILIKE p_categoria)
      AND (p_precio_max IS NULL OR p.precio_mercado <= p_precio_max)
    GROUP BY p.producto_id, p.nombre_producto, p.marca, c.nombre_categoria, p.precio_mercado
    HAVING SUM(vp.stock) > 0
    ORDER BY p.precio_mercado;
END;
$$;

-- AUTENTICACIÓN (LOGIN)
CREATE OR REPLACE FUNCTION autenticar_usuario(
    p_email VARCHAR,
    p_contrasenia VARCHAR,
    p_ip VARCHAR DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    exito BOOLEAN,
    id_usuario INT,
    nombre_usuario VARCHAR,
    rol VARCHAR,
    mensaje TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario RECORD;
BEGIN
    SELECT u.usuario_id, u.nombre, u.contrasenia_hash, r.nombre_rol, u.bloqueado_hasta
    INTO v_usuario
    FROM usuarios u
    INNER JOIN roles r ON u.rol_id = r.rol_id
    WHERE u.email = p_email;
    
    IF v_usuario.usuario_id IS NULL THEN
        INSERT INTO logs_sesion (usuario_id, email, estado, mensaje, direccion_ip, user_agent)
        VALUES (0, p_email, 'FALLIDO', 'Usuario no encontrado', p_ip, p_user_agent);
        RETURN QUERY SELECT FALSE, 0, NULL::VARCHAR, NULL::VARCHAR, 'Usuario no encontrado';
        RETURN;
    END IF;
    
    IF v_usuario.bloqueado_hasta IS NOT NULL AND v_usuario.bloqueado_hasta > NOW() THEN
        RETURN QUERY SELECT FALSE, v_usuario.usuario_id, v_usuario.nombre, v_usuario.nombre_rol, 
                    'Cuenta bloqueada hasta ' || TO_CHAR(v_usuario.bloqueado_hasta, 'HH24:MI:SS');
        RETURN;
    END IF;
    
    IF v_usuario.contrasenia_hash = crypt(p_contrasenia, v_usuario.contrasenia_hash) THEN
        INSERT INTO logs_sesion (usuario_id, email, estado, mensaje, direccion_ip, user_agent)
        VALUES (v_usuario.usuario_id, p_email, 'EXITOSO', 'Login exitoso', p_ip, p_user_agent);
        
        UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NULL 
        WHERE usuario_id = v_usuario.usuario_id;
        
        RETURN QUERY SELECT TRUE, v_usuario.usuario_id, v_usuario.nombre, v_usuario.nombre_rol, 'Login exitoso';
    ELSE
        INSERT INTO logs_sesion (usuario_id, email, estado, mensaje, direccion_ip, user_agent)
        VALUES (v_usuario.usuario_id, p_email, 'FALLIDO', 'Contraseña incorrecta', p_ip, p_user_agent);
        
        UPDATE usuarios SET intentos_fallidos = intentos_fallidos + 1 
        WHERE usuario_id = v_usuario.usuario_id;
        
        IF (SELECT intentos_fallidos FROM usuarios WHERE usuario_id = v_usuario.usuario_id) >= 5 THEN
            UPDATE usuarios SET bloqueado_hasta = NOW() + INTERVAL '30 minutes'
            WHERE usuario_id = v_usuario.usuario_id;
            
            RETURN QUERY SELECT FALSE, v_usuario.usuario_id, v_usuario.nombre, v_usuario.nombre_rol, 
                        'Cuenta bloqueada por 30 minutos por múltiples intentos fallidos';
        ELSE
            RETURN QUERY SELECT FALSE, v_usuario.usuario_id, v_usuario.nombre, v_usuario.nombre_rol, 
                        'Contraseña incorrecta. Intentos restantes: ' || 
                        (5 - (SELECT intentos_fallidos FROM usuarios WHERE usuario_id = v_usuario.usuario_id));
        END IF;
    END IF;
END;
$$;

-- REGISTRO DE USUARIOS
CREATE OR REPLACE FUNCTION registrar_usuario(
    p_nombre VARCHAR,
    p_email VARCHAR,
    p_contrasenia VARCHAR,
    p_rol_nombre VARCHAR DEFAULT 'Comprador'
)
RETURNS TABLE(
    exito BOOLEAN,
    id_usuario INT,
    mensaje TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rol_id INT;
    v_usuario_id INT;
BEGIN
    IF EXISTS (SELECT 1 FROM usuarios WHERE email = p_email) THEN
        RETURN QUERY SELECT FALSE, 0, 'El email ya está registrado';
        RETURN;
    END IF;
    
    SELECT rol_id INTO v_rol_id FROM roles WHERE nombre_rol = p_rol_nombre;
    IF v_rol_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 0, 'Rol no válido. Use "Administrador" o "Comprador"';
        RETURN;
    END IF;
    
    INSERT INTO usuarios (nombre, email, contrasenia_hash, rol_id)
    VALUES (p_nombre, p_email, crypt(p_contrasenia, gen_salt('bf')), v_rol_id)
    RETURNING usuario_id INTO v_usuario_id;
    
    INSERT INTO logs_sesion (usuario_id, email, estado, mensaje)
    VALUES (v_usuario_id, p_email, 'EXITOSO', 'Usuario registrado exitosamente');
    
    RETURN QUERY SELECT TRUE, v_usuario_id, 'Usuario registrado exitosamente';
END;
$$;

-- HISTORIAL DE LOGINS
CREATE OR REPLACE FUNCTION obtener_historial_logins(
    p_usuario_id INT,
    p_limite INT DEFAULT 10
)
RETURNS TABLE(
    fecha TIMESTAMP,
    estado VARCHAR,
    ip VARCHAR,
    mensaje VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT l.fecha_inicio_sesion, l.estado, l.direccion_ip, l.mensaje
    FROM logs_sesion l
    WHERE l.usuario_id = p_usuario_id
    ORDER BY l.fecha_inicio_sesion DESC
    LIMIT p_limite;
END;
$$;

-- ============================================================================
-- 7. VISTAS
-- ============================================================================

-- VISTA ADMINISTRADOR
CREATE OR REPLACE VIEW vista_panel_administrador AS
SELECT 
    p.producto_id,
    p.nombre_producto,
    p.marca,
    vp.talla,
    vp.color,
    vp.stock,
    CASE 
        WHEN vp.stock = 0 THEN 'AGOTADO'
        WHEN vp.stock < 10 THEN 'REABASTECER URGENTE'
        ELSE 'STOCK CORRECTO'
    END AS estado_inventario
FROM productos p
INNER JOIN variantes_producto vp ON p.producto_id = vp.producto_id
ORDER BY vp.stock;

-- VISTA HISTORIAL COMPRADOR
CREATE OR REPLACE VIEW vista_historial_comprador AS
SELECT 
    u.usuario_id,
    u.nombre AS comprador,
    p.pedido_id,
    p.fecha_pedido,
    prod.nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal
FROM usuarios u
INNER JOIN pedidos p ON u.usuario_id = p.comprador_id
INNER JOIN detalles_pedido dp ON p.pedido_id = dp.pedido_id
INNER JOIN variantes_producto vp ON dp.variante_id = vp.variante_id
INNER JOIN productos prod ON vp.producto_id = prod.producto_id;

-- VISTA AUDITORÍA DE LOGINS
CREATE OR REPLACE VIEW vista_auditoria_logins AS
SELECT
    l.log_id,
    l.usuario_id,
    l.email,
    u.nombre AS nombre_usuario,
    l.fecha_inicio_sesion,
    l.direccion_ip,
    l.user_agent,
    l.estado,
    l.mensaje
FROM logs_sesion l
LEFT JOIN usuarios u ON l.usuario_id = u.usuario_id
ORDER BY l.fecha_inicio_sesion DESC;

-- ============================================================================
-- 8. PRUEBAS
-- ============================================================================

-- Probar login
SELECT * FROM autenticar_usuario('admin.alex@tienda.com', 'admin123');

-- Probar registro
SELECT * FROM registrar_usuario('Pedro Pérez', 'pedro@email.com', 'pedro123', 'Comprador');

-- Ver auditoría
SELECT * FROM vista_auditoria_logins;

-- Ver productos
SELECT * FROM buscar_ropa_web();

-- Ver panel admin
SELECT * FROM vista_panel_administrador;

-- Ver historial de compras
SELECT * FROM vista_historial_comprador;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================