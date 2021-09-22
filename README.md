# MySQL Database Renamer

In MySQL there is not a native way to rename a database (e.g. RENAME DATABASE mydb1 TO mydb2) so this command line tool is able to perform that action. The way it does it is by creating a new database schema and then shifting all of the database objects from the old schema to the new schema. This now is able to account for view dependency issues so all objects are accounted for.

## Supported Components

Red Hat / CentOS 7
MySQL 5.x

## Usage

```bash
./mysql_db_rename.sh oldSchemaName newSchemaName hostname username password
```