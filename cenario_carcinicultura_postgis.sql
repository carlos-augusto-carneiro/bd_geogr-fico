-- =====================================================================
-- Aula: Banco de Dados Geográfico - Fundamentos, Modelagem e Consultas
-- Cenário: fazenda de camarão (carcinicultura)
-- PPGCC UERN/UFERSA - Tópicos Avançados em Banco de Dados
-- Autor: Carlos Augusto Carneiro de Freitas Filho
--
-- Requisitos: PostgreSQL + extensão PostGIS
-- Observação: nomes e coordenadas são FICTÍCIOS, criados para a aula.
-- Ordem das coordenadas no WKT: POINT(longitude latitude)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- ---------------------------------------------------------------------
-- 0) Limpeza (permite rodar o script mais de uma vez)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS viveiro  CASCADE;
DROP TABLE IF EXISTS area_app CASCADE;
DROP TABLE IF EXISTS canal    CASCADE;
DROP TABLE IF EXISTS sensor   CASCADE;
DROP TABLE IF EXISTS captacao CASCADE;

-- ---------------------------------------------------------------------
-- 1) Modelagem: uma coluna de geometria por tabela (SRID 4326 = WGS84)
-- ---------------------------------------------------------------------
CREATE TABLE viveiro  (id serial PRIMARY KEY, nome text, geom geometry(Polygon,    4326));  -- tanque de cultivo
CREATE TABLE area_app (id serial PRIMARY KEY, nome text, geom geometry(Polygon,    4326));  -- área de preservação (manguezal)
CREATE TABLE canal    (id serial PRIMARY KEY, nome text, geom geometry(LineString, 4326));  -- canal de abastecimento
CREATE TABLE sensor   (id serial PRIMARY KEY, nome text, geom geometry(Point,      4326));  -- sensor de qualidade da água
CREATE TABLE captacao (id serial PRIMARY KEY, nome text, geom geometry(Point,      4326));  -- casa de bombas

-- ---------------------------------------------------------------------
-- 2) Dados
-- ---------------------------------------------------------------------
INSERT INTO viveiro (nome, geom) VALUES
('Viveiro 1', ST_GeomFromText('POLYGON((-37.100 -4.900,-37.095 -4.900,-37.095 -4.904,-37.100 -4.904,-37.100 -4.900))', 4326)),
('Viveiro 2', ST_GeomFromText('POLYGON((-37.095 -4.900,-37.090 -4.900,-37.090 -4.904,-37.095 -4.904,-37.095 -4.900))', 4326)),
('Viveiro 3', ST_GeomFromText('POLYGON((-37.100 -4.906,-37.095 -4.906,-37.095 -4.910,-37.100 -4.910,-37.100 -4.906))', 4326));

INSERT INTO area_app (nome, geom) VALUES
('Manguezal (APP)', ST_GeomFromText('POLYGON((-37.092 -4.898,-37.080 -4.898,-37.080 -4.903,-37.092 -4.903,-37.092 -4.898))', 4326));

INSERT INTO canal (nome, geom) VALUES
('Canal de abastecimento', ST_GeomFromText('LINESTRING(-37.105 -4.895,-37.097 -4.897,-37.092 -4.897)', 4326));

INSERT INTO sensor (nome, geom) VALUES
('Sensor 1', ST_GeomFromText('POINT(-37.0975 -4.902)', 4326)),
('Sensor 2', ST_GeomFromText('POINT(-37.0985 -4.903)', 4326)),
('Sensor 3', ST_GeomFromText('POINT(-37.0925 -4.902)', 4326)),
('Sensor 4', ST_GeomFromText('POINT(-37.0975 -4.908)', 4326));

INSERT INTO captacao (nome, geom) VALUES
('Casa de bombas', ST_GeomFromText('POINT(-37.105 -4.895)', 4326));

-- ---------------------------------------------------------------------
-- 3) Índices espaciais (R-Tree implementada sobre GiST)
-- ---------------------------------------------------------------------
CREATE INDEX idx_viveiro_geom  ON viveiro  USING GIST (geom);
CREATE INDEX idx_area_app_geom ON area_app USING GIST (geom);
CREATE INDEX idx_canal_geom    ON canal    USING GIST (geom);
CREATE INDEX idx_sensor_geom   ON sensor   USING GIST (geom);
CREATE INDEX idx_captacao_geom ON captacao USING GIST (geom);

-- =====================================================================
-- CONSULTAS DA AULA
-- =====================================================================

-- Exemplo 1 (contenção): Quais sensores estão dentro do Viveiro 1?
-- Esperado: Sensor 1, Sensor 2
SELECT s.nome
FROM viveiro v
JOIN sensor s ON ST_Contains(v.geom, s.geom)
WHERE v.nome = 'Viveiro 1';

-- Exemplo 2 (interseção): Quais viveiros invadem a área de preservação?
-- Esperado: Viveiro 2
SELECT v.nome
FROM viveiro v
JOIN area_app a ON ST_Intersects(v.geom, a.geom);

-- Exemplo 3 (distância): Distância de cada viveiro até a captação, em metros
-- (::geography faz o cálculo sobre o elipsoide e devolve metros)
-- Esperado (aproximado): Viveiro 1 ~780 m | Viveiro 2 ~1240 m | Viveiro 3 ~1340 m
SELECT v.nome,
       ROUND(ST_Distance(v.geom::geography, c.geom::geography)) AS dist_m
FROM viveiro v, captacao c
ORDER BY dist_m;

-- =====================================================================
-- EXTRAS (úteis para a arguição)
-- =====================================================================

-- Versão otimizada do filtro por distância (usa o índice espacial):
-- sensores a até 500 m da casa de bombas
SELECT s.nome
FROM sensor s, captacao c
WHERE ST_DWithin(s.geom::geography, c.geom::geography, 500);

-- Viveiros vizinhos que compartilham o dique (ST_Touches)
-- Esperado: Viveiro 1 e Viveiro 2
SELECT a.nome AS viveiro_a, b.nome AS viveiro_b
FROM viveiro a
JOIN viveiro b ON a.id < b.id AND ST_Touches(a.geom, b.geom);

-- Conversão de SRID para sistema projetado em metros (SIRGAS 2000 / UTM 24S)
SELECT nome, ST_AsText(ST_Transform(geom, 31984)) AS geom_utm
FROM sensor;

-- Área de cada viveiro em metros quadrados
SELECT nome, ROUND(ST_Area(geom::geography)) AS area_m2
FROM viveiro;

-- Para visualizar tudo no mapa (pgAdmin/DBeaver/QGIS):
SELECT 'viveiro'  AS tipo, nome, geom FROM viveiro
UNION ALL SELECT 'area_app', nome, geom FROM area_app
UNION ALL SELECT 'canal',    nome, geom FROM canal
UNION ALL SELECT 'sensor',   nome, geom FROM sensor
UNION ALL SELECT 'captacao', nome, geom FROM captacao;