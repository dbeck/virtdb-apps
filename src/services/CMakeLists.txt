MESSAGE(STATUS "cmake configure src/services/...")

SUBDIRS(
  common
  dummy_data
  dummy_db_config
  dummy_meta_data
  pg_db_config
  )

