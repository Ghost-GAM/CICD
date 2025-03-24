#!/bin/bash
# Configuración de contenedores y base de datos
CONTAINER_ORIG="SQL"
CONTAINER_COPY="SQLCICD"
DB_NAME="MalaPracticaAerolineas"
SA_PASSWORD="Dragon#8"
BACKUP_FILE="backup.bak"
BACKUP_PATH="/var/opt/mssql/backup"

echo "=== Iniciando ciclo de backup y restauración ==="

while true; do
    echo "=== Deteniendo y Eliminando Contenedor de Restauración (${CONTAINER_COPY}) ==="
    docker stop $CONTAINER_COPY || true
    docker rm $CONTAINER_COPY || true

    echo "=== Iniciando Backup del Contenedor Original (${CONTAINER_ORIG}) ==="
    docker exec $CONTAINER_ORIG /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "BACKUP DATABASE [$DB_NAME] TO DISK = '$BACKUP_PATH/$BACKUP_FILE'"

    echo "=== Copiando Backup fuera del contenedor ==="
    docker cp $CONTAINER_ORIG:$BACKUP_PATH/$BACKUP_FILE ./$BACKUP_FILE

    echo "=== Creando Nuevo Contenedor (${CONTAINER_COPY}) ==="
    docker run -e 'ACCEPT_EULA=Y' -e "SA_PASSWORD=$SA_PASSWORD" -p 1435:1433 --name $CONTAINER_COPY -d mcr.microsoft.com/mssql/server:2019-latest

    # Esperar a que SQL Server en el nuevo contenedor esté listo
    echo "=== Esperando que SQL Server en el nuevo contenedor se inicie... ==="
    until docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null
    do
      echo "Esperando a que SQL Server esté listo..."
      sleep 5
    done

    echo "=== SQL Server Listo en el Nuevo Contenedor ==="

    # Crear la carpeta de backup en el nuevo contenedor (si no existe)
    echo "=== Creando carpeta de backup en el nuevo contenedor ==="
    docker exec $CONTAINER_COPY mkdir -p $BACKUP_PATH

    echo "=== Copiando Backup al Nuevo Contenedor ==="
    docker cp ./$BACKUP_FILE $CONTAINER_COPY:$BACKUP_PATH/$BACKUP_FILE

    echo "=== Restaurando Base de Datos en el Nuevo Contenedor ==="
    docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "
        RESTORE DATABASE [$DB_NAME] 
        FROM DISK = '$BACKUP_PATH/$BACKUP_FILE' 
        WITH MOVE '$DB_NAME' TO '/var/opt/mssql/data/$DB_NAME.mdf', 
        MOVE '${DB_NAME}_log' TO '/var/opt/mssql/data/${DB_NAME}_log.ldf', REPLACE
    "

    echo "=== Eliminando Backup después de la Restauración ==="
    rm -f ./$BACKUP_FILE
    docker exec $CONTAINER_COPY rm -f $BACKUP_PATH/$BACKUP_FILE

    echo "=== Esperando antes del próximo ciclo (60s) ==="
    sleep 60
done
