#!/bin/bash

# Configuración de contenedores y base de datos
CONTAINER_ORIG="SQL"
CONTAINER_COPY="SQLCICD"
DB_NAME="MalaPracticaAerolineas"
SA_PASSWORD="Dragon#8"
BACKUP_FILE="backup.bak"
BACKUP_PATH="/var/opt/mssql/backup"

echo "=== Iniciando ciclo automático de backup y restauración ==="

while true; do
    echo "=== Instalando herramientas SQL en el contenedor original ==="
    docker exec -u root $CONTAINER_ORIG bash -c "apt-get update && apt-get install -y mssql-tools unixodbc-dev"

    echo "=== Iniciando Backup del Contenedor Original (${CONTAINER_ORIG}) ==="
    docker exec $CONTAINER_ORIG /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "
    BACKUP DATABASE [$DB_NAME]
    TO DISK = '$BACKUP_PATH/$BACKUP_FILE'
    WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10;"

    if [ $? -ne 0 ]; then
        echo "Error: No se pudo crear el backup. Revisando logs..."
        docker logs $CONTAINER_ORIG
        exit 1
    fi

    echo "=== Copiando Backup fuera del contenedor ==="
    docker cp $CONTAINER_ORIG:$BACKUP_PATH/$BACKUP_FILE ./$BACKUP_FILE

    echo "=== Creando Nuevo Contenedor (${CONTAINER_COPY}) ==="
    docker run -e 'ACCEPT_EULA=Y' -e "SA_PASSWORD=$SA_PASSWORD" -p 1435:1433 --name $CONTAINER_COPY --memory 3g -d mcr.microsoft.com/mssql/server:2019-latest

    echo "=== Otorgando permisos al contenedor nuevo ==="
    docker exec -u root $CONTAINER_COPY chmod -R 777 /var/opt/mssql

    echo "=== Esperando que SQL Server en el nuevo contenedor se inicie... ==="
    MAX_RETRIES=60
    RETRIES=0
    until docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null || [ $RETRIES -eq $MAX_RETRIES ]
    do
        echo "Esperando a que SQL Server esté listo... Intento $((RETRIES+1))/$MAX_RETRIES"
        sleep 10
        RETRIES=$((RETRIES+1))
    done

    if [ $RETRIES -eq $MAX_RETRIES ]; then
        echo "Error: SQL Server no se inició correctamente. Revisando logs..."
        docker logs $CONTAINER_COPY
        exit 1
    fi

    echo "=== SQL Server Listo en el Nuevo Contenedor ==="
    docker exec $CONTAINER_COPY mkdir -p $BACKUP_PATH

    echo "=== Copiando Backup al Nuevo Contenedor ==="
    docker cp ./$BACKUP_FILE $CONTAINER_COPY:$BACKUP_PATH/$BACKUP_FILE

    echo "=== Restaurando la Base de Datos en el Nuevo Contenedor ==="
    docker exec $CONTAINER_COPY /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$SA_PASSWORD" -Q "
        RESTORE DATABASE [$DB_NAME]
        FROM DISK = '$BACKUP_PATH/$BACKUP_FILE'
        WITH MOVE '$DB_NAME' TO '/var/opt/mssql/data/$DB_NAME.mdf',
        MOVE '${DB_NAME}_log' TO '/var/opt/mssql/data/${DB_NAME}_log.ldf', REPLACE;"

    if [ $? -ne 0 ]; then
        echo "Error: No se pudo restaurar la base de datos. Revisando logs..."
        docker logs $CONTAINER_COPY
        exit 1
    fi

    echo "=== Eliminando Backup después de la Restauración ==="
    rm -f ./$BACKUP_FILE
    docker exec $CONTAINER_COPY rm -f $BACKUP_PATH/$BACKUP_FILE

    echo "=== Eliminando Contenedor (${CONTAINER_COPY}) ==="
    docker stop $CONTAINER_COPY || true
    docker rm $CONTAINER_COPY || true

    echo "=== Ciclo Completado. Esperando antes del próximo ciclo (60s) ==="
    sleep 60
done

