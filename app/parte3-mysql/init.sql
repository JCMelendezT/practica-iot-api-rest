-- =============================================================================
-- Base de datos de la practica: myflaskapp
--
-- Se importa durante el aprovisionamiento:
--     sudo mysql -u root -proot < /home/vagrant/app/parte3-mysql/init.sql
--
-- IMPORTANTE - este script deja la base SIEMPRE en el mismo estado:
-- borra la tabla books si existe y la vuelve a crear con 2 libros.
-- Eso significa que `vagrant provision` (o `vagrant up --provision`) es un
-- RESET de los datos. Para conservarlos usá `vagrant halt` + `vagrant up`.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS myflaskapp;
USE myflaskapp;

DROP TABLE IF EXISTS books;

CREATE TABLE books (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title varchar(255),
    description varchar(255),
    author varchar(255)
);

-- `id` va en NULL a proposito: AUTO_INCREMENT lo asigna MySQL.
-- (En la Parte 1, la lista de Python, el id lo genera el codigo con
--  books[-1]['id'] + 1. Esa diferencia tambien se puede explicar.)
INSERT INTO books (id, title, description, author) VALUES
    (NULL, "La hojarasca",    "Interesante", "Gabo"),
    (NULL, "El principito",   "Brillante",   "Antoine de Saint");
