declare @sql varchar(max) = ''

-- does a try-catch to obtain all modules that fail to compile/refresh
-- takes much longer to run than just refreshing without any error handling
-- took ~7 minutes 5 seconds for 807 modules
--select
--@sql += 'begin try exec sp_refreshsqlmodule ' + quotename(OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id), '''') + ' end try' + CHAR(13),
--@sql += 'begin catch print ' + quotename(OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) + ' failed to compile', '''') + ' end catch' + CHAR(13)
--from sys.sql_modules

-- refreshes modules directly
-- if one of them fails to compile, will throw an error
-- the last module printed is the one with the error
-- took ~1 minute 9 seconds for 799 modules (8 removed because they didn't compile)
select
@sql += 'print ' + quotename(OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id), '''') + CHAR(13),
@sql += 'exec sp_refreshsqlmodule ' + quotename(OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id), '''') + CHAR(13)
from sys.sql_modules
where OBJECT_NAME(object_id) not in ('GetMsrNlsExtract', 'CsvToTable', 'GetServicerPurchaseDetails', 'vwServicerPurchaserDetails', 'SplitStrings_Moden', 'BidCompare_SaveBidCompareSnapshot', 'vw_pipeline_schedule', 'vw_Daily_Warehouse_base_local')

exec (@sql)