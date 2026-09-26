// API REST de libros en Node.js (Express) + MySQL
// Mismo comportamiento que apirest_mysql.py, pero en JavaScript.
const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json()); // permite leer cuerpos JSON (equivale a request.json en Flask)

// Pool de conexiones a MySQL (mismos datos que usa la version en Python)
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'root',
  database: 'myflaskapp',
});

// GET /books -> todos los libros
app.get('/books', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM books');
  res.json({ books: rows });
});

// GET /books/:id -> un libro
app.get('/books/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM books WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  res.json({ book: rows[0] });
});

// POST /books -> crear libro (title es obligatorio)
app.post('/books', async (req, res) => {
  const { title, description = '', author = '' } = req.body || {};
  if (!title) return res.status(400).json({ error: 'title is required' });
  const [result] = await pool.query(
    'INSERT INTO books (title, description, author) VALUES (?, ?, ?)',
    [title, description, author]
  );
  res.status(201).json({ book: { id: result.insertId, title, description, author } });
});

// PUT /books/:id -> actualizar libro
app.put('/books/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM books WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  const book = { ...rows[0], ...req.body, id: rows[0].id };
  await pool.query(
    'UPDATE books SET title = ?, description = ?, author = ? WHERE id = ?',
    [book.title, book.description, book.author, book.id]
  );
  res.json({ book });
});

// DELETE /books/:id -> borrar libro
app.delete('/books/:id', async (req, res) => {
  await pool.query('DELETE FROM books WHERE id = ?', [req.params.id]);
  res.json({ result: true });
});

// Escucha en 0.0.0.0 para que Windows pueda llegar a la VM
app.listen(3000, '0.0.0.0', () => console.log('API Node escuchando en http://0.0.0.0:3000'));
