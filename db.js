const { Pool } = require('pg');

const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'S.W.A.T.D.R',
    password: 'Chivascampeon',
    port: 5432
});

pool.connect()
    .then(() => console.log('✅ Conectado a PostgreSQL'))
    .catch(err => console.error('❌ Error de conexión:', err));

module.exports = pool;