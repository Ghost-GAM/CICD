#!/bin/bash

# Detener y eliminar el contenedor si ya existe
docker stop sqlserver-container || true
docker rm sqlserver-container || true

# Ejecutar un nuevo contenedor de SQL Server
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Dragon#8" \
  -p 1433:1433 --name SQLCICD \
  -d mcr.microsoft.com/mssql/server:2022-preview-ubuntu-22.04

# Esperar a que SQL Server esté listo
sleep 20

echo "Contenedor de SQL Server iniciado."

# Crear una base de datos de prueba
docker exec -i sqlserver-container /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Dragon#8' -Q "CREATE DATABASE TestDB"

# Crear un backup de la base de datos
docker exec -i sqlserver-container /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Dragon#8' -Q "BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/backup/TestDB.bak'"

echo "Backup de la base de datos realizado."


# Nombre del contenedor original
CONTAINER_ORIG="SQL"
# Nombre del contenedor de respaldo
CONTAINER_COPY="SQLCICD"
# Nombre de la base de datos
DB_NAME="MalaPracticaAerolineas"

echo "=== Iniciando Backup del Contenedor Original ==="
docker exec $CONTAINER_ORIG /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Dragon#8" -Q "BACKUP DATABASE [$DB_NAME] TO DISK = '/var/opt/mssql/backup/backup.bak'"

echo "=== Copiando Backup fuera del contenedor ==="
docker cp $CONTAINER_ORIG:/var/opt/mssql/backup/backup.bak ./backup.bak

echo "=== Eliminando Contenedor Anterior (si existe) ==="
docker stop $CONTAINER_COPY || true
docker rm $CONTAINER_COPY || true

echo "=== Creando Nuevo Contenedor ==="
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Dragon#8' -p 1435:1433 --name $CONTAINER_COPY -d mcr.microsoft.com/mssql/server:2019-latest

echo "=== Copiando Backup al Nuevo Contenedor ==="
docker cp ./backup.bak $CONTAINER_COPY:/var/opt/mssql/backup/backup.bak

echo "=== Restaurando Base de Datos en el Nuevo Contenedor ==="
docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Dragon#8" -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = '/var/opt/mssql/backup/backup.bak' WITH MOVE '$DB_NAME' TO '/var/opt/mssql/data/$DB_NAME.mdf', MOVE '${DB_NAME}_log' TO '/var/opt/mssql/data/${DB_NAME}_log.ldf'"

echo "=== Proceso Completado ==="
