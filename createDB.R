library(RSQLite);library(DBI)

# 1. create DB 
connectDB <- dbConnect(SQLite(), dbname = "testdb.sqlite")

# 2. create table 
DBI::dbExecute(connectDB, "CREATE TABLE test (
                                 id VARCHAR(20) PRIMARY KEY,
                                 pw VARCHAR(20))")
