load database
  from sqlite:///sourcedata/home-assistant_v2.db
  into postgresql://homeassistant:MySuperSecretPassword@migration-postgresql-testing:5432/homeassistant
  with data only, include drop, create tables, drop indexes, truncate, batch rows = 1000
  SET work_mem to '64 MB', maintenance_work_mem to '512 MB'
;
