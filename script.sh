#!/bin/bash

# Nombre del contenedor original
CONTAINER_ORIG="SQL"
# Nombre del contenedor de respaldo
CONTAINER_COPY="SQLCICD"
# Nombre de la base de datos
DB_NAME="MalaPracticaAerolineas"

echo "=== Deteniendo y Eliminando Contenedor Existente (si aplica) ==="
docker stop $CONTAINER_COPY || true
docker rm $CONTAINER_COPY || true

echo "=== Iniciando Backup del Contenedor Original ==="
docker exec $CONTAINER_ORIG /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Dragon#8" -Q "BACKUP DATABASE [$DB_NAME] TO DISK = '/var/opt/mssql/backup/backup.bak'"

echo "=== Copiando Backup fuera del contenedor ==="
docker cp $CONTAINER_ORIG:/var/opt/mssql/backup/backup.bak ./backup.bak

echo "=== Creando Nuevo Contenedor ==="
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Dragon#8' -p 1435:1433 --name $CONTAINER_COPY -d mcr.microsoft.com/mssql/server:2019-latest

# Esperar a que SQL Server en el nuevo contenedor esté listo
echo "Esperando que SQL Server en el nuevo contenedor se inicie..."
until docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Dragon#8' -Q "SELECT 1" &> /dev/null
do
  echo "Esperando a que SQL Server esté listo..."
  sleep 5
done

echo "=== SQL Server Listo en el Nuevo Contenedor ==="

# Crear la carpeta de backup en el nuevo contenedor (si no existe)
echo "=== Creando carpeta de backup en el nuevo contenedor ==="
docker exec $CONTAINER_COPY mkdir -p /var/opt/mssql/backup

echo "=== Copiando Backup al Nuevo Contenedor ==="
docker cp ./backup.bak $CONTAINER_COPY:/var/opt/mssql/backup/backup.bak

echo "=== Restaurando Base de Datos en el Nuevo Contenedor ==="
docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Dragon#8" -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = '/var/opt/mssql/backup/backup.bak' WITH MOVE '$DB_NAME' TO '/var/opt/mssql/data/$DB_NAME.mdf', MOVE '${DB_NAME}_log' TO '/var/opt/mssql/data/${DB_NAME}_log.ldf'"

echo "=== Proceso Completado ==="
