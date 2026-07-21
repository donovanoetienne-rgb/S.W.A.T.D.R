# 🛍️ SWATDR - API Tienda Departamental

API completa para tienda departamental con autenticación, gestión de productos, pedidos y documentación interactiva con Swagger.

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Tecnologías](#-tecnologías)
- [Arquitectura](#-arquitectura)
- [Instalación](#-instalación)
- [Endpoints](#-endpoints)
- [Documentación Swagger](#-documentación-swagger)
- [Despliegue en GCP](#-despliegue-en-gcp)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Autor](#-autor)

---

## 🚀 Características

- 🔐 **Autenticación**: Login y registro con contraseñas cifradas (bcrypt)
- 📋 **Auditoría**: Registro de todos los intentos de inicio de sesión
- 📦 **Productos**: Catálogo con búsqueda por nombre, categoría y precio
- 📊 **Panel Administrador**: Control de inventario con alertas de stock bajo
- 📈 **Dashboard**: Estadísticas generales (usuarios, pedidos, ingresos)
- 🛒 **Pedidos**: Creación de pedidos con detalles
- 📚 **Swagger**: Documentación interactiva de la API
- 🗄️ **PostgreSQL**: Base de datos con funciones y vistas personalizadas
- ☁️ **GCP**: Desplegado en Google Cloud Platform

---

## 🛠️ Tecnologías

| Tecnología | Descripción |
|------------|-------------|
| **Node.js** | Entorno de ejecución para JavaScript |
| **Express** | Framework para construir la API REST |
| **PostgreSQL** | Base de datos relacional |
| **Swagger** | Documentación interactiva de la API |
| **pgcrypto** | Cifrado de contraseñas con bcrypt |
| **Google Cloud Platform** | Infraestructura en la nube (Cloud SQL y Compute Engine) |

---


---

## 📦 Instalación

### Requisitos previos

- Node.js (v18 o superior)
- PostgreSQL (local o en la nube)
- npm

### Pasos

```bash
# Clonar el repositorio
git clone https://github.com/donovanoteinne-rgb/S.W.A.T.D.R.git
cd S.W.A.T.D.R

# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env
# Edita .env con tus credenciales

# Ejecutar el servidor
node server.js
