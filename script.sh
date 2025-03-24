#!/bin/bash

# Configuración
CONTAINER_SQL="SQL"  # Nombre del contenedor
DB_NAME="MalaPracticaAerolineas"  # Nombre de la base de datos
TIMESTAMP=$(date +%Y%m%d%H%M%S)  # Marca de tiempo única
BACKUP_FILE="backup_${TIMESTAMP}.bak"  # Archivo con nombre único
BACKUP_PATH="/var/opt/mssql/backup"  # Carpeta de backups en el contenedor
SA_PASSWORD="Dragon#8"
BACKUP_DIR="/c/Users/llll_/source/repos/CICD/Bakups"  # Nueva ruta para guardar en el host

# Crear la carpeta de backup dentro del contenedor
echo "=== Creando Carpeta de Backup en el Contenedor SQL ==="
docker exec $CONTAINER_SQL bash -c "mkdir -p $BACKUP_PATH && chmod 777 $BACKUP_PATH"

# Crear el backup en el contenedor SQL
echo "=== Creando Backup en el Contenedor SQL ==="
docker exec $CONTAINER_SQL bash -c "/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \"$SA_PASSWORD\" -Q \"BACKUP DATABASE [$DB_NAME] TO DISK = '$BACKUP_PATH/$BACKUP_FILE' WITH FORMAT, INIT, SKIP, STATS = 10;\""
if [ $? -ne 0 ]; then
    echo "Error: No se pudo crear el backup en $CONTAINER_SQL. Abortando..."
    exit 1
fi

# Copiar el backup al host en la carpeta Bakups
echo "=== Copiando Backup al Host ==="
docker cp $CONTAINER_SQL:$BACKUP_PATH/$BACKUP_FILE "$BACKUP_DIR/$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo "Error: No se pudo copiar el backup al host. Abortando..."
    exit 1
fi

echo "=== Backup Guardado Exitosamente en $BACKUP_DIR/$BACKUP_FILE ==="
