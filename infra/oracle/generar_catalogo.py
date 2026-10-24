# Script auxiliar: generacion de SQL para catalogo geografico
# Fuente de datos: Repositorio hsvchcl/chilean-territorial-divisions, basado en la codificacion CUT SUBDERE
# Proyecto: RutaExpress (Issue #57)
import urllib.request
import json
import os

url = 'https://raw.githubusercontent.com/hsvchcl/chilean-territorial-divisions/master/regiones-provincias-comunas.json'
with urllib.request.urlopen(url) as r:
    data = json.loads(r.read().decode('utf-8'))

regions = {}
comunas = []
for reg in data:
    for prov in reg['provincias']:
        for com in prov['comunas']:
            com_code = int(com['code'])
            reg_id = int(str(com_code).zfill(5)[:2])
            reg_name = reg['region']
            if reg_id not in regions:
                regions[reg_id] = reg_name
            comunas.append((com_code, reg_id, com['name']))

sql = []
sql.append('-- =============================================================================')
sql.append('-- Script: 06_catalogo_geografico.sql')
sql.append('-- Descripcion: Catalogo Geografico de Chile (16 Regiones y 346 Comunas - CUT SUBDERE)')
sql.append('-- Fuente oficial: Codigo Unico Territorial (CUT) de SUBDERE, Ministerio del Interior')
sql.append('-- Proyecto: RutaExpress (Issue #57)')
sql.append('-- Esquema: USER_ENVIOS')
sql.append('-- =============================================================================')
sql.append('')
sql.append('ALTER SESSION SET CURRENT_SCHEMA = USER_ENVIOS;')
sql.append('')
sql.append('-- 1. Creacion de tablas de catalogo geografico')
sql.append('CREATE TABLE USER_ENVIOS.REGIONES (')
sql.append('    id_region  NUMBER(2)     NOT NULL,')
sql.append('    nombre     VARCHAR2(100) NOT NULL,')
sql.append('    CONSTRAINT pk_regiones PRIMARY KEY (id_region),')
sql.append('    CONSTRAINT uk_regiones_nombre UNIQUE (nombre)')
sql.append(');')
sql.append('')
sql.append('CREATE TABLE USER_ENVIOS.COMUNAS (')
sql.append('    id_comuna  NUMBER(5)     NOT NULL,')
sql.append('    id_region  NUMBER(2)     NOT NULL,')
sql.append('    nombre     VARCHAR2(100) NOT NULL,')
sql.append('    CONSTRAINT pk_comunas PRIMARY KEY (id_comuna),')
sql.append('    CONSTRAINT fk_comunas_region FOREIGN KEY (id_region) REFERENCES USER_ENVIOS.REGIONES (id_region),')
sql.append('    CONSTRAINT uk_comunas_region_nombre UNIQUE (id_region, nombre)')
sql.append(');')
sql.append('CREATE INDEX USER_ENVIOS.idx_comunas_region ON USER_ENVIOS.COMUNAS (id_region);')
sql.append('')
sql.append("COMMENT ON TABLE USER_ENVIOS.REGIONES IS 'Catalogo oficial de las 16 regiones de Chile (CUT SUBDERE)';")
sql.append("COMMENT ON TABLE USER_ENVIOS.COMUNAS IS 'Catalogo oficial de las 346 comunas de Chile (CUT SUBDERE)';")
sql.append('')
sql.append('-- 2. Insercion de las 16 Regiones')
for rid in sorted(regions.keys()):
    rname = regions[rid].replace("'", "''")
    sql.append(f"INSERT INTO USER_ENVIOS.REGIONES (id_region, nombre) VALUES ({rid}, '{rname}');")

sql.append('')
sql.append('-- 3. Insercion de las 346 Comunas')
for cid, rid, cname in comunas:
    escaped_cname = cname.replace("'", "''")
    sql.append(f"INSERT INTO USER_ENVIOS.COMUNAS (id_comuna, id_region, nombre) VALUES ({cid}, {rid}, '{escaped_cname}');")

sql.append('')
sql.append('COMMIT;')
sql.append('')
sql.append('-- 4. Consultas de validacion de integridad del catalogo')
sql.append('SELECT COUNT(*) AS total_regiones FROM USER_ENVIOS.REGIONES; -- Debe retornar 16')
sql.append('SELECT COUNT(*) AS total_comunas FROM USER_ENVIOS.COMUNAS;   -- Debe retornar 346')
sql.append('SELECT c.id_comuna, c.nombre FROM USER_ENVIOS.COMUNAS c WHERE c.id_region IS NULL; -- Debe retornar 0')
sql.append('')

output_path = os.path.join(os.path.dirname(__file__), '06_catalogo_geografico.sql')
with open(output_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(sql))

print(f'Generado exitosamente {output_path} con {len(regions)} regiones y {len(comunas)} comunas.')
